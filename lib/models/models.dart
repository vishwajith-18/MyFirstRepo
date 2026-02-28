import 'dart:convert';

class Player {
  final String id;
  final String name;

  Player({required this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};
  factory Player.fromMap(Map<String, dynamic> map) =>
      Player(id: map['id'], name: map['name']);
}

class Team {
  final String id;
  final String name;
  final List<Player> players;

  Team({required this.id, required this.name, required this.players});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'players': jsonEncode(players.map((p) => p.toMap()).toList()),
      };

  factory Team.fromMap(Map<String, dynamic> map) {
    var playersList = (jsonDecode(map['players_json'] ?? '[]') as List)
        .map((p) => Player.fromMap(p))
        .toList();
    return Team(
      id: map['id'].toString(),
      name: map['name'],
      players: playersList,
    );
  }
}

enum WicketType { bowled, caught, runOut, stumped, lbw, hitWicket, other }

class Ball {
  final int runs;
  final bool isWide;
  final bool isNoBall;
  final WicketType? wicket;
  final String? fielderId;
  final String strikerId;
  final String bowlerId;

  Ball({
    required this.runs,
    this.isWide = false,
    this.isNoBall = false,
    this.wicket,
    this.fielderId,
    required this.strikerId,
    required this.bowlerId,
  });

  Map<String, dynamic> toMap() => {
        'runs': runs,
        'isWide': isWide,
        'isNoBall': isNoBall,
        'wicket': wicket?.name,
        'fielderId': fielderId,
        'strikerId': strikerId,
        'bowlerId': bowlerId,
      };

  factory Ball.fromMap(Map<String, dynamic> map) => Ball(
        runs: map['runs'],
        isWide: map['isWide'] ?? false,
        isNoBall: map['isNoBall'] ?? false,
        wicket:
            map['wicket'] != null ? WicketType.values.byName(map['wicket']) : null,
        fielderId: map['fielderId'],
        strikerId: map['strikerId'],
        bowlerId: map['bowlerId'],
      );
}
