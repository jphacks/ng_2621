import 'game_snapshot.dart';

enum GameConnection { disconnected, demo, connected }

/// Implementations bind identity to the authenticated session, not UI input.
/// There is intentionally no setCoins, submit, approve or role-changing API.
abstract interface class GameRepository {
  GameConnection get connection;
  Stream<GameSnapshot> watchGameState();
}

class DisconnectedGameRepository implements GameRepository {
  const DisconnectedGameRepository();

  @override
  GameConnection get connection => GameConnection.disconnected;

  @override
  Stream<GameSnapshot> watchGameState() => const Stream.empty();
}
