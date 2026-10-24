'use strict';
const {test, before, beforeEach, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc, collection, query, where, getDocs} = require('firebase/firestore');
const {getFirestore} = require('firebase-admin/firestore');
const {seed} = require('../../scripts/seed-emulator.cjs');
let env, db, service;
const projectId = process.env.GCLOUD_PROJECT || 'demo-zoostudy-test';
const request = (uid, data = {}) => ({auth: uid ? {uid} : null, data});
const publishData = key => ({requestId: key, subject: 'english', title: '復習', description: '単語を書いてください', dueAt: '2026-01-01T00:00:00.000Z'});
const create = async key => (await service.publishAssignment(request('teacher_a', publishData(key)))).assignmentId;
const submit = (assignmentId, requestId = 'submit-a', uid = 'student_a', answerText = '回答') => service.submitAssignment(request(uid, {assignmentId, requestId, answerText}));
const review = (assignmentId, approve = true, requestId = 'review-a', version = 1, uid = 'teacher_a', studentId = 'student_a') =>
  service.reviewSubmission(request(uid, {assignmentId, studentId, approve, requestId, expectedVersion: version, feedback: '確認しました'}));
const denied = error => ['permission-denied', 'unauthenticated', 'failed-precondition', 'invalid-argument', 'already-exists', 'resource-exhausted'].includes(error.code);

before(async () => {
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  env = await initializeTestEnvironment({projectId, firestore: {host, port: Number(port), rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8')}});
  await seed(); db = getFirestore(); service = require('../service').createService(db);
});
beforeEach(async () => { await env.clearFirestore(); await seed(); });
after(async () => { await env.cleanup(); });

test('concurrent submit and approval grant exactly 30 then 70; replay cannot reopen reviewed work', async () => {
  const assignmentId = await create('create-a');
  await Promise.all(Array.from({length: 5}, () => submit(assignmentId)));
  assert.equal((await db.doc('zoos/student_a').get()).data().coins, 30);
  const s = (await db.doc(`submissions/${assignmentId}_student_a`).get()).data();
  assert.equal(s.status, 'pending_review'); assert.equal(s.revisionCount, 0);
  assert.ok(s.submittedAt.toMillis() > Date.parse('2026-01-01'));
  await Promise.all(Array.from({length: 5}, () => review(assignmentId)));
  assert.equal((await db.doc('zoos/student_a').get()).data().coins, 100);
  assert.equal((await db.collection('rewardTransactions').get()).size, 2);
  await submit(assignmentId); // Same request replay returns its prior result without changing state.
  assert.equal((await db.doc(`submissions/${assignmentId}_student_a`).get()).data().status, 'approved');
  await assert.rejects(submit(assignmentId, 'new-submit'), denied);
});

test('revision grants no extra submit coins; stale approval is rejected', async () => {
  const assignmentId = await create('create-b');
  await submit(assignmentId);
  await review(assignmentId, false);
  await submit(assignmentId); // Lost-response retry of initial submit must not count as resubmission.
  assert.equal((await db.doc(`submissions/${assignmentId}_student_a`).get()).data().status, 'needs_revision');
  await submit(assignmentId, 'resubmit', 'student_a', '修正した回答');
  assert.equal((await db.doc('zoos/student_a').get()).data().coins, 30);
  await assert.rejects(review(assignmentId, true, 'stale-approval', 1), denied);
  await review(assignmentId, true, 'fresh-approval', 3);
  assert.equal((await db.doc('zoos/student_a').get()).data().coins, 100);
  assert.equal((await db.doc(`submissions/${assignmentId}_student_a`).get()).data().revisionCount, 1);
});

test('server validates role, tenant, target student, unpublished tasks and input', async () => {
  const assignmentId = await create('create-c');
  await assert.rejects(submit(assignmentId, 'bad-role', 'teacher_a'), denied);
  await assert.rejects(submit(assignmentId, 'bad-tenant', 'student_other'), denied);
  await assert.rejects(submit(assignmentId, 'blank', 'student_a', '  '), denied);
  await assert.rejects(submit(assignmentId, 'long', 'student_a', 'a'.repeat(5001)), denied);
  await assert.rejects(review(assignmentId), denied);
  await submit(assignmentId);
  await assert.rejects(review(assignmentId, true, 'wrong-teacher', 1, 'teacher_other'), denied);
  await assert.rejects(review(assignmentId, true, 'wrong-student', 1, 'teacher_a', 'student_other'), denied);
  await assert.rejects(service.publishAssignment(request('student_a', publishData('student-publish'))), denied);
  await assert.rejects(service.sessionInfo(request(null)), denied);
  await db.doc(`assignments/${assignmentId}`).update({status: 'closed'});
  await assert.rejects(submit(assignmentId, 'closed', 'student_b'), denied);
});

test('publishing retries are idempotent and student wallets stay separate', async () => {
  const results = await Promise.all(Array.from({length: 4}, () => service.publishAssignment(request('teacher_a', publishData('same-publish')))));
  assert.equal(new Set(results.map(r => r.assignmentId)).size, 1);
  assert.equal((await db.collection('assignments').get()).size, 1);
  await submit(results[0].assignmentId);
  assert.equal((await db.doc('zoos/student_a').get()).data().coins, 30);
  assert.equal((await db.doc('zoos/student_b').get()).data().coins, 0);
  const context = await service.sessionInfo(request('teacher_a'));
  assert.equal(context.students.length, 2);
});

test('purchase uses server price, validates unlocks and survives repeated requests', async () => {
  const assignmentId = await create('create-d');
  await submit(assignmentId); await review(assignmentId);
  const buy = (requestId, itemId, uid = 'student_a') => service.purchaseItem(request(uid, {requestId, itemId, price: 0, coins: 999999}));
  await assert.rejects(buy('no-balance', 'fox'), denied);
  await assert.rejects(buy('locked', 'deer'), denied);
  await assert.rejects(buy('teacher-buy', 'rabbit', 'teacher_a'), denied);
  await Promise.all(Array.from({length: 4}, () => buy('rabbit-once', 'rabbit')));
  const zoo = (await db.doc('zoos/student_a').get()).data();
  assert.equal(zoo.coins, 0); assert.deepEqual(zoo.ownedAnimalIds, ['rabbit']);
  await assert.rejects(buy('rabbit-once', 'fox'), denied);
  await assert.rejects(buy('rabbit-again', 'rabbit'), denied);
  assert.deepEqual(require('../catalog.json'), JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/zoo/shop_catalog.json'), 'utf8').replace(/^\uFEFF/, '')));
});

test('Security Rules prevent client coin, role and submission writes and cross-tenant reads', async () => {
  const assignmentId = await create('create-rules'); await submit(assignmentId);
  const student = env.authenticatedContext('student_a').firestore();
  const other = env.authenticatedContext('student_other').firestore();
  const teacher = env.authenticatedContext('teacher_a').firestore();
  const anonymous = env.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(student, 'assignments', assignmentId)));
  await assertSucceeds(getDoc(doc(student, 'submissions', `${assignmentId}_student_a`)));
  await assertSucceeds(getDocs(query(collection(student, 'assignments'), where('classId', '==', 'class_a'), where('organizationId', '==', 'org_a'), where('status', '==', 'published'))));
  await assertSucceeds(getDocs(query(collection(student, 'submissions'), where('classId', '==', 'class_a'), where('organizationId', '==', 'org_a'), where('studentId', '==', 'student_a'))));
  await assertSucceeds(getDocs(query(collection(student, 'rewardTransactions'), where('classId', '==', 'class_a'), where('organizationId', '==', 'org_a'), where('studentId', '==', 'student_a'))));
  await assertSucceeds(getDocs(query(collection(teacher, 'submissions'), where('classId', '==', 'class_a'), where('organizationId', '==', 'org_a'))));
  await assertFails(getDoc(doc(other, 'assignments', assignmentId)));
  await assertFails(getDoc(doc(anonymous, 'assignments', assignmentId)));
  await assertFails(getDoc(doc(student, 'zoos', 'student_b')));
  await assertFails(getDoc(doc(env.authenticatedContext('student_b').firestore(), 'submissions', `${assignmentId}_student_a`)));
  await assertFails(updateDoc(doc(student, 'zoos', 'student_a'), {coins: 9999}));
  await assertFails(updateDoc(doc(student, 'classMemberships', 'class_a_student_a'), {role: 'teacher'}));
  await assertFails(setDoc(doc(student, 'rewardTransactions', 'forged'), {studentId: 'student_a', amount: 9999}));
  await assertFails(updateDoc(doc(teacher, 'submissions', `${assignmentId}_student_a`), {status: 'approved'}));
});

test('real callable endpoint binds Firebase Auth token to server membership', async () => {
  const signin = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key`,
    {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({email: 'student@example.test', password: 'ZooStudyDemo123!', returnSecureToken: true})});
  const token = (await signin.json()).idToken; assert.ok(token);
  const url = `http://127.0.0.1:5001/${projectId}/asia-northeast1/sessionInfo`;
  const response = await fetch(url, {method: 'POST', headers: {'Content-Type': 'application/json', Authorization: `Bearer ${token}`}, body: JSON.stringify({data: {role: 'teacher'}})});
  const body = await response.json(); assert.equal(response.status, 200); assert.equal(body.result.role, 'student');
  const deniedResponse = await fetch(url, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({data: {}})});
  assert.equal(deniedResponse.status, 401);
});

