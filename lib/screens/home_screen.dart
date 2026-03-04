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
  String? _savedStateJson;

  @override
  void initState() {
    super.initState();
    _loadSavedState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkResumeDialog());
  }

  Future<void> _loadSavedState() async {
    final stateJson = await DatabaseService.instance.getCurrentMatchState();
    if (mounted) setState(() => _savedStateJson = stateJson);
  }

  Future<void> _checkResumeDialog() async {
    final stateJson = await DatabaseService.instance.getCurrentMatchState();
    if (stateJson != null) {
      if (!mounted) return;
      
      final teams = ref.read(teamProvider);
      final savedStateMap = jsonDecode(stateJson);
      final savedState = MatchState.fromMap(savedStateMap, teams);
      
      // SILENTLY CLEAR IF EMPTY MATCH OR ALREADY COMPLETE
      if ((savedState.currentInningsBalls.isEmpty && savedState.isInnings1) || savedState.isMatchComplete) {
        await DatabaseService.instance.clearCurrentMatchState();
        if (mounted) setState(() => _savedStateJson = null);
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
                if (mounted) setState(() => _savedStateJson = null);
                Navigator.pop(c);
              },
              child: const Text('NO, DELETE'),
            ),
            TextButton(
              onPressed: () => _resumeAction(c, stateJson),
              child: const Text('YES, RESUME'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _resumeAction(BuildContext? dialogContext, String stateJson) async {
    final teams = ref.read(teamProvider);
    final savedStateMap = jsonDecode(stateJson);
    final savedState = MatchState.fromMap(savedStateMap, teams);
    ref.read(matchProvider.notifier).resumeMatch(savedState);
    if (dialogContext != null) Navigator.pop(dialogContext);
    Navigator.push(context, MaterialPageRoute(builder: (c) => const ScoringScreen()));
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
            
            if (_savedStateJson != null) ...[
              ElevatedButton.icon(
                onPressed: () => _resumeAction(null, _savedStateJson!),
                icon: const Icon(Icons.play_arrow),
                label: const Text('RESUME SAVED MATCH'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await DatabaseService.instance.clearCurrentMatchState();
                  setState(() => _savedStateJson = null);
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete Halted Match', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.red.shade300),
              ),
              const SizedBox(height: 24),
            ],

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
