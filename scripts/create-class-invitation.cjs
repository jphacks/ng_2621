'use strict';
const {parseArgs} = require('node:util');
const {randomBytes, createHash} = require('node:crypto');
const requireFunctions = require('node:module').createRequire(require('node:path').join(__dirname, '../functions/package.json'));
const {initializeApp} = requireFunctions('firebase-admin/app');
const {getFirestore, Timestamp} = requireFunctions('firebase-admin/firestore');
async function main() {
  const {values} = parseArgs({options: {project: {type: 'string'}, organization: {type: 'string'}, class: {type: 'string'}, uses: {type: 'string', default: '30'}, days: {type: 'string', default: '3'}}});
  const maxUses = Number(values.uses), days = Number(values.days);
  if (!values.project || !/^[A-Za-z0-9_-]{1,180}$/.test(values.organization || '') || !/^[A-Za-z0-9_-]{1,180}$/.test(values.class || '') || !Number.isSafeInteger(maxUses) || maxUses < 1 || maxUses > 1000 || !Number.isSafeInteger(days) || days < 1 || days > 30) throw new Error('Specify --project, --organization, --class, and valid --uses (1-1000), --days (1-30).');
  if (process.env.FIRESTORE_EMULATOR_HOST && !values.project.startsWith('demo-')) throw new Error('Use a demo-* project for emulators.');
  initializeApp({projectId: values.project});
  const db = getFirestore(), classroom = await db.doc(`classes/${values.class}`).get();
  if (!classroom.exists || classroom.data().organizationId !== values.organization) throw new Error('Create the class in the matching organization first.');
  const code = randomBytes(16).toString('hex');
  await db.doc(`classInvitations/${createHash('sha256').update(code).digest('hex')}`).create({organizationId: values.organization, classId: values.class, role: 'student', maxUses, useCount: 0, expiresAt: Timestamp.fromMillis(Date.now() + days * 86400000)});
  console.log(`Project: ${values.project}\nClass: ${values.class}\nStudent invitation: ${code}\nExpires in ${days} days; maximum ${maxUses} accounts.`);
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
