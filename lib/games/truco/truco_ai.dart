import 'dart:math';

import '../../core/game/player.dart';
import 'card/card.dart';
import 'trick.dart';
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
    _validateAIPlayer(state, player);

    return switch (state.phase) {
      TrucoPhase.waitingElevenDecision => _chooseEleven(state, player.id),
      TrucoPhase.waitingTrucoResponse => _chooseRaiseResponse(state, player.id),
      TrucoPhase.playing => _choosePlayingAction(
          state,
          player.id,
          _handOf(state, player.id),
        ),
      TrucoPhase.handFinished ||
      TrucoPhase.gameFinished =>
        throw StateError('A IA não pode agir nesta fase.'),
    };
  }

  TrucoAction _chooseEleven(TrucoState state, String playerId) {
    final team = _teamOf(state, playerId);
    if (state.handElevenTeamId != team.id) {
      throw StateError('Esta IA não participa da decisão de Mão de Onze.');
    }

    return random.nextBool()
        ? AcceptEleven(playerId)
        : FoldEleven(playerId);
  }

  TrucoAction _chooseRaiseResponse(TrucoState state, String playerId) {
    final raise = state.pendingRaise;
    if (raise == null) {
      throw StateError('Não há pedido de Truco pendente.');
    }
    if (raise.responderId != playerId) {
      throw StateError('Não é a vez desta IA responder ao Truco.');
    }

    final options = <TrucoAction>[
      AcceptTruco(playerId),
      FoldTruco(playerId),
    ];

    if (raise.requestedValue < 12) {
      options.add(
        RaiseTruco(
          playerId: playerId,
          requestedValue: TrucoRules.nextValue(raise.requestedValue),
        ),
      );
    }

    return options[random.nextInt(options.length)];
  }

  TrucoAction _choosePlayingAction(
    TrucoState state,
    String playerId,
    List<Card> hand,
  ) {
    if (state.turnPlayerId != playerId) {
      throw StateError('Não é a vez desta IA.');
    }

    if (!state.blindHand &&
        !state.elevenHand &&
        TrucoRules.canRaise(state.handValue) &&
        random.nextInt(100) < 25) {
      return RequestTruco(
        playerId: playerId,
        requestedValue: TrucoRules.nextValue(state.handValue),
      );
    }

    return PlayCard(
      playerId: playerId,
      card: hand[random.nextInt(hand.length)],
    );
  }
}

final class BasicTrucoAI implements TrucoAI {
  final Random random;

  BasicTrucoAI({Random? random}) : random = random ?? Random();

  @override
  TrucoAction chooseAction(TrucoState state, Player player) {
    _validateAIPlayer(state, player);

    return switch (state.phase) {
      TrucoPhase.waitingElevenDecision => _chooseEleven(
          state,
          player.id,
          _handOf(state, player.id),
        ),
      TrucoPhase.waitingTrucoResponse => _chooseRaiseResponse(
          state,
          player.id,
          state.hands[player.id] ?? const [],
        ),
      TrucoPhase.playing => _choosePlayingAction(
          state,
          player.id,
          _handOf(state, player.id),
        ),
      TrucoPhase.handFinished ||
      TrucoPhase.gameFinished =>
        throw StateError('A IA não pode agir nesta fase.'),
    };
  }

  TrucoAction _chooseEleven(
    TrucoState state,
    String playerId,
    List<Card> hand,
  ) {
    final team = _teamOf(state, playerId);
    if (state.handElevenTeamId != team.id) {
      throw StateError('Esta IA não participa da decisão de Mão de Onze.');
    }

    return _handStrength(state, hand) >= 2
        ? AcceptEleven(playerId)
        : FoldEleven(playerId);
  }

  TrucoAction _chooseRaiseResponse(
    TrucoState state,
    String playerId,
    List<Card> hand,
  ) {
    final raise = state.pendingRaise;
    if (raise == null) {
      throw StateError('Não há pedido de Truco pendente.');
    }
    if (raise.responderId != playerId) {
      throw StateError('Não é a vez desta IA responder ao Truco.');
    }

    final strength = _handStrength(state, hand);

    if (strength >= 3 &&
        raise.requestedValue < 12 &&
        random.nextInt(100) < 35) {
      return RaiseTruco(
        playerId: playerId,
        requestedValue: TrucoRules.nextValue(raise.requestedValue),
      );
    }

    if (strength >= 2 ||
        (strength == 1 && raise.requestedValue <= 3)) {
      return AcceptTruco(playerId);
    }

    return FoldTruco(playerId);
  }

  TrucoAction _choosePlayingAction(
    TrucoState state,
    String playerId,
    List<Card> hand,
  ) {
    if (state.turnPlayerId != playerId) {
      throw StateError('Não é a vez desta IA.');
    }

    if (!state.blindHand &&
        !state.elevenHand &&
        TrucoRules.canRaise(state.handValue) &&
        _shouldRaise(state, hand)) {
      return RequestTruco(
        playerId: playerId,
        requestedValue: TrucoRules.nextValue(state.handValue),
      );
    }

    return PlayCard(
      playerId: playerId,
      card: _chooseCard(state, playerId, hand),
    );
  }

  bool _shouldRaise(TrucoState state, List<Card> hand) {
    final strength = _handStrength(state, hand);
    if (strength == 0) {
      return false;
    }

    final chance = switch (strength) {
      1 => 10,
      2 => 35,
      _ => 70,
    };

    return random.nextInt(100) < chance;
  }

  Card _chooseCard(
    TrucoState state,
    String playerId,
    List<Card> hand,
  ) {
    final current = _currentTrick(state);

    if (current.isEmpty) {
      return _weakest(state, hand);
    }

    final best = _bestPlayed(state, current);
    final bestTied = current
        .where((play) => TrucoRules.compare(play.card, best.card, state.vira) == 0)
        .toList();
    final bestTeams = bestTied
        .map((play) => _teamOf(state, play.playerId).id)
        .toSet();

    if (bestTeams.length == 1 &&
        bestTeams.single == _teamOf(state, playerId).id) {
      return _weakest(state, hand);
    }

    final winningCards = hand
        .where(
          (card) =>
              TrucoRules.compare(card, best.card, state.vira) > 0,
        )
        .toList();

    if (winningCards.isEmpty) {
      return _weakest(state, hand);
    }

    return _weakest(state, winningCards);
  }

  Card _weakest(TrucoState state, Iterable<Card> cards) {
    return cards.reduce(
      (weakest, card) =>
          TrucoRules.compare(card, weakest, state.vira) < 0 ? card : weakest,
    );
  }

  PlayedCard _bestPlayed(
    TrucoState state,
    List<PlayedCard> cards,
  ) {
    var best = cards.first;
    for (final play in cards.skip(1)) {
      if (TrucoRules.compare(play.card, best.card, state.vira) > 0) {
        best = play;
      }
    }
    return best;
  }

  List<PlayedCard> _currentTrick(TrucoState state) {
    if (state.tricks.isEmpty) {
      return const [];
    }

    final current = state.tricks.last;
    if (current.cards.length == state.players.length) {
      return const [];
    }

    return current.cards;
  }

  int _handStrength(TrucoState state, Iterable<Card> hand) {
    var score = 0;

    for (final card in hand) {
      if (TrucoRules.isManilha(card, state.vira)) {
        score += 3;
        continue;
      }

      final rankStrength = TrucoRules.orderedRanks.indexOf(card.rank);
      if (rankStrength >= 7) {
        score += 2;
      } else if (rankStrength >= 5) {
        score += 1;
      }
    }

    if (score >= 6) return 3;
    if (score >= 3) return 2;
    if (score >= 1) return 1;
    return 0;
  }
}

Player _statePlayerOf(TrucoState state, String playerId) {
  for (final player in state.players) {
    if (player.id == playerId) {
      return player;
    }
  }
  throw StateError('Jogador inexistente.');
}

void _validateAIPlayer(TrucoState state, Player player) {
  final statePlayer = _statePlayerOf(state, player.id);
  if (statePlayer.kind != PlayerKind.ai) {
    throw ArgumentError('TrucoAI só pode controlar jogadores de IA.');
  }
}

List<Card> _handOf(TrucoState state, String playerId) {
  final hand = state.hands[playerId];
  if (hand == null || hand.isEmpty) {
    throw StateError('IA sem cartas disponíveis.');
  }
  return hand;
}

Team _teamOf(TrucoState state, String playerId) {
  for (final team in state.teams) {
    if (team.playerIds.contains(playerId)) {
      return team;
    }
  }
  throw StateError('Jogador não pertence a nenhuma equipe.');
}
