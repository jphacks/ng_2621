# タイル・横柵・テクスチャ

元画像は `assets/sprites/20261023.png` にバイト単位で変更せず保存しています。
追加パッケージ、画像の描き直し、購入・報酬・移動範囲の変更はありません。

## 16パーツ

| 行 | 左から順 |
| --- | --- |
| 1 | grass, grassQuarterDirt, grassHalfDirt, grassQuarterStone |
| 2 | fenceEnd, fenceGate, fence, grassHalfStone |
| 3 | bluePattern, water, dirt, stone |
| 4 | greenPattern, brownStripe, woodPattern, creamPattern |

地形・柵は16×16セルのまま使います。柵を可視部分だけで切り詰めると接続位置がずれるため、透明部分もセルに含めます。
パターン5種は右・下の透明な1ピクセルを除いた15×15を繰り返し、継ぎ目の隙間を防ぎます。

## 呼び出しと回転

```dart
import 'package:zoo_study/core/ui/zoo_ui.dart';

const TerrainSprite(part: TerrainPart.grassQuarterDirt, quarterTurns: 1)
const TerrainSprite(part: TerrainPart.fenceEnd, mirrorX: true)

TerrainTexture(
  part: TerrainPart.creamPattern,
  opacity: 0.14,
  child: yourWidget,
)
```

`quarterTurns` は時計回りに90度単位です。元画像の土1/4は右下、土1/2は下、石1/4は左下、石1/2は左に材料があるため、境界選択時にそれぞれ補正します。
原画像やマップ全体を回転させず、描画するパーツだけを回転します。補間・アンチエイリアスは無効です。

## マップの使い方

- `world.json` の `.` は草、`=` は土、`#` は石、`~` は購入後に表示する池の予約領域です。
- 今回は横道を土、縦道を石にしました。マップの寸法、動物の移動エリア、施設の購入条件・位置は変えていません。
- 草に面した材料の方向に合わせて1/2・1/4を選択します。
- 3/4・内側角・土と石と草の三者が交わる専用素材はないため、複雑な角は既存の全面タイル／優先する材料で補います。新しい形の画像を作成したわけではありません。
- 水面は水タイルを隙間なく繰り返します。森は新しい草地の上に既存の木表現を維持しています。
- 未所持の池は草として表示します。元の水面予約データは維持しています。

境界選択は `presentation/terrain/terrain_selection.dart`、まとめ描画は `terrain_painter.dart` です。
背景は動物の移動フレームごとには再描画せず、画像読込・所有状態の変更に応じて更新します。

## 柵

動物のエリアの上辺・下辺に横柵を配置します。
左端 → 中間（中央はゲート）→ 右端の順に接続し、右端は左端素材の左右反転です。
同じエリアを使うキツネと進化キツネは重ね描きせず1組の柵を共有します。
縦方向の素材は提供されていないため、横柵を90度回転して縦柵にはしていません。以前の仮の四角い線も横柵に置き換えています。
柵は見た目であり、ゲートの開閉・通行・衝突判定は追加していません。移動範囲は既存の矩形設定で制限します。

## パターン

下部ナビにクリーム柄を薄く使います。文字の読みやすさと画面の余白を維持します。
青・緑・茶ストライプ・仮木目も名前付きで登録し、用途が決まったときに呼び出せる状態にしています。意味を決めて画面へ詰め込むことはしていません。

## 表示の確認

`feat/game-next` を更新後、実行を一度停止して再起動します。

```powershell
git pull --ff-only origin feat/game-next
C:\flutter\bin\flutter.bat run -d RFCY201JHGF --dart-define=ZOOSTUDY_DEMO=true
```

起動時に新しい地面・下部のクリーム柄を確認し、動物を購入すると横柵、池を購入すると水面を確認できます。
表示確認用の描画テストでは動物4匹・池・森を配置して目視確認しています。この配置を通常デモの初期所持品へ追加していません。
Android実機での今回の更新確認は未実施です。

## 変更ファイル

```text
assets/sprites/20261023.png
assets/zoo/world.json
lib/core/ui/sprites/sprite_sheet_image.dart
lib/core/ui/sprites/pixel_sprite.dart
lib/core/ui/sprites/terrain_part.dart
lib/core/ui/sprites/terrain_sprite.dart
lib/core/ui/sprites/terrain_texture.dart
lib/core/ui/zoo_ui.dart
lib/core/ui/README.md
lib/features/zoo/domain/zoo_world.dart
lib/features/zoo/presentation/terrain/terrain_selection.dart
lib/features/zoo/presentation/terrain/terrain_painter.dart
lib/features/zoo/presentation/zoo_map.dart
lib/features/zoo/presentation/zoo_chrome.dart
lib/features/zoo/README.md
pubspec.yaml
test/core/ui/terrain_sprite_test.dart
test/features/zoo/terrain/terrain_selection_test.dart
test/features/shop/facility_map_test.dart
docs/terrain_usage.md
```

検証結果: `flutter analyze --no-pub` は指摘なし、`flutter test --no-pub` は70件成功。
16パーツの全可視ピクセルの所属と2倍描画、境界4種の全90度回転、柵端の反転、方向選択、施設の表示切り替え、既存素材と購入フローの回帰を検証しました。
元PNGと登録PNGはSHA-256が一致しています。
