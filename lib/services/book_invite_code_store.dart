import 'app_settings_service.dart';
import 'user_scope.dart';

class BookInviteCodeStore {
  BookInviteCodeStore._();

  static final BookInviteCodeStore instance = BookInviteCodeStore._();

  String _legacyKey(String bookId) => 'book_invite_code_$bookId';

  String _key(String bookId) => UserScope.key(_legacyKey(bookId));

  Future<String?> getInviteCode(String bookId) async {
    if (bookId.isEmpty) return null;
    final key = _key(bookId);
    final legacyKey = _legacyKey(bookId);

    final raw = await AppSettingsService.instance.getString(key);
    if ((raw == null || raw.trim().isEmpty) && legacyKey != key) {
      final legacy = await AppSettingsService.instance.getString(legacyKey);
      final legacyTrimmed = legacy?.trim();
      if (legacyTrimmed != null && legacyTrimmed.isNotEmpty) {
        try {
          await AppSettingsService.instance.setString(key, legacyTrimmed);
          await AppSettingsService.instance.setString(legacyKey, '');
          return legacyTrimmed;
        } catch (_) {
          return legacyTrimmed;
        }
      }
    }
    final trimmed = raw?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<void> setInviteCode(String bookId, String inviteCode) async {
    if (bookId.isEmpty) return;
    final code = inviteCode.trim();
    if (code.isEmpty) return;
    await AppSettingsService.instance.setString(_key(bookId), code);
  }

  Future<void> clearInviteCode(String bookId) async {
    if (bookId.isEmpty) return;
    await AppSettingsService.instance.setString(_key(bookId), '');
    // Best-effort: also clear legacy unscoped key.
    await AppSettingsService.instance.setString(_legacyKey(bookId), '');
  }
}
