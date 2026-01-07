import 'app_settings_service.dart';

class BookInviteCodeStore {
  BookInviteCodeStore._();

  static final BookInviteCodeStore instance = BookInviteCodeStore._();

  String _key(String bookId) => 'book_invite_code_$bookId';

  Future<String?> getInviteCode(String bookId) async {
    if (bookId.isEmpty) return null;
    final raw = await AppSettingsService.instance.getString(_key(bookId));
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
  }
}

