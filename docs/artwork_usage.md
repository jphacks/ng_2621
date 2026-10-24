# 20261024_2 の素材と配置

## 配置先

```text
assets/sprites/20261024_2.png              元の64×64透過PNG（変更なし）
lib/core/ui/sprites/zoo_art_part.dart      全21パーツのピクセル座標
lib/core/ui/sprites/zoo_art_sprite.dart    シート専用の表示API
lib/core/ui/sprites/pixel_sprite.dart     既存・追加シートで共用する描画処理
lib/features/animals/presentation/animal_art.dart
                                        動物IDと素材の対応、サイズ調整、代替表示
```

全画像を加工せず、描画時に矩形を指定します。フィルターとアンチエイリアスを無効にして、透過とドットを保持します。
既存 `ZooUiSprite` は同じAPIで使えます。任意の新しいシートを追加する場合は `PixelSprite` に assetPath・sourceRect・scale を指定できます。

## 使用箇所

| 素材 | 使用箇所 |
| --- | --- |
| 本とペン | 下部「課題」 |
| ホーム | 下部「ホーム」 |
| ショップ | その他メニュー、動物詳細からショップへのボタン |
| 山積みコイン | 上部の残高、ショップ価格 |
| ウサギ・キツネ・シカ・進化キツネ | 既存のショップ・マップ・動物一覧・詳細 |
| 池・木 | ショップの池・森エリアの商品アイコン |
| その他の動物・鳥6種類 | 名前付きで登録済み。商品や解放条件は追加していない |

白い動物の表示を見やすくするため、ショップの商品カードは淡い緑に、購入ボタンは既存のゲームUIと同系の緑にしています。
マップの施設タイル、動物の移動、所持・購入・通貨・課題管理・デバッグ残高のルールは変更しません。

## 呼び出し方

```dart
import 'package:zoo_study/core/ui/zoo_ui.dart';

const ZooArtSprite(part: ZooArtPart.home, scale: 2)
const ZooArtSprite(part: ZooArtPart.coins, scale: 2)
```

動物をIDで表示する場合:

```dart
import 'package:zoo_study/features/animals/presentation/animal_art.dart';

const AnimalArt(animalId: 'rabbit', size: 32)
```

鳥は `bird1`〜`bird6`。順序は左上・右上・左中・右中・左下・右下です。
`AnimalArt` の対応IDは rabbit / deer / fox / evolved_fox / penguin / monkey / rhino / giraffe / elephant / bird1〜bird6。
未知のIDは代替アイコン、マップでは従来の色付き仮表示です。world.json に個別の画像パスを指定した場合はそちらを優先します。
動物を販売対象に追加する場合は、別途 world.json と shop_catalog.json に定義し、価格・移動エリア・条件を決める必要があります。画像登録だけで購入や解放は行いません。

## 確認手順

1. feat/game-next を更新し、アプリを停止して再起動する（アセット追加のため）。
2. 既存のデモ起動フラグで起動し、下部ナビ・上部の所持金を確認。
3. その他 → ショップで商品画像を確認。
4. ウサギを購入し、動物園を見る → 動物をタップして同じ素材が表示されることを確認。

新21パーツは全可視ピクセルが1パーツだけに含まれることを検査し、2倍描画の全RGBAを元画像と比較します。
既存33パーツも同様に検証します。画像の描画確認はテスト環境で行い、Android実機での今回の更新確認は未実施です。

## 今回の変更ファイル

```text
assets/sprites/20261024_2.png
lib/core/ui/sprites/pixel_sprite.dart
lib/core/ui/sprites/zoo_art_part.dart
lib/core/ui/sprites/zoo_art_sprite.dart
lib/core/ui/sprites/zoo_ui_sprite.dart
lib/core/ui/zoo_ui.dart
lib/core/ui/README.md
lib/features/animals/presentation/animal_art.dart
lib/features/zoo/presentation/zoo_chrome.dart
lib/features/zoo/presentation/zoo_map.dart
lib/features/zoo/presentation/zoo_screen.dart
lib/features/zoo/README.md
lib/features/shop/presentation/shop_panel.dart
pubspec.yaml
test/core/ui/zoo_art_sprite_test.dart
docs/artwork_usage.md
```

検証: `flutter analyze --no-pub` は指摘なし、`flutter test --no-pub` は63件成功。
ホーム・ショップはテスト描画でも目視確認し、PNGが元ファイルと完全一致することをハッシュで確認しました。
