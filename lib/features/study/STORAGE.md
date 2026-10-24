# 保存機能の試し方

## 端末内保存：設定なしですぐ確認

    flutter pub get
    flutter run

通常のデバッグ起動は ZOOSTUDY_STORAGE=local です。課題、回答、提出状態、報酬、残高、動物・施設、購入履歴を端末に保存し、アプリを完全終了しても復元します。プラグインを追加したため、初回はホットリロードではなくアプリを停止して再起動してください。

先生・生徒が1つのデモデータを共有します。役割を確定すると最初の選択画面には戻れません。先生・生徒の選択も端末に保存し、終了・再実行後は前回の役割から再開します。開発中に役割だけをリセットする場合は一度だけ flutter run --dart-define=ZOOSTUDY_RESET_ROLE=true で起動し、その後は通常起動に戻してください。課題・回答などは削除しません。課題作成、回答、確認コメントの入力途中も端末に下書き保存します。別端末への同期はありません。保存に失敗した場合は画面に表示し、壊れた既存データを空データで自動上書きしません。

SharedPreferencesはデモと下書きだけに利用します。OSやブラウザーのデータ消去、異常終了時の完全な耐久性、暗号化、改ざん防止は保証しません。本番の残高・提出データの正本はFirestoreです。

## Firebaseエミュレーター：本番プロジェクト不要

Node.js 20とJava 21以上が必要です。WindowsではAndroid Studio付属Javaをスクリプトが検出します。

    cd functions
    npm ci
    cd ..
    .\scripts\start-emulators.ps1

別のターミナルで実行します。

    .\scripts\seed-emulator.ps1
    flutter run --dart-define=ZOOSTUDY_STORAGE=emulator

Webで試す場合は次のコマンドです。

    flutter run -d chrome --dart-define=ZOOSTUDY_STORAGE=emulator

Androidエミュレーターは10.0.2.2、Webは127.0.0.1に接続します。Auth:9099、Firestore:8080、Functions:5001、管理UI:4000を使用します。Android実機では別途ポート転送などが必要です。エミュレーターは外部公開しないでください。

架空のエミュレーター専用アカウント：

| 役割 | メール | パスワード |
|---|---|---|
| 先生 | teacher@example.test | ZooStudyDemo123! |
| 生徒A | student@example.test | ZooStudyDemo123! |
| 生徒B | student2@example.test | ZooStudyDemo123! |

固定パスワードはエミュレーター専用です。seedスクリプトはdemo-*プロジェクトとループバック接続以外では停止します。

1. 先生でログインし、「課題」から作成・配布。
2. 生徒でログインし、「課題」からテキスト回答を提出。本人の残高だけ30コイン増加。
3. 先生の課題画面で生徒を選び、承認または再提出依頼。
4. 承認で70コイン追加。再提出では提出報酬を再付与しません。
5. 生徒はショップで100コインのウサギを購入できます。
6. ログインし直してもサーバーの保存情報を取得できます。

同じブラウザープロファイルではAuthのログインがタブ間で共有されます。同時に先生・生徒を開くなら別のブラウザープロファイルを使います。画面でアカウントを切り替える場合は「その他 → ログアウト」を利用してください。

終了はCtrl+C。起動スクリプトは終了時に.firebase/demo-exportへ保存し、次回起動で読み込みます。強制終了・電源断では終了時保存ができない場合があります。

## 本番Firebase接続の準備（今回は未公開）

config/firebase.example.jsonをconfig/firebase.local.jsonへコピーし、対象プラットフォームのFirebaseクライアント設定を記入します。local.jsonはGit対象外です。サービスアカウント秘密鍵をアプリ・Gitへ入れてはいけません。

    flutter run --dart-define-from-file=config/firebase.local.json

Firebaseプロジェクト、Email/Password認証、事前登録したユーザーと所属情報が必要です。自己登録・招待・管理者UIは未実装です。このMVPは1アカウント1クラス、1クラス100人までです。

管理側で以下を用意します。クライアントには直接書き込みを許可しません。

- users/{uid}: organizationId, classId, displayName
- classMemberships/{classId_uid}: organizationId, classId, userId, displayName, role
- classes/{classId}: organizationId

Functionsはasia-northeast1、Node.js 20です。firebase.json、firestore.rules、firestore.indexes.json、functions/を用意しています。今回は本番プロジェクトの作成・デプロイ・課金設定を行っていません。サービス有効化・必要な課金プラン・公開承認を確認して別途配備してください。

認証はFirebase Authentication、読み取り制限はFirestore Security Rules、提出・確認・購入はCallable Functions内でも所属・役割を検証します。報酬と残高はFirestoreトランザクションで更新します。価格はサーバーのカタログから取得し、作成・更新時刻はサーバーで確定します。操作キーを保存するため、応答を受け取れず再送しても二重処理せず、古い提出の再送で状態を戻しません。確認時には回答のバージョンを照合して誤承認を防ぎます。

公開前にはApp Check、監視・利用量管理、保存・削除方針、アカウント無効化、バックアップ・復旧を実環境で確認してください。

## テスト

    flutter analyze
    flutter test
    .\scripts\test-backend.ps1

Flutterは保存・復元・保存失敗・下書きの順序・提出確認UI・購入連携を検証します。バックエンドテスト前には通常のエミュレーターを停止してください。テストは独立したdemo-zoostudy-testエミュレーターで並行実行、報酬重複防止、塾・クラス分離、不正な直接書き込みの拒否、実Authトークン付きCallableを確認します。本番データは使用しません。
