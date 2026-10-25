# 発表デモチュートリアル

## 起動

Android StudioのRun ConfigurationのAdditional run argsに以下を追加します。

```text
--dart-define=ZOOSTUDY_PRESENTATION=true
```

生徒端末では「生徒デモをはじめる」を押します。先生役を選ぶ画面・配布や承認を行う操作はありません。
先生端末では通常アプリの既存の先生画面を使用してください。
通信なしで先生画面も試す場合は、さらに `--dart-define=ZOOSTUDY_PRESENTATION_ROLE=teacher` を指定します。この起動も既存の `TeacherAssignmentsScreen`・課題詳細・学習記録・アドバイス画面をそのまま使い、データだけをメモリ内のデモ用に差し替えます。

PowerShellで実機を指定する場合：

```powershell
C:\flutter\bin\flutter.bat devices
C:\flutter\bin\flutter.bat run -d <端末ID> --dart-define=ZOOSTUDY_PRESENTATION=true
```

フラグ変更後は停止して再起動します。`--release` でも明示的なデモ起動に対応します。
Firebase・端末保存データを開く前に発表デモへ入ります。
通常起動の「その他 → 発表デモチュートリアル」からは生徒デモを開始します。

## 発表ルート

実通信は行いません。発表者が以下の順序で操作タイミングを合わせます。

| 順番 | 先生端末 | 生徒端末 |
| --- | --- | --- |
| 1 | 既存画面で「課題を作成」→「課題を配布する」 | 初期資金3,000コインで開始 |
| 2 | 配布済み課題・未提出の状態を表示 | 左下の「配布された課題を見る」→内容を確認 |
| 3 | 生徒の操作を待つ | 「回答する」→用意された回答を提出、＋30コイン |
| 4 | 既存の「提出内容を確認」で回答を表示 | 承認待ちの状態を表示 |
| 5 | 「内容を確認して承認」→「生徒の学習記録」からアドバイスを確認・送信 | 先生の送信操作を待つ |
| 6 | 承認済み・アドバイス送信済みを表示 | 「承認結果を確認」→アドバイスを読み「確認して動物園へ ＋70」 |
| 7 | 操作不要 | ウサギを購入→囲いに配置→池を購入・配置 |
| 8 | 操作不要 | キツネ・研究所を購入→研究所を配置→炎狐へ進化 |
| 9 | 操作不要 | 炎狐を囲いへ→図鑑→「育った園を見る」で完成景 |

生徒の承認結果・アドバイスは「その他 → 課題・先生からのお知らせ」で再確認できます。
課題名・内容・回答例・アドバイス・報酬表示は `PresentationScenario` にまとめています。
先生側の入力は編集可能ですが、変更内容は生徒端末へ届きません。生徒の回答を編集した場合も、先生端末には回答例を表示します。発表では両端末の情報を揃えるため、既定の内容をそのまま使用してください。

購入・配置・進化は実際のボタンを金色の枠でハイライトして誘導し、結果の確定で手順が進みます。
途中で体験資金を手動受領する操作はありません。
配置済みの柵をタップするとウサギなどの購入済み動物を選んで配置でき、研究所をタップすると既存の研究画面が開きます。
動物一覧はデモ中のみ炎狐のページから開きます。左右のページ移動で他の動物も見られます。
通常プレイの図鑑は従来どおり1ページ目から開きます。

案内は左下の旧木製枠に表示し、通常の「最初の仲間を迎えよう」はデモ中に表示しません。
再開・説明・案内表示切り替え・終了は「その他」にまとめています。
通常通知は上から約2.4秒重ねて表示し、デモ通知は左下の木枠内へ一時表示します。
完成景は全画面で表示し、「その他」から再開などを選べます。「自由に見てみる」でゲーム画面に戻れます。

## 説明上の区別

- **端末ごとに独立**：先生デモ用起動では既存画面に隔離したローカルデータを渡します。配布すると提出の回答例を用意するため、生徒の提出後に「提出内容を確認」を開いてください。生徒の受信・結果確認も手動です。通信・複数端末同期・AIによるアドバイス生成の実演ではありません。
- **実処理の再利用**：生徒のローカル課題提出・承認は既存StudyRepositoryで計算し、提出30＋承認70を一度ずつ加算。購入・配置・研究は既存のゲーム処理を使います。
- **デモ設定**：初期資金3,000コインと無料の4×4囲いはデモ専用。課題報酬とは別です。初期化すると3,000コインから再開します。
- **最終景**：27種類・4区画・施設を追加した「完成イメージ」です。通常の購入結果や課題報酬とは区別し、報酬履歴・残高は増やしません。
- **保存しない**：実アカウント・Firebase・既存の端末保存を変更しません。アプリ終了・初期化で消えます。
- **通常処理の維持**：課題管理・認証・Functions・Security Rules・通常アカウントの初期残高は変更していません。追加パッケージもありません。

初期3,000＋課題報酬100−ウサギ100−池200−キツネ250−研究所400−炎狐500＝残高1,650コインです。
デモで追加の購入をした場合は、その分だけ減ります。

## 実装の範囲

- `lib/features/game/demo/`：共通データ、既存先生画面に渡すデモ用データ、生徒のデモ進行、隔離Repository、完成景。先生の独自UIは廃止。
- `TeacherAssignmentsScreen`：文字2倍でも科目の選択欄が横にはみ出さないよう、`isExpanded` の設定だけ追加。
- `AnimalEncyclopedia`：任意の動物のページから開くオプション。通常時の初期ページは維持。
- `ZooScreen` / `ZooViewport` / `ZooMap`：デモでのチュートリアル抑制、柵・配置済み研究所のタップ導線。
- `FacilityPlacementScreen` / `ZooMap`：施設を掴んだ操作を優先し、ドラッグ中は親のスクロール・カメラ操作を抑制。掴んだ位置を保持してタイル単位で追従し、離すと通常の操作に戻る。確定前の変更は保存しない。

## 確認結果

- `flutter analyze --no-pub`：指摘なし。
- `flutter test --no-pub`：202件成功。発表フラグ専用の1件は通常実行ではスキップ。
- 発表フラグありの起動テスト：生徒用・先生用それぞれ1件成功。
- 先生側は既存の課題作成・課題詳細・学習記録画面を使っていることをWidgetテストで確認。

検証対象は、既存先生画面での作成・配布・回答表示・承認・アドバイス送信、生徒の報酬の二重付与防止、3,000コインからのリセット、購入・配置・研究・完成景までの通し操作です。
また、炎狐ページの初期表示、柵からのウサギ配置・キャンセル、研究所タップ、縦ドラッグ時にページ位置が変わらないこと、確定・キャンセル・通常スクロール復帰を検証します。
幅320・高さ568、文字倍率1倍と2倍の先生／生徒画面も対象です。
Android実機2台での同時リハーサルは未実施です。発表前に上記の順序で確認してください。

## 完成イメージの石畳とアーチ

通常動物園と完成景で上下の石畳を同じ幅にします。
横の土道は直通とし、その上下に1/2土、さらに手前の石畳の端に1/2石を使います。
完成景には石畳の中心にアーチ3基を等間隔で配置し、噴水の正面にベンチ、その両隣に植木を対称に配置します。
これらは完成イメージ用の描画装飾で、通常アカウントの施設所有数・配置データは変更しません。

## 変更ファイル

追加：

- `lib/features/game/demo/presentation_scenario.dart`
- `lib/features/game/demo/teacher_demo_screen.dart`
- `test/features/game/demo/teacher_demo_test.dart`
- `test/features/game/demo/demo_map_actions_test.dart`

更新：

- `lib/features/game/demo/demo_tutorial_screen.dart`
- `lib/features/game/demo/demo_tutorial_controller.dart`
- `lib/features/game/demo/demo_guide_panel.dart`
- `lib/features/game/demo/presentation_repository.dart`
- `lib/features/animals/presentation/animal_encyclopedia.dart`
- `lib/features/study/teacher_assignments_screen.dart`
- `lib/features/zoo/presentation/zoo_screen.dart`
- `lib/features/zoo/presentation/zoo_viewport.dart`
- `lib/features/zoo/presentation/zoo_map.dart`
- `lib/features/zoo/presentation/facility_placement_screen.dart`
- `test/features/game/demo/demo_bootstrap_test.dart`
- `test/features/game/demo/demo_tutorial_test.dart`
- `test/features/game/demo/demo_tutorial_ui_test.dart`
- `test/features/zoo/facility_placement_ui_test.dart`
- `README.md`
- `docs/presentation_tutorial.md`
