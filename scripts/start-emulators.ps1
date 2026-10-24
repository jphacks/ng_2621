param([switch]$NoUi)
$ErrorActionPreference = 'Stop'
$repoPath = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoPath
$bundledJava = 'C:\Program Files\Android\Android Studio\jbr'
if (Test-Path -LiteralPath "$bundledJava\bin\java.exe") { $env:JAVA_HOME = $bundledJava; $env:PATH = "$bundledJava\bin;$env:PATH" }
$env:XDG_CONFIG_HOME = Join-Path $repoPath 'build/firebase-config'
$env:FIREBASE_EMULATORS_PATH = Join-Path $repoPath 'build/firebase-emulators'
$env:CI = 'true'
$exportPath = Join-Path $repoPath '.firebase/demo-export'
$firebaseArgs = @('functions/node_modules/firebase-tools/lib/bin/firebase.js', 'emulators:start', '--project', 'demo-zoostudy', '--export-on-exit', $exportPath)
if ($NoUi) { $firebaseArgs += @('--only', 'auth,firestore,functions') }
if (Test-Path -LiteralPath $exportPath) { $firebaseArgs += @('--import', $exportPath) }
& node @firebaseArgs
exit $LASTEXITCODE
