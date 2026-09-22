enum PlayerKind { human, ai }

final class Player {
  final String id;
  final String name;
  final PlayerKind kind;

  const Player({
    required this.id,
    required this.name,
    this.kind = PlayerKind.human,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: PlayerKind.values.byName(json['kind'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is Player && other.id == id && other.name == name && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, name, kind);
}

final class Team {
  final String id;
  final String name;
  final List<String> playerIds;

  const Team({
    required this.id,
    required this.name,
    required this.playerIds,
  });

  Team copyWith({String? id, String? name, List<String>? playerIds}) => Team(
        id: id ?? this.id,
        name: name ?? this.name,
        playerIds: List.unmodifiable(playerIds ?? this.playerIds),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'playerIds': playerIds,
      };

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        name: json['name'] as String,
        playerIds: List<String>.from(json['playerIds'] as List),
      );
}
