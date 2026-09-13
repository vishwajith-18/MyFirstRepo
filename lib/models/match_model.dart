import 'dart:convert';
import 'models.dart';

class Innings {
  final List<Ball> balls;
  final int maxOvers;

  Innings({
    required this.balls,
    required this.maxOvers,
  });

  int get totalRuns => balls.fold(0, (sum, b) => sum + b.teamRuns);
  int get totalWickets => balls.where((b) => b.wicket != null).length;
  
  int get legalBalls => balls.where((b) => !b.isWide && !b.isNoBall).length;

  Map<String, Map<String, dynamic>> calculateBatterStats(Team battingTeam) {
    final Map<String, Map<String, dynamic>> stats = {};
    for (final p in battingTeam.players) {
      stats[p.id] = {'runs': 0, 'balls': 0, '4s': 0, '6s': 0, 'dismissed': false, 'howOut': '', 'bowlerId': '', 'fielderId': ''};
    }

    for (final b in balls) {
      if (!b.isWide && stats.containsKey(b.strikerId)) {
        stats[b.strikerId]!['balls'] = (stats[b.strikerId]!['balls'] as int) + 1;
        stats[b.strikerId]!['runs'] = (stats[b.strikerId]!['runs'] as int) + b.runs;
        
        // Count 4s and 6s based on actual runs, even in golden over.
        // During golden over, runs are doubled (4 becomes 8, 6 becomes 12)
        if (b.isGolden) {
          if (b.runs == 8) stats[b.strikerId]!['4s'] = (stats[b.strikerId]!['4s'] as int) + 1;
          if (b.runs == 12) stats[b.strikerId]!['6s'] = (stats[b.strikerId]!['6s'] as int) + 1;
        } else {
          if (b.runs == 4) stats[b.strikerId]!['4s'] = (stats[b.strikerId]!['4s'] as int) + 1;
          if (b.runs == 6) stats[b.strikerId]!['6s'] = (stats[b.strikerId]!['6s'] as int) + 1;
        }
      }
      if (b.wicket != null) {
        final outId = b.outPlayerId ?? b.strikerId;
        if (stats.containsKey(outId)) {
          stats[outId]!['dismissed'] = true;
          stats[outId]!['howOut'] = b.wicket!.name;
          stats[outId]!['bowlerId'] = b.bowlerId;
          stats[outId]!['fielderId'] = b.fielderId ?? '';
        }
      }
    }
    return stats;
  }

  Map<String, Map<String, dynamic>> calculateBowlerStats(Team bowlingTeam) {
    final Map<String, Map<String, dynamic>> stats = {};
    for (final p in bowlingTeam.players) {
      stats[p.id] = {'balls': 0, 'runs': 0, 'wickets': 0};
    }
    for (final b in balls) {
      if (stats.containsKey(b.bowlerId)) {
        if (!b.isWide && !b.isNoBall) {
          stats[b.bowlerId]!['balls'] = (stats[b.bowlerId]!['balls'] as int) + 1;
        }
        stats[b.bowlerId]!['runs'] = (stats[b.bowlerId]!['runs'] as int) + b.teamRuns;
        if (b.wicket != null && b.wicket != WicketType.runOut) {
          stats[b.bowlerId]!['wickets'] = (stats[b.bowlerId]!['wickets'] as int) + 1;
      }
    }
    for (final bId in stats.keys) {
      if ((stats[bId]!['runs'] as int) < 0) stats[bId]!['runs'] = 0;
    }
    return stats;
  }

  Map<String, dynamic> toMap() => {
    'balls': jsonEncode(balls.map((b) => b.toMap()).toList()),
    'maxOvers': maxOvers,
  };

  factory Innings.fromMap(Map<String, dynamic> map) {
    return Innings(
      balls: (jsonDecode(map['balls'] ?? '[]') as List).map((b) => Ball.fromMap(b)).toList(),
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
  final int? goldenOver;

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
    this.goldenOver,
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
    'golden_over': goldenOver,
  };

  Match copyWith({
    Innings? innings1,
    Innings? innings2,
    int? goldenOver,
  }) {
    return Match(
      id: id,
      teamA: teamA,
      teamB: teamB,
      maxOvers: maxOvers,
      tossWinnerId: tossWinnerId,
      tossWinnerBatsFirst: tossWinnerBatsFirst,
      innings1: innings1 ?? this.innings1,
      innings2: innings2 ?? this.innings2,
      date: date,
      goldenOver: goldenOver ?? this.goldenOver,
    );
  }

  Team get teamBattingFirst {
    final tossWon = tossWinnerId == teamA.id ? teamA : teamB;
    return tossWinnerBatsFirst ? tossWon : (tossWon.id == teamA.id ? teamB : teamA);
  }

  Team battingTeamFor(bool isInnings1) =>
      isInnings1 ? teamBattingFirst : (teamBattingFirst.id == teamA.id ? teamB : teamA);

  Team bowlingTeamFor(bool isInnings1) =>
      isInnings1 ? (teamBattingFirst.id == teamA.id ? teamB : teamA) : teamBattingFirst;

  bool isGoldenOverActive(int currentLegalBalls) {
    return goldenOver != null && (currentLegalBalls ~/ 6) + 1 == goldenOver;
  }

  int get targetForInnings2 {
    final i1Score = innings1?.totalRuns ?? 0;
    return i1Score > 0 ? i1Score + 1 : 1;
  }

  /// Human-readable match result string.
  String get resultString {
    final i1 = innings1;
    final i2 = innings2;
    if (i1 == null) return 'Match in progress';
    if (i2 == null) {
      return '${battingTeamFor(true).name}: ${i1.totalRuns}/${i1.totalWickets}';
    }
    if (i2.totalRuns > i1.totalRuns) {
      final team = battingTeamFor(false);
      int wicketsInHand = team.players.length - i2.totalWickets;
      return '${team.name} won by $wicketsInHand wicket${wicketsInHand == 1 ? '' : 's'}';
    } else if (i1.totalRuns > i2.totalRuns) {
      return '${battingTeamFor(true).name} won by ${i1.totalRuns - i2.totalRuns} runs';
    }
    return 'Match Tied!';
  }
}

String getHowOutString(Map<String, dynamic> stat, List<Team> allTeams) {
  Player? findPlayer(String id) {
    for (final t in allTeams) {
      for (final p in t.players) {
        if (p.id == id) return p;
      }
    }
    return null;
  }

  final typeStr = stat['howOut'] as String;
  if (typeStr.isEmpty) return 'not out';
  final type = WicketType.values.byName(typeStr);
  final bowler = findPlayer(stat['bowlerId'])?.name ?? '';
  final fielder = (stat['fielderId'] as String).isNotEmpty 
      ? (findPlayer(stat['fielderId'])?.name ?? '') 
      : '';

  if (type == WicketType.caught) return fielder.isNotEmpty ? 'c $fielder b $bowler' : 'c & b $bowler';
  if (type == WicketType.bowled) return 'b $bowler';
  if (type == WicketType.runOut) return fielder.isNotEmpty ? 'run out ($fielder)' : 'run out';
  if (type == WicketType.stumped) return 'st $fielder b $bowler';
  if (type == WicketType.lbw) return 'lbw b $bowler';
  if (type == WicketType.hitWicket) return 'hit wkt b $bowler';
  return type.name;
}
