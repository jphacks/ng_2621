# ゲームUI改善

## 内容

- 既存の木製ボタン素材を連結する `WoodPanel` / `WoodButton` を追加。画像ファイルは変更しない。
- 課題ボタン、動物数表示、シート見出しで木製素材を使用。
- 詳細シートの見出しと閉じるボタンを固定し、本文だけスクロール。
- 未購入の動物園にショップへの案内を表示。ズーム倍率を表示。
- ショップに「すべて」「動物」「施設」の表示フィルターを追加。
- 購入結果をスクロールで表示し、成功時にチェックマークを短く拡大。アニメーション無効設定に対応。

初期コイン、商品価格、購入処理、認証、課題管理は変更していない。課題ボタンの遷移先も維持する。

## 変更ファイル

- `lib/core/ui/widgets/wood_panel.dart`: 共通の木製枠とボタン。
- `lib/core/ui/zoo_ui.dart`: 共通部品の公開。
- `lib/features/zoo/presentation/zoo_chrome.dart`: ナビとシート枠。
- `lib/features/zoo/presentation/zoo_viewport.dart`: 案内、動物数、倍率表示。
- `lib/features/zoo/presentation/zoo_screen.dart`: ショップを開くコールバック。
- `lib/features/shop/presentation/shop_panel.dart`: 表示フィルターと購入結果の表示。
- `test/features/zoo/game_ui_polish_test.dart`: 案内、フィルター、固定見出し、倍率、押下操作の検証。
- `test/features/shop/shop_flow_test.dart`: 購入成功メッセージが操作領域に表示されることを検証。
- `lib/core/ui/README.md`, `lib/features/zoo/README.md`, 本書: 利用方法と記録。

## 検証

`flutter analyze` は指摘なし、`flutter test` は83件成功。
390×844の描画で空の動物園・所持動物あり・ショップ・購入結果を目視確認した。
目視確認用の残高と所持データは一時テスト内だけで生成し、アプリの初期データには反映していない。
Android実機・エミュレーターでの起動確認はこの環境では未実施。
