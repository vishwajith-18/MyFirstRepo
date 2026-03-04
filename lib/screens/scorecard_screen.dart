import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../models/match_model.dart';
import '../models/models.dart';
import '../services/pdf_service.dart';

class ScorecardScreen extends ConsumerWidget {
  const ScorecardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.read(matchProvider);
    final match = state.currentMatch;
    if (match == null) {
      return Scaffold(appBar: AppBar(title: const Text('Scorecard')), body: const Center(child: Text('No match data')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${match.teamA.name} vs ${match.teamB.name}'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            if (state.isMatchComplete) {
              ref.read(matchProvider.notifier).clearSession();
            }
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Download PDF Scorecard',
            onPressed: () => PDFService.generateScorecard(match),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MatchResultBanner(match: match),
            const SizedBox(height: 16),
            if (match.innings1 != null) ...[
              _InningsScorecardView(
                innings: match.innings1!,
                label: 'Innings 1: ${match.battingTeamFor(true).name}',
                battingTeam: match.battingTeamFor(true),
                bowlingTeam: match.bowlingTeamFor(true),
                allTeams: [match.teamA, match.teamB],
              ),
              const SizedBox(height: 24),
            ],
            if (match.innings2 != null) ...[
              _InningsScorecardView(
                innings: match.innings2!,
                label: 'Innings 2: ${match.battingTeamFor(false).name}',
                battingTeam: match.battingTeamFor(false),
                bowlingTeam: match.bowlingTeamFor(false),
                allTeams: [match.teamA, match.teamB],
              ),
            ],
          ],
        ),
      ),
    );
  }

}

// ─── Result Banner ───────────────────────────────────────────────────────────

class _MatchResultBanner extends StatelessWidget {
  final Match match;
  const _MatchResultBanner({required this.match});

  @override
  Widget build(BuildContext context) {
    final i1 = match.innings1;
    final i2 = match.innings2;
    if (i1 == null) return const SizedBox.shrink();

    String result = match.resultString;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          const Text('MATCH RESULT', style: TextStyle(fontSize: 13, letterSpacing: 2, color: Colors.green)),
          const SizedBox(height: 4),
          Text(result, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            '${match.teamA.name}: ${i1.totalRuns}/${i1.totalWickets}  |  ${match.teamB.name}: ${i2?.totalRuns ?? '-'}/${i2?.totalWickets ?? '-'}',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─── Innings Scorecard ────────────────────────────────────────────────────────

class _InningsScorecardView extends StatelessWidget {
  final Innings innings;
  final String label;
  final Team battingTeam;
  final Team bowlingTeam;
  final List<Team> allTeams;
  const _InningsScorecardView({required this.innings, required this.label, required this.battingTeam, required this.bowlingTeam, required this.allTeams});

  Player? _findPlayer(String id) {
    for (final t in allTeams) {
      for (final p in t.players) {
        if (p.id == id) return p;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Aggregate batter stats
    final batterStats = innings.calculateBatterStats(battingTeam);

    // Aggregate bowler stats
    final bowlerStats = innings.calculateBowlerStats(bowlingTeam);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // Batting Table
        Table(
          columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1), 4: FlexColumnWidth(3)},
          children: [
            _headerRow(['Batter', 'R', 'B', 'SR', 'W']),
            ...batterStats.entries.map((e) {
              final p = battingTeam.players.firstWhere((x) => x.id == e.key, orElse: () => Player(id: '', name: '?'));
              final r = e.value['runs'] as int;
              final b = e.value['balls'] as int;
              final sr = b > 0 ? (r / b * 100).toStringAsFixed(1) : '-';
              final howOut = e.value['dismissed'] as bool
                  ? _howOutStr(e.value)
                  : 'not out';
              return _dataRow([p.name, '$r', '$b', sr, howOut]);
            }),
          ],
        ),
        const SizedBox(height: 16),
        // Bowling Table
        Table(
          columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1), 4: FlexColumnWidth(1)},
          children: [
            _headerRow(['Bowler', 'O', 'R', 'W', 'Econ']),
            ...bowlerStats.entries.where((e) => (e.value['balls'] as int) > 0).map((e) {
              final p = bowlingTeam.players.firstWhere((x) => x.id == e.key, orElse: () => Player(id: '', name: '?'));
              final balls = e.value['balls'] as int;
              final overs = '${balls ~/ 6}.${balls % 6}';
              final runs = e.value['runs'] as int;
              final wkts = e.value['wickets'] as int;
              final econ = balls > 0 ? (runs / (balls / 6)).toStringAsFixed(1) : '-';
              return _dataRow([p.name, overs, '$runs', '$wkts', econ]);
            }),
          ],
        ),
      ],
    );
  }

  String _howOutStr(Map<String, dynamic> v) {
    final type = WicketType.values.byName(v['howOut']);
    final bowler = _findPlayer(v['bowlerId'])?.name ?? '';
    final fielder = v['fielderId'].isNotEmpty ? (_findPlayer(v['fielderId'])?.name ?? '') : '';

    if (type == WicketType.caught) {
      return fielder.isNotEmpty ? 'c $fielder b $bowler' : 'c & b $bowler';
    } else if (type == WicketType.bowled) {
      return 'b $bowler';
    } else if (type == WicketType.runOut) {
      return fielder.isNotEmpty ? 'run out ($fielder)' : 'run out';
    } else if (type == WicketType.stumped) {
      return 'st $fielder b $bowler';
    } else if (type == WicketType.lbw) {
      return 'lbw b $bowler';
    } else if (type == WicketType.hitWicket) {
      return 'hit wkt b $bowler';
    }
    return type.name;
  }

  TableRow _headerRow(List<String> cols) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2)),
      children: cols.map((c) => Padding(padding: const EdgeInsets.all(6), child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
    );
  }

  TableRow _dataRow(List<String> cols) {
    return TableRow(
      children: cols.map((c) => Padding(padding: const EdgeInsets.all(6), child: Text(c, style: const TextStyle(fontSize: 11)))).toList(),
    );
  }
}
