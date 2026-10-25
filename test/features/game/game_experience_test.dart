import 'package:zoo_study/core/storage/game_preferences_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/storage/draft_storage.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';
import 'package:zoo_study/features/game/experience/game_experience.dart';

class MemoryPreferences implements DraftStorage {
  bool failRead = false;
  final data = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async {
    if (failRead) throw StateError('read failed');
    return data[key];
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    data.remove(key);
  }
}

class ManagedPreferences extends MemoryPreferences
    implements GamePreferencesStorage {
  String? remoteGoal;
  int explicitGoalWrites = 0;
  @override
  Future<void> writeGoal(String key, String? goalId) async {
    remoteGoal = goalId;
    explicitGoalWrites++;
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    data[key] = {'goalId': remoteGoal, 'seen': value['seen']};
  }
}

ConfirmedGameReward reward(GameSnapshot state, String id, {String? student}) =>
    ConfirmedGameReward(
      organizationId: state.organizationId,
      studentId: student ?? state.studentId,
      transactionId: id,
      amount: 2,
      source: '自習',
    );
void main() {
  test('cloud goal writes are explicit and background receipts cannot overwrite another device goal', () async {
    final storage = ManagedPreferences();
    final experience = GameExperience(storage: storage);
    addTearDown(experience.dispose);
    await experience.receive(
      MockGameRepository.snapshotFor(DemoScenario.assigned),
    );
    await experience.setGoal('fox');
    expect(storage.remoteGoal, 'fox');
    storage.remoteGoal = 'rabbit';
    await experience.receive(
      MockGameRepository.snapshotFor(DemoScenario.submitted, revision: 2),
    );
    expect(storage.explicitGoalWrites, 1);
    expect(storage.remoteGoal, 'rabbit');
  });

  test(
    'failed preference reads do not overwrite existing goals and can recover',
    () async {
      final storage = MemoryPreferences();
      final snapshot = MockGameRepository.snapshotFor(DemoScenario.assigned);
      final first = GameExperience(storage: storage);
      addTearDown(first.dispose);
      await first.receive(snapshot);
      await first.setGoal('fox');
      storage.failRead = true;
      final second = GameExperience(storage: storage);
      addTearDown(second.dispose);
      await second.receive(snapshot);
      expect(second.ready, isFalse);
      expect(storage.data.values.single['goalId'], 'fox');
      storage.failRead = false;
      await second.receive(snapshot);
      expect(second.goalId, 'fox');
      final other = GameExperience(storage: storage);
      addTearDown(other.dispose);
      await other.receive(
        GameSnapshot(
          organizationId: 'other',
          studentId: 'other',
          revision: 1,
          coins: 0,
          confirmedAt: DateTime.utc(2026),
          classIds: const [],
        ),
      );
      expect(other.goalId, isNull);
    },
  );

  test('confirmed histories baseline once, reject another user, and deduplicate across restart', () async {
    final storage = MemoryPreferences();
    final experience = GameExperience(storage: storage);
    addTearDown(experience.dispose);
    final initial = MockGameRepository.snapshotFor(DemoScenario.assigned);
    await experience.receive(initial);
    await experience.receiveStudyHistory([reward(initial, 'old')]);
    expect(experience.reward, isNull);
    await experience.receiveStudyHistory([
      reward(initial, 'old'),
      reward(initial, 'new'),
    ]);
    expect(experience.reward!.transactionId, 'new');
    await expectLater(
      experience.receiveStudyHistory([
        reward(initial, 'wrong', student: 'other'),
      ]),
      throwsFormatException,
    );
    experience.dismissReward('new');
    await experience.receiveStudyHistory([reward(initial, 'new')]);
    expect(experience.reward, isNull);
    await experience.setGoal('fox');
    final restored = GameExperience(storage: storage);
    addTearDown(restored.dispose);
    await restored.receive(initial);
    expect(restored.goalId, 'fox');
    await restored.receiveStudyHistory([]);
    await restored.receiveStudyHistory([reward(initial, 'new')]);
    expect(restored.reward, isNull);
    expect(initial.coins, 0);
  });
  test('assignment receipts animate only after baseline and never change snapshot coins', () async {
    final experience = GameExperience();
    addTearDown(experience.dispose);
    await experience.receive(
      MockGameRepository.snapshotFor(DemoScenario.assigned),
    );
    final approved = MockGameRepository.snapshotFor(
      DemoScenario.approved,
      revision: 2,
    );
    await experience.receive(approved);
    expect(experience.reward!.amount, 30);
    final id = experience.reward!.transactionId;
    experience.dismissReward(id);
    expect(experience.reward!.amount, 70);
    experience.dismissReward(experience.reward!.transactionId);
    await experience.receive(approved);
    expect(experience.reward, isNull);
    expect(approved.coins, 100);
  });
}
