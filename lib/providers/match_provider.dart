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
    
    // Rotate for odd runs on legal ball or wide/noball (if specified)
    // Common rule: rotated on 1, 3, 5 runs
    if ((runs % 2 != 0) && !isWide) {
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

    state = state.copyWith(
      currentInningsBalls: updatedBalls,
      strikerId: newStriker,
      nonStrikerId: newNonStriker,
      history: updatedHistory,
    );

    // Save periodically or check for innings end
    _checkInningsEnd();
  }

  bool shouldPromptLastMan(Team team) {
    int wickets = state.currentInningsBalls.where((b) => b.wicket != null).length;
    return wickets == team.players.length - 1 && !state.isLastManSolo;
  }

  void endInnings() {
    // Logic to switch to innings 2 or end match
  }

  void undo() {
    if (state.history.isNotEmpty) {
      final lastState = state.history.last;
      final newHistory = List<MatchState>.from(state.history)..removeLast();
      state = lastState.copyWith(history: newHistory);
    }
  }

  void _checkInningsEnd() {
    // Logic for innings end (overs complete, all out, target reached)
    // This will be triggered in the UI or here
  }
  
  void setLastManSolo(bool solo) {
    state = state.copyWith(isLastManSolo: solo);
  }
}

final matchProvider = StateNotifierProvider<MatchNotifier, MatchState>((ref) => MatchNotifier());
