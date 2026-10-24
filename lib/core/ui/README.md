# 共通のドット絵 UI 素材

```text
assets/ui/zooStudyUI.png          元の透過 PNG（64×64、変更なし）
lib/core/ui/zoo_ui.dart           利用側の import 先
lib/core/ui/sprites/
  zoo_ui_part.dart               全33パーツの名前と元画像のピクセル座標
  zoo_ui_sprite.dart             補間なしの表示ウィジェット
```

ゲーム固有の処理・学習検出への依存はありません。個別 PNG の量産や画像の加工はせず、元シートの必要部分だけを描画します。

## 利用例

```dart
import 'package:zoo_study/core/ui/zoo_ui.dart';

const ZooUiSprite(
  part: ZooUiPart.encyclopediaRed,
  scale: 3,
  semanticLabel: '動物図鑑',
)
```

タップ動作は利用先で `IconButton` などに組み込みます。小さい素材をそのままタップ領域のサイズにしないでください。
`scale` は元画像の1ピクセルを何論理ピクセルで表示するかです。通常は整数を指定し、縦横比を変更しないでください。親からも表示サイズ以上の余裕を与えます。

## パーツ一覧

- 上段: `currency1`〜`currency7`。左から順。通貨や EXP への割り当ては未定義。
- 2段目: `cross`, `check`, `exclamation`, `dot`, `smile`, `cry`。
- 3段目: `sickness`, `anger`, `woodenButtonLeft`, `woodenButtonMiddle`, `woodenButtonRight`。
- 4段目: `lock`, `back`, `arrowLeft`, `arrowRight`, `encyclopediaRed`, `encyclopediaBlue`。
- 最下段: `cylinder`, `cylinderGauge`, `plus`, `minus`, `sliderLeft`, `sliderMiddle`, `sliderRight`, `sliderThumb`, `speechBubble`。

木製ボタンは `WoodPanel`（装飾枠）と `WoodButton`（押下操作）で連結して利用できます。上下の縁を保ち中央を繰り返し描画します。`WoodButton` は48論理ピクセル以上の操作領域を確保し、アニメーション無効設定では押下アニメーションを停止します。スライダーやゲージの操作部品は未実装です。
元シートを差し替える際はサイズ・配置が変わらないか確認し、変わる場合は `sourceRect` と `sheetSize` を更新してください。


## 追加素材（20261024_2.png）

`assets/sprites/20261024_2.png` に元画像を変更せず登録しています。
`ZooArtPart` が全21パーツの座標、`ZooArtSprite` が表示用 API です。
`PixelSprite` を2つのシートで共有し、従来の `ZooUiSprite` の使い方は変えていません。

```dart
const ZooArtSprite(part: ZooArtPart.bookAndPen, scale: 2)
const ZooArtSprite(part: ZooArtPart.coins, scale: 2)
```

`bookAndPen`, `home`, `shop`, `coins`, `deer`, `rabbit`, `penguin`, `monkey`,
`bird1`〜`bird6`, `rhino`, `fox`, `evolvedFox`, `giraffe`, `elephant`, `pond`, `tree`。
鳥は左上→右上→左中→右中→左下→右下の順です。
詳細は [追加素材の使い方](../../../docs/artwork_usage.md) を参照してください。


## タイル・柵・パターン（20261023.png）

`TerrainPart` が16パーツ、`TerrainSprite` が表示APIです。`quarterTurns` は90度単位、`mirrorX` は左右反転です。
`TerrainTexture` は透明な余白を除いたパターンを繰り返して子ウィジェットの背景に敷きます。
画像の読み込み・共有は `SpriteSheetImage` にまとめ、`PixelSprite` とマップ描画から利用します。
[配置と回転の説明](../../../docs/terrain_usage.md) を参照してください。

## 修正版と追加素材（20261024_3.zip）

`assets/ui/zooStudyUI.png` はZIPの修正版に置き換えました。既存33パーツの座標・APIは維持しています。
`assets/sprites/20261024_3.png` は新しい元画像をそのまま登録しています。
`ZooExtraPart` / `ZooExtraSprite` で16×16の区画を呼び出せます。透明な余白も区画内に保持します。

| 行 | 左から順のパーツ名 |
| --- | --- |
| 1 | `woodenButtonLeft`, `woodenButtonMiddle`, `woodenButtonRight`, `graySquareButton` |
| 2 | `grayRoundButton`, `creamSquareButton`, `limeButtonLeft`, `limeButtonRight` |
| 3 | `magnifyingGlass`, `brickLeft`, `brickMiddle`, `brickRight` |
| 4 | `fenceVertical`, `fenceBottomLeft`, `grassWaterQuarter`, `grassWaterHalf` |

```dart
const ZooExtraSprite(part: ZooExtraPart.magnifyingGlass, scale: 2)
// 左下の角を左右反転して右下にする。
const ZooExtraSprite(part: ZooExtraPart.fenceBottomLeft, mirrorX: true)
// 水際の向きを90度単位で変更する。
const ZooExtraSprite(part: ZooExtraPart.grassWaterQuarter, quarterTurns: 1)
```

追加シートは利用準備までで、マップや既存の木製部品の配置は変更していません。
新しい木製パーツは16×16、従来の木製パーツは別サイズなので同じ座標として扱わないでください。
