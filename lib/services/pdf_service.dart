import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/match_model.dart';
import '../models/models.dart';

class PDFService {
  static Future<void> generateScorecard(Match match) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Match Scorecard', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('${match.teamA.name} vs ${match.teamB.name}'),
              pw.Text('Date: ${match.date.toString().split(' ')[0]}'),
              pw.Divider(),
              pw.SizedBox(height: 20),
              _buildInningsTable(match.innings1, '1st Innings'),
              pw.SizedBox(height: 30),
              _buildInningsTable(match.innings2, '2nd Innings'),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _buildInningsTable(Innings? innings, String title) {
    if (innings == null) return pw.Text('$title: Not played');
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Metric', 'Value'],
          data: [
            ['Total Runs', '${innings.totalRuns}'],
            ['Wickets', '${innings.totalWickets}'],
            ['Overs', innings.oversFormatted],
          ],
        ),
      ],
    );
  }
}
