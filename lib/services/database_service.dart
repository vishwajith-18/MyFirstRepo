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
      CREATE TABLE matches (
        id TEXT PRIMARY KEY,
        teamA_id TEXT NOT NULL,
        teamB_id TEXT NOT NULL,
        overs INTEGER NOT NULL,
        toss_winner_id TEXT NOT NULL,
        toss_winner_bats_first INTEGER NOT NULL,
        innings1_json TEXT,
        innings2_json TEXT,
        date TEXT NOT NULL
      )
    ''');
  }

  // Team Operations
  Future<void> saveTeam(Team team) async {
    final db = await instance.database;
    await db.insert('teams', team.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Team>> getAllTeams() async {
    final db = await instance.database;
    final result = await db.query('teams');
    return result.map((json) => Team.fromMap(json)).toList();
  }

  // Match Operations
  Future<void> saveMatch(Match match) async {
    final db = await instance.database;
    await db.insert('matches', match.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Match>> getRecentMatches({int limit = 5}) async {
    final db = await instance.database;
    final result = await db.query('matches', orderBy: 'date DESC', limit: limit);
    
    // Note: This requires joining with teams or fetching teams separately.
    // For simplicity in this local-only app, we'll fetch all teams and map them.
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
      );
    }).toList();
  }
}
