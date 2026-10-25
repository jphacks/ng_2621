'use strict';
const {createHash} = require('node:crypto');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {HttpsError} = require('firebase-functions/v2/https');
const catalog = require('./catalog.json').items;
const {verifyAttachments} = require('./attachments');
const {normalizeStudyRecord} = require('./study_sessions');
const subjects = new Set(['japanese', 'mathematics', 'english', 'science', 'socialStudies', 'other']);
const fail = (code, message) => { throw new HttpsError(code, message); };
const id = (value, name) => {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,180}$/.test(value)) fail('invalid-argument', `${name}が無効です`);
  return value;
};
const text = (value, max, name, optional = false) => {
  if (typeof value !== 'string' || value.length > max || (!optional && !value.trim())) fail('invalid-argument', `${name}を確認してください`);
  return value.trim();
};
const ref = (db, collection, key) => db.collection(collection).doc(key);
const stamp = () => FieldValue.serverTimestamp();
const digest = data => createHash('sha256').update(JSON.stringify(data)).digest('hex');
function uidOf(request) {
  if (!request.auth?.uid) fail('unauthenticated', 'ログインしてください');
  return id(request.auth.uid, 'ユーザー');
}
async function session(tx, db, uid, requiredRole) {
  const user = await tx.get(ref(db, 'users', uid));
  if (!user.exists) fail('permission-denied', 'アカウントの所属設定が必要です');
  const {organizationId, classId} = user.data();
  id(organizationId, '塾'); id(classId, 'クラス');
  const [member, classroom] = await tx.getAll(ref(db, 'classMemberships', `${classId}_${uid}`), ref(db, 'classes', classId));
  if (!member.exists || !classroom.exists || member.data().userId !== uid || member.data().classId !== classId ||
      member.data().organizationId !== organizationId || classroom.data().organizationId !== organizationId ||
      !['teacher', 'student'].includes(member.data().role) || (requiredRole && member.data().role !== requiredRole)) {
    fail('permission-denied', 'このクラスの操作権限がありません');
  }
  return {uid, organizationId, classId, role: member.data().role, displayName: user.data().displayName || 'ユーザー'};
}
function inScope(assignment, context) {
  if (!assignment || assignment.organizationId !== context.organizationId || assignment.classId !== context.classId || assignment.status !== 'published') {
    fail('permission-denied', '配布先の課題だけを操作できます');
  }
}
async function operation(tx, db, uid, requestId, payload) {
  const doc = ref(db, 'operationRequests', `${uid}_${id(requestId, 'リクエスト')}`);
  const existing = await tx.get(doc);
  const fingerprint = digest(payload);
  if (existing.exists && existing.data().fingerprint !== fingerprint) fail('already-exists', 'リクエストの内容が一致しません');
  return {doc, fingerprint, result: existing.exists ? existing.data().result : null};
}
function complete(tx, op, result) {
  tx.create(op.doc, {fingerprint: op.fingerprint, result, createdAt: stamp()});
  return result;
}
function wallet(data, context) {
  if (!data) return {organizationId: context.organizationId, classId: context.classId,
    studentId: context.uid, coins: 0, revision: 0, ownedAnimalIds: [], ownedFacilityIds: []};
  if (data.organizationId !== context.organizationId || data.studentId !== context.uid ||
      data.classId !== context.classId || !Number.isSafeInteger(data.coins) || data.coins < 0) {
    fail('failed-precondition', '残高データを確認してください');
  }
  return data;
}

function createService(db = getFirestore(), adviceOptions = {}) {
  return {
    ...require('./study_advice').createAdviceService(db, {session, uidOf}, adviceOptions),
    async sessionInfo(request) {
      const uid = uidOf(request);
      const context = await db.runTransaction(tx => session(tx, db, uid));
      if (context.role === 'teacher') {
        const members = await db.collection('classMemberships').where('classId', '==', context.classId).get();
        context.students = members.docs.map(d => d.data()).filter(m => m.organizationId === context.organizationId && m.role === 'student')
          .map(m => ({id: m.userId, name: m.displayName || '生徒'}));
      } else context.students = [{id: uid, name: context.displayName}];
      return context;
    },

    async saveStudySession(request) {
      const uid = uidOf(request);
      const record = normalizeStudyRecord(request.data?.record);
      return db.runTransaction(async tx => {
        const context = await session(tx, db, uid, 'student');
        const doc = ref(db, 'studySessions', `${uid}_${record.id}`);
        const existing = await tx.get(doc);
        const fingerprint = digest(record);
        if (existing.exists) {
          if (existing.data().fingerprint !== fingerprint) fail('already-exists', '保存済みの学習記録と一致しません');
          return {sessionId: doc.id, rewardAmount: existing.data().rewardAmount || 0};
        }
        const entries = Object.entries(record.rewardMsByDay || {});
        const dailyRefs = entries.map(([day]) => ref(db, 'studyDailyRewards', `${uid}_${day}`));
        const dailyDocs = dailyRefs.length ? await tx.getAll(...dailyRefs) : [];
        let rewardAmount = 0;
        const dailyUpdates = entries.map(([day, ms], index) => {
          const previous = dailyDocs[index].data();
          const before = previous?.eligibleMs || 0;
          const paid = previous?.coinsGranted || 0;
          if (!Number.isSafeInteger(before) || before < 0 || paid !== Math.min(30, Math.floor(before / 120000))) {
            fail('failed-precondition', '日別の勉強報酬を確認してください');
          }
          const eligibleMs = before + ms;
          const coinsGranted = Math.min(30, Math.floor(eligibleMs / 120000));
          rewardAmount += coinsGranted - paid;
          return {...contextFields(context), studentId: uid, day, eligibleMs, coinsGranted, updatedAt: stamp()};
        });
        // Read all documents before any writes; concurrent saves share the daily cap.
        const zoo = rewardAmount > 0 ? await tx.get(ref(db, 'zoos', uid)) : null;
        if (zoo) {
          const current = wallet(zoo.data(), context);
          tx.set(zoo.ref, {...current, coins: current.coins + rewardAmount,
            revision: current.revision + 1, updatedAt: stamp()});
        }
        dailyUpdates.forEach((value, index) => tx.set(dailyRefs[index], value));
        tx.create(doc, {...contextFields(context), studentId: uid, studentName: context.displayName,
          record, fingerprint, rewardAmount, source: 'device_observation', receivedAt: stamp()});
        return {sessionId: doc.id, rewardAmount};
      });
    },
    async publishAssignment(request) {
      const uid = uidOf(request), data = request.data || {};
      const title = text(data.title, 100, 'タイトル'), description = text(data.description, 3000, '説明');
      if (!subjects.has(data.subject)) fail('invalid-argument', '科目を選択してください');
      const dueAt = new Date(data.dueAt);
      if (!Number.isFinite(dueAt.getTime())) fail('invalid-argument', '締切を確認してください');
      const payload = {type: 'publish', title, description, subject: data.subject, dueAt: dueAt.toISOString()};
      return db.runTransaction(async tx => {
        const context = await session(tx, db, uid, 'teacher');
        const op = await operation(tx, db, uid, data.requestId, payload);
        if (op.result) return op.result;
        const members = await tx.get(db.collection('classMemberships').where('classId', '==', context.classId));
        const students = members.docs.map(d => d.data()).filter(m => m.organizationId === context.organizationId && m.role === 'student');
        if (students.length > 100) fail('failed-precondition', 'このMVPは1クラス100人までです');
        const wallets = students.length ? await tx.getAll(...students.map(m => ref(db, 'zoos', m.userId))) : [];
        const assignmentId = `${uid}_${data.requestId}`;
        tx.create(ref(db, 'assignments', assignmentId), {...contextFields(context), teacherId: uid,
          title, description, subject: data.subject, dueAt: Timestamp.fromDate(dueAt), status: 'published',
          submissionReward: 30, approvalReward: 70, createdAt: stamp(), updatedAt: stamp()});
        students.forEach((student, index) => {
          const current = wallet(wallets[index].data(), {...context, uid: student.userId});
          tx.set(wallets[index].ref, {...current, revision: current.revision + 1, updatedAt: stamp()});
        });
        return complete(tx, op, {assignmentId});
      });
    },

    async submitAssignment(request) {
      const uid = uidOf(request), data = request.data || {};
      const assignmentId = id(data.assignmentId, '課題'), answerText = text(data.answerText ?? '', 5000, '回答', true);
      const initialContext = await db.runTransaction(tx => session(tx, db, uid, 'student'));
      const attachments = await verifyAttachments(initialContext, assignmentId, data.attachments ?? []);
      if (!answerText && attachments.length === 0) fail('invalid-argument', '回答を入力するか画像・PDFを添付してください');
      return db.runTransaction(async tx => {
        const context = await session(tx, db, uid, 'student');
        const op = await operation(tx, db, uid, data.requestId, {type: 'submit', assignmentId, answerText, attachments});
        if (op.result) return op.result;
        const submissionRef = ref(db, 'submissions', `${assignmentId}_${uid}`);
        const rewardRef = ref(db, 'rewardTransactions', `${assignmentId}_${uid}_submit`);
        const [assignment, submission, zoo, reward] = await tx.getAll(ref(db, 'assignments', assignmentId), submissionRef,
          ref(db, 'zoos', uid), rewardRef);
        inScope(assignment.data(), context);
        const previous = submission.data();
        if (previous?.status === 'approved') fail('failed-precondition', '承認済みの課題は変更できません');
        if (previous?.status === 'pending_review') {
          if (previous.answerText !== answerText || JSON.stringify(previous.attachments || []) !== JSON.stringify(attachments)) fail('failed-precondition', '先生の確認待ちです');
          return complete(tx, op, {rewardAmount: 0});
        }
        const current = wallet(zoo.data(), context), amount = reward.exists ? 0 : 30;
        tx.set(submissionRef, {...contextFields(context), assignmentId, studentId: uid, studentName: context.displayName,
          answerText, attachments, status: 'pending_review', submittedAt: stamp(), updatedAt: stamp(), reviewedAt: null,
          reviewedBy: null, feedback: previous?.feedback || '', revisionCount: previous ? previous.revisionCount + 1 : 0,
          version: (previous?.version || 0) + 1});
        if (amount) tx.create(rewardRef, {...contextFields(context), assignmentId, studentId: uid,
          kind: 'submit', amount, confirmedAt: stamp()});
        tx.set(zoo.ref, {...current, coins: current.coins + amount, revision: current.revision + 1, updatedAt: stamp()});
        return complete(tx, op, {rewardAmount: amount});
      });
    },

    async reviewSubmission(request) {
      const uid = uidOf(request), data = request.data || {};
      const assignmentId = id(data.assignmentId, '課題'), studentId = id(data.studentId, '生徒');
      if (typeof data.approve !== 'boolean' || !Number.isInteger(data.expectedVersion)) fail('invalid-argument', '確認内容が無効です');
      const feedback = text(data.feedback || '', 1000, 'コメント', true);
      return db.runTransaction(async tx => {
        const context = await session(tx, db, uid, 'teacher');
        const op = await operation(tx, db, uid, data.requestId,
          {type: 'review', assignmentId, studentId, approve: data.approve, feedback, expectedVersion: data.expectedVersion});
        if (op.result) return op.result;
        const [assignment, submission, student, zoo, reward] = await tx.getAll(ref(db, 'assignments', assignmentId),
          ref(db, 'submissions', `${assignmentId}_${studentId}`), ref(db, 'classMemberships', `${context.classId}_${studentId}`),
          ref(db, 'zoos', studentId), ref(db, 'rewardTransactions', `${assignmentId}_${studentId}_approve`));
        inScope(assignment.data(), context);
        if (!student.exists || student.data().role !== 'student' || student.data().organizationId !== context.organizationId) {
          fail('permission-denied', '担当クラスの生徒だけを確認できます');
        }
        const previous = submission.data();
        if (!previous) fail('failed-precondition', '未提出の課題は承認できません');
        if (previous.status === 'approved' && data.approve) return complete(tx, op, {rewardAmount: 0});
        if (previous.status !== 'pending_review' || previous.version !== data.expectedVersion) {
          fail('failed-precondition', '提出内容が更新されています。再読み込みして確認してください');
        }
        const current = wallet(zoo.data(), {...context, uid: studentId});
        const amount = data.approve && !reward.exists ? 70 : 0;
        tx.update(submission.ref, {status: data.approve ? 'approved' : 'needs_revision', feedback,
          reviewedBy: uid, reviewedAt: stamp(), updatedAt: stamp(), version: previous.version + 1});
        if (amount) tx.create(reward.ref, {...contextFields(context), assignmentId, studentId,
          kind: 'approve', amount, confirmedAt: stamp()});
        tx.set(zoo.ref, {...current, coins: current.coins + amount, revision: current.revision + 1, updatedAt: stamp()});
        return complete(tx, op, {rewardAmount: amount});
      });
    },

    async purchaseItem(request) {
      const uid = uidOf(request), data = request.data || {};
      const requestId = id(data.requestId, 'リクエスト'), itemId = id(data.itemId, '商品');
      const item = catalog.find(i => i.id === itemId);
      if (!item) fail('not-found', '商品が見つかりません');
      return db.runTransaction(async tx => {
        const context = await session(tx, db, uid, 'student');
        const [transaction, zoo] = await tx.getAll(ref(db, 'shopTransactions', `${uid}_${requestId}`), ref(db, 'zoos', uid));
        if (transaction.exists) {
          if (transaction.data().itemId !== itemId) fail('already-exists', '購入内容が一致しません');
          return transaction.data().receipt;
        }
        const current = wallet(zoo.data(), context);
        const field = item.kind === 'animal' ? 'ownedAnimalIds' : 'ownedFacilityIds';
        if (current[field].includes(item.targetId)) fail('already-exists', 'すでに購入済みです');
        if (!(item.requiredAnimalIds || []).every(a => current.ownedAnimalIds.includes(a)) ||
            current.ownedAnimalIds.length < (item.minimumAnimalSpecies || 0)) fail('failed-precondition', '解放条件を満たしていません');
        if (current.coins < item.price) fail('resource-exhausted', 'コインが足りません');
        const revision = current.revision + 1;
        const receipt = {requestId, itemId, price: item.price, revision};
        tx.set(zoo.ref, {...current, coins: current.coins - item.price, revision,
          [field]: [...current[field], item.targetId], updatedAt: stamp()});
        tx.create(transaction.ref, {...contextFields(context), studentId: uid, itemId, receipt, createdAt: stamp()});
        return receipt;
      });
    },
  };
}
function contextFields(context) { return {organizationId: context.organizationId, classId: context.classId}; }
module.exports = {createService};
