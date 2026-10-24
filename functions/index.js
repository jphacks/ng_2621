'use strict';
const {initializeApp} = require('firebase-admin/app');
const {onCall} = require('firebase-functions/v2/https');
initializeApp();
const service = require('./service').createService();
for (const name of ['sessionInfo', 'publishAssignment', 'submitAssignment', 'reviewSubmission', 'purchaseItem']) {
  exports[name] = onCall({region: 'asia-northeast1', maxInstances: 5}, request => service[name](request));
}
