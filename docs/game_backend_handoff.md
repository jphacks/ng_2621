# ゲーム担当 → 学習・Firebase担当 接続仕様

`feat/account-game-storage` で、以下の購入・配置API、追加カタログ、UID別保存、招待登録を実装しました。Firebaseエミュレーターで検証済みで、本番へのデプロイは未実施です。[アカウント設定](accounts.md) を参照してください。
全体の進め方は [フェーズ資料](game_experience_phases.md) を参照。

## 1. 確定データを返す

`GameRepository.watchGameState()` は現在の認証ユーザーに結び付いた `GameSnapshot` を返す。
所属・生徒IDを固定し、変更ごとに `revision` を単調増加する。
残高・所持品・配置・課題報酬は同じ確定状態から生成する。クライアントに残高を書かせない。

配置には次のDTOを使用する。旧データで `layout` がない場合は空として扱える。

```json
{
  "enclosures": [{"id":"pen1","left":0,"top":0,"width":4,"height":4}],
  "animalEnclosures": {"rabbit":"pen1"},
  "facilities": [{"facilityId":"laboratory","left":11,"top":0}]
}
```

`StudyRepository.loadStudyRecords()` は保存済みレコードの安定した `id`・`studentId`・確定 `rewardCoins` を返す。
ゲーム画面は初回取得を履歴の基準として扱い、学習・記録画面から戻った時に再取得する。
演出IDは `study:<record.id>`。0コインや別生徒の記録では演出しない。
学習画面への遷移は履歴読み込み完了を待たず、取得失敗後の初回成功分は履歴として扱う。
イベント型は `ConfirmedGameReward`。演出済みIDはゲームのUI設定として保存し、サーバー報酬台帳とは分離する。

## 2. 配置編集を購入窓口へ渡す

既存Dart型 `PurchaseRequest` に `layoutEdit` がある。以下のJSONをFirebaseアダプターからCallableへ渡す。

```json
{
  "requestId":"unique-operation-id",
  "itemId":"zoo_layout",
  "layoutEdit":{"kind":"enclosure","id":"pen1","left":0,"top":0,"width":4,"height":4}
}
```

| kind | 必要な値 | 課金 |
| --- | --- | --- |
| enclosure | 囲いID、left/top、width/height | 新規は面積×5、拡張は増分面積×5、同サイズ移動は0 |
| assignAnimal | 動物ID、enclosureId | 0。動物・囲いの所持を検証 |
| facility | 施設ID、left/top | 0。購入済み施設のみ |

応答は `PurchaseReceipt(requestId, itemId, price, revision)` 相当。
同じrequestId・同じ内容の再送には同じ結果を返す。内容が違う再利用は `requestConflict`。
通常商品は正の価格、配置操作だけ価格0を許可する。

## 3. サーバーで検証すること

- 認証・所属・対象の動物園をサーバー側で決定し、クライアント指定UIDを信用しない。
- カタログ・マップ・サイズ・占有範囲はサーバーの正規データを利用。価格をクライアントから受け取らない。
- 囲いは最小3×3。縮小は禁止。範囲外、通路、水辺、他の囲い・施設との衝突を拒否。
- 池・森は従来の予約範囲を保持。追加建築物は未配置なら土地を予約しない。森と囲いは現在のゲーム仕様どおり共存可。
- 追加商品ID：laboratory、bench、topiary、fountain、flowerArch。現在の仮価格・サイズは [建築物資料](building_sprites.md) とJSONを参照。
- 進化商品 evolved_fox はfox所持が条件。元のfoxは消費せず、所有の追加だけを行う。
- 残高検証・減算・所持品／配置更新・取引記録・revision更新を一つの原子的処理にする。

## 4. 共同で行う通し確認

1. 生徒の初回提出で+30、承認で+70。再送で重複しない。
2. 自習保存後の確定額を返し、同じ記録の再保存でコインも演出も重複しない。
3. 4×4囲いで80コイン、5×4への拡張は追加20コイン。同サイズの移動・動物割り当ては無料。
4. 残高不足・未所有の配置・不正な解放条件・他人の操作を拒否する。
5. 同一requestIdの同一内容を再送しても二重課金しない。異なる内容は拒否する。
6. 通信切断中に結果不明となった操作を同じrequestIdで再確認する。
7. 学習報酬と購入を同時実行しても、片方の残高・配置が消えない。
8. 別端末で再ログインし、残高・所持品・囲い・施設・動物の割り当てが復元される。
9. 所属・ユーザーを切り替えて、目標・演出履歴・残高が混ざらない。

ゲーム側で上記の一部をモック検証していても、エミュレーター・本番Firebaseでの検証完了とはしない。
