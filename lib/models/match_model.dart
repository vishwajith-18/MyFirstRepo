import 'dart:convert';
import 'models.dart';

class Innings {
  final List<Ball> balls;
  final List<String> playerIds; // Total players in team
  final int maxOvers;

  Innings({
    required this.balls,
    required this.playerIds,
    required this.maxOvers,
  });

  int get totalRuns => balls.fold(0, (sum, b) => sum + b.runs + (b.isWide || b.isNoBall ? 1 : 0));
  int get totalWickets => balls.where((b) => b.wicket != null).length;
  
  int get legalBalls => balls.where((b) => !b.isWide && !b.isNoBall).length;
  String get oversFormatted {
    int overs = legalBalls ~/ 6;
    int ballsInOver = legalBalls % 6;
    return "$overs.$ballsInOver";
  }

  Map<String, dynamic> toMap() => {
    'balls': jsonEncode(balls.map((b) => b.toMap()).toList()),
    'playerIds': playerIds,
    'maxOvers': maxOvers,
  };

  factory Innings.fromMap(Map<String, dynamic> map) {
    return Innings(
      balls: (jsonDecode(map['balls'] ?? '[]') as List).map((b) => Ball.fromMap(b)).toList(),
      playerIds: List<String>.from(map['playerIds'] ?? []),
      maxOvers: map['maxOvers'] ?? 0,
    );
  }
}

class Match {
  final String id;
  final Team teamA;
  final Team teamB;
  final int maxOvers;
  final String tossWinnerId;
  final bool tossWinnerBatsFirst;
  final Innings? innings1;
  final Innings? innings2;
  final DateTime date;

  Match({
    required this.id,
    required this.teamA,
    required this.teamB,
    required this.maxOvers,
    required this.tossWinnerId,
    required this.tossWinnerBatsFirst,
    this.innings1,
    this.innings2,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'teamA_id': teamA.id,
    'teamB_id': teamB.id,
    'overs': maxOvers,
    'toss_winner_id': tossWinnerId,
    'toss_winner_bats_first': tossWinnerBatsFirst ? 1 : 0,
    'innings1_json': innings1 != null ? jsonEncode(innings1!.toMap()) : null,
    'innings2_json': innings2 != null ? jsonEncode(innings2!.toMap()) : null,
    'date': date.toIso8601String(),
  };
}
