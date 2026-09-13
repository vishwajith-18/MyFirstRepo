import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../models/models.dart';
import 'scorecard_screen.dart';

const kGold       = Color(0xFFFFD700);
const kGoldLight  = Color(0xFFFFE566);
const kGoldDark   = Color(0xFFB8860B);
const kBgBlack    = Color(0xFF0A0A0F);
const kBgCard     = Color(0xFF13131A);
const kBgSurface  = Color(0xFF1C1C28);

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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(matchProvider.notifier).saveState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchProvider);
    final match = state.currentMatch;

    if (match == null) {
      return const Scaffold(
        backgroundColor: kBgBlack,
        body: Center(child: Text('No active match', style: TextStyle(color: Colors.white70))),
      );
    }

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

    int? target, runsNeeded, ballsRemaining;
    if (!state.isInnings1 && match.innings1 != null) {
      target = match.targetForInnings2;
      runsNeeded = target - currentScore;
      ballsRemaining = (match.maxOvers * 6) - legalBallsCount;
    }

    bool isGolden = match.isGoldenOverActive(legalBallsCount);

    return PopScope(
      canPop: state.currentInningsBalls.isEmpty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final String? action = await showDialog<String>(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: kBgSurface,
            title: const Text('Exit scoring?', style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
            content: const Text('Save progress or discard this session?', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, 'cancel'), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
              TextButton(onPressed: () => Navigator.pop(c, 'discard'), child: const Text('DISCARD', style: TextStyle(color: Colors.redAccent))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: kBgBlack),
                onPressed: () => Navigator.pop(c, 'save'), 
                child: const Text('SAVE & EXIT', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
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
        backgroundColor: kBgBlack,
        appBar: AppBar(
          backgroundColor: kBgBlack,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text('${battingTeam.name} Innings', style: const TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 17)),
          actions: [
            if (!state.isInnings1 && target != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Target: $target', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                    if (runsNeeded != null && ballsRemaining != null)
                      Text(runsNeeded > 0 ? '$runsNeeded off $ballsRemaining' : 'Target reached!', 
                           style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kGoldLight)),
                  ],
                ),
              ),
            IconButton(
              icon: const Icon(Icons.undo, color: kGold),
              tooltip: 'Undo last ball',
              onPressed: () => ref.read(matchProvider.notifier).undo(),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (isGolden)
                Container(
                  width: double.infinity,
                  color: kGoldDark,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: const Text(
                    '⭐ GOLDEN OVER ACTIVE ⭐',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 11, letterSpacing: 1.2),
                  ),
                ),
              // Compact fixed top header — score summary
              ScoreboardView(balls: state.currentInningsBalls, maxOvers: match.maxOvers),
              
              // Horizontal over timeline
              CurrentOverTimeline(balls: state.currentInningsBalls),
              
              // Compact player dropdown selectors
              PlayerSelectionView(
                state: state,
                battingTeam: battingTeam,
                bowlingTeam: bowlingTeam,
                dismissedIds: dismissedIds,
                lastOverBowlerId: lastOverBowlerId,
              ),
              
              const Divider(height: 1, color: Color(0x22FFD700)),
              
              // Fixed non-scrolling control panel for scoring buttons
              const Expanded(child: ScoringControlPanel()),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Scoreboard ───────────────────────────────────────────────────────────────

class ScoreboardView extends StatelessWidget {
  final List<Ball> balls;
  final int maxOvers;
  const ScoreboardView({super.key, required this.balls, required this.maxOvers});

  @override
  Widget build(BuildContext context) {
    int runs = 0, wickets = 0, legalBalls = 0;
    for (final b in balls) {
      runs += b.teamRuns;
      if (b.wicket != null) wickets++;
      if (!b.isWide && !b.isNoBall) legalBalls++;
    }
    String overs = "${legalBalls ~/ 6}.${legalBalls % 6}";
    double runRate = legalBalls > 0 ? (runs / (legalBalls / 6.0)) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33FFD700), width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$runs', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: kGold)),
              Text('/$wickets', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white70)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('OVERS: $overs / $maxOvers', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              Text('CRR: ${runRate.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: kGoldLight, fontWeight: FontWeight.w600)),
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
    if (b.isGolden) return Colors.amber.shade700;
    if (b.wicket != null) return Colors.red.shade800;
    if (b.isWide || b.isNoBall) return Colors.orange.shade800;
    if (b.runs == 4) return Colors.blue.shade700;
    if (b.runs == 6) return Colors.purple.shade700;
    if (b.runs == 0) return const Color(0xFF2C2C3A);
    return Colors.teal.shade700;
  }

  @override
  Widget build(BuildContext context) {
    if (balls.isEmpty) {
      return Container(
        height: 38,
        alignment: Alignment.center,
        child: const Text('Over timeline will appear here', style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
      );
    }

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
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              reverse: true,
              itemCount: oversList.length,
              itemBuilder: (context, index) {
                final overIdx = oversList.length - 1 - index;
                final overBalls = oversList[overIdx];
                final overNum = overIdx + 1;
                
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kBgSurface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0x33FFD700)),
                      ),
                      child: Text('Ov $overNum', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kGold)),
                    ),
                    const SizedBox(width: 4),
                    ...overBalls.map((b) => _ballCircle(b)).toList(),
                    if (index < oversList.length - 1 || hasOngoing)
                      const VerticalDivider(width: 14, thickness: 1, color: Colors.white24),
                  ],
                );
              },
            ),
          ),
          if (hasOngoing)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: kGoldDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Ov $ongoingOverNum', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                  const SizedBox(width: 4),
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
      margin: const EdgeInsets.only(right: 3),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: _color(b),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        _label(b),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
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

    String? currentStriker = availableBatters.any((p) => p.id == state.strikerId) ? (state.strikerId.isEmpty ? null : state.strikerId) : null;
    String? currentNonStriker = availableBatters.any((p) => p.id == state.nonStrikerId) ? (state.nonStrikerId.isEmpty ? null : state.nonStrikerId) : null;
    String? currentBowler = availableBowlers.any((p) => p.id == state.currentBowlerId) ? (state.currentBowlerId.isEmpty ? null : state.currentBowlerId) : null;

    final inputDecoration = InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: kBgSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0x33FFD700))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0x33FFD700))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kGold)),
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: currentStriker,
                  dropdownColor: kBgSurface,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: inputDecoration.copyWith(labelText: '🏏 Striker'),
                  items: [
                    if (currentStriker == null)
                      const DropdownMenuItem<String>(value: null, child: Text('Select Striker...', style: TextStyle(fontSize: 11))),
                    ...availableBatters.where((p) => p.id != currentNonStriker).map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 12)))),
                  ],
                  onChanged: (v) => ref.read(matchProvider.notifier).setupPlayers(v ?? '', state.nonStrikerId, state.currentBowlerId),
                ),
              ),
              const SizedBox(width: 8),
              if (!state.isLastManSolo) ...[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: currentNonStriker,
                    dropdownColor: kBgSurface,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: inputDecoration.copyWith(labelText: '🏃 Non-Striker'),
                    items: [
                      if (currentNonStriker == null)
                        const DropdownMenuItem<String>(value: null, child: Text('Select Non-Striker...', style: TextStyle(fontSize: 11))),
                      ...availableBatters.where((p) => p.id != currentStriker).map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 12)))),
                    ],
                    onChanged: (v) => ref.read(matchProvider.notifier).setupPlayers(state.strikerId, v ?? '', state.currentBowlerId),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: kBgSurface, borderRadius: BorderRadius.circular(8), border: Border.all(color: kGold)),
                    child: const Center(child: Text('SOLO BATTING', style: TextStyle(fontWeight: FontWeight.bold, color: kGold, fontSize: 11))),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: currentBowler,
            dropdownColor: kBgSurface,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: inputDecoration.copyWith(
              labelText: lastOverBowlerId.isNotEmpty ? '⚾ Bowler (Prev. bowler excluded)' : '⚾ Bowler',
            ),
            items: [
              if (currentBowler == null)
                const DropdownMenuItem<String>(value: null, child: Text('Select Bowler...', style: TextStyle(fontSize: 11))),
              ...availableBowlers.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 12)))),
            ],
            onChanged: (v) => ref.read(matchProvider.notifier).setupPlayers(state.strikerId, state.nonStrikerId, v ?? ''),
          ),
        ],
      ),
    );
  }
}

// ─── Scoring Controls (FIXED ON SCREEN) ───────────────────────────────────────

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

    // Layout fits perfectly inside Expanded without scrolling
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (!isReady)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Text('⚠️ Select Striker, Non-Striker & Bowler to start scoring', 
              style: TextStyle(color: kGoldLight, fontSize: 11, fontWeight: FontWeight.w600)),
          ),

        // RUN BUTTONS (0 to 6)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            children: [
              // Row 1: 0, 1, 2, 3
              Row(
                children: [0, 1, 2, 3].map((run) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: _runButton(ref, run, isReady),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 4),
              // Row 2: 4, 5, 6
              Row(
                children: [4, 5, 6].map((run) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: _runButton(ref, run, isReady),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),

        // ACTION BUTTONS (WIDE, NO BALL, WICKET) — ALWAYS ANCHORED & VISIBLE
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: _actionButton('WIDE', const Color(0xFFD97706), isReady ? () => showWidePopup(ref, context) : null),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: _actionButton('NO BALL', const Color(0xFFEA580C), isReady ? () => showNoBallPopup(ref, context) : null),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: _actionButton('WICKET', const Color(0xFFDC2626), isReady ? () => showWicketPopup(ref, context, battingTeam, bowlingTeam) : null),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _runButton(WidgetRef ref, int run, bool isReady) {
    Color bg;
    if (run == 4) {
      bg = const Color(0xFF1D4ED8);
    } else if (run == 6) {
      bg = const Color(0xFF6D28D9);
    } else if (run == 0) {
      bg = kBgSurface;
    } else {
      bg = const Color(0xFF0F766E);
    }

    return SizedBox(
      height: 46,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isReady ? bg : bg.withOpacity(0.4),
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          elevation: isReady ? 3 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isReady ? (run == 4 || run == 6 ? kGold : Colors.white24) : Colors.transparent),
          ),
        ),
        onPressed: isReady ? () => ref.read(matchProvider.notifier).recordBall(runs: run) : null,
        child: Text(
          '$run',
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.w900, 
            color: isReady ? (run == 4 || run == 6 ? kGoldLight : Colors.white) : Colors.white38
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback? onPressed) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null ? color : color.withOpacity(0.3),
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          elevation: onPressed != null ? 4 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: onPressed != null ? Colors.white38 : Colors.transparent),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 0.5,
            color: onPressed != null ? Colors.white : Colors.white38,
          ),
        ),
      ),
    );
  }
}

void showWidePopup(WidgetRef ref, BuildContext context) {
  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: kBgSurface,
      title: const Text('Wide! Extra runs?', style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [0, 1, 2, 3, 4].map((r) => SizedBox(
          width: 54,
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGoldDark, foregroundColor: Colors.black),
            onPressed: () {
              ref.read(matchProvider.notifier).recordBall(runs: r, isWide: true);
              Navigator.pop(c);
            },
            child: Text(r == 0 ? '0' : '+$r', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        )).toList(),
      ),
    ),
  );
}

void showNoBallPopup(WidgetRef ref, BuildContext context) {
  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: kBgSurface,
      title: const Text('No Ball! Runs scored?', style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [0, 1, 2, 4, 6].map((r) => SizedBox(
          width: 54,
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGoldDark, foregroundColor: Colors.black),
            onPressed: () {
              ref.read(matchProvider.notifier).recordBall(runs: r, isNoBall: true);
              Navigator.pop(c);
            },
            child: Text('$r', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        )).toList(),
      ),
    ),
  );
}

void showWicketPopup(WidgetRef ref, BuildContext context, Team batting, Team bowling) {
  showModalBottomSheet(
    context: context,
    backgroundColor: kBgSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
        backgroundColor: kBgSurface,
        title: const Text('Last man continues?', style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
        content: const Text('Only one batsman left. Continue solo?', style: TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: kBgBlack),
            onPressed: () {
              ref.read(matchProvider.notifier).setLastManSolo(true);
              Navigator.pop(c);
            },
            child: const Text('YES', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              ref.read(matchProvider.notifier).endInnings();
              Navigator.pop(c);
            },
            child: const Text('NO', style: TextStyle(color: Colors.white60)),
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
    final state = ref.watch(matchProvider);
    final striker = widget.batting.players.firstWhere((p) => p.id == state.strikerId, orElse: () => Player(id: '', name: '?'));
    final nonStriker = widget.batting.players.firstWhere((p) => p.id == state.nonStrikerId, orElse: () => Player(id: '', name: '?'));

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Wicket Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kGold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [WicketType.bowled, WicketType.caught, WicketType.runOut, WicketType.stumped, WicketType.lbw, WicketType.hitWicket].map((type) {
                final isSel = selectedType == type;
                return ChoiceChip(
                  label: Text(type.name.toUpperCase(), style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  selected: isSel,
                  selectedColor: kGold,
                  backgroundColor: kBgCard,
                  onSelected: (v) => setState(() { selectedType = v ? type : null; catcherId = null; runOutFielderId = null; runOutPlayerId = null; }),
                );
              }).toList(),
            ),

            if (selectedType == WicketType.caught) ...[
              const SizedBox(height: 14),
              const Text('Catcher (Optional)', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 12)),
              DropdownButtonFormField<String>(
                value: catcherId,
                dropdownColor: kBgCard,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                hint: const Text('Select catcher (optional)', style: TextStyle(color: Colors.white38, fontSize: 12)),
                items: widget.bowling.players.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                onChanged: (v) => setState(() => catcherId = v),
              ),
            ],

            if (selectedType == WicketType.runOut) ...[
              const SizedBox(height: 14),
              const Text('Runs completed before run out?', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 12)),
              Wrap(
                spacing: 8,
                children: [0, 1, 2, 3].map((r) => ChoiceChip(
                  label: Text('$r'),
                  selected: runOutRuns == r,
                  selectedColor: kGold,
                  backgroundColor: kBgCard,
                  labelStyle: TextStyle(color: runOutRuns == r ? Colors.black : Colors.white),
                  onSelected: (v) { if (v) setState(() => runOutRuns = r); },
                )).toList(),
              ),
              const SizedBox(height: 14),
              const Text('Who got Run Out?', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 12)),
              RadioListTile<String>(
                title: Text('Striker: ${striker.name}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                value: state.strikerId,
                activeColor: kGold,
                groupValue: runOutPlayerId,
                onChanged: (v) => setState(() => runOutPlayerId = v),
              ),
              RadioListTile<String>(
                title: Text('Non-Striker: ${nonStriker.name}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                value: state.nonStrikerId,
                activeColor: kGold,
                groupValue: runOutPlayerId,
                onChanged: (v) => setState(() => runOutPlayerId = v),
              ),
              const SizedBox(height: 8),
              const Text('Fielder who ran out (Optional)', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 12)),
              DropdownButtonFormField<String>(
                value: runOutFielderId,
                dropdownColor: kBgCard,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                hint: const Text('Select fielder (optional)', style: TextStyle(color: Colors.white38, fontSize: 12)),
                items: widget.bowling.players.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                onChanged: (v) => setState(() => runOutFielderId = v),
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedType != null ? kGold : Colors.grey.shade800,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
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
                  widget.onWicketConfirmed();
                },
                child: const Text('CONFIRM WICKET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
