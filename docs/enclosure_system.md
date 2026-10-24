# 池の水際・購入式の囲い・動物配置

## 操作

- 池の四隅は `grassWaterQuarter`、辺は `grassWaterHalf` を内側が水になるよう回転。中央は従来の水タイルを使う。水際を含む占有範囲は従来どおり。
- 「ショップ → 施設 → 柵（囲い）→ サイズと場所を選ぶ」、または「ホーム → 囲い・施設 → 囲いの購入・拡張」から購入する。
- 選択枠をドラッグ、またはマップのタップで左上を指定し、幅・高さ・位置をボタンで調整。確認ダイアログで金額を見て確定する。
- 幅・高さは柵を含むマス数。最小3×3で内側に最低1マス確保。面積1マス5コイン、4×4は80コイン、5×4への拡張は追加20コイン。
- 既存の囲いを選べばいつでも移動・拡張できる。同じサイズの移動は無料。縮小・撤去・返金は今回の対象外。
- 購入した動物は未配置として動物一覧に表示。「動物一覧 → 動物の詳細 → 囲いに配置する」で任意の購入済み囲いを選ぶ。
- 1つの囲いに複数の動物を配置可能。別の囲いへの変更も無料。
- 未配置の動物はマップに表示しない。固定の動物エリアを使った柵は描画しない。

動物の歩行範囲は囲いの内側から生成する。移動・拡張・割り当て変更時も個体を再生成せず、必要なときだけ位置と移動先を内側へ更新する。
囲い同士、通路、水辺、池の設置範囲との重なりを拒否する。後から購入する池の初期位置も予約する。森は動物と共存する従来仕様を維持する。
池の配置も購入済み囲いとの重なりを拒否する。旧動物定義の固定エリアは配置制約に使わない。

## 連携契約とコイン

`ShopRepository.purchase` の既存窓口を使い、ゲーム側で面積・差額を計算する。画面から価格や残高を送らない。

```dart
PurchaseRequest(
  requestId: 'operation-unique-id',
  itemId: 'zoo_layout',
  layoutEdit: LayoutEdit(
    kind: LayoutEditKind.enclosure,
    id: 'pen-id', left: 0, top: 0, width: 4, height: 4,
  ),
)
```

同じ囲いIDの更新は移動・拡張、新しいIDは購入。ほかに `assignAnimal`（動物IDと囲いID）、`facility`（施設IDと座標）がある。
`PurchaseReceipt.price` はこの経路に限り0も許可する。既存の固定価格商品の購入確認処理は従来の正数チェックを維持する。

`GameSnapshot` に省略可能な `layout` を追加した（既存schemaVersion 1と互換）。

```json
{
  "enclosures": [{"id":"pen-id","left":0,"top":0,"width":4,"height":4}],
  "animalEnclosures": {"rabbit":"pen-id","fox":"pen-id"},
  "facilities": [{"facilityId":"pond","left":15,"top":10}]
}
```

- 囲いを所有施設IDに混ぜず、独立した複数インスタンスとして管理する。
- デモの `MockGameRepository` が最新残高・寸法・衝突を検証し、差額引き落としと配置を同時に確定する。
- 結果不明時は同じリクエストID・同じ編集内容で再確認する。異なる内容への同じIDの使い回しは拒否する。
- `LayoutTransactions` を動物園が保持するため、編集画面を閉じても未確認操作を失わない。再確認中に新規操作を送らない。
- 課題側の `DemoAssignmentStore` は変更していない。既存の購入委譲先を拡張し、報酬投影に含まれない配置をゲーム側のデモアダプターで保持する。
- 今後のサーバアダプターは確定スナップショット全体にlayoutを含め、同じ価格・衝突・所持・冪等性を保存側で保証する。

施設位置の標準保存先は `SessionFacilityPlacementRepository` に変更し、同じ確定ゲーム状態で囲いと施設を扱う。
明示的に渡す `placementRepository` は独立したテスト・保存先用として保持するが、実サービスでは囲いと同じ権威データを共有する必要がある。
デモの配置は役割を選び直してもアプリ起動中は保持される。アプリ再起動で初期状態に戻る。永続化・Firebaseは未導入。

## 拡張箇所

- `game/domain/zoo_layout.dart`: 囲い、動物の割り当て、施設位置、編集要求の不変データ。
- `game/domain/layout_rules.dart`: 面積単価、拡張の差額、配置制約。
- `game/data/layout_mutation.dart`: 状態からの検証と次状態の生成。
- `game/presentation/layout_transactions.dart`: 非同期送信、未確認状態、同じ要求の再確認。
- `zoo/presentation/enclosure_screens.dart`: 購入・編集・動物割り当てのUI。
- `zoo/presentation/zoo_controller.dart` / `domain/animal_walker.dart`: 囲いから生成した動物の移動範囲。
- `zoo/presentation/terrain/`: 水際と購入済み柵の描画。動物の毎フレーム更新とは分離。

動物の `movementArea` は旧JSONとの互換用として残すが、アプリの配置済み個体では囲いの範囲を使う。新しい動物定義では省略可能。
現状は1種につき1匹という既存の所持データを維持している。同種複数個体の収集や自由形状の囲いは別の拡張となる。

## 変更ファイル

- 新規: `lib/features/game/domain/zoo_layout.dart`, `layout_rules.dart`, `data/layout_mutation.dart`, `presentation/layout_transactions.dart`。
- 更新: `lib/features/game/domain/game_snapshot.dart`, `data/mock_game_repository.dart`。
- 更新: `lib/features/shop/domain/shop_repository.dart`, `shop_catalog.dart`, `presentation/shop_catalog_filter.dart`, `shop_item_art.dart`, `shop_item_card.dart`, `shop_panel.dart`, `shop_screen.dart`, `assets/zoo/shop_catalog.json`。
- 新規: `lib/features/zoo/data/session_facility_placement_repository.dart`, `presentation/enclosure_screens.dart`, `presentation/terrain/water_edges.dart`。
- 更新: `lib/features/zoo/domain/animal_walker.dart`, `facility_placement.dart`, `zoo_world.dart`, `presentation/zoo_controller.dart`, `zoo_screen.dart`, `zoo_map.dart`, `zoo_viewport.dart`, `presentation/terrain/terrain_painter.dart`。
- 新規テスト: `test/features/game/enclosure_transactions_test.dart`, `layout_retry_test.dart`, `assignment_layout_bridge_test.dart`, `test/features/zoo/enclosure_ui_test.dart`, `terrain/water_edges_test.dart`, `test/support/layout_fixtures.dart`。
- 更新テスト: `test/features/shop/facility_map_test.dart`, `shop_browse_test.dart`, `shop_flow_test.dart`, `shop_repository_test.dart`, `test/features/zoo/animal_interaction_test.dart`, `facility_placement_test.dart`, `game_ui_polish_test.dart`, `zoo_world_test.dart`。
- 説明: 本書、`lib/features/zoo/README.md`, `docs/facility_placement.md`, `shop_browsing.md`, `game_integration_contract.md`。

## 検証

`flutter analyze`: 指摘なし。`flutter test`: 全108件成功。
課題報酬と囲い購入の連携、差額課金、無料移動・配置、複数動物、範囲内歩行、衝突、資金不足、同じ要求の再送、購入から拡張までのUIを検証。
提供画像を加工せず使い、実フォントで水際・縦柵・四隅・配置後の動物園を目視確認した。
Android実機・エミュレーターでの起動確認は未実施。
