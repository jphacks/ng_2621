'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {aggregateRecords,validateOutput} = require('../study_advice');
test('advice aggregates equal seven-day periods and excludes future records and identifiers', () => {
 const now = new Date('2026-10-25T00:00:00Z');
 const record = (day) => ({startedAt:day,elapsedMs:120000,stateMs:{suspended:60000},subject:'算数',studentId:'private'});
 const a = aggregateRecords([record('2026-10-24T00:00:00Z'),record('2026-10-17T00:00:00Z'),record('2026-10-26T00:00:00Z')],
 [{id:'task',dueAt:{toMillis:()=>now.getTime()-1000}}],[{assignmentId:'task',status:'pending_review'}],now);
 assert.equal(a.current.sessions,1); assert.equal(a.current.usageMinutes,1);
 assert.equal(a.previous.sessions,1); assert.equal(a.submittedOfDue,1);
 assert.ok(!JSON.stringify(a).includes('private'));
 assert.throws(()=>validateOutput({message:'hello'}));
 assert.deepEqual(validateOutput({summary:' s ',teacherNote:' t ',message:' m '}),{summary:'s',teacherNote:'t',message:'m'});
});

test('AI adapter handles missing configuration, sends aggregates only and rejects invalid output', async () => {
 const {generateWithGemini}=require('../study_advice');
 const oldKey=process.env.STUDY_ADVICE_API_KEY, oldModel=process.env.STUDY_ADVICE_MODEL, oldFetch=global.fetch;
 try {
   delete process.env.STUDY_ADVICE_API_KEY;
   await assert.rejects(generateWithGemini({}), e=>e.code==='failed-precondition');
   process.env.STUDY_ADVICE_API_KEY='test-key'; process.env.STUDY_ADVICE_MODEL='test-model';
   const aggregate={current:{sessions:3,usageMinutes:60}};
   global.fetch=async (url,options)=> {
     assert.ok(!url.includes('test-key'));
     const body=JSON.parse(options.body);
     assert.deepEqual(JSON.parse(body.contents[0].parts[0].text),aggregate);
     return {ok:true,json:async()=>({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify({summary:'記録',teacherNote:'確認',message:'こつこつできたね'})}]}}]})};
   };
   assert.equal((await generateWithGemini(aggregate)).message,'こつこつできたね');
   global.fetch=async()=>({ok:false});
   await assert.rejects(generateWithGemini(aggregate), e=>e.code==='unavailable');
   global.fetch=async()=>({ok:true,json:async()=>({candidates:[{finishReason:'MAX_TOKENS'}]})});
   await assert.rejects(generateWithGemini(aggregate), e=>e.code==='unavailable');
 } finally {
   global.fetch=oldFetch;
   if(oldKey===undefined) delete process.env.STUDY_ADVICE_API_KEY; else process.env.STUDY_ADVICE_API_KEY=oldKey;
   if(oldModel===undefined) delete process.env.STUDY_ADVICE_MODEL; else process.env.STUDY_ADVICE_MODEL=oldModel;
 }
});
