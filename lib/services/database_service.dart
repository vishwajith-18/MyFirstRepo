import 'package:sqflite/sqflite.dart' if (dart.library.js_interop) 'web_db_stub.dart';
import 'package:path/path.dart';
import '../models/models.dart';
import '../models/match_model.dart';
import 'dart:convert';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cricket.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE teams (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        players_json TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE players (
        id TEXT PRIMARY KEY,
        team_id TEXT NOT NULL,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX idx_players_name_lower ON players(LOWER(name))');

    await db.execute('''
      CREATE TABLE matches (
        id TEXT PRIMARY KEY,
        teamA_id TEXT NOT NULL,
        teamB_id TEXT NOT NULL,
        overs INTEGER NOT NULL,
        toss_winner_id TEXT NOT NULL,
        toss_winner_bats_first INTEGER NOT NULL,
        innings1_json TEXT,
        innings2_json TEXT,
        date TEXT NOT NULL,
        golden_over INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE current_match_state (
        id TEXT PRIMARY KEY,
        state_json TEXT NOT NULL
      )
    ''');
  }

  Future<void> saveTeam(Team team) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.insert('teams', team.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      
      // Sync players table for uniqueness check
      await txn.delete('players', where: 'team_id = ?', whereArgs: [team.id]);
      for (var p in team.players) {
        await txn.insert('players', {
          'id': p.id,
          'team_id': team.id,
          'name': p.name,
        });
      }
    });
  }

  Future<List<Team>> getAllTeams() async {
    final db = await instance.database;
    final result = await db.query('teams');
    return result.map((json) => Team.fromMap(json)).toList();
  }

  Future<void> updateTeam(Team team) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.update('teams', team.toMap(), where: 'id = ?', whereArgs: [team.id]);
      
      // Sync players table for uniqueness check
      await txn.delete('players', where: 'team_id = ?', whereArgs: [team.id]);
      for (var p in team.players) {
        await txn.insert('players', {
          'id': p.id,
          'team_id': team.id,
          'name': p.name,
        });
      }
    });
  }

  Future<void> deleteTeam(String id) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('teams', where: 'id = ?', whereArgs: [id]);
      await txn.delete('players', where: 'team_id = ?', whereArgs: [id]);
    });
  }

  Future<void> saveCurrentMatchState(String id, String stateJson) async {
    final db = await instance.database;
    await db.insert('current_match_state', {
      'id': id,
      'state_json': stateJson,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getCurrentMatchState() async {
    final db = await instance.database;
    final result = await db.query('current_match_state', limit: 1);
    if (result.isNotEmpty) {
      return result.first['state_json'] as String;
    }
    return null;
  }

  Future<void> clearCurrentMatchState() async {
    final db = await instance.database;
    await db.delete('current_match_state');
  }

  Future<void> saveMatch(Match match) async {
    final db = await instance.database;
    await db.insert('matches', match.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Match>> getRecentMatches({int limit = 10}) async {
    final db = await instance.database;
    final result = await db.query('matches', orderBy: 'date DESC', limit: limit);
    final teams = await getAllTeams();
    final teamMap = {for (var t in teams) t.id: t};

    return result.map((json) {
      final teamA = teamMap[json['teamA_id']];
      final teamB = teamMap[json['teamB_id']];
      return Match(
        id: json['id'] as String,
        teamA: teamA!,
        teamB: teamB!,
        maxOvers: json['overs'] as int,
        tossWinnerId: json['toss_winner_id'] as String,
        tossWinnerBatsFirst: json['toss_winner_bats_first'] == 1,
        innings1: json['innings1_json'] != null ? Innings.fromMap(jsonDecode(json['innings1_json'] as String)) : null,
        innings2: json['innings2_json'] != null ? Innings.fromMap(jsonDecode(json['innings2_json'] as String)) : null,
        date: DateTime.parse(json['date'] as String),
        goldenOver: json['golden_over'] as int?,
      );
    }).toList();
  }

  Future<void> deleteMatch(String id) async {
    final db = await instance.database;
    await db.delete('matches', where: 'id = ?', whereArgs: [id]);
  }

  Future<String?> isPlayerNameTaken(String name, String? excludeTeamId) async {
    final db = await instance.database;
    final result = await db.query(
      'players',
      where: 'LOWER(name) = ? AND team_id != ?',
      whereArgs: [name.toLowerCase(), excludeTeamId ?? ''],
    );
    if (result.isNotEmpty) {
      // Find team name for better error message
      final teamId = result.first['team_id'] as String;
      final teamRes = await db.query('teams', where: 'id = ?', whereArgs: [teamId]);
      if (teamRes.isNotEmpty) {
        return teamRes.first['name'] as String;
      }
      return "another team";
    }
    return null;
  }

  Future<void> enforceMatchHistoryLimit({int max = 10}) async {
    final db = await instance.database;
    final all = await db.query('matches', orderBy: 'date DESC');
    if (all.length > max) {
      final toDelete = all.sublist(max);
      for (final row in toDelete) {
        await db.delete('matches', where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }
}
