import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/team_provider.dart';
import '../models/models.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existingTeam != null ? 'Edit Team' : 'Add New Team')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Team Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            const Text('Player List (4-12 players)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...List.generate(_playerControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TextField(
                  controller: _playerControllers[index],
                  decoration: InputDecoration(
                    labelText: 'Player ${index + 1}',
                    border: const OutlineInputBorder(),
                  ),
                ),
              );
            }),
            if (_playerControllers.length < 12)
              TextButton.icon(
                onPressed: _addPlayerField,
                icon: const Icon(Icons.add),
                label: const Text('Add Player'),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                final names = _playerControllers
                    .map((c) => c.text.trim())
                    .where((n) => n.isNotEmpty)
                    .toList();
                
                if (_nameController.text.isNotEmpty && names.length >= 4) {
                  if (widget.existingTeam != null) {
                    ref.read(teamProvider.notifier).updateTeam(widget.existingTeam!.id, _nameController.text, names);
                  } else {
                    ref.read(teamProvider.notifier).addTeam(_nameController.text, names);
                  }
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please provide team name and at least 4 players')),
                  );
                }
              },
              child: const Center(child: Text('Save Team')),
            ),
          ],
        ),
      ),
    );
  }
}
