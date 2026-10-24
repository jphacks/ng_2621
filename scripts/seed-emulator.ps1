$ErrorActionPreference = 'Stop'
$repoPath = Split-Path -Parent $PSScriptRoot
$env:GCLOUD_PROJECT = 'demo-zoostudy'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
& node (Join-Path $repoPath 'scripts/seed-emulator.cjs')
exit $LASTEXITCODE
