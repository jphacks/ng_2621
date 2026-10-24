'use strict';
const {HttpsError} = require('firebase-functions/v2/https');
const states = ['studying','facePosture','faceCheck','material','device','unknown','suspended'];
const fail = () => { throw new HttpsError('invalid-argument', '学習記録の内容を確認してください'); };
function normalizeStudyRecord(raw) {
  if (!raw || typeof raw.id !== 'string' || !/^[A-Za-z0-9_-]{1,180}$/.test(raw.id) ||
      !['desk','face'].includes(raw.mode) || typeof raw.subject !== 'string' || raw.subject.length > 100 ||
      typeof raw.completed !== 'boolean' || !Number.isSafeInteger(raw.elapsedMs) || raw.elapsedMs < 0 ||
      raw.elapsedMs > 86400000 || !Number.isSafeInteger(raw.samples) || raw.samples < 0 || raw.samples > 100000 ||
      !raw.stateMs || Object.keys(raw.stateMs).length !== states.length ||
      states.some(s => !Number.isSafeInteger(raw.stateMs[s]) || raw.stateMs[s] < 0) ||
      states.reduce((sum,s) => sum + raw.stateMs[s], 0) !== raw.elapsedMs) fail();
  if (raw.mode === 'face' ? raw.stateMs.studying + raw.stateMs.material + raw.stateMs.device > 0
      : raw.stateMs.facePosture + raw.stateMs.faceCheck > 0) fail();
  if (typeof raw.startedAt !== 'string') fail();
  const started = new Date(raw.startedAt);
  if (!Number.isFinite(started.getTime()) || started.getTime() > Date.now() + 300000 ||
      raw.elapsedMs > Date.now() - started.getTime() + 300000) fail();
  const record = {id: raw.id, startedAt: started.toISOString(), mode: raw.mode, subject: raw.subject.trim(),
    completed: raw.completed, elapsedMs: raw.elapsedMs, samples: raw.samples,
    stateMs: Object.fromEntries(states.map(s => [s, raw.stateMs[s]])), detectorVersion: 'study-detector-v1'};
  if (raw.rewardPolicyVersion == null) {
    if (raw.rewardMsByDay != null) fail();
    return record;
  }
  if (raw.rewardPolicyVersion !== 2 || !raw.rewardMsByDay || Array.isArray(raw.rewardMsByDay) ||
      Object.keys(raw.rewardMsByDay).length > 2) fail();
  let eligible = 0;
  for (const [day, milliseconds] of Object.entries(raw.rewardMsByDay)) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || !Number.isSafeInteger(milliseconds) || milliseconds < 0) fail();
    const midnight = Date.parse(`${day}T00:00:00+09:00`);
    if (!Number.isFinite(midnight) || new Date(midnight + 32400000).toISOString().slice(0,10) !== day) fail();
    const capacity = Math.max(0, Math.min(midnight + 86400000, started.getTime() + raw.elapsedMs) - Math.max(midnight, started.getTime()));
    if (milliseconds > capacity) fail();
    eligible += milliseconds;
  }
  if (eligible > raw.elapsedMs || eligible > raw.samples * 8000) fail();
  record.detectorVersion = 'study-detector-v2';
  record.rewardPolicyVersion = 2;
  record.rewardMsByDay = Object.fromEntries(Object.entries(raw.rewardMsByDay).sort(([a],[b]) => a.localeCompare(b)));
  return record;
}
module.exports = {normalizeStudyRecord};
