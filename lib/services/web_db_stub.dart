// Stub to allow compilation on Web
class Database {
  Future<void> execute(String sql, [List<Object?>? arguments]) async {}
  Future<int> insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async => 0;
  Future<List<Map<String, Object?>>> query(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) async => [];
}

enum ConflictAlgorithm { replace, ignore, fail, abort, rollback }

Future<String> getDatabasesPath() async => '';
Future<Database> openDatabase(String path, {int? version, OnDatabaseCreateFn? onCreate}) async => Database();

typedef OnDatabaseCreateFn = Future<void> Function(Database db, int version);
