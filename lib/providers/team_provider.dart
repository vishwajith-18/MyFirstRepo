import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import 'package:uuid/uuid.dart';

class TeamNotifier extends StateNotifier<List<Team>> {
  TeamNotifier() : super([]) {
    loadTeams();
  }

  Future<void> loadTeams() async {
    state = await DatabaseService.instance.getAllTeams();
  }

  Future<void> addTeam(String name, List<String> playerNames) async {
    final players = playerNames
        .map((n) => Player(id: const Uuid().v4(), name: n))
        .toList();
    final team = Team(id: const Uuid().v4(), name: name, players: players);
    await DatabaseService.instance.saveTeam(team);
    await loadTeams();
  }

  Future<void> updateTeam(String id, String name, List<String> playerNames) async {
    final players = playerNames
        .map((n) => Player(id: const Uuid().v4(), name: n))
        .toList();
    final team = Team(id: id, name: name, players: players);
    await DatabaseService.instance.updateTeam(team);
    await loadTeams();
  }

  Future<void> deleteTeam(String id) async {
    await DatabaseService.instance.deleteTeam(id);
    await loadTeams();
  }
}

final teamProvider = StateNotifierProvider<TeamNotifier, List<Team>>((ref) => TeamNotifier());
