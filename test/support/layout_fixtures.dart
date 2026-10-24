import 'package:zoo_study/features/game/domain/zoo_layout.dart';

ZooLayout testLayout(Iterable<String> animals) => ZooLayout(
  enclosures: const {
    'test_pen': Enclosure(id: 'test_pen', left: 0, top: 0, width: 4, height: 4),
  },
  animalEnclosures: {for (final id in animals) id: 'test_pen'},
);
