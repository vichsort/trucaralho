import 'dart:math';

import '../../core/game/persistence.dart';
import '../../core/game/player.dart';
import '../../games/truco/truco_ai.dart';
import '../../games/truco/truco_game.dart';
import '../../games/truco/truco_state.dart';
import 'truco_game_config.dart';
import 'truco_session.dart';

final class TrucoGameSetup {
  final TrucoState initialState;
  final List<Player> players;
  final List<Team> teams;
  final Map<String, TrucoAI> ais;

  TrucoGameSetup({
    required this.initialState,
    required List<Player> players,
    required List<Team> teams,
    required Map<String, TrucoAI> ais,
  })  : ais = Map.unmodifiable(ais),
        players = List.unmodifiable(players),
        teams = List.unmodifiable(teams);

  TrucoSession createSession({
    required GameStatePersistence<TrucoState> persistence,
    required String persistenceKey,
    DateTime? startedAt,
  }) =>
      TrucoSession(
        initialState: initialState,
        persistence: persistence,
        persistenceKey: persistenceKey,
        ais: ais,
        startedAt: startedAt,
      );
}

final class TrucoGameFactory {
  final Random? random;
  final TrucoGame game;
  final TrucoAI Function(Player player)? aiBuilder;

  const TrucoGameFactory({
    this.random,
    this.game = const TrucoGame(),
    this.aiBuilder,
  });

  TrucoGameSetup create(TrucoGameConfig config) {
    final players = config.buildPlayers();
    final teams = config.buildTeams();
    final dealer = players[config.dealerIndex];
    final openingPlayer = players[(config.dealerIndex + 1) % players.length];

    final resolvedRandom = random ?? Random();
    final resolvedAIBuilder =
        aiBuilder ?? ((player) => BasicTrucoAI(random: resolvedRandom));

    final ais = <String, TrucoAI>{
      for (final player in players.where(
        (player) => player.kind == PlayerKind.ai,
      ))
        player.id: resolvedAIBuilder(player),
    };

    final initialState = game.startGame(
      players: players,
      teams: teams,
      dealerId: dealer.id,
      openingPlayerId: openingPlayer.id,
      random: resolvedRandom,
    );

    return TrucoGameSetup(
      initialState: initialState,
      players: players,
      teams: teams,
      ais: ais,
    );
  }

  TrucoSession createSession({
    required TrucoGameConfig config,
    required GameStatePersistence<TrucoState> persistence,
    required String persistenceKey,
    DateTime? startedAt,
  }) =>
      create(config).createSession(
        persistence: persistence,
        persistenceKey: persistenceKey,
        startedAt: startedAt,
      );
}
