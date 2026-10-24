'use strict';
const {createHash} = require('node:crypto');
const {getApp} = require('firebase-admin/app');
const {getStorage} = require('firebase-admin/storage');
const {HttpsError} = require('firebase-functions/v2/https');
const maxBytes = 10 * 1024 * 1024;
const types = {'application/pdf': 'pdf', 'image/jpeg': 'jpg', 'image/png': 'png'};
const invalid = message => { throw new HttpsError('invalid-argument', message); };
function bucket() {
  const app = getApp();
  const name = process.env.ZOOSTUDY_STORAGE_BUCKET || app.options.storageBucket ||
    (app.options.projectId?.startsWith('demo-') ? `${app.options.projectId}.appspot.com` : null);
  if (!name) throw new HttpsError('failed-precondition', 'Storageバケットを設定してください');
  return getStorage().bucket(name);
}
async function verifyAttachments(context, assignmentId, files = []) {
  if (!Array.isArray(files) || files.length > 3) invalid('添付は最大3件までにしてください');
  const ids = new Set();
  const verified = [];
  for (const file of files) {
    if (!file || typeof file.id !== 'string' || !/^[a-f0-9]{64}$/.test(file.id) || ids.has(file.id) ||
        typeof file.name !== 'string' || !file.name.trim() || file.name.length > 200 || /[/\\\x00-\x1F]/.test(file.name) ||
        !Number.isInteger(file.size) || file.size <= 0 || file.size > maxBytes || !Object.hasOwn(types, file.contentType)) invalid('添付ファイル情報を確認してください');
    ids.add(file.id);
    const path = `submissionFiles/${context.organizationId}/${context.classId}/${assignmentId}/${context.uid}/${file.id}.${types[file.contentType]}`;
    if (file.storagePath !== path) throw new HttpsError('permission-denied', '自分の課題に添付したファイルだけを提出できます');
    const object = bucket().file(path);
    let metadata, bytes;
    try {
      [metadata] = await object.getMetadata();
      if (Number(metadata.size) !== file.size || metadata.contentType !== file.contentType ||
          (file.generation && file.generation !== metadata.generation)) invalid('アップロードしたファイル情報が一致しません');
      [bytes] = await object.download({validation: false, start: 0, end: maxBytes});
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('failed-precondition', 'ファイルのアップロードを確認できませんでした。もう一度添付してください');
    }
    const extension = file.name.split('.').at(-1).toLowerCase();
    const validSignature = file.contentType === 'application/pdf' ? extension === 'pdf' && bytes.subarray(0, 5).equals(Buffer.from('%PDF-')) :
      file.contentType === 'image/png' ? extension === 'png' && bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])) :
      ['jpg','jpeg'].includes(extension) && bytes.subarray(0, 3).equals(Buffer.from([255,216,255]));
    if (bytes.length !== file.size || !validSignature || createHash('sha256').update(bytes).digest('hex') !== file.id) invalid('ファイルの内容・形式を確認してください');
    verified.push({id: file.id, name: file.name, size: bytes.length, contentType: file.contentType,
      storagePath: path, generation: metadata.generation});
  }
  return verified;
}
module.exports = {verifyAttachments};
