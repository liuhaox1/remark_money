// IO platform implementation
import 'dart:io' show Platform;
import 'package:sqflite/sqflite.dart' as sqflite;

Future<sqflite.Database> openDatabaseWithPlatform(
  String path, {
  String? password,
  int version = 1,
  Future<void> Function(sqflite.Database, int)? onCreate,
  Future<void> Function(sqflite.Database, int, int)? onUpgrade,
}) async {
  // Windows/Linux/macOS 平台使用普通 sqflite（不支持加密）
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return await sqflite.openDatabase(
      path,
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
  }

  // 移动平台（Android/iOS）使用加密版本
  // 注意：需要在移动平台上才能使用 sqflite_sqlcipher
  // 这里先使用普通版本，移动平台需要单独配置
  return await sqflite.openDatabase(
    path,
    version: version,
    onCreate: onCreate,
    onUpgrade: onUpgrade,
  );
}
