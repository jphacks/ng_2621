'use strict';
const {createHash} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');
const world = require('./game_world.json');
const catalog = require('./catalog.json').items;
const fail = (code, message) => { throw new HttpsError(code, message); };
const validId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
const overlap = (a, b) => a.left < b.left + b.width && a.left + a.width > b.left && a.top < b.top + b.height && a.top + a.height > b.top;
const position = (f, layout) => ({...f, ...(layout.facilities.find(p => p.facilityId === f.id) || {})});
function editPayload(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value) || !validId(value.id)) fail('invalid-argument', '配置データが無効です');
  const fields = {enclosure: ['kind','id','left','top','width','height'], facility: ['kind','id','left','top'], assignAnimal: ['kind','id','enclosureId']}[value.kind];
  if (!fields || Object.keys(value).some(k => !fields.includes(k)) || fields.some(k => value[k] == null)) fail('invalid-argument', '配置の項目が無効です');
  for (const k of fields.filter(k => !['kind','id','enclosureId'].includes(k))) {
    if (!Number.isSafeInteger(value[k]) || value[k] < 0 || value[k] > 1000) fail('invalid-argument', '配置の座標・サイズが無効です');
  }
  if (value.kind === 'assignAnimal' && !validId(value.enclosureId)) fail('invalid-argument', '囲いを選択してください');
  return Object.fromEntries(fields.map(k => [k, value[k]]));
}
function bounds(rect) {
  if (rect.width < 1 || rect.height < 1 || rect.left + rect.width > world.map.columns || rect.top + rect.height > world.map.rows) fail('invalid-argument', 'マップの範囲外です');
  for (let y = rect.top; y < rect.top + rect.height; y++) for (let x = rect.left; x < rect.left + rect.width; x++) {
    const terrain = world.map.tiles[y][x];
    const reservedWater = world.facilities.some(f => f.tile === 'water' && x >= f.left && x < f.left + f.width && y >= f.top && y < f.top + f.height);
    if (terrain !== '.' && !(terrain === '~' && reservedWater)) fail('invalid-argument', '通路・水辺には配置できません');
  }
}
function applyEdit(current, edit) {
  const layout = structuredClone(current.layout || {enclosures: [], animalEnclosures: {}, facilities: []});
  if (!Array.isArray(layout.enclosures) || !Array.isArray(layout.facilities) || !layout.animalEnclosures || typeof layout.animalEnclosures !== 'object' || Array.isArray(layout.animalEnclosures)) fail('failed-precondition', '配置の保存データが無効です');
  let price = 0;
  if (edit.kind === 'enclosure') {
    if (edit.width < 3 || edit.height < 3) fail('invalid-argument', '囲いは3×3マス以上です');
    bounds(edit);
    const previous = layout.enclosures.find(p => p.id === edit.id);
    if (previous && (edit.width < previous.width || edit.height < previous.height)) fail('invalid-argument', '囲いは縮小できません');
    if (layout.enclosures.some(p => p.id !== edit.id && overlap(edit, p))) fail('invalid-argument', '囲いが重なっています');
    for (const f of world.facilities) {
      if (f.tile === 'forest' || (f.tile === 'sprite' && !layout.facilities.some(p => p.facilityId === f.id))) continue;
      if (overlap(edit, position(f, layout))) fail('invalid-argument', '施設と重なっています');
    }
    price = (edit.width * edit.height - (previous ? previous.width * previous.height : 0)) * 5;
    layout.enclosures = [...layout.enclosures.filter(p => p.id !== edit.id), {id: edit.id, left: edit.left, top: edit.top, width: edit.width, height: edit.height}];
  } else if (edit.kind === 'assignAnimal') {
    if (!current.ownedAnimalIds.includes(edit.id) || !layout.enclosures.some(p => p.id === edit.enclosureId)) fail('failed-precondition', '購入済み動物・囲いを選択してください');
    layout.animalEnclosures[edit.id] = edit.enclosureId;
  } else {
    const definition = world.facilities.find(f => f.id === edit.id);
    if (!definition || !current.ownedFacilityIds.includes(edit.id)) fail('failed-precondition', '購入済み施設を選択してください');
    const next = {...definition, left: edit.left, top: edit.top};
    bounds(next);
    for (const f of world.facilities) {
      if (f.id === edit.id || (f.tile === 'sprite' && !layout.facilities.some(p => p.facilityId === f.id))) continue;
      if (overlap(next, position(f, layout))) fail('invalid-argument', '他の施設と重なっています');
    }
    if ((definition.blocksAnimalAreas ?? definition.tile === 'water') && layout.enclosures.some(p => overlap(next, p))) fail('invalid-argument', '囲いと重なっています');
    layout.facilities = [...layout.facilities.filter(p => p.facilityId !== edit.id), {facilityId: edit.id, left: edit.left, top: edit.top}];
  }
  if (layout.enclosures.length > 100) fail('resource-exhausted', '囲いの上限です');
  return {price, layout};
}
function createGamePurchase(db, {session, wallet, stamp, contextFields, uidOf, id}) {
  return async request => {
    const uid = uidOf(request), data = request.data || {};
    const requestId = id(data.requestId, 'リクエスト'), itemId = id(data.itemId, '商品');
    const edit = data.layoutEdit == null ? null : editPayload(data.layoutEdit);
    if ((itemId === 'zoo_layout') !== (edit !== null)) fail('invalid-argument', '配置リクエストを確認してください');
    const item = edit ? null : catalog.find(i => i.id === itemId);
    if (!edit && (!item || item.pricing === 'area')) fail('not-found', '商品または購入方法を確認してください');
    const fingerprint = createHash('sha256').update(JSON.stringify({itemId, edit})).digest('hex');
    return db.runTransaction(async tx => {
      const context = await session(tx, db, uid, 'student');
      const transactionRef = db.doc(`shopTransactions/${uid}_${requestId}`), zooRef = db.doc(`zoos/${uid}`);
      const [transaction, zoo] = await tx.getAll(transactionRef, zooRef);
      if (transaction.exists) {
        const old = transaction.data();
        if (old.itemId !== itemId || (old.fingerprint ? old.fingerprint !== fingerprint : edit !== null)) throw new HttpsError('already-exists', '購入内容が一致しません', {purchaseFailure: 'requestConflict'});
        return old.receipt;
      }
      const current = wallet(zoo.data(), context);
      let price, updates;
      if (edit) { const result = applyEdit(current, edit); price = result.price; updates = {layout: result.layout}; }
      else {
        const field = item.kind === 'animal' ? 'ownedAnimalIds' : 'ownedFacilityIds';
        if (current[field].includes(item.targetId)) fail('already-exists', 'すでに購入済みです');
        if (!(item.requiredAnimalIds || []).every(a => current.ownedAnimalIds.includes(a)) || current.ownedAnimalIds.length < (item.minimumAnimalSpecies || 0)) fail('failed-precondition', '解放条件を満たしていません');
        if (!(item.requiredFacilityIds || []).every(f => current.ownedFacilityIds.includes(f)) ||
            (item.acquisition === 'research' && !(item.requiredFacilityIds || []).every(f => (current.layout?.facilities || []).some(p => p.facilityId === f)))) {
          fail('failed-precondition', '研究に必要な施設を購入・配置してください');
        }
        price = item.price; updates = {[field]: [...current[field], item.targetId]};
      }
      if (current.coins < price) fail('resource-exhausted', 'コインが足りません');
      const revision = current.revision + 1, receipt = {requestId, itemId, price, revision};
      tx.set(zooRef, {...current, ...updates, coins: current.coins - price, revision, updatedAt: stamp()});
      tx.create(transactionRef, {...contextFields(context), studentId: uid, itemId, fingerprint, receipt, createdAt: stamp()});
      return receipt;
    });
  };
}
module.exports = {createGamePurchase, applyEdit};
