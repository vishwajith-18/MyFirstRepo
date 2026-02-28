import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../models/match_model.dart';
import '../services/pdf_service.dart';

class MatchHistoryScreen extends ConsumerWidget {
  const MatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recent Matches')),
      body: FutureBuilder<List<Match>>(
        future: DatabaseService.instance.getRecentMatches(limit: 5),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final matches = snapshot.data!;
          if (matches.isEmpty) return const Center(child: Text('No matches found'));

          return ListView.builder(
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final m = matches[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('${m.teamA.name} vs ${m.teamB.name}'),
                  subtitle: Text('Overs: ${m.maxOvers} | Date: ${m.date.toString().split(' ')[0]}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.picture_as_pdf),
                    onPressed: () => PDFService.generateScorecard(m),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
