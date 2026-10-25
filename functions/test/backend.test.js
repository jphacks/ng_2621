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

function rewardedRecord(id, seconds, start) {
  const at = start || new Date(Date.now() - 86400000 * 2).toISOString().slice(0,10) + 'T10:00:00+09:00';
  const date = new Date(at);
  const day = new Date(date.getTime() + 32400000).toISOString().slice(0,10);
  return {id, startedAt: date.toISOString(), mode:'desk', subject:'数学', completed:true,
    elapsedMs:seconds*1000, samples:seconds, rewardPolicyVersion:2, rewardMsByDay:{[day]:seconds*1000},
    stateMs:{studying:0,facePosture:0,faceCheck:0,material:seconds*1000,device:0,unknown:0,suspended:0}};
}
test('study rewards carry partial minutes, replay safely and cap concurrently at 30 per JST day', async()=>{
  const save = record => service.saveStudySession(request('student_a',{record}));
  assert.equal((await save(rewardedRecord('short-a',60))).rewardAmount,0);
  assert.equal((await save(rewardedRecord('short-b',60))).rewardAmount,1);
  await Promise.all(Array.from({length:4},()=>save(rewardedRecord('short-b',60))));
  assert.equal((await db.doc('zoos/student_a').get()).data().coins,1);
  await Promise.all(['long-a','long-b','long-c','long-d'].map(id=>save(rewardedRecord(id,1200))));
  assert.equal((await db.doc('zoos/student_a').get()).data().coins,30);
  assert.equal((await db.collection('studyDailyRewards').get()).docs[0].data().coinsGranted,30);
  const today = new Date(Date.now()-86400000).toISOString().slice(0,10)+'T10:00:00+09:00';
  assert.equal((await save(rewardedRecord('next-day',120,today))).rewardAmount,1);
  assert.equal((await db.doc('zoos/student_a').get()).data().coins,31);
  const peer=await service.saveStudySession(request('student_b',{record:rewardedRecord('peer',120)}));
  assert.equal(peer.rewardAmount,1);
  assert.equal((await db.doc('zoos/student_b').get()).data().coins,1);
});
test('reward bucket forgery and rewards without fresh samples are rejected', async()=>{
  const record=rewardedRecord('bad-reward',120);
  for(const bad of [
    {...record,rewardMsByDay:{'2026-02-30':120000}},
    {...record,rewardMsByDay:{'2000-01-01':120000}},
    {...record,samples:0},
    {...record,rewardMsByDay:{[Object.keys(record.rewardMsByDay)[0]]:120001}},
    {...record,rewardPolicyVersion:99},
  ]) await assert.rejects(service.saveStudySession(request('student_a',{record:bad})),denied);
  const client=env.authenticatedContext('student_a').firestore();
  await assertFails(setDoc(doc(client,'studyDailyRewards','student_a_fake'),{eligibleMs:999999999,coinsGranted:30}));
});


test('advice drafts remain teacher-only; approved message is scoped and immutable', async () => {
  const calls = [];
  const adviceService = require('../service').createService(db, {
    generateAdvice: async data => { calls.push(data); return {summary:'記録不足です',teacherNote:'本人に確認してください',message:'こまったことはあるかな？'}; }
  });
  const data = {studentId:'student_a',requestId:'advice-one'};
  await assert.rejects(adviceService.generateStudyAdvice(request('student_a',data)),denied);
  await assert.rejects(adviceService.generateStudyAdvice(request('teacher_other',data)),denied);
  const {advice:a} = await adviceService.generateStudyAdvice(request('teacher_a',data));
  await adviceService.generateStudyAdvice(request('teacher_a',data));
  assert.equal(calls.length,1);
  assert.equal((await db.collection('studyAdvice').get()).size,0);
  const owner=env.authenticatedContext('student_a').firestore();
  const peer=env.authenticatedContext('student_b').firestore();
  const teacher=env.authenticatedContext('teacher_a').firestore();
  await assertFails(getDoc(doc(owner,'studyAdviceDrafts',a.id)));
  await assertSucceeds(getDoc(doc(teacher,'studyAdviceDrafts',a.id)));
  const send={adviceId:a.id,message:'編集した文章'};
  await assert.rejects(adviceService.publishStudyAdvice(request('student_a',send)),denied);
  await assert.rejects(adviceService.publishStudyAdvice(request('teacher_other',send)),denied);
  await adviceService.publishStudyAdvice(request('teacher_a',send));
  await adviceService.publishStudyAdvice(request('teacher_a',send));
  await assert.rejects(adviceService.publishStudyAdvice(request('teacher_a',{...send,message:'変更'})),denied);
  const publicDoc=(await assertSucceeds(getDoc(doc(owner,'studyAdvice',a.id)))).data();
  assert.equal(publicDoc.message,'編集した文章'); assert.equal(publicDoc.teacherNote,''); assert.ok(!publicDoc.aggregate);
  await assertSucceeds(getDocs(query(collection(owner,'studyAdvice'),where('classId','==','class_a'),where('organizationId','==','org_a'),where('studentId','==','student_a'),where('status','==','published'))));
  await assertFails(getDoc(doc(peer,'studyAdvice',a.id)));
  await assertFails(setDoc(doc(owner,'studyAdvice','forged'),publicDoc));
  await assertFails(updateDoc(doc(teacher,'studyAdviceDrafts',a.id),{status:'published'}));
});

test('student invitation registration is atomic, repeatable, limited and cannot grant teacher role', async () => {
  const {invitationHash} = require('../accounts');
  const code = '1234567890abcdef1234567890abcdef';
  const invite = db.doc(`classInvitations/${invitationHash(code)}`);
  await invite.set({organizationId: 'org_a', classId: 'class_a', role: 'student', expiresAt: require('firebase-admin/firestore').Timestamp.fromMillis(Date.now() + 60000), maxUses: 1, useCount: 0});
  await Promise.all(Array.from({length: 3}, () => service.joinClass(request('new_student', {displayName: '新しい生徒', invitationCode: code, role: 'teacher', coins: 9999}))));
  assert.equal((await db.doc('users/new_student').get()).data().displayName, '新しい生徒');
  assert.equal((await db.doc('classMemberships/class_a_new_student').get()).data().role, 'student');
  assert.equal((await db.doc('zoos/new_student').get()).data().coins, 0);
  assert.equal((await invite.get()).data().useCount, 1);
  await assert.rejects(service.joinClass(request('new_other', {displayName: '別の生徒', invitationCode: code})), denied);
  await assert.rejects(service.joinClass(request(null, {displayName: '生徒', invitationCode: code})), denied);
  await assert.rejects(service.joinClass(request('student_a', {displayName: '所属変更', invitationCode: code})), denied);
  await assert.rejects(service.joinClass(request('new_other', {displayName: ' ', invitationCode: code})), denied);
  await invite.update({maxUses: 10, role: 'teacher'});
  await assert.rejects(service.joinClass(request('new_other', {displayName: '先生化', invitationCode: code})), denied);
  await invite.update({role: 'student', classId: 123});
  await assert.rejects(service.joinClass(request('new_other', {displayName: '設定不正', invitationCode: code})), denied);
  await invite.update({classId: 'class_a'});
  await invite.update({role: 'student', expiresAt: require('firebase-admin/firestore').Timestamp.fromMillis(0)});
  await assert.rejects(service.joinClass(request('new_other', {displayName: '期限切れ', invitationCode: code})), denied);
});

test('account game layout charges atomically, retains ownership and rejects conflicting replay', async () => {
  await db.doc('zoos/student_a').set({organizationId: 'org_a', classId: 'class_a', studentId: 'student_a', revision: 1, coins: 2000, ownedAnimalIds: [], ownedFacilityIds: []});
  const edit = (requestId, layoutEdit, uid = 'student_a') => service.purchaseItem(request(uid, {requestId, itemId: 'zoo_layout', layoutEdit}));
  const pen = {kind: 'enclosure', id: 'p1', left: 0, top: 0, width: 4, height: 4};
  const receipts = await Promise.all(Array.from({length: 4}, () => edit('pen', pen)));
  assert.equal(receipts[0].price, 80);
  assert.equal((await db.doc('zoos/student_a').get()).data().coins, 1920);
  assert.equal((await edit('expand', {...pen, width: 5})).price, 20);
  await assert.rejects(edit('pen', {...pen, left: 1}), error => error.code === 'already-exists' && error.details.purchaseFailure === 'requestConflict');
  await assert.rejects(edit('shrink', {...pen, width: 3}), denied);
  await assert.rejects(edit('road', {...pen, id: 'p2', left: 8}), denied);
  await assert.rejects(edit('assign', {kind: 'assignAnimal', id: 'rabbit', enclosureId: 'p1'}), denied);
  await service.purchaseItem(request('student_a', {requestId: 'rabbit', itemId: 'rabbit'}));
  await edit('assign', {kind: 'assignAnimal', id: 'rabbit', enclosureId: 'p1'});
  await service.purchaseItem(request('student_a', {requestId: 'lab', itemId: 'laboratory'}));
  await edit('place-lab', {kind: 'facility', id: 'laboratory', left: 11, top: 0});
  await assert.rejects(edit('overlap-lab', {...pen, id: 'p3', left: 11}), denied);
  await assert.rejects(edit('move-lab-pen', {kind: 'facility', id: 'laboratory', left: 1, top: 1}), denied);
  await assert.rejects(edit('teacher-layout', pen, 'teacher_a'), denied);
  const saved = (await db.doc('zoos/student_a').get()).data();
  assert.equal(saved.coins, 1400);
  assert.equal(saved.layout.animalEnclosures.rabbit, 'p1');
  assert.equal(saved.layout.facilities[0].facilityId, 'laboratory');
  assert.deepEqual(saved.ownedAnimalIds, ['rabbit']);
  // The existing study reward transaction must preserve layout and purchases.
  await Promise.all([
    service.saveStudySession(request('student_a', {record: rewardedRecord('account-keep', 120)})),
    service.purchaseItem(request('student_a', {requestId: 'concurrent-fox', itemId: 'fox'})),
    edit('concurrent-move', {kind: 'facility', id: 'laboratory', left: 15, top: 5}),
  ]);
  // A new server read restores both concurrent writes without overwriting layout.
  const restored = (await db.doc('zoos/student_a').get()).data();
  assert.equal(restored.coins, 1151);
  assert.deepEqual(new Set(restored.ownedAnimalIds), new Set(['rabbit', 'fox']));
  assert.deepEqual(restored.layout.enclosures, saved.layout.enclosures);
  assert.deepEqual(restored.layout.animalEnclosures, saved.layout.animalEnclosures);
  assert.deepEqual(restored.layout.facilities, [{facilityId: 'laboratory', left: 15, top: 5}]);
});

test('account settings and zoo data are isolated; wallet and roles remain server-only', async () => {
  const student = env.authenticatedContext('student_a').firestore();
  const otherDevice = env.authenticatedContext('student_a').firestore();
  const other = env.authenticatedContext('student_b').firestore();
  const guest = env.unauthenticatedContext().firestore();
  await assertSucceeds(setDoc(doc(student, 'gamePreferences/student_a'), {goalId: 'fox', seen: ['study:s1']}));
  assert.equal((await assertSucceeds(getDoc(doc(otherDevice, 'gamePreferences/student_a')))).data().goalId, 'fox');
  await assertFails(getDoc(doc(other, 'gamePreferences/student_a')));
  await assertFails(getDoc(doc(guest, 'gamePreferences/student_a')));
  await assertFails(setDoc(doc(student, 'gamePreferences/student_b'), {goalId: null, seen: []}));
  await assertFails(setDoc(doc(student, 'gamePreferences/student_a'), {goalId: 'fox', seen: [], coins: 9999}));
  await assertFails(setDoc(doc(student, 'users/student_a'), {role: 'teacher'}));
  await assertFails(setDoc(doc(student, 'zoos/student_a'), {coins: 9999}));
  await assertFails(getDoc(doc(other, 'zoos/student_a')));
  await assertFails(getDocs(collection(student, 'classInvitations')));
});

test('server game catalog and map match the shipped Flutter assets', () => {
  assert.deepEqual(require('../catalog.json'), JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/zoo/shop_catalog.json'), 'utf8')));
  assert.deepEqual(require('../game_world.json'), JSON.parse(fs.readFileSync(path.join(__dirname, '../../assets/zoo/world.json'), 'utf8')));
});

test('Auth signup and callable invitation enrollment create a restorable zero-coin account', async () => {
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const email = `new-${Date.now()}@example.test`;
  const signup = await fetch(`http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key`, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({email, password: 'ZooStudyDemo123!', returnSecureToken: true})});
  assert.equal(signup.status, 200);
  const account = await signup.json();
  const response = await fetch(`http://127.0.0.1:5001/${projectId}/asia-northeast1/joinClass`, {method: 'POST', headers: {'Content-Type': 'application/json', Authorization: `Bearer ${account.idToken}`}, body: JSON.stringify({data: {displayName: '登録テスト', invitationCode: '0123456789abcdef0123456789abcdef'}})});
  assert.equal(response.status, 200, JSON.stringify(await response.clone().json()));
  assert.equal((await service.sessionInfo(request(account.localId))).displayName, '登録テスト');
  const login = await fetch(`http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key`, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({email, password: 'ZooStudyDemo123!', returnSecureToken: true})});
  assert.equal((await login.json()).localId, account.localId);
  assert.equal((await db.doc(`zoos/${account.localId}`).get()).data().coins, 0);
});

test('enrollment respects the same 100-student class limit as assignment publishing', async () => {
  const batch = db.batch();
  for (let i = 0; i < 98; i++) batch.set(db.doc(`classMemberships/class_a_filled_${i}`), {organizationId: 'org_a', classId: 'class_a', userId: `filled_${i}`, role: 'student'});
  await batch.commit();
  await assert.rejects(service.joinClass(request('over_capacity', {displayName: '上限テスト', invitationCode: '0123456789abcdef0123456789abcdef'})), error => error.code === 'resource-exhausted');
  assert.equal((await db.doc('users/over_capacity').get()).exists, false);
});



test('teacher creates classes and email-free students; custom token restores the same UID after reissue', async () => {
  const classroom = await service.createManagedClass(request('teacher_a',{name:'ひまわり組',requestId:'room-one'}));
  assert.match(classroom.prefix,/^[2-9A-HJ-NP-Z]{6}$/);
  assert.deepEqual(await service.createManagedClass(request('teacher_a',{name:'ひまわり組',requestId:'room-one'})),classroom);
  const roster = await service.listManagedClasses(request('teacher_a'));
  assert.ok(roster.classes.some(c=>c.id===classroom.classId));
  const data = {classId:classroom.classId,name:'はなこ',requestId:'student-one'};
  const issued = await service.createManagedStudent(request('teacher_a',data));
  assert.match(issued.loginCode,/^[2-9A-HJ-NP-Z]{6}(-[2-9A-HJ-NP-Z]{4}){4}$/);
  assert.ok(issued.loginCode.startsWith(classroom.prefix+'-'));
  const retry = await service.createManagedStudent(request('teacher_a',data));
  assert.equal(retry.studentId,issued.studentId); assert.equal(retry.loginCode,null);
  assert.equal((await db.collection('classMemberships').where('classId','==',classroom.classId).where('role','==','student').get()).size,1);
  const login = code => service.loginWithStudentCode({data:{code},rawRequest:{ip:'127.0.0.11'}});
  const loginResponse=await fetch('http://127.0.0.1:5001/'+projectId+'/asia-northeast1/loginWithStudentCode',{
    method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({data:{code:issued.loginCode.toLowerCase()}})});
  const loginBody=await loginResponse.json(); assert.equal(loginResponse.status,200,JSON.stringify(loginBody));
  const {token}=loginBody.result;
  const signIn=await fetch('http://'+process.env.FIREBASE_AUTH_EMULATOR_HOST+'/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=demo-key',{
    method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token,returnSecureToken:true})});
  assert.equal(signIn.status,200,JSON.stringify(await signIn.clone().json()));
  const auth=await signIn.json();
  const verified=await require('firebase-admin/auth').getAuth().verifyIdToken(auth.idToken);
  assert.equal(verified.uid,issued.studentId);
  assert.equal((await service.sessionInfo(request(verified.uid))).role,'student');
  await service.saveStudySession(request(issued.studentId,{record:rewardedRecord('code-study',120)}));
  assert.equal((await db.doc('zoos/'+issued.studentId).get()).data().coins,1);
  const replacement=await service.reissueStudentCode(request('teacher_a',{classId:classroom.classId,studentId:issued.studentId,requestId:'replace-one'}));
  assert.notEqual(replacement.loginCode,issued.loginCode);
  await assert.rejects(login(issued.loginCode),denied);
  await login(replacement.loginCode);
  assert.equal((await db.doc('zoos/'+issued.studentId).get()).data().coins,1);
  assert.equal((await db.collection('studySessions').where('studentId','==',issued.studentId).get()).size,1);
  const student=env.authenticatedContext(issued.studentId).firestore();
  const teacher=env.authenticatedContext('teacher_a').firestore();
  const privateDoc=(await db.doc('studentCodeAccounts/'+issued.studentId).get()).data();
  assert.ok(!JSON.stringify(privateDoc).includes(replacement.loginCode));
  await assertFails(getDoc(doc(student,'studentCodeAccounts',issued.studentId)));
  await assertFails(getDoc(doc(teacher,'studentLoginCodes',privateDoc.codeHash)));
  await assertFails(setDoc(doc(student,'studentLoginCodes','forged'),{studentId:'teacher_a'}));
  await service.selectManagedClass(request('teacher_a',{classId:classroom.classId}));
  const teacherContext=await service.sessionInfo(request('teacher_a'));
  assert.equal(teacherContext.classId,classroom.classId);
  assert.ok(teacherContext.students.some(s=>s.id===issued.studentId));
});

test('student code administration rejects student privileges, other classes and teacher targets', async () => {
  await assert.rejects(service.createManagedClass(request('student_a',{name:'勝手なクラス',requestId:'bad'})),denied);
  await assert.rejects(service.listManagedClasses(request(null)),denied);
  await assert.rejects(service.selectManagedClass(request('teacher_a',{classId:'class_other'})),denied);
  await assert.rejects(service.createManagedStudent(request('teacher_other',{classId:'class_a',name:'生徒',requestId:'bad-student'})),denied);
  await assert.rejects(service.listManagedStudents(request('teacher_other',{classId:'class_a'})),denied);
  await assert.rejects(service.reissueStudentCode(request('teacher_a',{classId:'class_a',studentId:'teacher_a',requestId:'teacher-code'})),denied);
  await assert.rejects(service.reissueStudentCode(request('student_a',{classId:'class_a',studentId:'student_a',requestId:'self-code'})),denied);
  await assert.rejects(service.loginWithStudentCode({data:{code:'bad'},rawRequest:{ip:'127.0.0.12'}}),denied);
  const roster = await service.listManagedStudents(request('teacher_a',{classId:'class_a'}));
  assert.equal(roster.students.length,2); assert.ok(!JSON.stringify(roster).includes('codeHash'));
});

test('code creation respects the class limit; concurrent retries cannot duplicate accounts', async () => {
  const batch=db.batch();
  for(let i=0;i<97;i++) batch.set(db.doc('classMemberships/class_a_code_filled_'+i),{organizationId:'org_a',classId:'class_a',userId:'code_filled_'+i,role:'student'});
  await batch.commit();
  const data={classId:'class_a',name:'最後の一人',requestId:'last-code-student'};
  const results=await Promise.all(Array.from({length:4},()=>service.createManagedStudent(request('teacher_a',data))));
  assert.equal(new Set(results.map(r=>r.studentId)).size,1);
  assert.equal(results.filter(r=>r.loginCode).length,1);
  await assert.rejects(service.createManagedStudent(request('teacher_a',{...data,name:'上限超え',requestId:'too-many-code'})),denied);
  const previous=await db.doc('studentCodeAccounts/'+results[0].studentId).get();
  await Promise.all(Array.from({length:3},()=>service.reissueStudentCode(request('teacher_a',{classId:'class_a',studentId:results[0].studentId,requestId:'rotate-once'}))));
  const latest=(await db.doc('studentCodeAccounts/'+results[0].studentId).get()).data();
  assert.notEqual(latest.codeHash,previous.data().codeHash);
  assert.equal((await db.doc('studentLoginCodes/'+previous.data().codeHash).get()).exists,false);
});
