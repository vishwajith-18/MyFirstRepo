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
    Player? findPlayer(String id) {
      for (final t in allTeams) {
        for (final p in t.players) {
          if (p.id == id) return p;
        }
      }
      return null;
    }

    // Build per-batter stats
    final Map<String, Map<String, dynamic>> stats = {};
    for (final p in battingTeam.players) {
      stats[p.id] = {'runs': 0, 'balls': 0, 'dismissed': false, 'howOut': ''};
    }

    for (final b in innings.balls) {
      if (!b.isWide && stats.containsKey(b.strikerId)) {
        stats[b.strikerId]!['balls'] = (stats[b.strikerId]!['balls'] as int) + 1;
        stats[b.strikerId]!['runs'] = (stats[b.strikerId]!['runs'] as int) + b.runs;
      }
      if (b.wicket != null) {
        final outId = b.outPlayerId ?? b.strikerId;
        if (stats.containsKey(outId)) {
          stats[outId]!['dismissed'] = true;
          final bowler = findPlayer(b.bowlerId)?.name ?? '';
          final fielder = b.fielderId != null ? findPlayer(b.fielderId!)?.name ?? '' : '';

          String howOut = b.wicket!.name;
          if (b.wicket == WicketType.caught) {
            howOut = fielder.isNotEmpty ? 'c $fielder b $bowler' : 'c & b $bowler';
          } else if (b.wicket == WicketType.bowled) {
            howOut = 'b $bowler';
          } else if (b.wicket == WicketType.runOut) {
            howOut = fielder.isNotEmpty ? 'run out ($fielder)' : 'run out';
          } else if (b.wicket == WicketType.stumped) {
            howOut = 'st $fielder b $bowler';
          } else if (b.wicket == WicketType.lbw) {
            howOut = 'lbw b $bowler';
          } else if (b.wicket == WicketType.hitWicket) {
            howOut = 'hit wkt b $bowler';
          }
          stats[outId]!['howOut'] = howOut;
        }
      }
    }

    // Build table rows – only players who batted or got out
    final List<List<String>> data = [];
    for (final p in battingTeam.players) {
      final s = stats[p.id]!;
      final r = s['runs'] as int;
      final balls = s['balls'] as int;
      if (balls == 0 && !(s['dismissed'] as bool)) continue; // Never faced a ball
      final sr = balls > 0 ? (r / balls * 100).toStringAsFixed(1) : '-';
      final out = s['dismissed'] as bool ? (s['howOut'] as String) : 'not out';
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
    final Map<String, Map<String, dynamic>> stats = {};
    for (final p in bowlingTeam.players) {
      stats[p.id] = {'balls': 0, 'runs': 0, 'wickets': 0};
    }
    for (final b in innings.balls) {
      if (stats.containsKey(b.bowlerId)) {
        if (!b.isWide && !b.isNoBall) {
          stats[b.bowlerId]!['balls'] = (stats[b.bowlerId]!['balls'] as int) + 1;
        }
        stats[b.bowlerId]!['runs'] = (stats[b.bowlerId]!['runs'] as int) +
            b.runs + (b.isWide || b.isNoBall ? 1 : 0);
        if (b.wicket != null && b.wicket != WicketType.runOut) {
          stats[b.bowlerId]!['wickets'] = (stats[b.bowlerId]!['wickets'] as int) + 1;
        }
      }
    }

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
}
