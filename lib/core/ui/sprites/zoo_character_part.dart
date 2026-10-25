import 'dart:ui';

/// New sheet in user-specified reading order; IDs are independent of unlock rules.
enum ZooCharacterPart {
  panda('panda', 'パンダ', Rect.fromLTWH(3, 3, 11, 13)),
  cat('cat', '猫', Rect.fromLTWH(19, 4, 12, 11)),
  sheep('sheep', '羊', Rect.fromLTWH(34, 4, 14, 10)),
  frog('frog', 'カエル', Rect.fromLTWH(50, 5, 9, 8)),
  axolotl('axolotl', 'ウーパールーパー', Rect.fromLTWH(1, 19, 13, 11)),
  fireFox('fire_fox', '炎狐', Rect.fromLTWH(18, 20, 11, 8)),
  snowFox('snow_fox', '雪狐', Rect.fromLTWH(34, 20, 12, 8)),
  iceFox('ice_fox', '氷狐', Rect.fromLTWH(50, 20, 13, 8)),
  lightningFox('lightning_fox', '雷狐', Rect.fromLTWH(2, 36, 13, 8)),
  spiritFox('spirit_fox', '霊狐', Rect.fromLTWH(18, 35, 13, 9)),
  legendaryFox('legendary_fox', '伝説の狐', Rect.fromLTWH(33, 33, 15, 14)),
  iceEmperorPenguin(
    'ice_emperor_penguin',
    '氷帝ペンギン',
    Rect.fromLTWH(53, 35, 7, 11),
  ),
  kiwi('kiwi', 'kiwi', Rect.fromLTWH(3, 50, 9, 12)),
  teacherMale('teacher_male', '先生（男）', Rect.fromLTWH(21, 51, 5, 12)),
  teacherFemale('teacher_female', '先生（女）', Rect.fromLTWH(36, 51, 7, 12)),
  child('child', '子供', Rect.fromLTWH(53, 56, 5, 7));

  const ZooCharacterPart(this.id, this.label, this.sourceRect);
  final String id, label;
  final Rect sourceRect;

  bool get isPerson =>
      this == teacherMale || this == teacherFemale || this == child;
}
