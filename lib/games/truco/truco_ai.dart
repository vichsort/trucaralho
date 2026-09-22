import 'dart:math';

import '../../core/game/player.dart';
import 'card/card.dart';
import 'truco_action.dart';
import 'truco_rules.dart';
import 'truco_state.dart';

abstract interface class TrucoAI {
  TrucoAction chooseAction(TrucoState state, Player player);
}

final class RandomTrucoAI implements TrucoAI {
  final Random random;

  RandomTrucoAI({Random? random}) : random = random ?? Random();

  @override
  TrucoAction chooseAction(TrucoState state, Player player) {
    final hand = state.hands[player.id] ?? const <Card>[];
    if (hand.isEmpty) throw StateError('IA sem cartas disponíveis.');
    return PlayCard(
      playerId: player.id,
      card: hand[random.nextInt(hand.length)],
    );
  }
}

/// IA simples baseada apenas no domínio de Truco.
///
/// A estratégia reproduz o comportamento essencial da IA histórica:
/// avalia quantidade de cartas fortes para decidir se aceita/pede aumento.
/// A execução da ação continua sendo responsabilidade de [TrucoGame].
final class BasicTrucoAI implements TrucoAI {
  final Random random;

  BasicTrucoAI({Random? random}) : random = random ?? Random();

  @override
  TrucoAction chooseAction(TrucoState state, Player player) {
    final hand = state.hands[player.id] ?? const <Card>[];
    if (hand.isEmpty) throw StateError('IA sem cartas disponíveis.');

    if (state.phase == TrucoPhase.waitingElevenDecision &&
        _isTeamAtEleven(state, player.id)) {
      return _shouldAcceptEleven(state, player.id)
          ? AcceptEleven(player.id)
          : FoldEleven(player.id);
    }

    if (state.phase == TrucoPhase.waitingTrucoResponse &&
        state.pendingRaise?.responderId == player.id) {
      return _respondToRaise(state, player.id, hand);
    }

    if (state.phase == TrucoPhase.playing &&
        state.turnPlayerId == player.id &&
        !state.blindHand &&
        !state.elevenHand &&
        state.handValue < 12 &&
        _shouldRaise(state, player.id, hand)) {
      return RequestTruco(
        playerId: player.id,
        requestedValue: TrucoRules.nextValue(state.handValue),
      );
    }

    return PlayCard(
      playerId: player.id,
      card: _chooseCard(state, hand),
    );
  }

  TrucoAction _respondToRaise(
    TrucoState state,
    String playerId,
    List<Card> hand,
  ) {
    final raise = state.pendingRaise!;
    final strength = _handStrength(state, hand);

    if (strength >= 2) {
      if (raise.requestedValue < 12 &&
          strength >= 3 &&
          random.nextInt(100) < 35) {
        return RaiseTruco(
          playerId: playerId,
          requestedValue: TrucoRules.nextValue(raise.requestedValue),
        );
      }
      return AcceptTruco(playerId);
    }

    if (strength == 1 && raise.requestedValue < 6) {
      return AcceptTruco(playerId);
    }

    return FoldTruco(playerId);
  }

  bool _shouldAcceptEleven(TrucoState state, String playerId) {
    final hand = state.hands[playerId]!;
    return _handStrength(state, hand) >= 2;
  }

  bool _shouldRaise(TrucoState state, String playerId, List<Card> hand) {
    final strength = _handStrength(state, hand);
    if (strength == 0) return false;
    final baseChance = strength >= 3 ? 70 : strength == 2 ? 35 : 10;
    return random.nextInt(100) < baseChance;
  }

  Card _chooseCard(TrucoState state, List<Card> hand) {
    return hand.reduce(
      (best, card) =>
          TrucoRules.compare(card, best, state.vira) < 0 ? card : best,
    );
  }

  int _handStrength(TrucoState state, List<Card> hand) {
    final strong = hand.where(
      (card) =>
          TrucoRules.isManilha(card, state.vira) ||
          _nonManilhaStrength(card) >= 7,
    );
    return strong.length.clamp(0, 3);
  }

  int _nonManilhaStrength(Card card) {
    return TrucoRules.orderedRanks.indexOf(card.rank);
  }

  bool _isTeamAtEleven(TrucoState state, String playerId) {
    final team = state.teams.firstWhere(
      (team) => team.playerIds.contains(playerId),
    );
    return state.handElevenTeamId == team.id;
  }
}
