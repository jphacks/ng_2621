'use strict';
const requireFunctions = require('node:module').createRequire(require('node:path').join(__dirname, '../functions/package.json'));
const {initializeApp, getApps} = requireFunctions('firebase-admin/app');
const {getAuth} = requireFunctions('firebase-admin/auth');
const {getFirestore} = requireFunctions('firebase-admin/firestore');
async function seed() {
  const projectId = process.env.GCLOUD_PROJECT || 'demo-zoostudy';
  if (!projectId.startsWith('demo-') || !/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '') ||
      !/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIREBASE_AUTH_EMULATOR_HOST || '')) {
    throw new Error('Seeding is permitted only for localhost emulators and demo-* projects.');
  }
  if (!getApps().length) initializeApp({projectId});
  const db = getFirestore(), auth = getAuth();
  const users = [
    {uid: 'teacher_a', email: 'teacher@example.test', displayName: 'デモ先生', organizationId: 'org_a', classId: 'class_a', role: 'teacher'},
    {uid: 'student_a', email: 'student@example.test', displayName: 'デモ生徒A', organizationId: 'org_a', classId: 'class_a', role: 'student'},
    {uid: 'student_b', email: 'student2@example.test', displayName: 'デモ生徒B', organizationId: 'org_a', classId: 'class_a', role: 'student'},
    {uid: 'teacher_other', email: 'teacher.other@example.test', displayName: '別の塾の先生', organizationId: 'org_other', classId: 'class_other', role: 'teacher'},
    {uid: 'student_other', email: 'student.other@example.test', displayName: '別の塾の生徒', organizationId: 'org_other', classId: 'class_other', role: 'student'},
  ];
  for (const user of users) {
    const {uid, email, displayName, organizationId, classId, role} = user;
    try { await auth.getUser(uid); } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
      await auth.createUser({uid, email, displayName, password: 'ZooStudyDemo123!'});
    }
    await db.doc(`users/${uid}`).set({organizationId, classId, displayName});
    await db.doc(`classMemberships/${classId}_${uid}`).set({organizationId, classId, userId: uid, displayName, role});
    await db.doc(`classes/${classId}`).set({organizationId, name: classId === 'class_a' ? 'デモクラス' : '別の塾のクラス'});
    await db.doc(`organizations/${organizationId}`).set({name: organizationId});
  }
  return users;
}
module.exports = {seed};
if (require.main === module) seed().then(() => console.log('Emulator demo accounts ready. No production data was changed.')).catch(error => { console.error(error.message); process.exitCode = 1; });

