# アカウント別の保存・復元

作業ブランチ：`feat/account-game-storage`。既存のメール／パスワード認証を拡張し、Firebase AuthenticationのUIDごとに保存する。
本番プロジェクトへのデプロイは行っていない。通常の起動は従来どおり端末内デモなので、アカウント機能は `ZOOSTUDY_STORAGE=emulator` または `firebase` を指定する。

## できること

- 生徒の新規登録、招待コードでのクラス参加、ログイン／再ログイン、パスワード再設定。
- 登録失敗後にAuthだけ作成されても、同じアカウントでクラス参加を再試行できる。
- コイン、所持動物・施設、囲い、施設配置、動物の割り当てをUIDごとに保存・復元。
- 目標動物と演出履歴をアカウント別に保存。通知履歴の保存では別端末の目標を上書きしない。
- ログアウト・別アカウントへの切り替えで、前のユーザーのゲーム画面・購読を破棄する。
- プロフィールとホームに登録時の表示名を表示。

**新規アカウントは0コインから開始する。** ローカルデモの残高・動物園は自動移行せず、元のデモデータも消さない。
現在は1アカウント1クラス・1クラス生徒100人まで。所属の自由変更、先生の自己登録、アカウント削除、プロフィール編集、Googleログインは今回の対象外。

## 保存先

| 保存先 | 内容・書き込み元 |
| --- | --- |
| Firebase Authentication | メール・パスワード。パスワードはFirestoreやアプリの下書きに保存しない |
| `users/{uid}` | 表示名・所属。登録Callableまたは管理者が作成 |
| `classMemberships/{classId_uid}` | 所属・先生／生徒の権限。クライアントによる権限付与は禁止 |
| `zoos/{uid}` | 残高・所持品・revision・layout。Functionsの原子的な取引だけで更新 |
| `gamePreferences/{uid}` | 目標・演出済みID。本人のみ読み書きでき、残高などの追加フィールドは拒否 |
| `shopTransactions/{uid_requestId}` | 購入・配置の確定結果とリクエスト内容のハッシュ。再送時の二重課金を防ぐ |
| `classInvitations/{hash}` | 生徒向けの招待。期限・利用上限を管理。アプリからの直接読書きは禁止 |

目標は明示操作で更新し、演出済みIDはトランザクションで既存分と合流する。履歴は最新2000件まで保持し、初回ロードの報酬は従来どおり再演出しない。
旧 `zoos` にlayoutがなければ空として扱い、既存残高・所持品を消さない。所持動物は囲いを用意して割り当てるとマップに表示される。

## Windows・Androidでエミュレーターを試す

Node.js 20とJava 21を用意する。Android StudioのJBRがある場合は既存スクリプトが利用する。

```powershell
npm --prefix functions ci
powershell -ExecutionPolicy Bypass -File scripts/start-emulators.ps1
```

サーバーを起動したまま、別のターミナルで初期データを作成する。seedはlocalhostのdemo-*プロジェクト専用。

```powershell
$env:GCLOUD_PROJECT = 'demo-zoostudy'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
npm --prefix functions run seed
flutter devices
flutter run -d <Android端末ID> --dart-define=ZOOSTUDY_STORAGE=emulator
```

Androidエミュレーターは標準で `10.0.2.2` を使用する。USB接続の実機は次の転送を設定し、ホストを127.0.0.1で指定する。

```powershell
adb reverse tcp:9099 tcp:9099
adb reverse tcp:8080 tcp:8080
adb reverse tcp:5001 tcp:5001
adb reverse tcp:9199 tcp:9199
flutter run -d <Android端末ID> --dart-define=ZOOSTUDY_STORAGE=emulator --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

アカウント画面の「生徒アカウントを新規作成」→メール・8文字以上のパスワード・表示名・招待コードを入力する。
エミュレーター専用の招待コードは `0123456789abcdef0123456789abcdef`（seed後24時間・100回まで）。本番には作成しない。
アカウントモードでは端末上の役割選択を使わず、サーバーの所属・役割を適用する。既存のデモ先生は `teacher@example.test`、パスワードは `ZooStudyDemo123!`。
アカウントを変える場合は「その他 → ログアウト」。別端末では同じログイン情報を使う。
エミュレーターはスクリプトを正常終了すると `.firebase/demo-export` に保存し、次回起動時に読み込む。

## 本番Firebaseを用意する

1. FirebaseプロジェクトでEmail/Password認証、Firestore、Cloud Storageを有効にする。FunctionsのデプロイにはBlazeプランが必要。
2. `config/firebase.example.json` を `config/firebase.local.json` にコピーし、対象Android／Webアプリのクライアント設定を入力する。
3. 管理者がorganizations・classesを作成する。先生はAuthに登録したUIDに対応するusersとclassMembershipsを管理者権限で設定する。既存のデモseedを本番には使わない。
4. 管理者の認証で、対象プロジェクトへルール・Functionsをデプロイする。

```powershell
node functions/node_modules/firebase-tools/lib/bin/firebase.js deploy --only firestore,functions,storage --project <対象プロジェクトID>
```

5. 管理者が生徒用の招待を作成し、必要な生徒へコードを渡す。管理者のADC認証を使い、秘密鍵をリポジトリやアプリへ入れない。

```powershell
node scripts/create-class-invitation.cjs --project <対象プロジェクトID> --organization <organizationId> --class <classId> --uses 30 --days 3
flutter run -d <Android端末ID> --dart-define-from-file=config/firebase.local.json
```

usersの必須項目はorganizationId・classId・displayName、classMembershipsは同じ所属にuserId・displayName・role（teacher）を指定する。classesにはorganizationId・nameを設定する。
FunctionsのStorageバケット設定など既存の準備は [STORAGE.md](../lib/features/study/STORAGE.md) を参照する。

## 変更点と検証

- `accounts.js`：招待を検証し、ユーザー・生徒権限・0コインの動物園を一括作成。再送は所属を変えず、招待を二重消費しない。
- `game_purchase.js`：正規カタログ・マップから価格・条件・占有範囲を検証。購入・面積差額・配置・取引記録を一括確定。
- FirebaseStudyRepositoryの変更はlayoutの受け取りと購入時のlayoutEdit送信のみ。課題・学習判定・学習報酬の実装は維持。
- ゲーム設定はCloudGamePreferences、フォームはFirebaseから独立したAccountFormとして分離。
- 商品・マップを増やす際は、アセットと `functions/catalog.json`・`functions/game_world.json` を一緒に更新する。テストで一致を検証する。

Flutterの解析・全テストと、Auth・Firestore・Functions・Storageエミュレーターのテストを実施する。
バックエンドテストは `scripts/test-backend.ps1` または `bash scripts/test-backend.sh`。
本番デプロイ、Android実機、実際のメール配送は未確認。

### 検証結果

- `flutter analyze`：指摘なし。
- `flutter test`：169件成功。登録フォームの検証、参加の再試行、権限表示、目標の明示保存、既存の課題・ゲーム操作を含む。
- Firebaseエミュレーター：19件成功。Auth REST登録→認証トークン付きCallableで参加→再ログインを確認。
- 他人の残高・設定へのアクセス拒否、先生権限の自己付与拒否、招待の期限・上限・再送、クラス100人制限を確認。
- 学習報酬・動物購入・施設移動を同時実行しても、残高・所持品・配置が失われないことを確認。

### 主な変更ファイル

| 範囲 | ファイル |
| --- | --- |
| 起動・ログイン | `lib/app_bootstrap.dart`、`firebase_login_screen.dart`、`account_form.dart` |
| 設定保存 | `cloud_game_preferences.dart`、`game_preferences_storage.dart`、`game_experience.dart` |
| ゲーム側接続 | `firebase_study_repository.dart` のlayout・購入送信・購入エラー分類、`zoo_screen.dart` と `zoo_chrome.dart` のプロフィール表示 |
| サーバー・ルール | `functions/accounts.js`、`game_purchase.js`、`service.js`、`index.js`、`catalog.json`、`game_world.json`、`firestore.rules` |
| 管理・検証 | `create-class-invitation.cjs`、`seed-emulator.cjs`、`test-backend.sh`、`backend.test.js`、`account_form_test.dart`、`game_experience_test.dart` |

このブランチは最新のUI作業ブランチから作成しており、mainへの統合・本番への反映は行っていない。
