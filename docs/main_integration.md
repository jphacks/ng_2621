# mainとゲーム機能の統合記録

## 統合対象

- main: `52fd0b9`
- ゲーム機能: `c6c5593`（feat/game-next）
- mainの認証・課題・学習検出・ログアウトを保持し、ゲーム側のショップ、ドット絵UI、池・囲い・動物配置を統合。
- 競合した `lib/features/zoo/presentation/zoo_screen.dart` は、両側の引数と画面遷移を保持して解決。
- `test/features/game/assignment_layout_bridge_test.dart` は、永続化の非同期処理に合わせ、ウィジェットを使わない通常の非同期テストに変更。
- 課題管理・認証・Functionsの実装はmainの内容を維持。

## 検証結果

- `flutter pub get`: 成功。
- `flutter analyze`: 指摘なし。
- `flutter test`: 136件成功。課題報酬後の囲い維持、配置、購入、スプライト、学習・認証画面、PDF添付描画を含む。
- PDFテスト用にクラウド環境へClangとPDFiumの実行環境を用意。リポジトリへの追加依存はなし。
- Android実機・エミュレーターでの見た目とネイティブ動作は未確認。
- Functionsテストは依存パッケージとFirebaseエミュレーターが未準備のため未検証。

## 残課題と手動確認

囲い・配置の取引はローカルデモで検証済み。FirebaseStudyRepositoryとFunctionsには配置編集データの送受信が未実装であり、Firebase接続時に同じ配置機能が動くことは保証しない。共同開発者との連携が必要。

Androidでは、ログイン後のホーム表示、学習／課題への遷移、その他からのログアウトを確認する。ローカルデモでは、報酬取得→囲い購入→動物購入・配置→池配置→再起動後の保持を確認する。異なる保存モード間でデータを共有する想定はない。
