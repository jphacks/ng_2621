'use strict';
const {createHash, randomInt} = require('node:crypto');
const {getAuth} = require('firebase-admin/auth');
const {Timestamp} = require('firebase-admin/firestore');
const {HttpsError} = require('firebase-functions/v2/https');
const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
const hash = value => createHash('sha256').update(value).digest('hex');
const random = size => Array.from({length:size},()=>alphabet[randomInt(alphabet.length)]).join('');
const fail = (code,message) => {throw new HttpsError(code,message);};
const identifier = value => {if(typeof value!=='string'||!/^[A-Za-z0-9_-]{1,180}$/.test(value)) fail('invalid-argument','入力を確認してください'); return value;};
const name = value => {if(typeof value!=='string'||!value.trim()||value.trim().length>40) fail('invalid-argument','名前を1〜40文字で入力してください'); return value.trim();};
function normalizeStudentCode(value) {
  if (typeof value !== 'string' || value.length > 100) return '';
  const code = value.toUpperCase().replace(/[\s-]/g,'');
  return /^[2-9A-HJ-NP-Z]{22}$/.test(code) ? code : '';
}
const formatCode = value => value.slice(0,6)+'-'+value.slice(6).match(/.{4}/g).join('-');
function createStudentCodeService(db, {session, uidOf}, {mintToken = uid => getAuth().createCustomToken(uid), clock = () => Date.now()} = {}) {
  async function scope(tx,uid,classId) {
    const c = await session(tx,db,uid,'teacher');
    identifier(classId);
    const [room,member] = await tx.getAll(db.doc('classes/'+classId),db.doc('classMemberships/'+classId+'_'+uid));
    const m=member.data();
    if(!room.exists || room.data().organizationId!==c.organizationId || !m || m.role!=='teacher' || m.userId!==uid || m.classId!==classId || m.organizationId!==c.organizationId)
      fail('permission-denied','担当クラスだけを管理できます');
    return {...c,classId,room};
  }
  async function prefix(tx,c) {
    if(c.room.data().loginPrefix) return {value:c.room.data().loginPrefix};
    const value=random(6), ref=db.doc('classLoginPrefixes/'+value);
    if((await tx.get(ref)).exists) fail('aborted','コードが重複しました。もう一度お試しください');
    return {value,ref};
  }
  async function prepareCode(tx,c,studentId,requestId) {
    const credential=db.doc('studentCodeAccounts/'+studentId), previous=await tx.get(credential);
    if(previous.data()?.issueRequestId===requestId && previous.data()?.issuedBy===c.uid)
      return {replayed:true, result:{studentId,loginCode:null,codeUnavailable:true}};
    const p=await prefix(tx,c), raw=p.value+random(16), digest=hash(raw), ref=db.doc('studentLoginCodes/'+digest);
    if((await tx.get(ref)).exists) fail('aborted','コードが重複しました。もう一度お試しください');
    return {credential,previous,p,raw,digest,ref};
  }
  function writeCode(tx,c,studentId,requestId,code) {
    if(code.previous.data()?.codeHash) tx.delete(db.doc('studentLoginCodes/'+code.previous.data().codeHash));
    if(code.p.ref) {
      tx.create(code.p.ref,{classId:c.classId,organizationId:c.organizationId});
      tx.update(c.room.ref,{loginPrefix:code.p.value});
    }
    tx.create(code.ref,{studentId,classId:c.classId,organizationId:c.organizationId,createdAt:Timestamp.fromMillis(clock())});
    tx.set(code.credential,{studentId,classId:c.classId,organizationId:c.organizationId,codeHash:code.digest,issueRequestId:requestId,issuedBy:c.uid,updatedAt:Timestamp.fromMillis(clock())});
    return {studentId,loginCode:formatCode(code.raw),codeUnavailable:false};
  }
  return {
    async listManagedClasses(request) {
      const uid=uidOf(request), c=await db.runTransaction(tx=>session(tx,db,uid,'teacher'));
      const members=await db.collection('classMemberships').where('userId','==',uid).limit(101).get();
      const ids=members.docs.map(d=>d.data()).filter(m=>m.role==='teacher'&&m.organizationId===c.organizationId).map(m=>m.classId);
      if(ids.length>100) fail('resource-exhausted','管理できるクラスは100件までです');
      const rooms=ids.length?await db.getAll(...ids.map(id=>db.doc('classes/'+id))):[];
      return {currentClassId:c.classId,classes:rooms.filter(d=>d.exists&&d.data().organizationId===c.organizationId).map(d=>({id:d.id,name:d.data().name||'クラス',prefix:d.data().loginPrefix||''}))};
    },
    async createManagedClass(request) {
      const uid=uidOf(request), className=name(request.data?.name), requestId=identifier(request.data?.requestId);
      const classId='c_'+hash(uid+':'+requestId).slice(0,32);
      return db.runTransaction(async tx=> {
        const c=await session(tx,db,uid,'teacher'), ref=db.doc('classes/'+classId), old=await tx.get(ref);
        if(old.exists) {
          if(old.data().organizationId!==c.organizationId||old.data().name!==className) fail('already-exists','登録内容が一致しません');
          return {classId,prefix:old.data().loginPrefix};
        }
        const memberships=await tx.get(db.collection('classMemberships').where('userId','==',uid));
        if(memberships.docs.filter(d=>d.data().role==='teacher').length>=100) fail('resource-exhausted','管理できるクラスは100件までです');
        const value=random(6), prefixRef=db.doc('classLoginPrefixes/'+value);
        if((await tx.get(prefixRef)).exists) fail('aborted','もう一度お試しください');
        tx.create(ref,{organizationId:c.organizationId,name:className,loginPrefix:value,createdBy:uid,createdAt:Timestamp.fromMillis(clock())});
        tx.create(prefixRef,{classId,organizationId:c.organizationId});
        tx.create(db.doc('classMemberships/'+classId+'_'+uid),{organizationId:c.organizationId,classId,userId:uid,displayName:c.displayName,role:'teacher'});
        return {classId,prefix:value};
      });
    },
    async selectManagedClass(request) {
      const uid=uidOf(request);
      return db.runTransaction(async tx=> {
        const c=await scope(tx,uid,request.data?.classId);
        tx.update(db.doc('users/'+uid),{classId:c.classId});
        return {classId:c.classId};
      });
    },
    async listManagedStudents(request) {
      const uid=uidOf(request), classId=request.data?.classId;
      const c=await db.runTransaction(tx=>scope(tx,uid,classId));
      const members=await db.collection('classMemberships').where('classId','==',classId).get();
      const students=members.docs.map(d=>d.data()).filter(m=>m.organizationId===c.organizationId&&m.role==='student');
      const credentials=students.length?await db.getAll(...students.map(m=>db.doc('studentCodeAccounts/'+m.userId))):[];
      return {students:students.map((m,i)=>({id:m.userId,name:m.displayName||'生徒',hasCode:credentials[i].exists}))};
    },
    async createManagedStudent(request) {
      const uid=uidOf(request), displayName=name(request.data?.name), classId=identifier(request.data?.classId), requestId=identifier(request.data?.requestId);
      const studentId='s_'+hash(uid+':'+requestId).slice(0,40);
      return db.runTransaction(async tx=> {
        const c=await scope(tx,uid,classId), userRef=db.doc('users/'+studentId), existing=await tx.get(userRef);
        if(existing.exists && (existing.data().classId!==classId||existing.data().displayName!==displayName||existing.data().organizationId!==c.organizationId)) fail('already-exists','登録内容が一致しません');
        const members=await tx.get(db.collection('classMemberships').where('classId','==',classId));
        if(!existing.exists&&members.docs.filter(d=>d.data().organizationId===c.organizationId&&d.data().role==='student').length>=100) fail('resource-exhausted','このクラスは生徒100人までです');
        const code=await prepareCode(tx,c,studentId,requestId);
        if(code.replayed) return code.result;
        if(!existing.exists) {
          const scopeFields={organizationId:c.organizationId,classId};
          tx.create(userRef,{...scopeFields,displayName,createdBy:uid,createdAt:Timestamp.fromMillis(clock())});
          tx.create(db.doc('classMemberships/'+classId+'_'+studentId),{...scopeFields,userId:studentId,displayName,role:'student'});
          tx.create(db.doc('zoos/'+studentId),{...scopeFields,studentId,coins:0,revision:1,ownedAnimalIds:[],ownedFacilityIds:[],layout:{enclosures:[],animalEnclosures:{},facilities:[]}});
        }
        return writeCode(tx,c,studentId,requestId,code);
      });
    },
    async reissueStudentCode(request) {
      const uid=uidOf(request), studentId=identifier(request.data?.studentId), requestId=identifier(request.data?.requestId);
      return db.runTransaction(async tx=> {
        const c=await scope(tx,uid,request.data?.classId);
        const [user,member]=await tx.getAll(db.doc('users/'+studentId),db.doc('classMemberships/'+c.classId+'_'+studentId));
        const m=member.data();
        if(!user.exists||user.data().classId!==c.classId||user.data().organizationId!==c.organizationId||!m||m.userId!==studentId||m.role!=='student'||m.organizationId!==c.organizationId||m.classId!==c.classId) fail('permission-denied','このクラスの生徒だけが対象です');
        const code=await prepareCode(tx,c,studentId,requestId);
        return code.replayed?code.result:writeCode(tx,c,studentId,requestId,code);
      });
    },
    async loginWithStudentCode(request) {
      // Count unsuccessful attempts too. Raw codes and IP addresses are never logged or stored.
      const now=clock(), ip=request.rawRequest?.ip||'unknown', window=Math.floor(now/60000);
      const attempt=db.doc('studentCodeAttempts/'+hash(ip+':'+window));
      await db.runTransaction(async tx=> {
        const previous=await tx.get(attempt), count=previous.data()?.count||0;
        if(count>=120) fail('resource-exhausted','しばらく待ってから、もう一度お試しください');
        tx.set(attempt,{count:count+1,expiresAt:Timestamp.fromMillis(now+3600000)});
      });
      const raw=normalizeStudentCode(request.data?.code);
      if(!raw) fail('unauthenticated','コードを確認するか、先生に再発行をお願いしてください');
      const digest=hash(raw);
      const studentId=await db.runTransaction(async tx=> {
        const entry=await tx.get(db.doc('studentLoginCodes/'+digest)), value=entry.data();
        if(!value) fail('unauthenticated','コードを確認するか、先生に再発行をお願いしてください');
        const [credential,user,member,room]=await tx.getAll(db.doc('studentCodeAccounts/'+value.studentId),db.doc('users/'+value.studentId),
          db.doc('classMemberships/'+value.classId+'_'+value.studentId),db.doc('classes/'+value.classId));
        const m=member.data();
        if(credential.data()?.codeHash!==digest||!user.exists||user.data().classId!==value.classId||user.data().organizationId!==value.organizationId||!m||m.role!=='student'||m.userId!==value.studentId||m.classId!==value.classId||m.organizationId!==value.organizationId||!room.exists||room.data().organizationId!==value.organizationId)
          fail('unauthenticated','コードを確認するか、先生に再発行をお願いしてください');
        return value.studentId;
      });
      return {token:await mintToken(studentId)};
    }
  };
}
module.exports={createStudentCodeService,normalizeStudentCode};
