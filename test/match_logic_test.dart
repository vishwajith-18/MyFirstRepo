import 'package:flutter_test/flutter_test.dart';
import 'package:vish_cric/models/models.dart';
import 'package:vish_cric/models/match_model.dart';
import 'package:vish_cric/providers/match_provider.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Match Logic Tests', () {
    late MatchNotifier notifier;
    late Team teamA;
    late Team teamB;
    late Match match;

    setUp(() {
      notifier = MatchNotifier();
      teamA = Team(
        id: 'A',
        name: 'Team A',
        players: List.generate(11, (i) => Player(id: 'a$i', name: 'A Player $i')),
      );
      teamB = Team(
        id: 'B',
        name: 'Team B',
        players: List.generate(11, (i) => Player(id: 'b$i', name: 'B Player $i')),
      );

      match = Match(
        id: 'test-match',
        teamA: teamA,
        teamB: teamB,
        maxOvers: 2,
        tossWinnerId: 'A',
        tossWinnerBatsFirst: true,
        date: DateTime.now(),
        goldenOver: 1, // First over is golden
      );
    });

    test('Innings 1: Golden Over Scoring (Doubled runs & Wicket Penalty)', () {
      notifier.startMatch(match);
      notifier.setupPlayers('a0', 'a1', 'b0');

      // Ball 0.1: 1 run -> Team gets 2 (Golden Over)
      notifier.recordBall(runs: 1);
      expect(notifier.state.currentInningsBalls.last.teamRuns, 2);
      expect(notifier.state.currentInningsBalls.last.runs, 2); // Batter runs doubled
      
      // Ball 0.2: Wicket -> Team gets -5
      notifier.recordBall(runs: 0, wicket: WicketType.bowled);
      expect(notifier.state.currentInningsBalls.last.teamRuns, -5);
      expect(notifier.state.currentInningsBalls.last.runs, -5);

      // Ball 0.3: Wide -> Team gets 2
      notifier.recordBall(runs: 0, isWide: true);
      expect(notifier.state.currentInningsBalls.last.teamRuns, 2);

      // Ball 0.4: No-ball with 1 run -> (2 base + 1*2) = 4
      notifier.recordBall(runs: 1, isNoBall: true);
      expect(notifier.state.currentInningsBalls.last.teamRuns, 4);

      // Total runs calculation verify: 2 + (-5) + 2 + 4 = 3
      final total = notifier.state.currentInningsBalls.fold(0, (sum, b) => sum + b.teamRuns);
      expect(total, 3);
    });

    test('Innings 2: Target and Golden Over in 2nd Innings', () {
      // Setup Innings 1 finish with 10 runs
      final i1Balls = [
        Ball(runs: 10, teamRuns: 10, strikerId: 'a0', bowlerId: 'b0') 
      ];
      final innings1 = Innings(balls: i1Balls, playerIds: ['a0'], maxOvers: 2);
      final matchWithI1 = match.copyWith(innings1: innings1);
      
      notifier.startMatch(matchWithI1);
      notifier.endInnings(); // Transition to Inning 2

      expect(notifier.state.isInnings1, false);
      
      // Target = 10 + 1 = 11
      notifier.setupPlayers('b0', 'b1', 'a0');
      
      // Ball 0.1: Golden Over (from match setup)
      // Score 6 -> doubled to 12
      notifier.recordBall(runs: 6);
      
      expect(notifier.state.currentInningsBalls.last.teamRuns, 12);
      expect(notifier.state.isMatchComplete, true); // Chased successfully
    });

    test('Over Rotation and Undo', () {
      notifier.startMatch(match);
      notifier.setupPlayers('a0', 'a1', 'b0');

      // 6 balls
      for (int i = 0; i < 6; i++) {
        notifier.recordBall(runs: 0);
      }

      // Check currentBowlerId is cleared (over end)
      expect(notifier.state.currentBowlerId, '');
      
      // Undo
      notifier.undo();
      expect(notifier.state.currentInningsBalls.length, 5);
      expect(notifier.state.currentBowlerId.isNotEmpty, true);
    });
  });
}
