'use strict';
const {createHash} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');
const {FieldValue, Timestamp} = require('firebase-admin/firestore');
function invitationHash(code) { return createHash('sha256').update(code.trim().toLowerCase()).digest('hex'); }
function createAccountService(db) {
  return {
    async joinClass(request) {
      const uid = request.auth?.uid;
      if (!uid) throw new HttpsError('unauthenticated', 'ログインしてください');
      const {displayName, invitationCode} = request.data || {};
      if (typeof displayName !== 'string' || !displayName.trim() || displayName.trim().length > 40 || typeof invitationCode !== 'string' || !/^[a-f0-9]{32}$/i.test(invitationCode.trim())) throw new HttpsError('invalid-argument', '表示名と招待コードを確認してください');
      return db.runTransaction(async tx => {
        const userRef = db.doc(`users/${uid}`), inviteRef = db.doc(`classInvitations/${invitationHash(invitationCode)}`);
        const [user, invite] = await tx.getAll(userRef, inviteRef);
        if (user.exists) {
          // Retrying onboarding never changes an existing account's class or role.
          if (user.data().enrollmentHash !== invitationHash(invitationCode)) throw new HttpsError('failed-precondition', '登録済みアカウントの所属は変更できません');
          return {joined: true};
        }
        const value = invite.data();
        if (!value || value.role !== 'student' || typeof value.classId !== 'string' || typeof value.organizationId !== 'string' || !/^[A-Za-z0-9_-]{1,180}$/.test(value.classId) || !/^[A-Za-z0-9_-]{1,180}$/.test(value.organizationId) || !(value.expiresAt instanceof Timestamp) || value.expiresAt.toMillis() <= Date.now() || !Number.isSafeInteger(value.maxUses) || value.maxUses < 1 || !Number.isSafeInteger(value.useCount) || value.useCount < 0 || value.useCount >= value.maxUses) throw new HttpsError('permission-denied', '招待コードが無効または期限切れです');
        const classroom = await tx.get(db.doc(`classes/${value.classId}`));
        const memberRef = db.doc(`classMemberships/${value.classId}_${uid}`), zooRef = db.doc(`zoos/${uid}`);
        const [member, zoo] = await tx.getAll(memberRef, zooRef);
        if (!classroom.exists || classroom.data().organizationId !== value.organizationId || member.exists || zoo.exists) throw new HttpsError('failed-precondition', '所属データを管理者に確認してください');
        const members = await tx.get(db.collection('classMemberships').where('classId', '==', value.classId));
        if (members.docs.filter(d => d.data().organizationId === value.organizationId && d.data().role === 'student').length >= 100) throw new HttpsError('resource-exhausted', 'このクラスは生徒100人の上限に達しています');
        const name = displayName.trim(), scope = {organizationId: value.organizationId, classId: value.classId};
        tx.create(userRef, {...scope, displayName: name, enrollmentHash: invitationHash(invitationCode), createdAt: FieldValue.serverTimestamp()});
        tx.create(memberRef, {...scope, userId: uid, displayName: name, role: 'student'});
        tx.create(zooRef, {...scope, studentId: uid, coins: 0, revision: 1, ownedAnimalIds: [], ownedFacilityIds: [], layout: {enclosures: [], animalEnclosures: {}, facilities: []}, updatedAt: FieldValue.serverTimestamp()});
        tx.update(inviteRef, {useCount: value.useCount + 1});
        return {joined: true};
      });
    },
  };
}
module.exports = {createAccountService, invitationHash};
