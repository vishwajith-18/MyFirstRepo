import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../models/match_model.dart';
import '../providers/match_provider.dart';
import '../services/pdf_service.dart';
import 'scorecard_screen.dart';

const kGold       = Color(0xFFFFD700);
const kGoldLight  = Color(0xFFFFE566);
const kBgBlack    = Color(0xFF0A0A0F);
const kBgCard     = Color(0xFF13131A);
const kBgSurface  = Color(0xFF1C1C28);

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
    ref.read(matchProvider.notifier).loadMatchForScorecard(match);
    Navigator.push(context, MaterialPageRoute(builder: (c) => const ScorecardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgBlack,
      appBar: AppBar(
        backgroundColor: kBgBlack,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Match History', style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Match>>(
        future: _matchesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading matches: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kGold));
          final matches = snapshot.data!;
          if (matches.isEmpty) return const Center(child: Text('No recent matches found', style: TextStyle(color: Colors.white54, fontSize: 16)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final m = matches[index];
              final i1Score = m.innings1 != null ? '${m.innings1!.totalRuns}/${m.innings1!.totalWickets}' : '-';
              final i2Score = m.innings2 != null ? '${m.innings2!.totalRuns}/${m.innings2!.totalWickets}' : '-';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: kBgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x33FFD700)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  onTap: () => _viewScorecard(context, m),
                  title: Text('${m.teamA.name} vs ${m.teamB.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('${m.date.toString().split(' ')[0]}  |  $i1Score vs $i2Score  |  ${m.maxOvers} ov', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: kGoldLight, size: 22),
                        onPressed: () => PDFService.generateScorecard(m),
                        tooltip: 'Download PDF',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: kBgSurface,
                            title: const Text('Delete Match?', style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
                            content: const Text('This will permanently remove this match record.', style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                              TextButton(onPressed: () { Navigator.pop(c); _deleteMatch(m.id); }, child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                            ],
                          ),
                        ),
                      ),
                    ],
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
