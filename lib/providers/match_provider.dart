import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../models/match_model.dart';
import '../services/database_service.dart';
import 'dart:async';

class MatchState {
  final Match? currentMatch;
  final bool isInnings1;
  final String strikerId;
  final String nonStrikerId;
  final String currentBowlerId;
  final List<Ball> currentInningsBalls;
  final bool isLastManSolo;
  final List<MatchState> history; // For Undo

  MatchState({
    this.currentMatch,
    this.isInnings1 = true,
    this.strikerId = '',
    this.nonStrikerId = '',
    this.currentBowlerId = '',
    this.currentInningsBalls = const [],
    this.isLastManSolo = false,
    this.history = const [],
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
    );
  }
}

class MatchNotifier extends StateNotifier<MatchState> {
  MatchNotifier() : super(MatchState());

  void startMatch(Match match) {
    state = MatchState(
      currentMatch: match,
      isInnings1: true,
      currentInningsBalls: [],
      history: [],
    );
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
  }) {
    // Save state to history for undo
    final prevState = state.copyWith(history: []);
    final updatedHistory = [...state.history, prevState];

    final newBall = Ball(
      runs: runs,
      isWide: isWide,
      isNoBall: isNoBall,
      wicket: wicket,
      fielderId: fielderId,
      strikerId: state.strikerId,
      bowlerId: state.currentBowlerId,
    );

    final updatedBalls = [...state.currentInningsBalls, newBall];
    
    // Core Logic: Striker Rotation
    String newStriker = state.strikerId;
    String newNonStriker = state.nonStrikerId;

    bool isLegal = !isWide && !isNoBall;
    
    // Rotate for odd runs on legal ball (or no-balls if runs were scored)
    if ((runs % 2 != 0)) {
       final temp = newStriker;
       newStriker = newNonStriker;
       newNonStriker = temp;
    }

    // Over logic
    int legalBallsInInnings = updatedBalls.where((b) => !b.isWide && !b.isNoBall).length;
    bool isOverEnd = legalBallsInInnings > 0 && legalBallsInInnings % 6 == 0 && isLegal;

    if (isOverEnd) {
      // Rotate striker for new over
      final temp = newStriker;
      newStriker = newNonStriker;
      newNonStriker = temp;
    }

    // Wicket Handling
    if (wicket != null) {
      if (wicket == WicketType.runOut) {
        // Run out logic: UI will tell us who got out
        // For simplicity, we clear the fielder/player who got out if needed
        // but typically the UI just asks for the new batsman to replace the one who left
      } else {
        // Bowled, Caught, etc. - Striker is OUT
        newStriker = ''; 
      }
    }

    state = state.copyWith(
      currentInningsBalls: updatedBalls,
      strikerId: newStriker,
      nonStrikerId: newNonStriker,
      history: updatedHistory,
    );

    _checkInningsEnd();
  }

  bool shouldPromptLastMan(Team team) {
    int wickets = state.currentInningsBalls.where((b) => b.wicket != null).length;
    return wickets == team.players.length - 1 && !state.isLastManSolo;
  }

  void endInnings() {
    if (state.currentMatch == null) return;
    
    final battingTeam = state.isInnings1 
        ? (state.currentMatch!.tossWinnerBatsFirst ? state.currentMatch!.teamA : state.currentMatch!.teamB)
        : (state.currentMatch!.tossWinnerBatsFirst ? state.currentMatch!.teamB : state.currentMatch!.teamA);

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
      isInnings1: false, 
      currentInningsBalls: [], 
      strikerId: '', 
      nonStrikerId: '', 
      currentBowlerId: '',
      isLastManSolo: false,
    );

    // Save to DB
    DatabaseService.instance.saveMatch(updatedMatch);
  }

  void undo() {
    if (state.history.isNotEmpty) {
      final lastState = state.history.last;
      final newHistory = List<MatchState>.from(state.history)..removeLast();
      state = lastState.copyWith(history: newHistory);
    }
  }

  void setLastManSolo(bool solo) {
    state = state.copyWith(isLastManSolo: solo);
  }

  void _checkInningsEnd() {
    if (state.currentMatch == null) return;

    final battingTeam = state.isInnings1 
        ? (state.currentMatch!.tossWinnerBatsFirst ? state.currentMatch!.teamA : state.currentMatch!.teamB)
        : (state.currentMatch!.tossWinnerBatsFirst ? state.currentMatch!.teamB : state.currentMatch!.teamA);

    int totalWickets = state.currentInningsBalls.where((b) => b.wicket != null).length;
    int legalBalls = state.currentInningsBalls.where((b) => !b.isWide && !b.isNoBall).length;
    int maxBalls = state.currentMatch!.maxOvers * 6;

    // All Out or Overs Finished
    bool inningsFinished = (totalWickets >= battingTeam.players.length - 1 && !state.isLastManSolo) || 
                          (totalWickets >= battingTeam.players.length && state.isLastManSolo) ||
                          (legalBalls >= maxBalls);

    if (state.isInnings1) {
      if (inningsFinished) {
        endInnings();
      }
    } else {
      // Innings 2: Chasing logic
      final i1Balls = state.currentMatch!.innings1?.balls ?? [];
      int target = i1Balls.fold(0, (sum, b) => sum + b.runs + (b.isWide || b.isNoBall ? 1 : 0)) + 1;
      
      int currentScore = state.currentInningsBalls.fold(0, (sum, b) => sum + b.runs + (b.isWide || b.isNoBall ? 1 : 0));

      if (currentScore >= target || inningsFinished) {
        // Match Finished!
        // TODO: Update database with final score
      }
    }
  }
}

final matchProvider = StateNotifierProvider<MatchNotifier, MatchState>((ref) => MatchNotifier());
