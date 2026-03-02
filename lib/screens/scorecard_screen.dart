import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../models/match_model.dart';
import '../models/models.dart';

class ScorecardScreen extends ConsumerWidget {
  const ScorecardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.read(matchProvider).currentMatch;
    if (match == null) {
      return Scaffold(appBar: AppBar(title: const Text('Scorecard')), body: const Center(child: Text('No match data')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${match.teamA.name} vs ${match.teamB.name}'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
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
                label: 'Innings 1: ${_battingTeamName(match, true)}',
                battingTeam: _battingTeam(match, true),
                bowlingTeam: _bowlingTeam(match, true),
                allTeams: [match.teamA, match.teamB],
              ),
              const SizedBox(height: 24),
            ],
            if (match.innings2 != null) ...[
              _InningsScorecardView(
                innings: match.innings2!,
                label: 'Innings 2: ${_battingTeamName(match, false)}',
                battingTeam: _battingTeam(match, false),
                bowlingTeam: _bowlingTeam(match, false),
                allTeams: [match.teamA, match.teamB],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Team _battingTeam(Match match, bool isInnings1) {
    if (isInnings1) {
      return match.tossWinnerBatsFirst
          ? (match.tossWinnerId == match.teamA.id ? match.teamA : match.teamB)
          : (match.tossWinnerId == match.teamA.id ? match.teamB : match.teamA);
    } else {
      return match.tossWinnerBatsFirst
          ? (match.tossWinnerId == match.teamA.id ? match.teamB : match.teamA)
          : (match.tossWinnerId == match.teamA.id ? match.teamA : match.teamB);
    }
  }

  Team _bowlingTeam(Match match, bool isInnings1) {
    final batting = _battingTeam(match, isInnings1);
    return batting.id == match.teamA.id ? match.teamB : match.teamA;
  }

  String _battingTeamName(Match match, bool isInnings1) => _battingTeam(match, isInnings1).name;
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

    String result = '';
    if (i2 != null) {
      if (i2.totalRuns > i1.totalRuns) {
        result = '2nd innings team won by ${i2.totalRuns - i1.totalRuns} runs (chased target)';
      } else if (i1.totalRuns > i2.totalRuns) {
        result = '1st innings team won by ${i1.totalRuns - i2.totalRuns} runs';
      } else {
        result = 'Match Tied!';
      }
    }

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
    final Map<String, Map<String, dynamic>> batterStats = {};
    for (final p in battingTeam.players) {
      batterStats[p.id] = {'runs': 0, 'balls': 0, 'dismissed': false, 'howOut': '', 'bowler': '', 'fielder': ''};
    }

    for (final b in innings.balls) {
      if (!b.isWide) {
        // ball faced
        if (batterStats.containsKey(b.strikerId)) {
          batterStats[b.strikerId]!['balls'] = (batterStats[b.strikerId]!['balls'] as int) + 1;
          if (!b.isWide) {
            batterStats[b.strikerId]!['runs'] = (batterStats[b.strikerId]!['runs'] as int) + b.runs;
          }
        }
      }
      if (b.wicket != null) {
        final outId = b.outPlayerId ?? b.strikerId;
        if (batterStats.containsKey(outId)) {
          batterStats[outId]!['dismissed'] = true;
          batterStats[outId]!['howOut'] = b.wicket!.name;
          batterStats[outId]!['bowler'] = _findPlayer(b.bowlerId)?.name ?? '';
          batterStats[outId]!['fielder'] = b.fielderId != null ? (_findPlayer(b.fielderId!)?.name ?? '') : '';
        }
      }
    }

    // Aggregate bowler stats
    final Map<String, Map<String, dynamic>> bowlerStats = {};
    for (final p in bowlingTeam.players) {
      bowlerStats[p.id] = {'balls': 0, 'runs': 0, 'wickets': 0};
    }
    for (final b in innings.balls) {
      if (bowlerStats.containsKey(b.bowlerId)) {
        if (!b.isWide && !b.isNoBall) bowlerStats[b.bowlerId]!['balls'] = (bowlerStats[b.bowlerId]!['balls'] as int) + 1;
        bowlerStats[b.bowlerId]!['runs'] = (bowlerStats[b.bowlerId]!['runs'] as int) + b.runs + (b.isWide || b.isNoBall ? 1 : 0);
        if (b.wicket != null && b.wicket != WicketType.runOut) bowlerStats[b.bowlerId]!['wickets'] = (bowlerStats[b.bowlerId]!['wickets'] as int) + 1;
      }
    }

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
                  ? '${e.value['howOut']} ${e.value['fielder'].isNotEmpty ? "(${e.value['fielder']})" : ""} b ${e.value['bowler']}'.trim()
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
