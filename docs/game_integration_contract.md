# 新 ZooStudy フェーズ1・2：ゲーム側の接続契約

## 担当境界と現在地

ユーザー指定により、Codex の今回の担当はゲーム側の連携インターフェースとモックです。
課題管理・認証・先生画面は共同開発者の担当です。`lib/features/study/` は変更しません。
添付の AGENTS.md と ZooStudy_Codex_Implementation_Spec.md は同一内容でした。
調査時点のチェックアウトにはリポジトリ内 AGENTS.md は存在せず、添付を仕様の原本として読みました。

新しい方針は「宿題が、動物園を育てる。」です。
このフェーズでは外部システムの確定結果を読み取り、ゲームの残高・課題状態・履歴に表示します。
課題作成、回答送信、講師承認、報酬の実付与、認証、購入の実処理はまだ実装しません。
したがって、指示書のフェーズ1全体の受け入れ条件（先生が配布し、生徒が提出して先生一覧に反映）は、課題管理側との統合後に検証する必要があります。

## 階層

```text
lib/features/game/
  domain/game_snapshot.dart       課題の要約・報酬明細・確定状態のDTO
  domain/game_repository.dart     課題管理の実装に依存しない読み取りインターフェース
  data/mock_game_repository.dart  インメモリの固定結果と外部更新を模擬するテスト入口
  presentation/game_session.dart  購読・読み込み・再試行・古い更新の排除
  presentation/game_status.dart   課題状態／確定報酬履歴の閲覧
```

既存の動物園のマップ・移動ロジック・カメラ・画像素材はそのまま使います。
`ZooStudyApp(gameRepository: adapter)` で課題管理担当が実装するリポジトリを注入できます。
注入したインスタンスの終了処理・認証ユーザー変更時の作り直しは注入元の責務です。
`GameRepository` にコイン加算、提出、承認、ロール変更を行う API はありません。

## データ形式（schemaVersion = 1）

```json
{
  "schemaVersion": 1,
  "organizationId": "demo_org",
  "studentId": "demo_student",
  "classIds": ["demo_class"],
  "revision": 1,
  "confirmedAt": "2026-10-24T03:01:00Z",
  "coins": 30,
  "assignments": [{
    "id": "demo_assignment",
    "organizationId": "demo_org",
    "classId": "demo_class",
    "title": "数学プリント No.3",
    "description": "指定された問題に取り組みましょう。",
    "dueAt": "2026-10-30T14:59:00Z",
    "status": "pending_review",
    "submittedAt": "2026-10-24T03:00:00Z",
    "feedback": null,
    "revisionCount": 0,
    "submissionReward": 30,
    "approvalReward": 70
  }],
  "rewards": [{
    "id": "demo_assignment_demo_student_submit",
    "assignmentId": "demo_assignment",
    "studentId": "demo_student",
    "kind": "submit",
    "amount": 30,
    "confirmedAt": "2026-10-24T03:00:00Z"
  }],
  "ownedAnimalIds": [],
  "ownedFacilityIds": []
}
```

- `watchGameState()` は初期スナップショットと以降の変更を返します。差分ではなく、その時点の一貫した投影全体です。
- 時刻はタイムゾーン付き ISO 8601。Firestore アダプターではサーバー Timestamp を UTC に変換し、UI は端末の現地時刻で表示します。
- `revision` は同一生徒・同一塾の状態についてサーバー側で単調増加する整数です。再送や順序逆転は残高加算せず無視します。
- `coins` は取引後の確定残高です。表示側で30・70を加算したり、履歴の合計から再計算したりしません。
- 課題状態は `not_submitted / pending_review / needs_revision / approved` の4種類。未提出は `submittedAt=null`、それ以外は確定した提出日時が必要です。
- 期限後表示は `submittedAt > dueAt` で判断し、課題状態とは別に表示します。
- 報酬キーは `${assignmentId}_${studentId}_submit` と `${assignmentId}_${studentId}_approve`。履歴に含む課題は `assignments` にも含めます。
- `ownedAnimalIds` / `ownedFacilityIds` は購入連携用に予約しています。フェーズ1の表示用の動物は従来の配置確認用3匹のままで、所持状態とまだ連動しません。
- 混在した塾・クラス・生徒、重複した課題ID・報酬キー、負の残高、未対応スキーマ／状態は受け付けません。これらはクライアントの整合性検査であり、認可の代わりにはなりません。

## 課題管理側への実装依頼

1. 認証セッションから生徒と所属塾・クラスを確定する。画面から渡された任意のUIDやロールを信用しない。
2. 提出・承認時の報酬は信頼できるサーバーのトランザクションで確定する。冪等なキー、対象クラス・生徒・講師の検証、空回答の拒否もサーバー側で行う。
3. 確定した残高・状態・取引履歴・将来の所持品を一貫したスナップショットとして通知する。更新順序で部分的な状態が見えないようにする。
4. 同じユーザーで接続を再開した場合は現在のスナップショットを再送する。ユーザー／塾が変わる場合は GameSession を再作成し、以前の状態を使い回さない。
5. エラーはストリームで通知する。ゲームは前回確定残高を保持し「更新停止」と表示する。再読み込みで再購読する。

Firebase SDK・Cloud Functions・Security Rules は未導入です。クライアントの DTO 受信テストは、本番の権限検証や二重付与防止が完成したことを意味しません。

## ローカルでの確認

通常起動は未接続で、残高は `—`。データがないことを0コインと断定しません。
モックは debug ビルドかつ明示フラグを付けた場合のみ有効です。profile/release の通常起動ではフラグを付けても有効にしません。

```powershell
C:\flutter\bin\flutter.bat run -d emulator-5554 --dart-define=ZOOSTUDY_DEMO=true
```

課題ボタンで固定の未提出課題を確認します。状態例を変える場合はアプリを停止して、例えば以下で再起動します。

```powershell
C:\flutter\bin\flutter.bat run -d emulator-5554 --dart-define=ZOOSTUDY_DEMO=true --dart-define=ZOOSTUDY_DEMO_SCENARIO=submitted
```

| シナリオ | 課題状態 | 固定の確定残高 |
| --- | --- | ---: |
| assigned（既定） | 未提出 | 0 |
| submitted | 確認待ち | 30 |
| needsRevision | 再提出待ち | 30 |
| resubmitted | 確認待ち | 30 |
| approved | 承認済み | 100 |

これらは静的なテスト結果を切り替えるモックで、提出・承認・報酬処理ではありません。
モックの状態はインメモリで、画面の開閉では保持しますがアプリ再起動でリセットされます。
UI には「デモデータ・閲覧専用」と表示します。課題作成・提出・先生向け画面は追加していません。

## 検証と次のフェーズ

`flutter analyze` と `flutter test` を実行します。
DTO の往復、スコープ混在、負残高、期限後、再送・順序逆転、ストリーム更新とエラー復旧、課題UI・報酬履歴を検証します。

フェーズ2のゲーム担当分として、外部で確定した提出30・承認70を受けた通知を追加しました（以下参照）。
続くフェーズ3でカタログ・購入リポジトリの契約を追加し、残高・条件・二重購入の検証と所持動物のマップ反映をモックで動かします。
本番の報酬・購入の原子性と認可はサーバー側担当との接続が必要です。

## このフェーズの変更ファイル

```text
lib/features/game/domain/game_snapshot.dart
lib/features/game/domain/game_repository.dart
lib/features/game/data/mock_game_repository.dart
lib/features/game/presentation/game_session.dart
lib/features/game/presentation/game_status.dart
lib/main.dart
lib/features/zoo/presentation/zoo_screen.dart
lib/features/zoo/presentation/zoo_chrome.dart
lib/features/zoo/README.md
test/features/game/game_integration_test.dart
test/features/game/game_status_test.dart
test/features/game/game_bootstrap_test.dart
test/widget_test.dart
docs/game_integration_contract.md
```

フェーズ0: `flutter pub get --enforce-lockfile`、`flutter analyze --no-pub`、既存14テストが成功。
フェーズ1ゲーム担当分: `flutter analyze --no-pub`、`flutter test --no-pub`（26件）、明示的デモ起動入口のテスト（approvedシナリオ1件）が成功。
このクラウド環境で Android SDK / Xcode によるネイティブビルド・実機確認は未実施です。


## フェーズ2：確定報酬の通知（ゲーム担当分）

追加・変更したファイル:

```text
lib/features/game/domain/game_notice.dart
lib/features/game/presentation/game_notice_banner.dart
lib/features/game/presentation/game_session.dart
lib/features/zoo/presentation/zoo_screen.dart
test/features/game/game_notice_test.dart
test/features/game/game_reward_flow_test.dart
docs/game_integration_contract.md
```

- 最初のスナップショットは既存履歴として扱い、過去の報酬を新規獲得として通知しません。
- それ以降、新しい確定報酬キーを受け取った場合だけ「課題を提出！ +30コイン」「先生が確認！ +70コイン」を表示します。表示額は受信した確定明細を使います。
- 状態が approved に変わっただけでは報酬通知を作りません。通知を表示・閉じてもコインは加算しません。
- 新しい提出報酬と承認報酬を同時に受信した場合も通知は2件に分けてキューに入れます。閉じると次の通知が表示されます。
- 通知は自動消去せず、ユーザーが閉じるまで保持します。タップすると確定履歴が開きます。
- 再提出依頼は1サイクルにつき1回通知します。同じ依頼の再送では重複せず、revisionCount が進んだ後の別の依頼は通知します。再提出結果の受信自体では新たな報酬通知を出しません。
- 再購読・同じ結果の再送・古い revision では再通知しません。受信履歴から一時的に明細が省略されても、同じ GameSession 内の既知キーは維持します。
- この重複抑止は画面の通知に限り、セッション内だけです。アプリ再起動後は最初に受信した履歴を基準にします。DB の二重付与防止・原子性・認可を保証する処理ではありません。

### インタラクティブなデモの操作

上記の `--dart-define=ZOOSTUDY_DEMO=true` で debug 起動し、**その他 → 連携デモ** を開きます。

1. 「初回提出の確定結果を受信」→ 30コイン表示と提出通知。
2. 通知を閉じる。「同じ確定結果を再受信」→ 残高も通知も増えない。
3. 「承認の確定結果を受信」→ 100コイン表示と追加70コインの通知。
4. 通知をタップすると提出30・承認70の履歴が確認できる。

再提出経路は、確認待ちの状態で「再提出依頼を受信」→「再提出の確定結果を受信」→「承認の確定結果を受信」です。残高表示は30→30→100です。
この操作はモックの固定スナップショットの受信シミュレーションで、課題の作成・回答送信・講師権限による承認操作ではありません。
通常起動の未接続状態と profile/release の標準起動経路にはデモメニューを出しません。

次はフェーズ3のゲーム担当分として、購入契約とショップ・所持動物の描画連動を実装します。
