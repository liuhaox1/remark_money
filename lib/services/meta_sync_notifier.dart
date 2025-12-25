import 'dart:async';

/// Emits low-frequency "meta" changes (accounts/budget/etc) so background sync
/// can react without UI wiring.
class MetaSyncNotifier {
  MetaSyncNotifier._();

  static final MetaSyncNotifier instance = MetaSyncNotifier._();

  final StreamController<String> _accountsChanged =
      StreamController<String>.broadcast();
  final StreamController<void> _categoriesChanged =
      StreamController<void>.broadcast();
  final StreamController<String> _tagsChanged =
      StreamController<String>.broadcast();

  Stream<String> get onAccountsChanged => _accountsChanged.stream;
  Stream<void> get onCategoriesChanged => _categoriesChanged.stream;
  Stream<String> get onTagsChanged => _tagsChanged.stream;

  void notifyAccountsChanged(String bookId) {
    if (_accountsChanged.hasListener) {
      _accountsChanged.add(bookId);
    }
  }

  void notifyCategoriesChanged() {
    if (_categoriesChanged.hasListener) {
      _categoriesChanged.add(null);
    }
  }

  void notifyTagsChanged(String bookId) {
    if (bookId.isEmpty) return;
    if (_tagsChanged.hasListener) {
      _tagsChanged.add(bookId);
    }
  }
}
