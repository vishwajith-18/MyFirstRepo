import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/match_model.dart';
import '../models/models.dart';

class PDFService {
  static Future<void> generateScorecard(Match match) async {
    final pdf = pw.Document();

    final battingTeam1 = match.battingTeamFor(true);
    final bowlingTeam1 = match.bowlingTeamFor(true);
    final battingTeam2 = match.battingTeamFor(false);
    final bowlingTeam2 = match.bowlingTeamFor(false);

    final allTeams = [match.teamA, match.teamB];
    final result = match.resultString;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          // ─── Header ───────────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('VISH_CRIC Scorecard',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text(match.date.toString().split(' ')[0],
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text('${match.teamA.name} vs ${match.teamB.name}  •  ${match.maxOvers} Overs',
              style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: PdfColors.blue100,
            child: pw.Text('RESULT: $result',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 10),

          // ─── Innings 1 ────────────────────────────────────────────────────
          if (match.innings1 != null) ...[
            _sectionHeader('Innings 1 – ${battingTeam1.name}  '
                '${match.innings1!.totalRuns}/${match.innings1!.totalWickets}  '
                '(${match.innings1!.oversFormatted} ov)'),
            pw.SizedBox(height: 4),
            _battingTable(match.innings1!, battingTeam1, allTeams),
            pw.SizedBox(height: 6),
            _bowlingTable(match.innings1!, bowlingTeam1),
            pw.SizedBox(height: 12),
          ],

          // ─── Innings 2 ────────────────────────────────────────────────────
          if (match.innings2 != null) ...[
            _sectionHeader('Innings 2 – ${battingTeam2.name}  '
                '${match.innings2!.totalRuns}/${match.innings2!.totalWickets}  '
                '(${match.innings2!.oversFormatted} ov)'),
            pw.SizedBox(height: 4),
            _battingTable(match.innings2!, battingTeam2, allTeams),
            pw.SizedBox(height: 6),
            _bowlingTable(match.innings2!, bowlingTeam2),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ─── Section header ───────────────────────────────────────────────────────
  static pw.Widget _sectionHeader(String text) {
    return pw.Container(
      color: PdfColors.grey300,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    );
  }

  // ─── Batting table ────────────────────────────────────────────────────────
  static pw.Widget _battingTable(Innings innings, Team battingTeam, List<Team> allTeams) {
    // Build per-batter stats
    final stats = innings.calculateBatterStats(battingTeam);

    // Build table rows – only players who batted or got out
    final List<List<String>> data = [];
    for (final p in battingTeam.players) {
      final s = stats[p.id]!;
      final r = s['runs'] as int;
      final balls = s['balls'] as int;
      if (balls == 0 && !(s['dismissed'] as bool)) continue; // Never faced a ball
      final sr = balls > 0 ? (r / balls * 100).toStringAsFixed(1) : '-';
      final out = s['dismissed'] as bool ? _howOutStr(s, allTeams) : 'not out';
      data.add([p.name, '$r', '$balls', sr, out]);
    }

    if (data.isEmpty) {
      return pw.Text('No batting data', style: const pw.TextStyle(fontSize: 8));
    }

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(0.6),
        2: const pw.FlexColumnWidth(0.6),
        3: const pw.FlexColumnWidth(0.8),
        4: const pw.FlexColumnWidth(3),
      },
      headers: ['Batter', 'R', 'B', 'SR', 'Dismissal'],
      data: data,
    );
  }

  // ─── Bowling table ────────────────────────────────────────────────────────
  static pw.Widget _bowlingTable(Innings innings, Team bowlingTeam) {
    final stats = innings.calculateBowlerStats(bowlingTeam);

    final List<List<String>> data = stats.entries
        .where((e) => (e.value['balls'] as int) > 0)
        .map((e) {
          final p = bowlingTeam.players.firstWhere((x) => x.id == e.key,
              orElse: () => Player(id: '', name: '?'));
          final balls = e.value['balls'] as int;
          final overs = '${balls ~/ 6}.${balls % 6}';
          final runs = e.value['runs'] as int;
          final wkts = e.value['wickets'] as int;
          final econ = balls > 0 ? (runs / (balls / 6)).toStringAsFixed(1) : '-';
          return [p.name, overs, '$runs', '$wkts', econ];
        })
        .toList();

    if (data.isEmpty) {
      return pw.Text('No bowling data', style: const pw.TextStyle(fontSize: 8));
    }

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(0.8),
        2: const pw.FlexColumnWidth(0.8),
        3: const pw.FlexColumnWidth(0.6),
        4: const pw.FlexColumnWidth(0.8),
      },
      headers: ['Bowler', 'O', 'R', 'W', 'Econ'],
      data: data,
    );
  }

  static String _howOutStr(Map<String, dynamic> s, List<Team> allTeams) {
    Player? findPlayer(String id) {
      for (final t in allTeams) {
        for (final p in t.players) {
          if (p.id == id) return p;
        }
      }
      return null;
    }

    final type = WicketType.values.byName(s['howOut']);
    final bowler = findPlayer(s['bowlerId'])?.name ?? '';
    final fielder = s['fielderId'].isNotEmpty ? (findPlayer(s['fielderId'])?.name ?? '') : '';

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
}
