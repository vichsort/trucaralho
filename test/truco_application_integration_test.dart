import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:trucaralho/application/truco/truco_game_config.dart';
import 'package:trucaralho/application/truco/truco_game_factory.dart';
import 'package:trucaralho/application/truco/truco_session.dart';
import 'package:trucaralho/core/game/persistence.dart';
import 'package:trucaralho/core/game/player.dart';
import 'package:trucaralho/core/game/serialization.dart';
import 'package:trucaralho/games/truco/truco_ai.dart';
import 'package:trucaralho/games/truco/truco_action.dart';
import 'package:trucaralho/games/truco/truco_rules.dart';
import 'package:trucaralho/games/truco/truco_state.dart';
import 'package:trucaralho/infrastructure/persistence/file_game_state_store.dart';

final serializer = JsonStateSerializer<TrucoState>(
  encode: (state) => state.toJson(),
  decode: TrucoState.fromJson,
);

TrucoGameFactory factory({Random? random}) => TrucoGameFactory(
      random: random ?? Random(42),
      aiBuilder: (_) => LowestCardAI(),
    );

GameStatePersistence<TrucoState> persistence(Directory directory) =>
    GameStatePersistence<TrucoState>(
      serializer: serializer,
      store: FileGameStateStore(rootDirectory: directory),
      game: 'truco_paulista',
    );

final class LowestCardAI implements TrucoAI {
  @override
  TrucoAction chooseAction(TrucoState state, Player player) {
    if (state.phase == TrucoPhase.waitingElevenDecision) {
      return AcceptEleven(player.id);
    }

    if (state.phase == TrucoPhase.waitingTrucoResponse) {
      return AcceptTruco(player.id);
    }

    final hand = state.hands[player.id];
    if (hand == null || hand.isEmpty) {
      throw StateError('IA sem cartas para jogar.');
    }

    final card = hand.reduce(
      (weakest, candidate) =>
          TrucoRules.compare(candidate, weakest, state.vira) < 0
              ? candidate
              : weakest,
    );

    return PlayCard(playerId: player.id, card: card);
  }
}

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'trucaralho_e15_',
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('factory -> session -> IA joga -> humano continua o fluxo real', () async {
    final setup = factory().create(
      TrucoGameConfig(
        dealerIndex: 1,
        humanName: 'Vitor',
        aiNames: const ['Bot'],
      ),
    );

    final session = setup.createSession(
      persistence: persistence(tempDirectory),
      persistenceKey: 'current',
    );

    expect(session.state.turnPlayerId, 'human');
    expect(
      session.state.hands.values.every((cards) => cards.length == 3),
      isTrue,
    );

    final humanCard = session.state.hands['human']!.first;
    await session.dispatch(
      PlayCard(playerId: 'human', card: humanCard),
    );

    expect(session.history.events.map((event) => event.type), [
      'play_card',
      'play_card',
    ]);
    expect(session.state.tricks.single.cards.length, 2);
    expect(session.state.turnPlayerId, 'human');
  });

  test('mão completa pela composição da aplicação termina e registra histórico', () async {
    final setup = factory().create(
      TrucoGameConfig(
        dealerIndex: 1,
        humanName: 'Vitor',
        aiNames: const ['Bot'],
      ),
    );

    final session = setup.createSession(
      persistence: persistence(tempDirectory),
      persistenceKey: 'current',
    );

    var actions = 0;
    while (session.state.phase == TrucoPhase.playing) {
      if (actions++ >= 6) {
        fail('A mão deveria terminar após no máximo 3 vazas completas.');
      }

      final hand = session.state.hands['human']!;
      final card = hand.reduce(
        (strongest, candidate) =>
            TrucoRules.compare(candidate, strongest, session.state.vira) > 0
                ? candidate
                : strongest,
      );

      await session.dispatch(
        PlayCard(playerId: 'human', card: card),
      );
    }

    expect(session.state.phase, TrucoPhase.handFinished);
    expect(session.state.handWinnerTeamId, isNotNull);
    expect(session.history.hands, hasLength(1));
    expect(session.history.hands.single.handNumber, 1);
    expect(
      session.history.events.where((event) => event.type == 'play_card'),
      hasLength(6),
    );
    expect(session.state.teamScores.values.any((score) => score == 1), isTrue);
  });

  test('estado inicial criado pela factory é persistido em arquivo e restaurado', () async {
    final setup = factory(random: Random(42)).create(
      TrucoGameConfig(),
    );

    final original = setup.createSession(
      persistence: persistence(tempDirectory),
      persistenceKey: 'current',
    );

    await original.save(
      savedAt: DateTime.utc(2026, 9, 22, 18),
    );

    final restored = factory(random: Random(999)).createSession(
      config: TrucoGameConfig(),
      persistence: persistence(tempDirectory),
      persistenceKey: 'current',
    );

    expect(await restored.restore(), isTrue);
    expect(restored.state.toJson(), original.state.toJson());
  });

  test('snapshot pendente de Truco é salvo em arquivo e retomado pela IA após restore', () async {
    final setup = factory().create(
      TrucoGameConfig(
        dealerIndex: 1,
        humanName: 'Vitor',
        aiNames: const ['Bot'],
      ),
    );

    final source = TrucoSession(
      initialState: setup.initialState,
      persistence: persistence(tempDirectory),
      persistenceKey: 'current',
    );

    await source.dispatch(
      const RequestTruco(
        playerId: 'human',
        requestedValue: 3,
      ),
    );

    expect(source.state.phase, TrucoPhase.waitingTrucoResponse);
    expect(source.state.pendingRaise, isNotNull);

    await source.save();

    final restored = setup.createSession(
      persistence: persistence(tempDirectory),
      persistenceKey: 'current',
    );

    expect(await restored.restore(), isTrue);
    expect(restored.state.phase, TrucoPhase.playing);
    expect(restored.state.handValue, 3);
    expect(restored.state.pendingRaise, isNull);
    expect(restored.history.events, hasLength(1));
  });
}
