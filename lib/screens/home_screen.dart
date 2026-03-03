import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'team_list_screen.dart';
import 'match_history_screen.dart';
import 'scoring_screen.dart';
import '../services/database_service.dart';
import '../providers/match_provider.dart';
import '../providers/team_provider.dart';
import 'dart:convert';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkResumeMatch());
  }

  Future<void> _checkResumeMatch() async {
    final stateJson = await DatabaseService.instance.getCurrentMatchState();
    if (stateJson != null) {
      if (!mounted) return;
      
      final teams = ref.read(teamProvider);
      final savedStateMap = jsonDecode(stateJson);
      final savedState = MatchState.fromMap(savedStateMap, teams);
      
      // ONLY RESUME IF AT LEAST 1 BALL BOWLED
      if (savedState.currentInningsBalls.isEmpty && savedState.isInnings1) {
        // Just clear it silently if it's an empty match
        await DatabaseService.instance.clearCurrentMatchState();
        return;
      }

      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Resume Match?'),
          content: const Text('An unfinished match was found. Would you like to resume?'),
          actions: [
            TextButton(
              onPressed: () {
                DatabaseService.instance.clearCurrentMatchState();
                Navigator.pop(c);
              },
              child: const Text('NO, DELETE'),
            ),
            TextButton(
              onPressed: () async {
                final teams = ref.read(teamProvider);
                final savedStateMap = jsonDecode(stateJson);
                final savedState = MatchState.fromMap(savedStateMap, teams);
                ref.read(matchProvider.notifier).resumeMatch(savedState);
                Navigator.pop(c);
                Navigator.push(context, MaterialPageRoute(builder: (c) => const ScoringScreen()));
              },
              child: const Text('YES, RESUME'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.sports_cricket, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 16),
            const Text(
              'VISH_CRIC',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TeamListScreen())),
              icon: const Icon(Icons.group),
              label: const Text('Manage Teams'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MatchHistoryScreen())),
              icon: const Icon(Icons.history),
              label: const Text('Match History'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade800),
            ),
          ],
        ),
      ),
    );
  }
}
