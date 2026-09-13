import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/team_provider.dart';
import 'add_team_screen.dart';
import 'match_setup_screen.dart';

import '../theme/app_theme.dart';

class TeamListScreen extends ConsumerWidget {
  const TeamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(teamProvider);

    return Scaffold(
      backgroundColor: AppTheme.kBgBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.kBgBlack,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Manage Teams', style: TextStyle(color: AppTheme.kGold, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.kGold,
        foregroundColor: AppTheme.kBgBlack,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AddTeamScreen())),
        child: const Icon(Icons.add, size: 28),
      ),
      body: teams.isEmpty
          ? const Center(child: Text('No teams added yet', style: TextStyle(color: Colors.white54, fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: teams.length,
              itemBuilder: (context, index) {
                final team = teams[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.kBgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x33FFD700)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.kBgSurface,
                      child: Text(
                        team.name.isNotEmpty ? team.name[0].toUpperCase() : 'T',
                        style: const TextStyle(color: AppTheme.kGold, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(team.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text('${team.players.length} Players', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: AppTheme.kGoldLight, size: 24),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AddTeamScreen(existingTeam: team))),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                          onPressed: () => ref.read(teamProvider.notifier).deleteTeam(team.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: teams.length >= 2
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.kGold,
                    foregroundColor: AppTheme.kBgBlack,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MatchSetupScreen())),
                  child: const Text('START NEW MATCH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
                ),
              ),
            )
          : null,
    );
  }
}
