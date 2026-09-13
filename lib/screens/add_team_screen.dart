import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/team_provider.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import 'package:uuid/uuid.dart';

import '../theme/app_theme.dart';

class AddTeamScreen extends ConsumerStatefulWidget {
  final Team? existingTeam;
  const AddTeamScreen({super.key, this.existingTeam});

  @override
  ConsumerState<AddTeamScreen> createState() => _AddTeamScreenState();
}

class _AddTeamScreenState extends ConsumerState<AddTeamScreen> {
  final _nameController = TextEditingController();
  final List<TextEditingController> _playerControllers = 
      List.generate(6, (index) => TextEditingController());

  @override
  void initState() {
    super.initState();
    if (widget.existingTeam != null) {
      _nameController.text = widget.existingTeam!.name;
      _playerControllers.clear();
      for (var player in widget.existingTeam!.players) {
        _playerControllers.add(TextEditingController(text: player.name));
      }
    }
  }

  void _addPlayerField() {
    if (_playerControllers.length < 12) {
      setState(() {
        _playerControllers.add(TextEditingController());
      });
    }
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
      filled: true,
      fillColor: AppTheme.kBgCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x33FFD700))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x33FFD700))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.kGold, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kBgBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.kBgBlack,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.existingTeam != null ? 'Edit Team' : 'Add New Team', style: const TextStyle(color: AppTheme.kGold, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: _inputDeco('Team Name'),
            ),
            const SizedBox(height: 24),
            const Text('Player Roster (4 - 12 players)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.kGold)),
            const SizedBox(height: 12),
            ...List.generate(_playerControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: TextField(
                  controller: _playerControllers[index],
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _inputDeco('Player ${index + 1} Name'),
                ),
              );
            }),
            if (_playerControllers.length < 12)
              Center(
                child: TextButton.icon(
                  onPressed: _addPlayerField,
                  icon: const Icon(Icons.add, color: AppTheme.kGold),
                  label: const Text('Add Another Player', style: TextStyle(color: AppTheme.kGold, fontWeight: FontWeight.bold)),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.kGold,
                  foregroundColor: AppTheme.kBgBlack,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final teamName = _nameController.text.trim();
                  final names = _playerControllers
                      .map((c) => c.text.trim())
                      .where((n) => n.isNotEmpty)
                      .toList();
                  
                  if (teamName.isEmpty || names.length < 4) {
                     ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please provide team name and at least 4 players')),
                    );
                    return;
                  }

                  final seenNames = <String>{};
                  for (var n in names) {
                    if (seenNames.contains(n.toLowerCase())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Duplicate player name found in list: $n')),
                      );
                      return;
                    }
                    seenNames.add(n.toLowerCase());
                  }

                  for (var n in names) {
                    final existingTeamName = await DatabaseService.instance.isPlayerNameTaken(n, widget.existingTeam?.id);
                    if (existingTeamName != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Player "$n" already exists in team "$existingTeamName"')),
                      );
                      return;
                    }
                  }
                  
                  if (widget.existingTeam != null) {
                    final oldPlayers = widget.existingTeam!.players;
                    List<Player> updatedPlayers = [];
                    for (int i = 0; i < names.length; i++) {
                      final newName = names[i];
                      final exactMatches = oldPlayers.where((p) => p.name.toLowerCase() == newName.toLowerCase());
                      if (exactMatches.isNotEmpty) {
                        updatedPlayers.add(Player(id: exactMatches.first.id, name: newName));
                      } else if (i < oldPlayers.length) {
                        updatedPlayers.add(Player(id: oldPlayers[i].id, name: newName));
                      } else {
                        updatedPlayers.add(Player(id: const Uuid().v4(), name: newName));
                      }
                    }
                    ref.read(teamProvider.notifier).updateTeam(widget.existingTeam!.id, teamName, updatedPlayers);
                  } else {
                    ref.read(teamProvider.notifier).addTeam(teamName, names);
                  }
                  Navigator.pop(context);
                },
                child: const Text('SAVE TEAM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
