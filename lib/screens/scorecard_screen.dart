import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';
import '../models/match_model.dart';
import '../models/models.dart';
import '../services/pdf_service.dart';

const kGold       = Color(0xFFFFD700);
const kGoldLight  = Color(0xFFFFE566);
const kGoldDark   = Color(0xFFB8860B);
const kBgBlack    = Color(0xFF0A0A0F);
const kBgCard     = Color(0xFF13131A);
const kBgSurface  = Color(0xFF1C1C28);

class ScorecardScreen extends ConsumerWidget {
  const ScorecardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.read(matchProvider);
    final match = state.currentMatch;

    if (match == null) {
      return Scaffold(
        backgroundColor: kBgBlack,
        appBar: AppBar(title: const Text('Scorecard', style: TextStyle(color: kGold))),
        body: const Center(child: Text('No match data', style: TextStyle(color: Colors.white70))),
      );
    }

    return Scaffold(
      backgroundColor: kBgBlack,
      appBar: AppBar(
        backgroundColor: kBgBlack,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('${match.teamA.name} vs ${match.teamB.name}', style: const TextStyle(color: kGold, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.home, color: kGold),
          tooltip: 'Return Home',
          onPressed: () async {
            if (state.isMatchComplete) {
              await ref.read(matchProvider.notifier).clearSession();
            }
            if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: kGoldLight),
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
            const SizedBox(height: 20),
            if (match.innings1 != null) ...[
              _InningsScorecardView(
                innings: match.innings1!,
                label: '1st Innings: ${match.battingTeamFor(true).name}',
                battingTeam: match.battingTeamFor(true),
                bowlingTeam: match.bowlingTeamFor(true),
                allTeams: [match.teamA, match.teamB],
              ),
              const SizedBox(height: 24),
            ],
            if (match.innings2 != null) ...[
              _InningsScorecardView(
                innings: match.innings2!,
                label: '2nd Innings: ${match.battingTeamFor(false).name}',
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
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x33FFD700), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          const Text('🏆 MATCH RESULT', style: TextStyle(fontSize: 12, letterSpacing: 2, color: kGold, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(result, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kBgSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${match.teamA.name}: ${i1.totalRuns}/${i1.totalWickets}  |  ${match.teamB.name}: ${i2?.totalRuns ?? '-'}/${i2?.totalWickets ?? '-'}',
              style: const TextStyle(fontSize: 13, color: kGoldLight, fontWeight: FontWeight.w600),
            ),
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

  @override
  Widget build(BuildContext context) {
    final batterStats = innings.calculateBatterStats(battingTeam);
    final bowlerStats = innings.calculateBowlerStats(bowlingTeam);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFD700)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kGold)),
          const SizedBox(height: 12),
          // Batting Table
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3), 
              1: FlexColumnWidth(0.8), 
              2: FlexColumnWidth(0.8), 
              3: FlexColumnWidth(0.8), 
              4: FlexColumnWidth(0.8), 
              5: FlexColumnWidth(1), 
              6: FlexColumnWidth(3)
            },
            children: [
              _headerRow(['Batter', 'R', 'B', '4s', '6s', 'SR', 'W']),
              ...batterStats.entries.where((e) {
                final b = e.value['balls'] as int;
                final dismissed = e.value['dismissed'] as bool;
                return b > 0 || dismissed;
              }).map((e) {
                final p = battingTeam.players.firstWhere((x) => x.id == e.key, orElse: () => Player(id: '', name: '?'));
                final r = e.value['runs'] as int;
                final b = e.value['balls'] as int;
                final fours = e.value['4s'] as int;
                final sixes = e.value['6s'] as int;
                final sr = b > 0 ? (r / b * 100).toStringAsFixed(1) : '-';
                final howOut = e.value['dismissed'] as bool
                    ? getHowOutString(e.value, allTeams)
                    : 'not out';
                return _dataRow([p.name, '$r', '$b', '$fours', '$sixes', sr, howOut]);
              }),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Bowling', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kGoldLight)),
          const SizedBox(height: 8),
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
      ),
    );
  }

  TableRow _headerRow(List<String> cols) {
    return TableRow(
      decoration: const BoxDecoration(color: kBgSurface),
      children: cols.map((c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), 
        child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: kGold)),
      )).toList(),
    );
  }

  TableRow _dataRow(List<String> cols) {
    return TableRow(
      children: cols.map((c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), 
        child: Text(c, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      )).toList(),
    );
  }
}
