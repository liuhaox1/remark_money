import 'package:shared_preferences/shared_preferences.dart';
import '../models/record.dart';

class RecordRepository {
  static const _key = 'records_v1';

  Future<List<Record>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) => Record.fromJson(s)).toList();
  }

  Future<void> saveRecords(List<Record> records) async {
    final prefs = await SharedPreferences.getInstance();
    final list = records.map((r) => r.toJson()).toList();
    await prefs.setStringList(_key, list);
  }

  /// 插入记录（存储到最前）
  Future<List<Record>> insert(Record record) async {
    final list = await loadRecords();
    list.insert(0, record);
    await saveRecords(list);
    return list;
  }

  /// 删除记录
  Future<List<Record>> remove(String id) async {
    final list = await loadRecords();
    list.removeWhere((r) => r.id == id);
    await saveRecords(list);
    return list;
  }

  Future<List<Record>> update(Record updated) async {
    final list = await loadRecords();
    final index = list.indexWhere((r) => r.id == updated.id);
    if (index != -1) {
      list[index] = updated;
      await saveRecords(list);
    }
    return list;
  }
}
