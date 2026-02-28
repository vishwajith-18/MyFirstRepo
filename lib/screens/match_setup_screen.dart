import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/team_provider.dart';
import '../providers/match_provider.dart';
import '../models/match_model.dart';
import 'scoring_screen.dart';
import 'package:uuid/uuid.dart';

class MatchSetupScreen extends ConsumerStatefulWidget {
  const MatchSetupScreen({super.key});

  @override
  ConsumerState<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends ConsumerState<MatchSetupScreen> {
  String? teamAId;
  String? teamBId;
  String? tossWinnerId;
  bool teamABatsFirst = true;
  int overs = 5;

  @override
  Widget build(BuildContext context) {
    final teams = ref.watch(teamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Match Setup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: teamAId,
              decoration: const InputDecoration(labelText: 'Team A'),
              items: teams.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
              onChanged: (v) => setState(() => teamAId = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: teamBId,
              decoration: const InputDecoration(labelText: 'Team B'),
              items: teams.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
              onChanged: (v) => setState(() => teamBId = v),
            ),
            const SizedBox(height: 24),
            if (teamAId != null && teamBId != null) ...[
              const Text('Toss Result', style: TextStyle(fontWeight: FontWeight.bold)),
              RadioListTile<String>(
                title: Text(teams.firstWhere((t) => t.id == teamAId).name),
                value: teamAId!,
                groupValue: tossWinnerId,
                onChanged: (v) => setState(() => tossWinnerId = v),
              ),
              RadioListTile<String>(
                title: Text(teams.firstWhere((t) => t.id == teamBId).name),
                value: teamBId!,
                groupValue: tossWinnerId,
                onChanged: (v) => setState(() => tossWinnerId = v),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Winner Bats First?'),
                value: teamABatsFirst,
                onChanged: (v) => setState(() => teamABatsFirst = v),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: 'Number of Overs (1-50)'),
              keyboardType: TextInputType.number,
              onChanged: (v) => setState(() => overs = int.tryParse(v) ?? 5),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                if (teamAId != null && teamBId != null && tossWinnerId != null) {
                  final teamA = teams.firstWhere((t) => t.id == teamAId);
                  final teamB = teams.firstWhere((t) => t.id == teamBId);
                  
                  final match = Match(
                    id: const Uuid().v4(),
                    teamA: teamA,
                    teamB: teamB,
                    maxOvers: overs,
                    tossWinnerId: tossWinnerId!,
                    tossWinnerBatsFirst: teamABatsFirst,
                    date: DateTime.now(),
                  );
                  
                  ref.read(matchProvider.notifier).startMatch(match);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const ScoringScreen()));
                }
              },
              child: const Center(child: Text('Start Scoring')),
            ),
          ],
        ),
      ),
    );
  }
}
