// Stub file for non-IO platforms
import 'package:sqflite/sqflite.dart' as sqflite;

Future<sqflite.Database> openDatabaseWithPlatform(
  String path, {
  String? password,
  int version = 1,
  Future<void> Function(sqflite.Database, int)? onCreate,
  Future<void> Function(sqflite.Database, int, int)? onUpgrade,
}) async {
  // Web 平台使用普通 sqflite
  return await sqflite.openDatabase(
    path,
    version: version,
    onCreate: onCreate,
    onUpgrade: onUpgrade,
  );
}

