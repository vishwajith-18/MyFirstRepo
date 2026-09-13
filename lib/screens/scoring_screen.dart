import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../models/models.dart';
import 'scorecard_screen.dart';

class ScoringScreen extends ConsumerStatefulWidget {
  const ScoringScreen({super.key});

  @override
  ConsumerState<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends ConsumerState<ScoringScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Persist player selection when app is backgrounded or paused
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(matchProvider.notifier).saveState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchProvider);
    final match = state.currentMatch;

    if (match == null) return const Scaffold(body: Center(child: Text('No active match')));

    // Navigate to scorecard when match is complete
    if (state.isMatchComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (c) => const ScorecardScreen()),
          (route) => route.isFirst,
        );
      });
    }

    final battingTeam = match.battingTeamFor(state.isInnings1);
    final bowlingTeam = match.bowlingTeamFor(state.isInnings1);

    // Single pass to gather stats and last over's bowler
    final dismissedIds = <String>{};
    int legalBallsCount = 0, currentScore = 0;
    String lastOverBowlerId = '';
    
    for (final b in state.currentInningsBalls) {
      if (b.wicket != null) dismissedIds.add(b.outPlayerId ?? b.strikerId);
      if (!b.isWide && !b.isNoBall) {
        legalBallsCount++;
        if (legalBallsCount % 6 == 0) lastOverBowlerId = b.bowlerId;
      }
      currentScore += b.teamRuns;
    }

    // Target for 2nd innings
    int? target, runsNeeded, ballsRemaining;
    if (!state.isInnings1 && match.innings1 != null) {
      target = match.targetForInnings2;
      runsNeeded = target - currentScore;
      ballsRemaining = (match.maxOvers * 6) - legalBallsCount;
    }

    // Is Golden Over right now?
    bool isGolden = match.isGoldenOverActive(legalBallsCount);

    // Allow free back navigation only if no balls bowled in current innings
    return PopScope(
      canPop: state.currentInningsBalls.isEmpty,
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
          await ref.read(matchProvider.notifier).clearSession();
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
            // Fixed top section — score, timeline, player selectors
            ScoreboardView(balls: state.currentInningsBalls),
            CurrentOverTimeline(balls: state.currentInningsBalls),
            PlayerSelectionView(
              state: state,
              battingTeam: battingTeam,
              bowlingTeam: bowlingTeam,
              dismissedIds: dismissedIds,
              lastOverBowlerId: lastOverBowlerId,
            ),
            const Divider(height: 1),
            // Expanded scoring panel — fills remaining space, buttons never go off-screen
            const Expanded(child: ScoringControlPanel()),
          ],
        ),
      ),
    );
  }
}

// ─── Scoreboard ───────────────────────────────────────────────────────────────

class ScoreboardView extends StatelessWidget {
  final List<Ball> balls;
  const ScoreboardView({super.key, required this.balls});

  @override
  Widget build(BuildContext context) {
    int runs = 0, wickets = 0, legalBalls = 0;
    for (final b in balls) {
      runs += b.teamRuns;
      if (b.wicket != null) wickets++;
      if (!b.isWide && !b.isNoBall) legalBalls++;
    }
    String overs = "${legalBalls ~/ 6}.${legalBalls % 6}";

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      color: Colors.blueAccent.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Score', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
              Text('$runs/$wickets', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Overs', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
              Text(overs, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Over Timeline ────────────────────────────────────────────────────────────

class CurrentOverTimeline extends StatelessWidget {
  final List<Ball> balls;
  const CurrentOverTimeline({super.key, required this.balls});

  String _label(Ball b) {
    if (b.timelineLabel != null) return b.timelineLabel!;
    if (b.isWide) return 'Wd';
    if (b.isNoBall) return 'Nb';
    if (b.wicket != null) return 'W';
    return '${b.runs}';
  }

  Color _color(Ball b) {
    if (b.isGolden) return Colors.amber.shade900;
    if (b.wicket != null) return Colors.brown.shade700;  // Wicket takes priority
    if (b.isWide || b.isNoBall) return Colors.orange.shade700;
    if (b.runs == 4) return Colors.blue.shade600;
    if (b.runs == 6) return Colors.green.shade700;
    if (b.runs == 0) return Colors.grey.shade600;
    return Colors.green.shade500;
  }

  @override
  Widget build(BuildContext context) {
    if (balls.isEmpty) return const SizedBox.shrink();

    // Group balls into overs
    final oversList = <List<Ball>>[];
    var currentOver = <Ball>[];
    int legalCount = 0;

    for (final b in balls) {
      currentOver.add(b);
      if (!b.isWide && !b.isNoBall) {
        legalCount++;
        if (legalCount % 6 == 0) {
          oversList.add(currentOver);
          currentOver = <Ball>[];
        }
      }
    }
    
    final bool hasOngoing = currentOver.isNotEmpty;
    final int ongoingOverNum = oversList.length + 1;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.black12,
      height: 70,
      child: Row(
        children: [
          // HISTORY (Scrollable to the left)
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              reverse: true, // Newer history on the right
              itemCount: oversList.length,
              itemBuilder: (context, index) {
                // Since it's reversed, index 0 is the most recent historical over
                final overIdx = oversList.length - 1 - index;
                final overBalls = oversList[overIdx];
                final overNum = overIdx + 1;
                
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade800,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Ov $overNum', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
                    ),
                    const SizedBox(width: 8),
                    ...overBalls.map((b) => _ballCircle(b)).toList(),
                    if (index < oversList.length - 1 || hasOngoing)
                      const VerticalDivider(width: 24, thickness: 1, indent: 10, endIndent: 10),
                  ],
                );
              },
            ),
          ),
          
          // CURRENT OVER (Fixed on the right)
          if (hasOngoing)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.shade700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Ov $ongoingOverNum', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  ...currentOver.map((b) => _ballCircle(b)).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _ballCircle(Ball b) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _color(b),
        borderRadius: BorderRadius.circular(18), // circular
      ),
      alignment: Alignment.center,
      child: Text(
        _label(b),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
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

    // Validate striker/non-striker values exist in available list to prevent crash
    String? currentStriker = availableBatters.any((p) => p.id == state.strikerId) ? (state.strikerId.isEmpty ? null : state.strikerId) : null;
    String? currentNonStriker = availableBatters.any((p) => p.id == state.nonStrikerId) ? (state.nonStrikerId.isEmpty ? null : state.nonStrikerId) : null;
    String? currentBowler = availableBowlers.any((p) => p.id == state.currentBowlerId) ? (state.currentBowlerId.isEmpty ? null : state.currentBowlerId) : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: currentStriker,
                  decoration: const InputDecoration(labelText: 'Striker'),
                  items: [
                    if (currentStriker == null)
                      const DropdownMenuItem<String>(value: null, child: Text('Select Striker...')),
                    ...availableBatters.where((p) => p.id != currentNonStriker).map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                  ],
                  onChanged: (v) => ref.read(matchProvider.notifier).setupPlayers(v ?? '', state.nonStrikerId, state.currentBowlerId),
                ),
              ),
              if (!state.isLastManSolo) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: currentNonStriker,
                    decoration: const InputDecoration(labelText: 'Non-Striker'),
                    items: [
                      if (currentNonStriker == null)
                        const DropdownMenuItem<String>(value: null, child: Text('Select Non-Striker...')),
                      ...availableBatters.where((p) => p.id != currentStriker).map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                    ],
                    onChanged: (v) => ref.read(matchProvider.notifier).setupPlayers(state.strikerId, v ?? '', state.currentBowlerId),
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
            value: currentBowler,
            decoration: InputDecoration(
              labelText: lastOverBowlerId.isNotEmpty ? 'Bowler (prev. bowler excluded)' : 'Bowler',
            ),
            items: [
              if (currentBowler == null)
                const DropdownMenuItem<String>(value: null, child: Text('Select Bowler...')),
              ...availableBowlers.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
            ],
            onChanged: (v) => ref.read(matchProvider.notifier).setupPlayers(state.strikerId, state.nonStrikerId, v ?? ''),
          ),
        ],
      ),
    );
  }
}

// ─── Scoring Controls ─────────────────────────────────────────────────────────

class ScoringControlPanel extends ConsumerWidget {
  const ScoringControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchProvider);
    final match = state.currentMatch;
    if (match == null) return const SizedBox.shrink();
    
    final battingTeam = match.battingTeamFor(state.isInnings1);
    final bowlingTeam = match.bowlingTeamFor(state.isInnings1);
    
    final isReady = state.strikerId.isNotEmpty && (state.isLastManSolo || state.nonStrikerId.isNotEmpty) && state.currentBowlerId.isNotEmpty;

    // No SingleChildScrollView — entire panel is fixed inside Expanded.
    // Column with spaceBetween keeps WIDE/NO BALL/WICKET always anchored at bottom.
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [0, 1, 2, 3, 4, 5, 6].map((run) {
              return SizedBox(
                width: 72,
                height: 72,
                child: ElevatedButton(
                  onPressed: isReady ? () => ref.read(matchProvider.notifier).recordBall(runs: run) : null,
                  child: Text('$run', style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),
        ),
        // Bottom section — warning + action buttons always visible
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isReady)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('Select Striker, Non-Striker & Bowler to score', style: TextStyle(color: Colors.orange, fontSize: 12)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton('WIDE', Colors.orange.shade900, isReady ? () => showWidePopup(ref, context) : null),
                  _actionButton('NO BALL', Colors.deepOrange.shade900, isReady ? () => showNoBallPopup(ref, context) : null),
                  _actionButton('WICKET', Colors.red.shade900, isReady ? () => showWicketPopup(ref, context, battingTeam, bowlingTeam) : null),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: onPressed != null ? color : Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      child: Text(label),
    );
  }

}

void showWidePopup(WidgetRef ref, BuildContext context) {
  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Wide! Extra runs?'),
      content: Wrap(
        spacing: 10,
        children: [0, 1, 2, 3, 4].map((r) => ElevatedButton(
          onPressed: () {
            ref.read(matchProvider.notifier).recordBall(runs: r, isWide: true);
            Navigator.pop(c);
          },
          child: Text(r == 0 ? '0' : '+$r'),
        )).toList(),
      ),
    ),
  );
}

void showNoBallPopup(WidgetRef ref, BuildContext context) {
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

void showWicketPopup(WidgetRef ref, BuildContext context, Team batting, Team bowling) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => _WicketSheet(
      batting: batting, 
      bowling: bowling,
      onWicketConfirmed: () => checkForLastMan(ref, context),
    ),
  );
}

void checkForLastMan(WidgetRef ref, BuildContext context) {
  final state = ref.read(matchProvider);
  if (state.isMatchComplete) return;
  final match = state.currentMatch;
  if (match == null) return;
  final battingTeam = match.battingTeamFor(state.isInnings1);
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

// ─── Wicket Sheet ─────────────────────────────────────────────────────────────

class _WicketSheet extends ConsumerStatefulWidget {
  final Team batting;
  final Team bowling;
  final VoidCallback onWicketConfirmed;
  const _WicketSheet({required this.batting, required this.bowling, required this.onWicketConfirmed});

  @override
  ConsumerState<_WicketSheet> createState() => _WicketSheetState();
}

class _WicketSheetState extends ConsumerState<_WicketSheet> {
  WicketType? selectedType;
  String? catcherId;
  String? runOutFielderId;
  String? runOutPlayerId;
  int runOutRuns = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchProvider); // reactive to get latest striker/non-striker
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

            // Run Out - pick who got out + optional fielder + runs scored
            if (selectedType == WicketType.runOut) ...[
              const SizedBox(height: 16),
              const Text('Runs completed?', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(
                spacing: 10,
                children: [0, 1, 2, 3].map((r) => ChoiceChip(
                  label: Text('$r'),
                  selected: runOutRuns == r,
                  onSelected: (v) { if (v) setState(() => runOutRuns = r); },
                )).toList(),
              ),
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
                  final notifier = ref.read(matchProvider.notifier);
                  if (selectedType == WicketType.runOut) {
                    notifier.recordBall(runs: runOutRuns, wicket: WicketType.runOut, fielderId: runOutFielderId, outPlayerId: runOutPlayerId);
                  } else if (selectedType == WicketType.caught) {
                    notifier.recordBall(runs: 0, wicket: WicketType.caught, fielderId: catcherId);
                  } else {
                    notifier.recordBall(runs: 0, wicket: selectedType!);
                  }
                  Navigator.pop(context);
                  // Check last man solo using parent context via callback
                  widget.onWicketConfirmed();
                },
                child: const Text('Confirm Wicket'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
