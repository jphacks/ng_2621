'use strict';
const {test, before, beforeEach, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {createHash} = require('node:crypto');
const {getStorage} = require('firebase-admin/storage');
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
  env = await initializeTestEnvironment({projectId, firestore: {host, port: Number(port), rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8')}, storage: {host: '127.0.0.1', port: 9199, rules: fs.readFileSync(path.join(__dirname, '../../storage.rules'), 'utf8')}});
  await seed(); db = getFirestore(); service = require('../service').createService(db);
});
beforeEach(async () => { await env.clearFirestore(); await env.clearStorage(); await seed(); });
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


test('file-only submission, immutable uploads, teacher access and peer isolation', async () => {
  const assignmentId = await create('file-task');
  const bytes = Buffer.from('%PDF-1.4\n1 0 obj\n<<>>\nendobj\n%%EOF');
  const hash = createHash('sha256').update(bytes).digest('hex');
  const storagePath = `submissionFiles/org_a/class_a/${assignmentId}/student_a/${hash}.pdf`;
  const owner = env.authenticatedContext('student_a').storage(`gs://${projectId}.appspot.com`).ref(storagePath);
  await assertSucceeds(owner.put(bytes, {contentType: 'application/pdf'}));
  const metadata = await owner.getMetadata();
  const attachment = {id: hash, name: 'homework.pdf', size: bytes.length, contentType: 'application/pdf', storagePath, generation: metadata.generation};
  const input = request('student_a', {assignmentId, requestId: 'files-only', answerText: '', attachments: [attachment]});
  await Promise.all([service.submitAssignment(input), service.submitAssignment(input)]);
  assert.equal((await db.doc('zoos/student_a').get()).data().coins, 30);
  const saved = (await db.doc(`submissions/${assignmentId}_student_a`).get()).data();
  assert.equal(saved.attachments[0].storagePath, storagePath);
  assert.equal(saved.answerText, '');
  await assertSucceeds(env.authenticatedContext('teacher_a').storage(`gs://${projectId}.appspot.com`).ref(storagePath).getMetadata());
  await assertFails(env.authenticatedContext('student_b').storage(`gs://${projectId}.appspot.com`).ref(storagePath).getMetadata());
  await assertFails(env.authenticatedContext('teacher_other').storage(`gs://${projectId}.appspot.com`).ref(storagePath).getMetadata());
  await assertFails(owner.put(bytes, {contentType: 'application/pdf'}));
  await assertFails(owner.delete());
  await review(assignmentId);
  assert.equal((await db.doc('zoos/student_a').get()).data().coins, 100);
});

test('unuploaded, forged, oversized and cross-user files cannot earn a reward', async () => {
  const assignmentId = await create('bad-file-task');
  const bytes = Buffer.from('%PDF-1.4\n%%EOF');
  const hash = createHash('sha256').update(bytes).digest('hex');
  const storagePath = `submissionFiles/org_a/class_a/${assignmentId}/student_a/${hash}.pdf`;
  const attachment = {id: hash, name: 'homework.pdf', size: bytes.length, contentType: 'application/pdf', storagePath};
  const send = (file, key) => service.submitAssignment(request('student_a', {assignmentId, requestId: key, answerText: '', attachments: [file]}));
  await assert.rejects(send(attachment, 'missing-file'), denied);
  await assert.rejects(send({...attachment, storagePath: storagePath.replace('/student_a/', '/student_b/')}, 'stolen-file'), denied);
  await assert.rejects(send({...attachment, size: 10 * 1024 * 1024 + 1}, 'huge-file'), denied);
  const owner = env.authenticatedContext('student_a').storage(`gs://${projectId}.appspot.com`).ref(storagePath);
  await assertFails(owner.put(Buffer.alloc(10 * 1024 * 1024 + 1), {contentType: 'application/pdf'}));
  await assertFails(owner.put(bytes, {contentType: 'application/javascript'}));
  // A client can lie about MIME; the trusted submission function checks actual bytes and hash.
  await owner.put(Buffer.from('NOT A PDF'), {contentType: 'application/pdf'});
  await assert.rejects(send({...attachment, size: 9}, 'forged-content'), denied);
  assert.equal((await db.doc('zoos/student_a').get()).data()?.coins ?? 0, 0);
  assert.equal((await db.collection('submissions').get()).size, 0);
});

test('study records are immutable, idempotent, reward-free and readable only by owner or class teacher', async () => {
  const record = {id: 'study-1', startedAt: new Date(Date.now() - 20000).toISOString(),
    elapsedMs: 20000, samples: 2, mode: 'face', subject: '数学', completed: true,
    stateMs: {studying: 0, facePosture: 3000, faceCheck: 0, material: 0, device: 0, unknown: 2000, suspended: 15000},
    studentId: 'student_other', studentName: '偽名', rawFrame: 'must-not-be-stored'};
  await Promise.all(Array.from({length: 4}, () => service.saveStudySession(request('student_a', {record}))));
  assert.equal((await db.collection('studySessions').get()).size, 1);
  const saved = (await db.doc('studySessions/student_a_study-1').get()).data();
  assert.equal(saved.studentId, 'student_a');
  assert.notEqual(saved.studentName, '偽名');
  assert.equal(saved.record.rawFrame, undefined);
  assert.equal((await db.doc('zoos/student_a').get()).data()?.coins ?? 0, 0);
  assert.equal((await db.collection('rewardTransactions').get()).size, 0);
  const owner = env.authenticatedContext('student_a').firestore();
  const teacher = env.authenticatedContext('teacher_a').firestore();
  const peer = env.authenticatedContext('student_b').firestore();
  const other = env.authenticatedContext('teacher_other').firestore();
  const key = 'student_a_study-1';
  await assertSucceeds(getDoc(doc(owner, 'studySessions', key)));
  await assertSucceeds(getDoc(doc(teacher, 'studySessions', key)));
  await assertSucceeds(getDocs(query(collection(teacher, 'studySessions'), where('classId', '==', 'class_a'), where('organizationId', '==', 'org_a'))));
  await assertSucceeds(getDocs(query(collection(owner, 'studySessions'), where('classId', '==', 'class_a'), where('organizationId', '==', 'org_a'), where('studentId', '==', 'student_a'))));
  await assertFails(getDoc(doc(peer, 'studySessions', key)));
  await assertFails(getDoc(doc(other, 'studySessions', key)));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'studySessions', key)));
  await assertFails(setDoc(doc(owner, 'studySessions', 'forged'), {...saved, receivedAt: new Date()}));
  await assertFails(updateDoc(doc(teacher, 'studySessions', key), {record: {}}));
  await assert.rejects(service.saveStudySession(request('student_a', {record: {...record, subject: '英語'}})), denied);
  await assert.rejects(service.saveStudySession(request('teacher_a', {record})), denied);
});

test('malformed study statistics and future time are rejected before persistence', async () => {
  const record = {id: 'study-invalid', startedAt: new Date(Date.now() - 20000).toISOString(),
    elapsedMs: 20000, samples: 2, mode: 'desk', subject: '数学', completed: false,
    stateMs: {studying: 3000, facePosture: 0, faceCheck: 0, material: 0, device: 0, unknown: 2000, suspended: 15000}};
  for (const bad of [
    {...record, elapsedMs: -1}, {...record, elapsedMs: 86400001},
    {...record, stateMs: {...record.stateMs, unknown: 0}}, {...record, mode: 'face'},
    {...record, startedAt: new Date(Date.now() + 86400000).toISOString()},
    {...record, samples: -1}, {...record, id: '../wrong'},
  ]) await assert.rejects(service.saveStudySession(request('student_a', {record: bad})), denied);
  await assert.rejects(service.saveStudySession(request(null, {record})), denied);
  assert.equal((await db.collection('studySessions').get()).size, 0);
});
