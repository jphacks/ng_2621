# 新 ZooStudy フェーズ1〜4：ゲーム側の接続契約

## 担当境界と現在地

ユーザー指定により、Codex の今回の担当はゲーム側の連携インターフェースとモックです。
課題管理・認証・先生画面は共同開発者の担当です。`lib/features/study/` は変更しません。
添付の AGENTS.md と ZooStudy_Codex_Implementation_Spec.md は同一内容でした。
調査時点のチェックアウトにはリポジトリ内 AGENTS.md は存在せず、添付を仕様の原本として読みました。

新しい方針は「宿題が、動物園を育てる。」です。
このフェーズでは外部システムの確定結果を読み取り、ゲームの残高・課題状態・履歴に表示します。
課題作成、回答送信、講師承認、報酬の実付与、認証は担当範囲外です。フェーズ3で購入のゲーム側インターフェースとインメモリモックを追加しました。本番の購入処理はまだ未接続です。
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
- `ownedAnimalIds` / `ownedFacilityIds` は購入連携用に予約しています。フェーズ3から確定した所持状態と描画が連動します。未接続・未購入では動物を表示せず、未所持の施設も描画しません。元の定義や素材は残しています。
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
C:\flutter\bin\flutter.bat run -d emulator-5554 --dart-define=ZOOSTUDY_DEMO=true --dart-define=ZOOSTUDY_DEMO_BONUS_COINS=0
```

課題ボタンで固定の未提出課題を確認します。状態例を変える場合はアプリを停止して、例えば以下で再起動します。

```powershell
C:\flutter\bin\flutter.bat run -d emulator-5554 --dart-define=ZOOSTUDY_DEMO=true --dart-define=ZOOSTUDY_DEMO_BONUS_COINS=0 --dart-define=ZOOSTUDY_DEMO_SCENARIO=submitted
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

上記の `--dart-define=ZOOSTUDY_DEMO=true --dart-define=ZOOSTUDY_DEMO_BONUS_COINS=0` で debug 起動し、**その他 → 連携デモ** を開きます。

1. 「初回提出の確定結果を受信」→ 30コイン表示と提出通知。
2. 通知を閉じる。「同じ確定結果を再受信」→ 残高も通知も増えない。
3. 「承認の確定結果を受信」→ 100コイン表示と追加70コインの通知。
4. 通知をタップすると提出30・承認70の履歴が確認できる。

再提出経路は、確認待ちの状態で「再提出依頼を受信」→「再提出の確定結果を受信」→「承認の確定結果を受信」です。残高表示は30→30→100です。
この操作はモックの固定スナップショットの受信シミュレーションで、課題の作成・回答送信・講師権限による承認操作ではありません。
通常起動の未接続状態と profile/release の標準起動経路にはデモメニューを出しません。

フェーズ3で以下の購入契約とショップ・所持動物の描画連動を追加しました。


## フェーズ3：ショップと所持情報の反映

### 購入契約

`GameRepository` の読み取り API は変更せず、同じセッションに `ShopRepository` を追加実装します。

- `Future<ShopCatalog> loadCatalog()`：商品一覧・正規価格・条件の取得。
- `Future<PurchaseReceipt> purchase(PurchaseRequest(requestId, itemId))`：UID・価格・残高をクライアント引数にしません。
- `PurchaseReceipt`：`requestId`, `itemId`, `price`, `revision`。確定後は同じセッションのゲーム状態ストリームにも、減算後残高と所持品を一緒に通知します。
- サーバー実装では認証ユーザーと塾にキーをスコープし、正規カタログ・残高・条件・所有を検証して、購入記録＋残高減算＋所持追加＋revision更新を原子的に実施してください。
- 同じキー・同じ商品は保存済みの結果を返します。同じキーで別商品を要求した場合は `requestConflict`。別キーでも単一所有品の重複購入は拒否します。
- `PurchaseFailure` は未決済と確認できる拒否結果に使います。タイムアウトなど成否が不明な例外では同じキーを再利用して結果を照会／再送します。
- UI の連打抑止だけを二重決済対策にしないでください。モックは await 後に再検証し、その後の残高・所持・記録の更新を await なしでまとめて実行します。

現在は `MockGameRepository implements GameRepository, ShopRepository` がこの契約をインメモリで模擬します。
Firebase の原子性・Security Rules・本番認可・永続保存を実装したものではありません。
`receiveConfirmedSnapshot` は外部の完全な確定結果を置き換えるテスト入口です。アダプターは購入後の所持品・残高を含む一貫した状態を必ず渡してください。
連携デモの受信は専用の `receiveDemoScenario` で既知の報酬を再加算せず、購入済み所持品と消費残高を維持します。

### 商品と表示

`assets/zoo/shop_catalog.json` が商品定義です。モックではこの定義を正規カタログとして扱い、UI が申告した価格は受け取りません。

| 商品 | 価格 | 条件 |
| --- | ---: | --- |
| ウサギ | 100 | なし |
| キツネ | 250 | なし |
| シカ | 400 | キツネ所持 |
| 池 | 200 | なし |
| 森エリア | 500 | 動物3種類所持 |
| 進化キツネ | 800 | キツネ所持。購入しても元のキツネは残る |

動物の価格・条件は商品 JSON、移動範囲・施設のタイル位置は `world.json` に分離しています。
購入後に確定スナップショットを受信すると、所持 ID に対応する動物・施設だけを自動配置します。
既存の動物の位置・待機状態は保持し、施設や柵は所持状態が変わったときだけ背景を再描画します。
未所持の池の予約領域は草地として表示します。元の水タイルデータは削除しません。
動物は仮ドット絵で、画像パスを設定すれば既存の画像読み込み処理で差し替えられます。

### 実演手順

```powershell
git pull --ff-only origin chore/zoo-study-pre-hackday-setup
C:\flutter\bin\flutter.bat run -d emulator-5554 --dart-define=ZOOSTUDY_DEMO=true --dart-define=ZOOSTUDY_DEMO_BONUS_COINS=0
```

1. 起動時は0コイン・動物0匹。
2. その他 → 連携デモ → 初回提出の確定結果を受信。30コインを確認。
3. その他 → ショップ。ウサギは「コイン不足」で購入不可。
4. その他 → 連携デモ → 承認の確定結果を受信。100コインを確認。
5. その他 → ショップ → ウサギの「購入する」→ 金額を確認して「購入を確定」。確定結果を受信すると0コイン・購入済みになる。
6. 「動物園を見る」でショップを閉じる。ウサギ1匹が配置され、ランダムウォークする。ウサギをタップすると詳細が開く。
7. 同じ結果を再受信しても消費した100コインは復活せず、所持動物も消えない。

現在の操作用モックは1課題分の100コインのみです。他の商品や解放条件は十分な確定残高を用意したテストで検証しています。実画面で複数商品を購入するには、課題管理側から追加の確定報酬を供給する必要があります。
モックの残高・購入・再送キーは同一プロセス内では保持され、アプリの再起動でリセットされます。
本物の先生の配布・承認や回答提出の画面は実装していません。最優先フローのゲーム側を受信シミュレーションで検証した段階です。

### 変更ファイル

```text
assets/zoo/shop_catalog.json
assets/zoo/world.json
pubspec.yaml
lib/features/shop/domain/shop_catalog.dart
lib/features/shop/domain/shop_repository.dart
lib/features/shop/data/shop_catalog_loader.dart
lib/features/shop/presentation/shop_panel.dart
lib/features/game/data/mock_game_repository.dart
lib/features/zoo/domain/zoo_world.dart
lib/features/zoo/presentation/zoo_controller.dart
lib/features/zoo/presentation/zoo_map.dart
lib/features/zoo/presentation/zoo_screen.dart
lib/features/zoo/README.md
test/features/shop/shop_repository_test.dart
test/features/shop/shop_flow_test.dart
test/features/shop/facility_map_test.dart
test/features/zoo/zoo_world_test.dart
test/widget_test.dart
docs/game_integration_contract.md
```

次はゲーム側の UX 改善・素材の差し替えと、共同開発者による本番アダプター接続です。進化演出や保存先の実装は未完了です。

フェーズ3の検証結果: `flutter analyze --no-pub` は指摘なし、`flutter test --no-pub` は48件成功。
購入の残高・条件・重複・並行再送、タイムアウト後の同一キー再利用、元動物を残す解放、購入後の報酬再受信、施設の実描画と移動状態の保持を検証しました。
Android のビルド・実機動作、本番 Firebase の取引・認可・永続化は未検証です。


## フェーズ4：ゲーム側 UX

今回の対象はゲーム側だけです。仕様書の講師用フィルター・一括承認、課題提出フォーム、認証、立ち絵・新しい画像素材の追加は実装していません。

### 購入操作

- 「購入する」を押すと確認ダイアログを表示し、商品名・価格・現在の残高と購入後の見込みを示します。「やめる」や戻る操作では購入 API を呼びません。
- 「購入を確定」後にも最新の接続状態・残高・条件・所持を確認し、変化していれば新規の購入を止めます。最終検証は従来どおりリポジトリ／サーバーの責務です。
- リスト下部の商品を購入しても結果・復旧ボタンを見失わないよう、結果表示へスクロールします。
- 確認中は進捗表示と連打抑止。成功カードは画面のアニメーション抑制設定に従って切り替えます。
- 購入応答が20秒返らない場合も成否不明に移行します。タイムアウトはサーバー処理の取消を意味しません。
- 成否不明の場合は他の購入を止め、「購入結果を確認する」で同じキーを再送します。ショップを閉じて開き直しても、同じゲーム画面の生存中はキーと結果確認状態を維持します。
- `ShopPurchaseController` は `ZooScreen` が所有します。`ShopPanel` に同じインスタンスを渡して再利用します。単独でパネルを使う場合は任意注入でき、省略時はパネルが自分で作成・破棄します。
- レシートの requestId・itemId の不一致や無効値は成功扱いせず、成否不明として確認を促します。
- 成功応答だけで表示残高や所持を加算・減算しません。対応する revision と所持情報が届くまで「確定データの反映を待っています」と表示し、新しい購入は止めます。
- 確定状態が反映された後は「動物園を見る」で戻れます。商品読込失敗・残高更新停止・反映待ちには再読み込み操作を用意しています。
- キーの保存はゲーム画面のメモリ内のみです。アプリ再起動をまたぐ結果確認、タイムアウト後の本番サーバーによる照会は永続化・本番アダプター接続時の課題です。

### 動物の操作

- マップ上の動物、または動物一覧の項目から詳細シートを開けます。名前・解放状態・登録済みの進化先を表示し、ショップへ移動できます。
- 小さいスプライトそのものに厳密にタップを合わせる必要がないよう、画面上の中心から24論理ピクセル以内の最も近い動物を選択します。重なった場合は一覧からも選べます。
- 実際の描画変換を使うため、拡大・移動後にも位置が一致します。ドラッグやピンチは動物選択として扱いません。
- 読み上げの動物ラベルにも詳細を開くアクションを付けています。動物一覧は所持情報の更新に追従します。
- 立ち絵や画像素材、既存の移動・購入・報酬データ仕様は変更していません。

### 変更ファイル

```text
lib/features/shop/presentation/shop_purchase_controller.dart
lib/features/shop/presentation/shop_panel.dart
lib/features/zoo/presentation/zoo_map.dart
lib/features/zoo/presentation/zoo_viewport.dart
lib/features/zoo/presentation/zoo_screen.dart
test/features/shop/shop_purchase_controller_test.dart
test/features/shop/shop_ux_test.dart
test/features/shop/shop_flow_test.dart
test/features/zoo/animal_interaction_test.dart
lib/features/zoo/README.md
docs/game_integration_contract.md
```

### 手元での確認

1. デモ起動し、連携デモで提出・承認の確定結果を受信して100コインを表示。
2. ショップでウサギを選び「やめる」。残高・所持が変わらないことを確認。
3. 改めて「購入を確定」。成功後「動物園を見る」で戻る。
4. ウサギをタップして詳細を確認。マップを拡大・移動した後や、動物一覧からも開ける。
5. 通信結果不明や読込失敗は故障を模擬したテストで検証。通常のモックショップは通信エラーを発生させません。

次は共同開発者の課題管理・認証・本番購入アダプターとの統合と、端末での UX 確認です。先生向け画面のフェーズ4は担当範囲外のままです。

フェーズ4ゲーム担当分の検証結果: `flutter analyze --no-pub` は指摘なし、`flutter test --no-pub` は60件成功。
購入キャンセル、確認後の残高再検証、処理中の重複抑止、成否不明・タイムアウトと遅延応答、ショップ再表示時のキー維持、確定状態待ち、読込再試行、スクロール下部での結果表示、文字サイズ2倍、購入後の詳細表示、拡大・移動後の動物選択を検証しました。
Android 実機での操作と本番接続は未検証です。


## 一時的なデバッグ用コイン

debug の明示的デモ起動時に限り、初期残高へ1,000コインを追加します。通常起動の未接続状態や profile/release の標準起動には適用しません。
課題報酬の履歴に偽の取引を作らず、購入残高や重複受信の扱いはそのままです。

```powershell
C:\flutter\bin\flutter.bat run -d emulator-5554 --dart-define=ZOOSTUDY_DEMO=true
```

`ZOOSTUDY_DEMO_BONUS_COINS` の既定値は1000。0で無効化、別の非負整数で変更できます。変更後はアプリを停止して再起動します。
以前のフェーズの操作例は、報酬だけのフローを再現するため0を指定しています。
未提出なら1000、提出結果で1030、承認結果で1100。購入分は減算し、同じ結果を再受信しても消費済みコインは復活しません。
アプリ再起動時はモック全体が初期化され、ボーナスも改めて初期残高に含まれます。本番付与・永続保存ではありません。

## フェーズ5の提案（未着手）

元の指示書はフェーズ4までです。次は「本番接続・保存・端末での総合確認」を置けます。
ゲーム側は認証済みセッションの GameRepository / ShopRepository 接続、取引結果の復旧、Androidでの確認を担当します。
課題管理・認証・先生画面・サーバーでの報酬確定は共同開発者の担当として、無断で変更しません。

## 購入式の囲い・配置更新の追加契約

`GameSnapshot.layout` と `PurchaseRequest.layoutEdit` を追加した。
`itemId: zoo_layout` で購入・差額拡張・無料移動・動物割り当て・施設配置を確定する。
この経路のレシートのみ0コインを許可し、固定商品購入の正数チェックは維持する。
データ形式・価格・冪等性・既存デモへの接続は [囲い仕様](enclosure_system.md) を参照。
