$ErrorActionPreference = 'Stop'
$repoPath = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoPath
$bundledJava = 'C:\Program Files\Android\Android Studio\jbr'
if (Test-Path -LiteralPath "$bundledJava\bin\java.exe") { $env:JAVA_HOME = $bundledJava; $env:PATH = "$bundledJava\bin;$env:PATH" }
$env:XDG_CONFIG_HOME = Join-Path $repoPath 'build/firebase-config'
$env:FIREBASE_EMULATORS_PATH = Join-Path $repoPath 'build/firebase-emulators'
$env:CI = 'true'
& node functions/node_modules/firebase-tools/lib/bin/firebase.js emulators:exec --only auth,firestore,functions --project demo-zoostudy-test 'node --test functions/test/backend.test.js'
exit $LASTEXITCODE
