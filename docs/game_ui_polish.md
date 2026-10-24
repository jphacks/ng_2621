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

## 追加シートによるドット絵UI統一

`20261024_3.png` の木製・クリーム・灰色・黄緑・灰色丸ボタンを枠として使用する。
元PNGやパーツ座標は変更せず、ゲーム内のヘッダー、下部ナビ、倍率表示、案内、商品カード、購入結果、詳細一覧、通知、確認ダイアログを統一した。
閉じる・一覧移動には既存のドット絵アイコン、全体表示には新シートの虫眼鏡を使う。意味に合う素材がない一部の補助アイコンは従来表示を残す。

- `lib/core/ui/widgets/sprite_panel.dart`: 枠の描画、ゲーム内ボタンテーマ、一覧・確認ダイアログ部品（追加）。
- `lib/core/ui/widgets/wood_panel.dart`: 既存APIを維持し、新シートの共通枠へ描画を委譲。
- `lib/core/ui/zoo_ui.dart`: 部品を公開。
- `lib/features/zoo/presentation/zoo_chrome.dart`: ヘッダー、ナビ、シート枠。
- `lib/features/zoo/presentation/zoo_viewport.dart`: 案内枠、倍率、丸型操作ボタン。
- `lib/features/zoo/presentation/zoo_screen.dart`: ゲーム画面内のテーマ適用と詳細一覧の枠。
- `lib/features/shop/presentation/shop_panel.dart`: 商品枠・フィルター・購入結果・確認ダイアログ。
- `lib/features/game/presentation/game_notice_banner.dart`: 通知の枠とドット絵アイコン。通知処理は維持。
- `test/core/ui/sprite_panel_test.dart`: 横長・縦長の枠の四隅が元画像のピクセル・透明度を保つ検証（追加）。
- `test/features/zoo/game_ui_polish_test.dart`: カテゴリ操作の対象を新しいボタンのキーに更新。
- `lib/core/ui/README.md`, 本書: 利用方法と変更記録。

今回の検証は `flutter analyze` 指摘なし、`flutter test` 全86件成功。
390×844の描画を目視確認。既存の小画面・大きな文字・購入キャンセル・購入結果再確認・課題連携テストも成功。
認証・課題管理、コイン計算、価格、所持データ、マップ配置は変更していない。追加パッケージなし。
Android実機での起動確認は未実施。

## 素材指定の調整

- ホームボタンを黄緑からクリーム色に変更（選択中のセマンティクスは維持）。
- 空の動物園のチュートリアルを `zooStudyUI.png` の木製3パーツに変更。内部のショップボタンは維持。
- 「その他」のシート背景には、従来の最下部ナビと同じクリーム柄（`TerrainTexture`）を使用。
- 最下部のホーム・課題・その他ナビ背景を、追加シートのレンガ左・中・右を連結・反復する描画に変更。
- パターン背景でも一覧のタップ時フィードバックが隠れないよう、一覧内に透明なMaterialを配置。

変更ファイル: `lib/core/ui/widgets/wood_panel.dart`, `lib/core/ui/widgets/sprite_panel.dart`,
`lib/features/zoo/presentation/zoo_chrome.dart`, `zoo_screen.dart`, `zoo_viewport.dart`,
`lib/core/ui/README.md`, 本書。
認証・課題管理・購入処理・画像ファイルは変更なし。
検証: `flutter analyze` 指摘なし、`flutter test` 全86件成功。ホームと「その他」の描画を目視確認。

## 接続部分のピクセル修正

レンガの上端2pxを独立させて最上部だけに描画し、下部は不透明な14pxを繰り返すよう変更した。各段に凹みが繰り返される隙間を解消。
旧UIシートの木製3パーツは修正版画像に合わせて高さを12pxから11pxに修正し、透明な最下行を除外。縦方向の中央部分も高さから計算して下端を揃える。

変更ファイル: `lib/core/ui/widgets/sprite_panel.dart`, `lib/core/ui/widgets/wood_panel.dart`,
`lib/core/ui/sprites/zoo_ui_part.dart`, `test/core/ui/sprite_seams_test.dart`, `lib/core/ui/README.md`, 本書。
元画像とゲーム処理は変更なし。レンガ内部の透明な隙間と、木製3パーツの全ピクセルを比較する回帰テストを追加。
検証: `flutter analyze` 指摘なし、`flutter test` 全88件成功。ホーム画面の描画も目視確認。
