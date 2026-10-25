import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/auth/data/school_account_api.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';
import 'package:zoo_study/features/zoo/presentation/teacher_class_home.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_viewport.dart';

import '../study/memory_storage.dart';

void main() {
  testWidgets('class selection replaces the map with the selected class data', (
    tester,
  ) async {
    final storage = MemoryStorage();
    final api = LocalSchoolAccountApi(storage);
    final first = await api.call('createManagedClass', {'name': 'ひまわり組'});
    await api.call('createManagedClass', {'name': 'さくら組'});
    await storage.write(
      'class-zoo.${first['classId']}',
      GameSnapshot(
        organizationId: 'local',
        studentId: 'class',
        revision: 1,
        coins: 0,
        confirmedAt: DateTime(2026),
        classIds: [first['classId'] as String],
        ownedAnimalIds: ['test-class-animal'],
      ).toJson(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherClassHome(api: api, storage: storage),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ひまわり組の動物園'), findsOneWidget);
    expect(
      tester
          .widget<ZooViewport>(find.byType(ZooViewport))
          .controller
          .ownedAnimals,
      contains('test-class-animal'),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('さくら組').last);
    await tester.pumpAndSettle();
    expect(find.text('さくら組の動物園'), findsOneWidget);
    expect(
      tester
          .widget<ZooViewport>(find.byType(ZooViewport))
          .controller
          .ownedAnimals,
      isEmpty,
    );
    expect(find.text('マイ動物園'), findsNothing);
    expect(find.text('ショップ'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no classes offers class registration', (tester) async {
    var managed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherClassHome(
            api: LocalSchoolAccountApi(MemoryStorage()),
            onManage: () async {
              managed = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('クラスを登録する'));
    await tester.pumpAndSettle();
    expect(managed, isTrue);
    expect(find.byType(ZooViewport), findsNothing);
  });
}
