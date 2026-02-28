import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../models/models.dart';

class ScoringScreen extends ConsumerWidget {
  const ScoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final match = state.currentMatch;
    
    if (match == null) return const Scaffold(body: Center(child: Text('No active match')));

    final battingTeam = state.isInnings1 
        ? (match.tossWinnerBatsFirst ? (match.tossWinnerId == match.teamA.id ? match.teamA : match.teamB) : (match.tossWinnerId == match.teamA.id ? match.teamB : match.teamA))
        : (match.tossWinnerBatsFirst ? (match.tossWinnerId == match.teamA.id ? match.teamB : match.teamA) : (match.tossWinnerId == match.teamA.id ? match.teamA : match.teamB));

    final bowlingTeam = battingTeam.id == match.teamA.id ? match.teamB : match.teamA;

    return Scaffold(
      appBar: AppBar(
        title: Text('${battingTeam.name} Innings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: () => ref.read(matchProvider.notifier).undo(),
          ),
        ],
      ),
      body: Column(
        children: [
          ScoreboardView(state: state),
          PlayerSelectionView(state: state, battingTeam: battingTeam, bowlingTeam: bowlingTeam),
          const Divider(),
          Expanded(child: ScoringControlPanel()),
        ],
      ),
    );
  }

}

class ScoreboardView extends StatelessWidget {
  final MatchState state;
  const ScoreboardView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    int runs = state.currentInningsBalls.fold(0, (sum, b) => sum + b.runs + (b.isWide || b.isNoBall ? 1 : 0));
    int wickets = state.currentInningsBalls.where((b) => b.wicket != null).length;
    int legalBalls = state.currentInningsBalls.where((b) => !b.isWide && !b.isNoBall).length;
    String overs = "${legalBalls ~/ 6}.${legalBalls % 6}";

    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.blueAccent.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Score', style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
              Text('$runs/$wickets', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Overs', style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
              Text(overs, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class PlayerSelectionView extends ConsumerWidget {
  final MatchState state;
  final Team battingTeam;
  final Team bowlingTeam;

  const PlayerSelectionView({
    super.key,
    required this.state,
    required this.battingTeam,
    required this.bowlingTeam,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: state.strikerId.isEmpty ? null : state.strikerId,
                  decoration: const InputDecoration(labelText: 'Striker'),
                  items: battingTeam.players.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (v) => ref.read(matchProvider.notifier).setupPlayers(v!, state.nonStrikerId, state.currentBowlerId),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: state.nonStrikerId.isEmpty ? null : state.nonStrikerId,
                  decoration: const InputDecoration(labelText: 'Non-Striker'),
                  items: battingTeam.players.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (v) => ref.read(matchProvider.notifier).setupPlayers(state.strikerId, v!, state.currentBowlerId),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: state.currentBowlerId.isEmpty ? null : state.currentBowlerId,
            decoration: const InputDecoration(labelText: 'Bowler'),
            items: bowlingTeam.players.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
            onChanged: (v) => ref.read(matchProvider.notifier).setupPlayers(state.strikerId, state.nonStrikerId, v!),
          ),
        ],
      ),
    );
  }
}

class ScoringControlPanel extends ConsumerWidget {
  const ScoringControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [0, 1, 2, 3, 4, 6].map((run) {
                return SizedBox(
                  width: 80,
                  height: 80,
                  child: ElevatedButton(
                    onPressed: () => ref.read(matchProvider.notifier).recordBall(runs: run),
                    child: Text('$run', style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionButton(
                  'WIDE',
                  Colors.orange.shade900,
                  () => ref.read(matchProvider.notifier).recordBall(runs: 0, isWide: true),
                ),
                _actionButton(
                  'NO BALL',
                  Colors.deepOrange.shade900,
                  () => _showNoBallPopup(ref, context),
                ),
                _actionButton(
                  'WICKET',
                  Colors.red.shade900,
                  () => _showWicketPopup(ref, context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      child: Text(label),
    );
  }

  void _showNoBallPopup(WidgetRef ref, BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('No Ball! Runs scored?'),
        content: Wrap(
          spacing: 10,
          children: [0, 1, 2, 4, 6].map((r) => ElevatedButton(
            onPressed: () {
              ref.read(matchProvider.notifier).recordBall(runs: r, isNoBall: true);
              Navigator.pop(c);
            },
            child: Text('$r'),
          )).toList(),
        ),
      ),
    );
  }

  void _showWicketPopup(WidgetRef ref, BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Wicket Type', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(title: const Text('Bowled'), onTap: () {
              ref.read(matchProvider.notifier).recordBall(runs: 0, wicket: WicketType.bowled);
              Navigator.pop(c);
            }),
            ListTile(title: const Text('Caught'), onTap: () {
              ref.read(matchProvider.notifier).recordBall(runs: 0, wicket: WicketType.caught);
              Navigator.pop(c);
            }),
            ListTile(title: const Text('Run Out'), onTap: () {
              ref.read(matchProvider.notifier).recordBall(runs: 0, wicket: WicketType.runOut);
              Navigator.pop(c);
              _checkForLastMan(ref, context);
            }),
          ],
        ),
      ),
    );
  }

  void _checkForLastMan(WidgetRef ref, BuildContext context) {
    final state = ref.read(matchProvider);
    final match = state.currentMatch!;
    final battingTeam = state.isInnings1 ? match.teamA : match.teamB;
    if (ref.read(matchProvider.notifier).shouldPromptLastMan(battingTeam)) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Last Man Solo?'),
          content: const Text('One player remaining. Continue solo?'),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(matchProvider.notifier).setLastManSolo(true);
                Navigator.pop(c);
              },
              child: const Text('YES'),
            ),
            TextButton(
              onPressed: () {
                ref.read(matchProvider.notifier).endInnings();
                Navigator.pop(c);
                Navigator.pop(context);
              },
              child: const Text('NO (End Innings)'),
            ),
          ],
        ),
      );
    }
  }
}
