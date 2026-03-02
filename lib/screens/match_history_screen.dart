import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../models/match_model.dart';
import '../providers/match_provider.dart';
import 'scorecard_screen.dart';

class MatchHistoryScreen extends ConsumerStatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  ConsumerState<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends ConsumerState<MatchHistoryScreen> {
  late Future<List<Match>> _matchesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _matchesFuture = DatabaseService.instance.getRecentMatches(limit: 10);
    });
  }

  void _deleteMatch(String id) async {
    await DatabaseService.instance.deleteMatch(id);
    _reload();
  }

  void _viewScorecard(BuildContext context, Match match) {
    // Temporarily set match in provider so scorecard can read it
    ref.read(matchProvider.notifier).loadMatchForScorecard(match);
    Navigator.push(context, MaterialPageRoute(builder: (c) => const ScorecardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Match History (Last 10)')),
      body: FutureBuilder<List<Match>>(
        future: _matchesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final matches = snapshot.data!;
          if (matches.isEmpty) return const Center(child: Text('No matches found'));

          return ListView.builder(
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final m = matches[index];
              final i1Score = m.innings1 != null ? '${m.innings1!.totalRuns}/${m.innings1!.totalWickets}' : '-';
              final i2Score = m.innings2 != null ? '${m.innings2!.totalRuns}/${m.innings2!.totalWickets}' : '-';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  onTap: () => _viewScorecard(context, m),
                  title: Text('${m.teamA.name} vs ${m.teamB.name}'),
                  subtitle: Text('${m.date.toString().split(' ')[0]}  |  $i1Score  vs  $i2Score  |  ${m.maxOvers} ov'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Delete Match?'),
                        content: const Text('This will permanently remove this match record.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                          TextButton(onPressed: () { Navigator.pop(c); _deleteMatch(m.id); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ),
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
