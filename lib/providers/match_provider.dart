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
        teamA: teamMap[m['teamA_id']]!,
        teamB: teamMap[m['teamB_id']]!,
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

  void saveState() {
    if (state.currentMatch != null) {
      DatabaseService.instance.saveCurrentMatchState(
        state.currentMatch!.id,
        jsonEncode(state.toMap()),
      );
    }
  }

  void startMatch(Match match) {
    state = MatchState(
      currentMatch: match,
      isInnings1: true,
      currentInningsBalls: [],
      history: [],
      isMatchComplete: false,
    );
    saveState();
  }

  void setupPlayers(String striker, String nonStriker, String bowler) {
    state = state.copyWith(
      strikerId: striker,
      nonStrikerId: nonStriker,
      currentBowlerId: bowler,
    );
  }

  void recordBall({
    required int runs,
    bool isWide = false,
    bool isNoBall = false,
    WicketType? wicket,
    String? fielderId,
    String? outPlayerId,
  }) {
    // Save state to history for undo
    final prevState = state.copyWith(history: []);
    final updatedHistory = [...state.history, prevState];

    // GOLDEN OVER LOGIC
    int legalBallsParsed = state.currentInningsBalls.where((b) => !b.isWide && !b.isNoBall).length;
    int currentOverNum = (legalBallsParsed ~/ 6) + 1;
    bool isGolden = state.currentMatch?.goldenOver == currentOverNum;

    int finalRuns = runs;
    int ballScoreForTeam = runs;
    String? timelineLabel;

    if (isGolden) {
      if (wicket != null) {
        // Wicket in Golden Over: -5 team runs, -5 batsman, -5 bowler
        finalRuns = -5;
        ballScoreForTeam = -5;
        timelineLabel = "GO:W-5";
      } else if (isWide) {
        finalRuns = 0; // Wide runs don't go to batter
        ballScoreForTeam = 2; // Doubled from 1
        timelineLabel = "GO:2";
      } else if (isNoBall) {
        // No-ball: 2 base + (scored runs * 2)
        finalRuns = runs * 2; // Batter gets doubled runs
        ballScoreForTeam = 2 + (runs * 2);
        timelineLabel = runs > 0 ? "Nb$runs→Nb${2 + (runs * 2)}" : "Nb";
      } else {
        // Normal runs doubled
        finalRuns = runs * 2;
        ballScoreForTeam = runs * 2;
        timelineLabel = "GO:${runs * 2}";
      }
    } else {
      // Normal over logic
      if (isWide || isNoBall) {
        ballScoreForTeam = runs + 1;
      }
      if (isNoBall) {
        timelineLabel = runs > 0 ? "Nb$runs" : "Nb";
      } else if (wicket != null) {
        timelineLabel = "W";
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
    
    // Rotate for odd runs on legal ball (only if NOT in solo mode)
    if (!state.isLastManSolo && (runs % 2 != 0)) {
       final temp = newStriker;
       newStriker = newNonStriker;
       newNonStriker = temp;
    }

    // Over logic
    int legalBallsInInnings = updatedBalls.where((b) => !b.isWide && !b.isNoBall).length;
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

    // Wicket Handling
    if (wicket != null) {
      final playerOut = outPlayerId ?? state.strikerId;
      if (playerOut == state.nonStrikerId) {
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

    saveState();
    _checkInningsEnd();
  }

  bool shouldPromptLastMan(Team team) {
    int wickets = state.currentInningsBalls.where((b) => b.wicket != null).length;
    return wickets == team.players.length - 1 && !state.isLastManSolo;
  }

  void endInnings() {
    if (state.currentMatch == null) return;
    
    final battingTeam = state.currentMatch!.battingTeamFor(state.isInnings1);

    final finishedInnings = Innings(
      balls: state.currentInningsBalls,
      playerIds: battingTeam.players.map((p) => p.id).toList(),
      maxOvers: state.currentMatch!.maxOvers,
    );

    final updatedMatch = state.currentMatch!.copyWith(
      innings1: state.isInnings1 ? finishedInnings : state.currentMatch!.innings1,
      innings2: !state.isInnings1 ? finishedInnings : state.currentMatch!.innings2,
    );

    state = state.copyWith(
      currentMatch: updatedMatch,
      isMatchComplete: !state.isInnings1, // FINISH MATCH IF IT WAS INNINGS 2
      isInnings1: false, 
      currentInningsBalls: [], 
      strikerId: '', 
      nonStrikerId: '', 
      currentBowlerId: '',
      isLastManSolo: false,
    );

    // Save to DB + enforce 10-match limit
    DatabaseService.instance.saveMatch(updatedMatch);
    DatabaseService.instance.enforceMatchHistoryLimit();
    saveState();
  }

  void loadMatchForScorecard(Match match) {
    state = state.copyWith(currentMatch: match);
  }

  void undo() {
    if (state.history.isNotEmpty) {
      final lastState = state.history.last;
      final newHistory = List<MatchState>.from(state.history)..removeLast();
      state = lastState.copyWith(history: newHistory);
      saveState();
    }
  }

  void setLastManSolo(bool solo) {
    if (solo && state.currentMatch != null) {
      final battingTeam = state.isInnings1 ? state.currentMatch!.battingTeamFor(true) : state.currentMatch!.battingTeamFor(false);
      final dismissedIds = state.currentInningsBalls
          .where((b) => b.wicket != null)
          .map((b) => b.outPlayerId ?? b.strikerId)
          .toSet();
      final lastBatter = battingTeam.players.firstWhere((p) => !dismissedIds.contains(p.id));
      
      state = state.copyWith(
        isLastManSolo: true,
        strikerId: lastBatter.id,
        nonStrikerId: '', // Empty non-striker for solo mode
      );
    } else {
      state = state.copyWith(isLastManSolo: solo);
    }
    saveState();
  }

  void resumeMatch(MatchState savedState) {
    state = savedState;
  }

  void clearSession() {
    DatabaseService.instance.clearCurrentMatchState();
    state = MatchState();
  }

  void _checkInningsEnd() {
    if (state.currentMatch == null) return;

    final battingTeam = state.currentMatch!.battingTeamFor(state.isInnings1);

    int totalWickets = state.currentInningsBalls.where((b) => b.wicket != null).length;
    int legalBalls = state.currentInningsBalls.where((b) => !b.isWide && !b.isNoBall).length;
    int maxBalls = state.currentMatch!.maxOvers * 6;

    // Robust All Out / Last Man check: 
    // If wickets == total players - 1, we wait for the Last Man prompt (setLastManSolo)
    // Unless solo mode is already on.
    bool allOutCorrected = false;
    if (state.isLastManSolo) {
       allOutCorrected = totalWickets >= battingTeam.players.length;
    } else {
       // If not solo, it ends if totalWickets >= players.length (safety)
       // BUT it should NOT automatically end at totalWickets == players.length - 1
       allOutCorrected = totalWickets >= battingTeam.players.length; 
    }

    bool inningsFinished = allOutCorrected || (legalBalls >= maxBalls);

    if (state.isInnings1) {
      if (inningsFinished) {
        endInnings();
      }
    } else {
      // Innings 2: Chasing logic
      final i1 = state.currentMatch!.innings1;
      if (i1 == null) return;
      
      // REFINED TARGET LOGIC: if I1 score > 0 then score + 1 else 1
      int i1Score = i1.totalRuns;
      int target = i1Score > 0 ? i1Score + 1 : 1;
      
      int currentScore = state.currentInningsBalls.fold(0, (sum, b) => sum + b.teamRuns);

      if (currentScore >= target || inningsFinished) {
        // Match Finished!
        final finishedInnings2 = Innings(
          balls: state.currentInningsBalls,
          playerIds: battingTeam.players.map((p) => p.id).toList(),
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
        DatabaseService.instance.saveMatch(finalMatch);
      }
    }
  }
}

final matchProvider = StateNotifierProvider<MatchNotifier, MatchState>((ref) => MatchNotifier());
