import 'draft_storage.dart';

/// Cloud preferences separate explicit goal edits from background receipt writes.
abstract interface class GamePreferencesStorage implements DraftStorage {
  Future<void> writeGoal(String key, String? goalId);
}
