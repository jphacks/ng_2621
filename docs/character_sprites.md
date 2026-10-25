# 新しい動物・人物素材

`20261024_2 (4).zip` 内の `20261024_2.png` をそのまま
`assets/sprites/zoo_characters.png` に保存。既存の同名シートは保持しています。
64×64、4列×4段。透明余白だけを切り出し、最近傍で描画します。

| 順番 | 名称 | 表示用ID |
| --- | --- | --- |
| 1 | パンダ | `panda` |
| 2 | 猫 | `cat` |
| 3 | 羊 | `sheep` |
| 4 | カエル | `frog` |
| 5 | ウーパールーパー | `axolotl` |
| 6 | 炎狐 | `fire_fox` |
| 7 | 雪狐 | `snow_fox` |
| 8 | 氷狐 | `ice_fox` |
| 9 | 雷狐 | `lightning_fox` |
| 10 | 霊狐 | `spirit_fox` |
| 11 | 伝説の狐 | `legendary_fox` |
| 12 | 氷帝ペンギン | `ice_emperor_penguin` |
| 13 | kiwi | `kiwi` |
| 14 | 先生（男） | `teacher_male` |
| 15 | 先生（女） | `teacher_female` |
| 16 | 子供 | `child` |

`ZooCharacterSprite(part: ZooCharacterPart.panda, scale: 2)` で表示できます。
人物は `teacherMale` / `teacherFemale` / `child` を指定します。
動物・kiwiの画像は `AnimalArt` に登録し、既存のパンダ仮表示も差し替えました。
人物は動物表示のIDマッピングから除外しています。

素材の順番・IDは上記のとおり。通常動物の販売と特殊な進化先は
`docs/animal_roster.md` にまとめています。

kiwiは入手条件未定です。条件が決まるまで販売・進化・図鑑のデータに登録しません。
先生・子供は人物としての表示APIのみ用意し、先生画面への適用は別途指示を待ちます。
