import 'dart:async';

/// Emits low-frequency "meta" changes (accounts/budget/etc) so background sync
/// can react without UI wiring.
class MetaSyncNotifier {
  MetaSyncNotifier._();

  static final MetaSyncNotifier instance = MetaSyncNotifier._();

  final StreamController<String> _accountsChanged =
      StreamController<String>.broadcast();
  final StreamController<String> _budgetChanged =
      StreamController<String>.broadcast();
  final StreamController<String> _categoriesChanged =
      StreamController<String>.broadcast();
  final StreamController<String> _tagsChanged =
      StreamController<String>.broadcast();
  final StreamController<String> _savingsPlansChanged =
      StreamController<String>.broadcast();

  Stream<String> get onAccountsChanged => _accountsChanged.stream;
  Stream<String> get onBudgetChanged => _budgetChanged.stream;
  Stream<String> get onCategoriesChanged => _categoriesChanged.stream;
  Stream<String> get onTagsChanged => _tagsChanged.stream;
  Stream<String> get onSavingsPlansChanged => _savingsPlansChanged.stream;

  void notifyAccountsChanged(String bookId) {
    if (_accountsChanged.hasListener) {
      _accountsChanged.add(bookId);
    }
  }

  void notifyBudgetChanged(String bookId) {
    if (bookId.isEmpty) return;
    if (_budgetChanged.hasListener) {
      _budgetChanged.add(bookId);
    }
  }

  void notifyCategoriesChanged(String bookId) {
    if (bookId.isEmpty) return;
    if (_categoriesChanged.hasListener) {
      _categoriesChanged.add(bookId);
    }
  }

  void notifyTagsChanged(String bookId) {
    if (bookId.isEmpty) return;
    if (_tagsChanged.hasListener) {
      _tagsChanged.add(bookId);
    }
  }

  void notifySavingsPlansChanged(String bookId) {
    if (bookId.isEmpty) return;
    if (_savingsPlansChanged.hasListener) {
      _savingsPlansChanged.add(bookId);
    }
  }
}
