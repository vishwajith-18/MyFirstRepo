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
  bool? tossWinnerChoseBat;
  int? overs;

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
              items: teams.where((t) => t.id != teamAId).map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
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
              const Text('Decision', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tossWinnerChoseBat == true ? Colors.blue : Colors.grey[300],
                      foregroundColor: tossWinnerChoseBat == true ? Colors.white : Colors.black,
                    ),
                    onPressed: tossWinnerId == null ? null : () => setState(() => tossWinnerChoseBat = true),
                    child: const Text('BAT'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tossWinnerChoseBat == false ? Colors.blue : Colors.grey[300],
                      foregroundColor: tossWinnerChoseBat == false ? Colors.white : Colors.black,
                    ),
                    onPressed: tossWinnerId == null ? null : () => setState(() => tossWinnerChoseBat = false),
                    child: const Text('BOWL'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: 'Number of Overs (1-50)'),
              keyboardType: TextInputType.number,
              onChanged: (v) => setState(() => overs = int.tryParse(v)),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: (teamAId != null && teamBId != null && tossWinnerId != null && tossWinnerChoseBat != null && overs != null && overs! > 0)
                ? () {
                    final teamA = teams.firstWhere((t) => t.id == teamAId);
                    final teamB = teams.firstWhere((t) => t.id == teamBId);
                    
                    final match = Match(
                      id: const Uuid().v4(),
                      teamA: teamA,
                      teamB: teamB,
                      maxOvers: overs!,
                      tossWinnerId: tossWinnerId!,
                      tossWinnerBatsFirst: tossWinnerChoseBat!,
                      date: DateTime.now(),
                    );
                    
                    ref.read(matchProvider.notifier).startMatch(match);
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const ScoringScreen()));
                  }
                : null, // Disabled until all fields are filled
              child: const Center(child: Text('Start Scoring')),
            ),
          ],
        ),
      ),
    );
  }
}
