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

木製ボタンやスライダーは各パーツを呼び出せる状態です。つなぎ合わせた操作部品、ゲージの値・増減操作、画面への配置は未実装です。
元シートを差し替える際はサイズ・配置が変わらないか確認し、変わる場合は `sourceRect` と `sheetSize` を更新してください。
