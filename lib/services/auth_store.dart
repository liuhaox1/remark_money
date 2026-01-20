import 'package:shared_preferences/shared_preferences.dart';

Future<void> clearSyncV2LocalState(SharedPreferences prefs) async {
  final keys = prefs.getKeys().toList(growable: false);
  for (final k in keys) {
    if (k.startsWith('sync_v2_last_change_id_') ||
        k.startsWith('sync_v2_conflicts_') ||
        k.startsWith('sync_v2_summary_checked_at_') ||
        k.startsWith('bill_id_pool_v1_') ||
        k.startsWith('data_version_') ||
        k.startsWith('budget_update_time_') ||
        k.startsWith('budget_local_edit_ms_') ||
        k.startsWith('budget_server_update_ms_') ||
        k.startsWith('budget_server_sync_version_') ||
        k.startsWith('budget_local_base_sync_version_') ||
        k.startsWith('budget_conflict_backup_')) {
      await prefs.remove(k);
    }
  }
}

Future<void> clearAuthTokenOnly() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('auth_token');
  await prefs.remove('auth_user_id');
  await prefs.remove('auth_nickname');
  await prefs.remove('auth_username');
}

/// Full reset for auth + local sync state (used by explicit "reset" flows).
Future<void> clearAuthTokenAndLocalSyncState() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('auth_token');
  await prefs.remove('auth_user_id');
  await prefs.remove('auth_nickname');
  await prefs.remove('auth_username');
  await clearSyncV2LocalState(prefs);
}
