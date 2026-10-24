import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/game/domain/zoo_layout.dart';
import 'package:zoo_study/features/shop/domain/shop_repository.dart';
import 'package:zoo_study/features/study/demo_assignment_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('existing assignment delegate keeps enclosure purchases through later rewards', () async {
    final store = DemoAssignmentStore();
    addTearDown(store.dispose);
    String publish() {
      store.publish(
        DemoAssignment(
          subject: AssignmentSubject.mathematics,
          title: '課題',
          description: '復習',
          dueAt: DateTime(2026, 10, 30),
        ),
      );
      return store.assignments.last.id;
    }

    final first = publish();
    store.submit(first, '回答', role: DemoStudyRole.student);
    store.review(first, role: DemoStudyRole.teacher, approve: true);
    expect(store.coins, 100);
    await rootBundle.loadString('assets/zoo/world.json');
    await store.purchase(
      const PurchaseRequest(
        requestId: 'bridge_pen',
        itemId: 'zoo_layout',
        layoutEdit: LayoutEdit(
          kind: LayoutEditKind.enclosure,
          id: 'p',
          width: 4,
          height: 4,
        ),
      ),
    );
    expect(store.coins, 20);
    final second = publish();
    expect(store.snapshot.layout.enclosures['p']!.area, 16);
    store.submit(second, '回答', role: DemoStudyRole.student);
    expect(store.coins, 50);
    store.review(second, role: DemoStudyRole.teacher, approve: true);
    expect(store.coins, 120);
    expect(store.snapshot.layout.enclosures['p']!.area, 16);
  });
}
