> 最新の囲い対応・配置保存先については [囲い仕様](enclosure_system.md) を参照してください。以下は施設配置の初期実装記録です。

# 施設の配置・移動（池での初期確認）

## 操作

1. ショップの施設タブで池を購入し、商品詳細の「配置・移動する」を押す。
2. または「その他 → 施設の配置・移動 → 池」から開く。
3. マップをタップして施設の左上を指定する。ピンチで拡大、ドラッグでマップを移動できる。
4. 矢印で1マスずつ調整し、「ここに設置」で確定する。

枠とメッセージで設置可否を表示する。キャンセルや戻るでは確定位置を変更しない。
保存中は再送・キャンセル・戻るを停止し、保存失敗時は候補を維持して再試行できる。
一覧・ショップからの画面遷移後も、元の動物園と購入状態を維持する。移動の追加コイン消費はない。

既存動作を維持するため、未編集の購入済み施設は従来の定義位置に表示する。
池のサイズは既存の5×4マス。動物園の座標は内部では0始まり、画面では1始まりで表示する。

## 配置ルール

- 所有する施設のみ。マップ全体に収まる長方形のタイル配置。
- 通路・元からある水辺に重ねない。旧固定池用の水タイルは移動可能な施設の下地として草扱い。
- 他施設の確定位置と重ねない。未配置・未購入施設は初期位置を予約し、後からの購入による衝突を防ぐ。
- 池は未解放の動物も含めた定義上の移動エリアと重ねない。
- 森は従来どおり動物エリアと共存できる。`blocksAnimalAreas` を指定すれば施設ごとに変更可能。

動物の移動ロジックや担当範囲外の課題管理、認証、報酬、購入処理は変更していない。

## 拡張用の構成

| 層 | ファイル・役割 |
| --- | --- |
| 定義 | `zoo_world.dart` の `FacilityDefinition`: ID、表示名、描画種別、初期位置、幅・高さ、動物エリアの制約 |
| 配置データ・ルール | `facility_placement.dart`: IDと座標だけの不変データ、JSON変換、衝突検証。Flutterに依存しない |
| 保存契約 | `facility_placement_repository.dart`: 非同期の `load` / `save` |
| デモ保存 | `memory_facility_placement_repository.dart`: 起動中のメモリ保存 |
| 確定状態 | `ZooController`: 読み込みデータの検証、確定配置の保持、地形だけの再描画通知 |
| 編集 | `facility_placement_screen.dart`: 独立した候補、グリッド・設置可否表示、保存とキャンセル |
| 描画 | `ZooMap` / `ZooTerrainPainter`: 確定位置またはプレビュー位置を参照。元のJSONを変更しない |

`FacilityPlacement` の保存例:

```json
{"facilityId":"pond","left":15,"top":10}
```

施設の追加は `world.json` の施設定義と `shop_catalog.json` の商品を同じIDで追加する。
既存の `water` / `forest` 描画種別なら配置画面を増やさず利用できる。
新しい描画種別・形状が必要なら、定義の検証と地形描画を追加する。現状は矩形・回転なし・1種類につき1施設。

保存先は `ZooScreen(placementRepository: ...)` へ実装を渡して変更できる。
現在は既存デモと同様、アプリ再起動で購入・配置とも初期状態に戻る。永続化やFirebaseは未導入。
将来のサーバ保存は施設IDへの同一座標の更新として扱い、所持情報・配置制約も保存側で検証する。

## 変更ファイル

- 新規: `lib/features/zoo/domain/facility_placement.dart`, `facility_placement_repository.dart`。
- 新規: `lib/features/zoo/data/memory_facility_placement_repository.dart`。
- 新規: `lib/features/zoo/presentation/facility_placement_screen.dart`。
- 更新: `lib/features/zoo/domain/zoo_world.dart`, `assets/zoo/world.json`（施設の表示名追加）。
- 更新: `lib/features/zoo/presentation/zoo_controller.dart`, `zoo_map.dart`, `terrain/terrain_painter.dart`, `zoo_screen.dart`。
- 更新: `lib/features/shop/presentation/shop_screen.dart`, `shop_panel.dart`（購入済み施設から編集する導線）。
- 新規テスト: `test/features/zoo/facility_placement_test.dart`, `facility_placement_ui_test.dart`。
- 更新テスト: `test/features/shop/facility_map_test.dart`（移動後に旧位置の水面が消える検証）。
- 説明: 本書、`lib/features/zoo/README.md`, `docs/shop_browsing.md`。

## 検証

`flutter analyze` 指摘なし、`flutter test` 全100件成功。
配置制約、保存データの復元・不正データ拒否、ズーム後のタップ、キャンセル、保存失敗からの再試行、保存中の二重送信・戻る抑止、縦横の小画面・文字拡大を検証。
実データの池を購入→編集→確定する導線と、移動後の地形描画も確認。
Android実機・エミュレーターでの起動確認は未実施。

## 囲い対応後の更新

旧動物エリアとの判定を、購入済み囲いとの衝突判定に変更した。
水際の四隅・辺には専用の1/4・1/2タイルを使用する。
標準の配置保存は確定したGameSnapshotのlayoutに集約し、独立したメモリ保存はテスト用として残す。
