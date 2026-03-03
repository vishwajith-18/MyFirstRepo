import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../models/models.dart';
import 'scorecard_screen.dart';

class ScoringScreen extends ConsumerWidget {
  const ScoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final match = state.currentMatch;

    if (match == null) return const Scaffold(body: Center(child: Text('No active match')));

    // Navigate to scorecard when match is complete
    if (state.isMatchComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const ScorecardScreen()));
      });
    }

    final battingTeam = match.battingTeamFor(state.isInnings1);
    final bowlingTeam = match.bowlingTeamFor(state.isInnings1);

    // Get dismissed player IDs
    final dismissedIds = state.currentInningsBalls
        .where((b) => b.wicket != null)
        .map((b) => b.outPlayerId ?? b.strikerId)
        .toSet();

    // Compute last over's bowler ID (to disable them for consecutive over)
    final legalBalls = state.currentInningsBalls.where((b) => !b.isWide && !b.isNoBall).toList();
    final currentOverIndex = legalBalls.length ~/ 6;
    String lastOverBowlerId = '';
    if (currentOverIndex > 0) {
      // find first ball of last completed over
      final lastOverStartIndex = (currentOverIndex - 1) * 6;
      if (lastOverStartIndex < legalBalls.length) {
        lastOverBowlerId = legalBalls[lastOverStartIndex].bowlerId;
      }
    }

    // Target for 2nd innings
    int? target;
    int? runsNeeded;
    int? ballsRemaining;
    if (!state.isInnings1 && match.innings1 != null) {
      int i1Score = match.innings1!.totalRuns;
      target = i1Score > 0 ? i1Score + 1 : 1;
      int currentScore = state.currentInningsBalls.fold(0, (sum, b) => sum + b.teamRuns);
      runsNeeded = target - currentScore;
      int maxBalls = match.maxOvers * 6;
      int legalBallsBowled = state.currentInningsBalls.where((b) => !b.isWide && !b.isNoBall).length;
      ballsRemaining = maxBalls - legalBallsBowled;
    }

    // Is Golden Over right now?
    int legalBallsParsed = state.currentInningsBalls.where((b) => !b.isWide && !b.isNoBall).length;
    bool isGolden = match.goldenOver != null && (legalBallsParsed ~/ 6) + 1 == match.goldenOver;

    return PopScope(
      canPop: state.currentInningsBalls.isEmpty && state.isInnings1,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final String? action = await showDialog<String>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Exit scoring?'),
            content: const Text('Save progress or discard this session?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, 'cancel'), child: const Text('CANCEL')),
              TextButton(onPressed: () => Navigator.pop(c, 'discard'), child: const Text('DISCARD', style: TextStyle(color: Colors.red))),
              TextButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('SAVE & EXIT')),
            ],
          ),
        );

        if (action == null || action == 'cancel') return;
        
        if (action == 'discard') {
          await DatabaseService.instance.clearCurrentMatchState();
        }
        
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${battingTeam.name} Innings'),
          actions: [
            if (!state.isInnings1 && target != null)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Target: $target', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    if (runsNeeded != null && ballsRemaining != null)
                      Text(runsNeeded > 0 ? '$runsNeeded off $ballsRemaining' : 'Target reached!', 
                           style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: () => ref.read(matchProvider.notifier).undo(),
            ),
          ],
        ),
        body: Column(
          children: [
            if (isGolden)
              Container(
                width: double.infinity,
                color: Colors.amber.shade700,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: const Text(
                  '⭐ GOLDEN OVER ACTIVE ⭐',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            ScoreboardView(state: state),
            CurrentOverTimeline(state: state),
            PlayerSelectionView(
              state: state,
              battingTeam: battingTeam,
              bowlingTeam: bowlingTeam,
              dismissedIds: dismissedIds,
              lastOverBowlerId: lastOverBowlerId,
            ),
            const Divider(),
            Expanded(child: ScoringControlPanel(battingTeam: battingTeam, bowlingTeam: bowlingTeam)),
          ],
        ),
      ),
    );
  }
}

// ─── Scoreboard ───────────────────────────────────────────────────────────────

class ScoreboardView extends StatelessWidget {
  final MatchState state;
  const ScoreboardView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    int runs = state.currentInningsBalls.fold(0, (sum, b) => sum + b.teamRuns);
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

// ─── Over Timeline ────────────────────────────────────────────────────────────

class CurrentOverTimeline extends StatelessWidget {
  final MatchState state;
  const CurrentOverTimeline({super.key, required this.state});

  String _label(Ball b) {
    if (b.timelineLabel != null) return b.timelineLabel!;
    if (b.isWide) return 'Wd';
    if (b.isNoBall) return 'Nb';
    if (b.wicket != null) return 'W';
    return '${b.runs}';
  }

  Color _color(Ball b) {
    if (b.isGolden) return Colors.amber.shade900;
    if (b.wicket != null) return Colors.brown.shade700;
    if (b.isWide || b.isNoBall) return Colors.orange.shade700;
    if (b.runs == 4) return Colors.blue.shade600;
    if (b.runs == 6) return Colors.green.shade700;
    if (b.runs == 0) return Colors.grey.shade600;
    return Colors.green.shade500;
  }

  @override
  Widget build(BuildContext context) {
    final legal = state.currentInningsBalls.where((b) => !b.isWide && !b.isNoBall).length;
    final currentOverStart = (legal ~/ 6) * 6;
    // all balls from the start of this over (including extras)
    // The legal balls index is tricky, we need to reconstruct the current over
    // We'll collect balls that belong to the current over by counting legal deliveries
    int legalCount = 0;
    final currentOverBalls = <Ball>[];

    for (final b in state.currentInningsBalls) {
      final overNum = legalCount ~/ 6;
      final targetOver = currentOverStart ~/ 6;
      if (overNum == targetOver) {
        currentOverBalls.add(b);
      }
      if (!b.isWide && !b.isNoBall) legalCount++;
    }

    if (currentOverBalls.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black12,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: currentOverBalls.map((b) {
            return Container(
              margin: const EdgeInsets.only(right: 6),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _color(b),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                _label(b),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Player Selection ─────────────────────────────────────────────────────────

class PlayerSelectionView extends ConsumerWidget {
  final MatchState state;
  final Team battingTeam;
  final Team bowlingTeam;
  final Set<String> dismissedIds;
  final String lastOverBowlerId;

  const PlayerSelectionView({
    super.key,
    required this.state,
    required this.battingTeam,
    required this.bowlingTeam,
    required this.dismissedIds,
    required this.lastOverBowlerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableBatters = battingTeam.players.where((p) => !dismissedIds.contains(p.id)).toList();
    final availableBowlers = bowlingTeam.players.where((p) => p.id != lastOverBowlerId).toList();

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
                  items: availableBatters.where((p) => p.id != state.nonStrikerId).map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (v) => ref.read(matchProvider.notifier).setupPlayers(v!, state.nonStrikerId, state.currentBowlerId),
                ),
              ),
              if (!state.isLastManSolo) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: state.nonStrikerId.isEmpty ? null : state.nonStrikerId,
                    decoration: const InputDecoration(labelText: 'Non-Striker'),
                    items: availableBatters.where((p) => p.id != state.strikerId).map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                    onChanged: (v) => ref.read(matchProvider.notifier).setupPlayers(state.strikerId, v!, state.currentBowlerId),
                  ),
                ),
              ] else ...[
                 const SizedBox(width: 16),
                 const Expanded(child: Center(child: Text('SOLO BATTING', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)))),
              ],
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: state.currentBowlerId.isEmpty ? null : state.currentBowlerId,
            decoration: InputDecoration(
              labelText: lastOverBowlerId.isNotEmpty ? 'Bowler (prev. bowler excluded)' : 'Bowler',
            ),
            items: availableBowlers.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
            onChanged: (v) => ref.read(matchProvider.notifier).setupPlayers(state.strikerId, state.nonStrikerId, v!),
          ),
        ],
      ),
    );
  }
}

// ─── Scoring Controls ─────────────────────────────────────────────────────────

class ScoringControlPanel extends ConsumerWidget {
  final Team battingTeam;
  final Team bowlingTeam;
  const ScoringControlPanel({super.key, required this.battingTeam, required this.bowlingTeam});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final isReady = state.strikerId.isNotEmpty && state.nonStrikerId.isNotEmpty && state.currentBowlerId.isNotEmpty;

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
                    onPressed: isReady ? () => ref.read(matchProvider.notifier).recordBall(runs: run) : null,
                    child: Text('$run', style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
          ),
          if (!isReady)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Select Striker, Non-Striker & Bowler to score', style: TextStyle(color: Colors.orange)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionButton('WIDE', Colors.orange.shade900, isReady ? () => ref.read(matchProvider.notifier).recordBall(runs: 0, isWide: true) : null),
                _actionButton('NO BALL', Colors.deepOrange.shade900, isReady ? () => _showNoBallPopup(ref, context) : null),
                _actionButton('WICKET', Colors.red.shade900, isReady ? () => _showWicketPopup(ref, context, battingTeam, bowlingTeam) : null),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: onPressed != null ? color : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
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

  void _showWicketPopup(WidgetRef ref, BuildContext context, Team batting, Team bowling) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => _WicketSheet(ref: ref, batting: batting, bowling: bowling),
    );
  }
}

// ─── Wicket Sheet ─────────────────────────────────────────────────────────────

class _WicketSheet extends StatefulWidget {
  final WidgetRef ref;
  final Team batting;
  final Team bowling;
  const _WicketSheet({required this.ref, required this.batting, required this.bowling});

  @override
  State<_WicketSheet> createState() => _WicketSheetState();
}

class _WicketSheetState extends State<_WicketSheet> {
  WicketType? selectedType;
  String? catcherId;
  String? runOutFielderId;
  String? runOutPlayerId; // who got out – striker or non-striker

  @override
  Widget build(BuildContext context) {
    final state = widget.ref.read(matchProvider);
    final striker = widget.batting.players.firstWhere((p) => p.id == state.strikerId, orElse: () => Player(id: '', name: '?'));
    final nonStriker = widget.batting.players.firstWhere((p) => p.id == state.nonStrikerId, orElse: () => Player(id: '', name: '?'));

    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Wicket Type', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [WicketType.bowled, WicketType.caught, WicketType.runOut, WicketType.stumped, WicketType.lbw, WicketType.hitWicket].map((type) {
                return ChoiceChip(
                  label: Text(type.name.toUpperCase()),
                  selected: selectedType == type,
                  onSelected: (v) => setState(() { selectedType = v ? type : null; catcherId = null; runOutFielderId = null; runOutPlayerId = null; }),
                );
              }).toList(),
            ),

            // Caught – optional catcher selection
            if (selectedType == WicketType.caught) ...[
              const SizedBox(height: 16),
              const Text('Catcher (Optional)', style: TextStyle(fontWeight: FontWeight.w600)),
              DropdownButtonFormField<String>(
                value: catcherId,
                hint: const Text('Select catcher (optional)'),
                items: widget.bowling.players.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                onChanged: (v) => setState(() => catcherId = v),
              ),
            ],

            // Run Out – pick who got out + optional fielder
            if (selectedType == WicketType.runOut) ...[
              const SizedBox(height: 16),
              const Text('Who got Run Out?', style: TextStyle(fontWeight: FontWeight.w600)),
              RadioListTile<String>(
                title: Text('Striker: ${striker.name}'),
                value: state.strikerId,
                groupValue: runOutPlayerId,
                onChanged: (v) => setState(() => runOutPlayerId = v),
              ),
              RadioListTile<String>(
                title: Text('Non-Striker: ${nonStriker.name}'),
                value: state.nonStrikerId,
                groupValue: runOutPlayerId,
                onChanged: (v) => setState(() => runOutPlayerId = v),
              ),
              const SizedBox(height: 8),
              const Text('Fielder who ran out (Optional)', style: TextStyle(fontWeight: FontWeight.w600)),
              DropdownButtonFormField<String>(
                value: runOutFielderId,
                hint: const Text('Select fielder (optional)'),
                items: widget.bowling.players.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                onChanged: (v) => setState(() => runOutFielderId = v),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedType == null ? null : () {
                  final notifier = widget.ref.read(matchProvider.notifier);
                  if (selectedType == WicketType.runOut) {
                    notifier.recordBall(runs: 0, wicket: WicketType.runOut, fielderId: runOutFielderId, outPlayerId: runOutPlayerId);
                  } else if (selectedType == WicketType.caught) {
                    notifier.recordBall(runs: 0, wicket: WicketType.caught, fielderId: catcherId);
                  } else {
                    notifier.recordBall(runs: 0, wicket: selectedType!);
                  }
                  Navigator.pop(context);
                  // Check last man solo
                  _checkForLastMan(widget.ref, context);
                },
                child: const Text('Confirm Wicket'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _checkForLastMan(WidgetRef ref, BuildContext context) {
    final state = ref.read(matchProvider);
    final match = state.currentMatch;
    if (match == null) return;
    final battingTeam = state.isInnings1 ? match.teamA : match.teamB;
    if (ref.read(matchProvider.notifier).shouldPromptLastMan(battingTeam)) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text('Last man continues?'),
          content: const Text('Only one batsman left. Continue solo?'),
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
              },
              child: const Text('NO'),
            ),
          ],
        ),
      );
    }
  }
}
