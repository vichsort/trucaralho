import '../../core/game/persistence.dart';
import '../../core/game/player.dart';
import '../../games/truco/truco_ai.dart';
import '../../games/truco/truco_action.dart';
import '../../games/truco/truco_game.dart';
import '../../games/truco/truco_history.dart';
import '../../games/truco/truco_state.dart';

final class TrucoSession {
  TrucoState _state;
  final TrucoGame game;
  final GameStatePersistence<TrucoState> persistence;
  final String persistenceKey;
  final Map<String, TrucoAI> _ais;
  final TrucoHistoryRecorder _historyRecorder;

  TrucoSession({
    required TrucoState initialState,
    required this.persistence,
    required this.persistenceKey,
    this.game = const TrucoGame(),
    Map<String, TrucoAI> ais = const {},
    DateTime? startedAt,
  })  : _state = initialState,
        _ais = Map.unmodifiable(ais),
        _historyRecorder = TrucoHistoryRecorder(
          initialState: initialState,
          startedAt: startedAt,
        ) {
    _validateAIConfiguration(initialState, ais);
  }

  TrucoState get state => _state;

  TrucoMatchHistory get history => _historyRecorder.build(
        finishedAt: _state.phase == TrucoPhase.gameFinished
            ? DateTime.now()
            : null,
      );

  Future<void> dispatch(TrucoAction action) async {
    _apply(action);
    await _runAITurns();
  }

  Future<void> save({DateTime? savedAt}) => persistence.save(
        persistenceKey,
        _state,
        savedAt: savedAt,
      );

  Future<bool> restore() async {
    final restored = await persistence.restore(persistenceKey);
    if (restored == null) {
      return false;
    }

    _validateAIConfiguration(restored, _ais);
    _state = restored;
    await _runAITurns();
    return true;
  }

  Future<void> deleteSavedState() => persistence.delete(persistenceKey);

  TrucoAI? _aiForCurrentTurn() {
    final playerId = switch (_state.phase) {
      TrucoPhase.playing => _state.turnPlayerId,
      TrucoPhase.waitingTrucoResponse => _state.pendingRaise?.responderId,
      TrucoPhase.waitingElevenDecision => _elevenDecisionPlayerId(),
      TrucoPhase.handFinished || TrucoPhase.gameFinished => null,
    };

    return playerId == null ? null : _ais[playerId];
  }

  String? _elevenDecisionPlayerId() {
    final teamId = _state.handElevenTeamId;
    if (teamId == null) {
      return null;
    }

    final team = _state.teams.firstWhere((team) => team.id == teamId);
    for (final playerId in team.playerIds) {
      final player = _state.players.firstWhere((player) => player.id == playerId);
      if (player.kind == PlayerKind.ai) {
        return player.id;
      }
    }
    return null;
  }

  Player? _currentAIPlayer() {
    final ai = _aiForCurrentTurn();
    if (ai == null) {
      return null;
    }

    final playerId = switch (_state.phase) {
      TrucoPhase.playing => _state.turnPlayerId,
      TrucoPhase.waitingTrucoResponse => _state.pendingRaise!.responderId,
      TrucoPhase.waitingElevenDecision => _elevenDecisionPlayerId()!,
      TrucoPhase.handFinished || TrucoPhase.gameFinished => null,
    };

    if (playerId == null) {
      return null;
    }

    return _state.players.firstWhere((player) => player.id == playerId);
  }

  Future<void> _runAITurns() async {
    while (true) {
      final player = _currentAIPlayer();
      if (player == null) {
        return;
      }

      final ai = _ais[player.id];
      if (ai == null) {
        return;
      }

      final action = ai.chooseAction(_state, player);
      _apply(action);
    }
  }

  void _apply(TrucoAction action) {
    final before = _state;
    final after = game.apply(before, action);

    _historyRecorder.record(
      before: before,
      action: action,
      after: after,
    );

    _state = after;
  }

  void _validateAIConfiguration(
    TrucoState state,
    Map<String, TrucoAI> ais,
  ) {
    for (final entry in ais.entries) {
      final player = state.players.where((player) => player.id == entry.key);
      if (player.isEmpty) {
        throw ArgumentError('IA configurada para jogador inexistente.');
      }
      if (player.single.kind != PlayerKind.ai) {
        throw ArgumentError(
          'Somente jogadores marcados como IA podem possuir estratégia.',
        );
      }
    }
  }
}
