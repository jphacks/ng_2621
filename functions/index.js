'use strict';
const {initializeApp} = require('firebase-admin/app');
const {onCall} = require('firebase-functions/v2/https');
initializeApp();
const service = require('./service').createService();
for (const name of ['sessionInfo', 'saveStudySession', 'publishAssignment', 'submitAssignment', 'reviewSubmission', 'purchaseItem']) {
  exports[name] = onCall({region: 'asia-northeast1', maxInstances: 5, concurrency: 4, memory: '512MiB', timeoutSeconds: 60}, request => service[name](request));
}

const {defineSecret} = require('firebase-functions/params');
const adviceKey = defineSecret('STUDY_ADVICE_API_KEY');
for (const name of ['generateStudyAdvice', 'publishStudyAdvice']) {
  exports[name] = onCall({region: 'asia-northeast1', maxInstances: 3, concurrency: 4, memory: '512MiB', timeoutSeconds: 60,
    ...(name === 'generateStudyAdvice' ? {secrets: [adviceKey]} : {})}, request => service[name](request));
}
