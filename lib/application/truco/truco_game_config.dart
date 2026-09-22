import '../../core/game/player.dart';

enum TrucoGameMode {
  oneVsOne,
  twoVsTwo,
}

final class TrucoGameConfig {
  final TrucoGameMode mode;
  final String humanName;
  final List<String> aiNames;
  final int dealerIndex;

  TrucoGameConfig({
    this.mode = TrucoGameMode.oneVsOne,
    this.humanName = 'Você',
    List<String> aiNames = const ['IA'],
    this.dealerIndex = 0,
  }) : aiNames = List.unmodifiable(aiNames) {
    _validate();
  }

  int get playerCount => switch (mode) {
        TrucoGameMode.oneVsOne => 2,
        TrucoGameMode.twoVsTwo => 4,
      };

  int get aiCount => playerCount - 1;

  void _validate() {
    if (humanName.trim().isEmpty) {
      throw ArgumentError('O nome do jogador humano não pode ser vazio.');
    }
    if (aiNames.length != aiCount) {
      throw ArgumentError(
        'O modo $mode exige exatamente $aiCount jogadores de IA.',
      );
    }
    if (aiNames.any((name) => name.trim().isEmpty)) {
      throw ArgumentError('O nome de um jogador de IA não pode ser vazio.');
    }
    if (dealerIndex < 0 || dealerIndex >= playerCount) {
      throw ArgumentError('Índice de distribuidor inválido.');
    }
  }

  List<Player> buildPlayers() => [
        Player(id: 'human', name: humanName, kind: PlayerKind.human),
        for (var index = 0; index < aiNames.length; index++)
          Player(
            id: 'ai_' + (index + 1).toString(),
            name: aiNames[index],
            kind: PlayerKind.ai,
          ),
      ];

  List<Team> buildTeams() {
    final players = buildPlayers();

    return switch (mode) {
      TrucoGameMode.oneVsOne => [
          Team(
            id: 'team_1',
            name: 'Nós',
            playerIds: [players[0].id],
          ),
          Team(
            id: 'team_2',
            name: 'Adversários',
            playerIds: [players[1].id],
          ),
        ],
      TrucoGameMode.twoVsTwo => [
          Team(
            id: 'team_1',
            name: 'Nós',
            playerIds: [players[0].id, players[2].id],
          ),
          Team(
            id: 'team_2',
            name: 'Adversários',
            playerIds: [players[1].id, players[3].id],
          ),
        ],
    };
  }
}
