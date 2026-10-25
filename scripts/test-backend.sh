#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CI=true
node functions/node_modules/firebase-tools/lib/bin/firebase.js emulators:exec \
  --only auth,firestore,functions,storage --project demo-zoostudy-test \
  'node --test functions/test/backend.test.js'
