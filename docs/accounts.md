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


## 先生が登録する生徒コードログイン（login_2）

生徒はメール不要です。先生は従来のメール・パスワードでログインし「その他 → クラス・生徒管理」でクラスを作成、クラスを選択して生徒名を登録します。登録成功時に専用ログインコードとQRが表示されます。新しいクラスで課題・学習記録を扱う場合は「このクラスで課題・学習記録を開く」を押し、管理画面から戻ります。先生の選択中クラスはusers.classIdに保存するため、同じ先生アカウントの別端末にも共通です。別端末はログインし直して反映します。生徒は現在1人1クラスです。

生徒はFirebase接続時の入口「生徒（コード）」でコードを入力するか「QRコードをよみとる」で読み取って確定します。先生・従来のメールアカウントは「先生・メール」から入ります。QRの内容はコード文字列だけで、URLや氏名は含みません。Android/iOS/macOS/Webでカメラ読取を提供し、Windows等は手入力です。WebのカメラはHTTPSまたはlocalhostとブラウザーの許可が必要です。

### コードと保存

形式はクラス識別子6文字＋ランダム16文字（4文字ずつ区切り）。例：ABC234-DEFG-HJKL-MNPQ-RSTU。0・1・I・Oは使いません。クラス識別子もサーバーで自動発行し、クラス名の変更とは独立します。コード入力は小文字・空白・ハイフンの有無を吸収します。クラス名や生徒名だけでログインすることはできません。

新しい生徒のFirestore UIDを先に確保し、コード確認後にAdmin SDKのcustom tokenでFirebase Authへ入ります。初回のコードログインでAuthユーザーが作られ、以後は同じUIDを使うため課題・学習記録・コイン・動物園を引き継ぎます。先生はコード発行によって生徒になれず、担当外のクラスの管理もできません。新規クラス作成は既に先生権限を持つ人だけです。

studentLoginCodes（コードのSHA-256をキーにした照合情報）、studentCodeAccounts（生徒UIDに紐付く現在のハッシュ・発行情報）、classLoginPrefixes（クラス識別子の重複予約）はサーバーだけが読み書きします。Firebaseモードではコード平文を保存せず、発行時の応答で一度だけ表示します。画面を閉じる前に本人に渡す用のコード・QRを控えてください。後から再表示はせず、必要なら一覧の「コード発行」で再発行します。再発行は古いコードを無効化し、UIDと保存データは維持します。既にログイン中の端末は自動ログアウトしません。

コード照合は未ログインで利用可能なCallableです。IPごとに1分120回の上限を設け、不正形式・不一致もカウントし、エラーから生徒名を返しません。IPはそのまま保存せず時間窓と組み合わせたハッシュで管理します。studentCodeAttempts.expiresAtのTTLをfirestore.indexes.jsonに設定し、約1時間後を削除対象にしています。実際の削除はFirestore TTLのタイミングに従います。

同じ登録requestIdの再送は生徒やクラスを増やしません。コードを平文保存しないため、発行済みリクエストの再送ではcodeUnavailableを返し、一覧から新しいコードを再発行します。同じ発行リクエストの並行処理でも有効なコードは1つです。生徒数上限100人はメール登録とコード登録で共通、先生が管理できるクラスは100件までです。既存のメール登録生徒にもコードを発行でき、同じUIDで併用できます。

### 端末内デモと検証方法

通常のデバッグ起動では、先生の「その他 → クラス・生徒管理」でクラス・名簿・コードを端末内のschool-accounts-previewに保存します。「その他 → ログアウト」で最初の選択へ戻り、「生徒はこちら → 確定」から発行したコードを入力すると、登録した生徒名で利用を開始できます。端末内モードのコードは同じ端末だけで有効です。Firebaseアカウントは作成せず、別端末や先生の課題・記録とは自動同期しません。

別端末との共有を含むFirebaseのメール不要ログインは、上記のエミュレーター手順で起動して試します。先生でログイン→クラス作成→生徒登録→コードを控える→ログアウト→「生徒（コード）」でコード入力、という流れです。実機のQR読取は別画面や紙に出したQRを使ってください。先生用のGoogleログインは追加していません。

本番にはFunctions・Firestoreルール・インデックス（TTLを含む）の配備と、custom token署名権限（実行サービスアカウントのIAM設定）の確認が必要です。今回、本番への配備・IAM変更は行っていません。


端末内のコード利用では、student.<生徒ID>.*に保存先を分けます。コイン・所持品・課題提出・学習記録・下書き・ゲーム設定は他の生徒の保存データと共有しません。前回の生徒IDだけをstudent-sessionへ保存し、コード文字列はセッションに保存しません。再起動後も「生徒はこちら」を選ぶと同じ生徒として復帰します。ログアウトするとセッションだけを消して役割選択へ戻り、再ログイン時は保存済みのデータを復元します。コード再発行は既存セッションを強制終了しません。

## 端末内のクラス配布・学習記録（2026-10-25）

通常の端末内モードで、先生の「課題」に入ると「課題・学習記録の対象クラス」を選択できます。配布した課題はクラスIDごとに保存し、そのクラスに登録された生徒が同じ端末でコードログインすると読み込みます。あとから登録した生徒にも配布済み課題を読み込みます。他クラスには配布しません。過去のクラス未指定の課題は削除せず、「以前の課題をこのクラスに配布」で選択中クラスへコピーできます。複数回押しても重複配布しません。

先生の提出確認・承認・学習記録・アドバイスは、そのクラスの登録生徒が保存したデータを使います。課題画面を開く際と「提出状況を更新」、学習記録画面を開く際と再読み込みで最新データを取得します。画像・PDFは元の生徒の添付ファイルを参照します。学習記録は保存済みの終了・中断記録が対象で、カメラのライブ監視ではありません。

上の「先生の課題とは自動同期しません」はこの変更前の仕様です。同じ端末内の役割切り替えに対応したもので、別スマホ・PC間の通信やサーバーは追加していません。Firebaseモードの配布処理は変更していません。
