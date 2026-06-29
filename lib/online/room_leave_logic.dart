import '../models/game_state.dart';
import '../models/uno_player.dart';

/// Chỉnh [currentPlayerIndex] sau khi một người rời ván (logic room_service).
int adjustCurrentPlayerIndexAfterLeave({
  required int leaverIndex,
  required int currentPlayerIndex,
  required int playerCountAfter,
}) {
  var idx = currentPlayerIndex;
  if (leaverIndex < idx) {
    idx--;
  } else if (leaverIndex == idx) {
    if (idx >= playerCountAfter) idx = 0;
  } else if (idx >= playerCountAfter) {
    idx = 0;
  }
  return idx;
}

/// Gỡ người chơi khỏi [players] tại chỗ. Trả index lượt mới, hoặc null nếu không tìm thấy.
int? removePlayerFromGameInPlace({
  required List<UnoPlayer> players,
  required int currentPlayerIndex,
  required String leaverId,
}) {
  final leaverIndex = players.indexWhere((p) => p.id == leaverId);
  if (leaverIndex < 0) return null;
  players.removeAt(leaverIndex);
  if (players.isEmpty) return 0;
  return adjustCurrentPlayerIndexAfterLeave(
    leaverIndex: leaverIndex,
    currentPlayerIndex: currentPlayerIndex,
    playerCountAfter: players.length,
  );
}

/// Kết quả gỡ người — dùng trong test khi cần list mới (không mutate).
({List<UnoPlayer> players, int currentPlayerIndex}) removePlayerFromGame({
  required List<UnoPlayer> players,
  required int currentPlayerIndex,
  required String leaverId,
}) {
  final copy = List<UnoPlayer>.from(players);
  final nextIndex = removePlayerFromGameInPlace(
    players: copy,
    currentPlayerIndex: currentPlayerIndex,
    leaverId: leaverId,
  );
  if (nextIndex == null) {
    return (players: players, currentPlayerIndex: currentPlayerIndex);
  }
  return (players: copy, currentPlayerIndex: nextIndex);
}

/// Gỡ người khỏi ván đang chơi; trả true nếu ván kết thúc (còn 1 người).
bool forfeitPlayerInGame({
  required GameState game,
  required String playerId,
  required String playerName,
  required String reason,
}) {
  final nextIndex = removePlayerFromGameInPlace(
    players: game.players,
    currentPlayerIndex: game.currentPlayerIndex,
    leaverId: playerId,
  );
  if (nextIndex == null) return false;
  if (game.players.isEmpty) return true;
  if (game.players.length == 1) {
    game.currentPlayerIndex = nextIndex;
    final winner = game.players.first;
    game.status = GameStatus.finished;
    game.winnerId = winner.id;
    game.log.add('$playerName $reason. ${winner.name} THẮNG!');
    return true;
  }
  game.currentPlayerIndex = nextIndex;
  game.log.add('$playerName $reason.');
  return false;
}

/// Chọn host mới khi host cũ không còn trong phòng.
String resolveHostIdAfterRemoval({
  required String currentHostId,
  required List<String> remainingMemberIdsInOrder,
}) {
  if (remainingMemberIdsInOrder.isEmpty) return currentHostId;
  if (remainingMemberIdsInOrder.contains(currentHostId)) {
    return currentHostId;
  }
  return remainingMemberIdsInOrder.first;
}

/// Đồng bộ [game.players] với danh sách uid còn trong phòng.
void syncGamePlayersWithMembers({
  required GameState game,
  required Set<String> memberIds,
}) {
  if (memberIds.isEmpty) {
    game.players.clear();
    return;
  }
  final currentId = game.players.isNotEmpty &&
          game.currentPlayerIndex < game.players.length
      ? game.players[game.currentPlayerIndex].id
      : null;
  game.players.removeWhere((p) => !memberIds.contains(p.id));
  if (game.players.isEmpty) return;
  if (currentId != null) {
    final idx = game.players.indexWhere((p) => p.id == currentId);
    game.currentPlayerIndex = idx >= 0 ? idx : 0;
  } else {
    game.currentPlayerIndex = 0;
  }
}
