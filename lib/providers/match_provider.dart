import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../models/match_model.dart';
import '../services/database_service.dart';
import 'dart:convert';

class MatchState {
  final Match? currentMatch;
  final bool isInnings1;
  final String strikerId;
  final String nonStrikerId;
  final String currentBowlerId;
  final List<Ball> currentInningsBalls;
  final bool isLastManSolo;
  final List<MatchState> history; // For Undo
  final bool isMatchComplete;

  MatchState({
    this.currentMatch,
    this.isInnings1 = true,
    this.strikerId = '',
    this.nonStrikerId = '',
    this.currentBowlerId = '',
    this.currentInningsBalls = const [],
    this.isLastManSolo = false,
    this.history = const [],
    this.isMatchComplete = false,
  });

  MatchState copyWith({
    Match? currentMatch,
    bool? isInnings1,
    String? strikerId,
    String? nonStrikerId,
    String? currentBowlerId,
    List<Ball>? currentInningsBalls,
    bool? isLastManSolo,
    List<MatchState>? history,
    bool? isMatchComplete,
  }) {
    return MatchState(
      currentMatch: currentMatch ?? this.currentMatch,
      isInnings1: isInnings1 ?? this.isInnings1,
      strikerId: strikerId ?? this.strikerId,
      nonStrikerId: nonStrikerId ?? this.nonStrikerId,
      currentBowlerId: currentBowlerId ?? this.currentBowlerId,
      currentInningsBalls: currentInningsBalls ?? this.currentInningsBalls,
      isLastManSolo: isLastManSolo ?? this.isLastManSolo,
      history: history ?? this.history,
      isMatchComplete: isMatchComplete ?? this.isMatchComplete,
    );
  }

  Map<String, dynamic> toMap() => {
    'currentMatch': currentMatch?.toMap(),
    'isInnings1': isInnings1,
    'strikerId': strikerId,
    'nonStrikerId': nonStrikerId,
    'currentBowlerId': currentBowlerId,
    'currentInningsBalls': currentInningsBalls.map((b) => b.toMap()).toList(),
    'isLastManSolo': isLastManSolo,
    'isMatchComplete': isMatchComplete,
  };

  static MatchState fromMap(Map<String, dynamic> map, List<Team> allTeams) {
    Map<String, Team> teamMap = {for (var t in allTeams) t.id: t};
    Match? match;
    if (map['currentMatch'] != null) {
      final m = map['currentMatch'];
      match = Match(
        id: m['id'],
        teamA: teamMap[m['teamA_id']] ?? Team(id: m['teamA_id'], name: 'Unknown', players: []),
        teamB: teamMap[m['teamB_id']] ?? Team(id: m['teamB_id'], name: 'Unknown', players: []),
        maxOvers: m['overs'],
        tossWinnerId: m['toss_winner_id'],
        tossWinnerBatsFirst: m['toss_winner_bats_first'] == 1,
        innings1: m['innings1_json'] != null ? Innings.fromMap(jsonDecode(m['innings1_json'])) : null,
        innings2: m['innings2_json'] != null ? Innings.fromMap(jsonDecode(m['innings2_json'])) : null,
        date: DateTime.parse(m['date']),
        goldenOver: m['golden_over'],
      );
    }

    return MatchState(
      currentMatch: match,
      isInnings1: map['isInnings1'] ?? true,
      strikerId: map['strikerId'] ?? '',
      nonStrikerId: map['nonStrikerId'] ?? '',
      currentBowlerId: map['currentBowlerId'] ?? '',
      currentInningsBalls: (map['currentInningsBalls'] as List?)?.map((b) => Ball.fromMap(b)).toList() ?? [],
      isLastManSolo: map['isLastManSolo'] ?? false,
      isMatchComplete: map['isMatchComplete'] ?? false,
    );
  }
}

class MatchNotifier extends StateNotifier<MatchState> {
  MatchNotifier() : super(MatchState());

  Future<void> saveState() async {
    if (state.currentMatch != null) {
      await DatabaseService.instance.saveCurrentMatchState(
        state.currentMatch!.id,
        jsonEncode(state.toMap()),
      );
    }
  }

  Future<void> startMatch(Match match) async {
    await clearSession();
    state = MatchState(
      currentMatch: match,
      isInnings1: true,
      currentInningsBalls: [],
      history: [],
      isMatchComplete: false,
    );
    await saveState();
  }

  Future<void> setupPlayers(String striker, String nonStriker, String bowler) async {
    state = state.copyWith(
      strikerId: striker,
      nonStrikerId: nonStriker,
      currentBowlerId: bowler,
    );
    await saveState();
  }

  Future<void> recordBall({
    required int runs,
    bool isWide = false,
    bool isNoBall = false,
    WicketType? wicket,
    String? fielderId,
    String? outPlayerId,
  }) async {
    final prevState = state.copyWith(history: []);
    final updatedHistory = [...state.history, prevState];

    int legalBallsParsed = state.currentInningsBalls.where((b) => !b.isWide && !b.isNoBall).length;
    bool isGolden = state.currentMatch?.isGoldenOverActive(legalBallsParsed) ?? false;

    int finalRuns = runs;
    int ballScoreForTeam = runs;
    String? timelineLabel;

    if (isGolden) {
      if (isWide && wicket != null) {
        // Golden Over: Wide + Wicket (net -3 for team, -5 to batter)
        finalRuns = -5;
        ballScoreForTeam = 2 + (-5) + (runs * 2); 
        timelineLabel = "Wd+GO:W(-3)";
      } else if (wicket != null && wicket == WicketType.runOut) {
        // Run out in Golden Over: -5 team runs, PLUS doubled completed runs.
        // A run out on a no-ball additionally concedes the doubled no-ball penalty (+2).
        final noBallPenalty = isNoBall ? 2 : 0;
        finalRuns = -5;
        ballScoreForTeam = -5 + noBallPenalty + (runs * 2);
        timelineLabel = isNoBall
            ? "GO:Nb+W-5${runs > 0 ? '+${runs * 2}' : ''}"
            : "GO:W-5${runs > 0 ? '+${runs * 2}' : ''}";
      } else if (wicket != null) {
        // Wicket in Golden Over: -5 team runs, -5 batsman
        finalRuns = -5;
        ballScoreForTeam = -5;
        timelineLabel = "GO:W-5";
      } else if (isWide) {
        finalRuns = 0; // Wide runs don't go to batter
        ballScoreForTeam = 2; // Doubled from 1
        timelineLabel = "GO:Wd+2";
      } else if (isNoBall) {
        // No-ball: 2 base + (scored runs * 2)
        finalRuns = runs * 2; // Batter gets doubled runs
        ballScoreForTeam = 2 + (runs * 2);
        timelineLabel = runs > 0 ? "Nb$runs→Nb${2 + (runs * 2)}" : "Nb";
      } else {
        // Normal runs doubled; show bullet for dot ball
        finalRuns = runs * 2;
        ballScoreForTeam = runs * 2;
        timelineLabel = runs == 0 ? "GO:•" : "GO:${runs * 2}";
      }
    } else {
      // Normal over logic
      if (isWide || isNoBall) {
        ballScoreForTeam = runs + 1;
      }
      if (isWide && runs > 0) {
        finalRuns = 0; // Wide extra runs do not go to batter
      }
      
      if (isNoBall) {
        timelineLabel = wicket != null
            ? (runs > 0 ? "Nb$runs+W" : "Nb+W")
            : (runs > 0 ? "Nb$runs" : "Nb");
      } else if (isWide && wicket != null) {
        timelineLabel = runs > 0 ? "Wd+${runs}+W" : "Wd+W";
      } else if (isWide) {
        // Show extra runs on wide overthrows, else plain "Wd"
        timelineLabel = runs > 0 ? "Wd+$runs" : null;
      } else if (wicket != null) {
        if (wicket == WicketType.runOut && runs > 0) {
           timelineLabel = "W+$runs";
        } else {
           timelineLabel = "W";
        }
      }
    }

    final newBall = Ball(
      runs: finalRuns,
      isWide: isWide,
      isNoBall: isNoBall,
      wicket: wicket,
      fielderId: fielderId,
      outPlayerId: outPlayerId,
      strikerId: state.strikerId,
      bowlerId: state.currentBowlerId,
      isGolden: isGolden,
      timelineLabel: timelineLabel,
      teamRuns: ballScoreForTeam,
    );

    final updatedBalls = [...state.currentInningsBalls, newBall];
    
    // Core Logic: Striker Rotation
    String newStriker = state.strikerId;
    String newNonStriker = state.nonStrikerId;

    bool isLegal = !isWide && !isNoBall;

    // Rotate strike for odd runs (use physical runs to detect crossing)
    if (!state.isLastManSolo && ((wicket == null || wicket == WicketType.runOut) && (runs % 2 != 0))) {
       final temp = newStriker;
       newStriker = newNonStriker;
       newNonStriker = temp;
    }

    // Over logic
    int legalBallsInInnings = legalBallsParsed + (isLegal ? 1 : 0);
    bool isOverEnd = legalBallsInInnings > 0 && legalBallsInInnings % 6 == 0 && isLegal;

    String newBowler = state.currentBowlerId;
    if (isOverEnd) {
      if (!state.isLastManSolo) {
        // Rotate striker for new over
        final temp = newStriker;
        newStriker = newNonStriker;
        newNonStriker = temp;
      }
      newBowler = ''; // Clear bowler
    }

    // Wicket Handling – compare against post-rotation slots
    if (wicket != null) {
      final playerOut = outPlayerId ?? state.strikerId;
      if (playerOut == newNonStriker) {
        newNonStriker = '';
      } else {
        newStriker = '';
      }
    }

    state = state.copyWith(
      currentInningsBalls: updatedBalls,
      strikerId: newStriker,
      nonStrikerId: newNonStriker,
      currentBowlerId: newBowler,
      history: updatedHistory,
    );

    await saveState();
    await _checkInningsEnd();
  }

  bool shouldPromptLastMan(Team team) {
    int wickets = state.currentInningsBalls.where((b) => b.wicket != null).length;
    return wickets == team.players.length - 1 && !state.isLastManSolo;
  }

  Future<void> endInnings() async {
    if (state.currentMatch == null) return;

    final wasInnings1 = state.isInnings1;

    final finishedInnings = Innings(
      balls: state.currentInningsBalls,
      maxOvers: state.currentMatch!.maxOvers,
    );

    final updatedMatch = state.currentMatch!.copyWith(
      innings1: wasInnings1 ? finishedInnings : state.currentMatch!.innings1,
      innings2: !wasInnings1 ? finishedInnings : state.currentMatch!.innings2,
    );

    state = state.copyWith(
      currentMatch: updatedMatch,
      isMatchComplete: !wasInnings1, // FINISH MATCH IF IT WAS INNINGS 2
      isInnings1: false,
      currentInningsBalls: [],
      strikerId: '',
      nonStrikerId: '',
      currentBowlerId: '',
      isLastManSolo: false,
    );

    // Only persist to permanent match history once the match has actually
    // finished (innings 2 just ended). Saving on innings-1-end would leave an
    // unfinishable "ghost" match in history if the user later discards, and
    // could evict a real completed match via the history limit.
    if (!wasInnings1) {
      await DatabaseService.instance.saveMatch(updatedMatch);
      await DatabaseService.instance.enforceMatchHistoryLimit();
    }
    await saveState();
  }

  void loadMatchForScorecard(Match match) {
    state = state.copyWith(currentMatch: match);
  }

  /// True when the next undo step would step back into an already-finished
  /// (different) innings, rather than just undoing the last ball of the
  /// current one.
  bool wouldUndoCrossInnings() {
    return state.history.isNotEmpty && state.history.last.isInnings1 != state.isInnings1;
  }

  Future<void> undo() async {
    if (state.history.isNotEmpty) {
      final lastState = state.history.last;
      final newHistory = state.history.sublist(0, state.history.length - 1);
      state = lastState.copyWith(history: newHistory);
      await saveState();
    }
  }

  Future<void> setLastManSolo(bool solo) async {
    if (solo && state.currentMatch != null) {
      final battingTeam = state.currentMatch!.battingTeamFor(state.isInnings1);
      final dismissedIds = state.currentInningsBalls
          .where((b) => b.wicket != null)
          .map((b) => b.outPlayerId ?? b.strikerId)
          .toSet();
      final lastBatter = battingTeam.players.firstWhere(
        (p) => !dismissedIds.contains(p.id),
        orElse: () => battingTeam.players.first,
      );
      state = state.copyWith(
        isLastManSolo: true,
        strikerId: lastBatter.id,
        nonStrikerId: '',
      );
    }
    await saveState();
  }

  void resumeMatch(MatchState savedState) {
    state = savedState;
  }

  Future<void> clearSession() async {
    await DatabaseService.instance.clearCurrentMatchState();
    state = MatchState();
  }

  Future<void> _checkInningsEnd() async {
    if (state.currentMatch == null) return;

    final battingTeam = state.currentMatch!.battingTeamFor(state.isInnings1);

    int totalWickets = 0, legalBalls = 0, currentScore = 0;
    for (final b in state.currentInningsBalls) {
      if (b.wicket != null) totalWickets++;
      if (!b.isWide && !b.isNoBall) legalBalls++;
      currentScore += b.teamRuns;
    }
    int maxBalls = state.currentMatch!.maxOvers * 6;

    // All Out if wickets >= total players (minus 1 if solo mode not yet active)
    bool allOut = totalWickets >= battingTeam.players.length;
    bool inningsFinished = allOut || (legalBalls >= maxBalls);

    if (state.isInnings1) {
      if (inningsFinished) {
        await endInnings();
      }
    } else {
      // Innings 2: Chasing logic
      final i1 = state.currentMatch!.innings1;
      if (i1 == null) return;
      
      int target = state.currentMatch!.targetForInnings2;

      if (currentScore >= target || inningsFinished) {
        // Match Finished!
        final finishedInnings2 = Innings(
          balls: state.currentInningsBalls,
          maxOvers: state.currentMatch!.maxOvers,
        );
        final finalMatch = state.currentMatch!.copyWith(
          innings2: finishedInnings2,
        );
        state = state.copyWith(
          currentMatch: finalMatch,
          isMatchComplete: true,
          isInnings1: false,
        );
        await DatabaseService.instance.saveMatch(finalMatch);
        await DatabaseService.instance.enforceMatchHistoryLimit();
        await saveState();
      }
    }
  }
}

final matchProvider = StateNotifierProvider<MatchNotifier, MatchState>((ref) => MatchNotifier());
