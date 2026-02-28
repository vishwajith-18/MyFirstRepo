import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/team_provider.dart';
import 'add_team_screen.dart';
import 'match_setup_screen.dart';

class TeamListScreen extends ConsumerWidget {
  const TeamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(teamProvider);

    return Scaffold(
      app_bar: AppBar(title: const Text('Teams')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AddTeamScreen())),
        child: const Icon(Icons.add),
      ),
      body: teams.isEmpty
          ? const Center(child: Text('No teams added yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: teams.length,
              itemBuilder: (context, index) {
                final team = teams[index];
                return Card(
                  child: ListTile(
                    title: Text(team.name),
                    subtitle: Text('${team.players.length} Players'),
                    onTap: () {
                      // Optionally show player list or start match setup
                    },
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
      bottom_navigation_bar: teams.length >= 2
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MatchSetupScreen())),
                child: const Text('Start New Match'),
              ),
            )
          : null,
    );
  }
}
