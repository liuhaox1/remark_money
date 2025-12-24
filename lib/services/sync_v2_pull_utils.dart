class SyncV2PullUtils {
  static int computeNextCursor({
    required int previousCursor,
    dynamic nextChangeIdFromServer,
    required List<Map<String, dynamic>> changes,
  }) {
    int parseInt(dynamic v) {
      if (v == null) return -1;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final s = v.trim();
        if (s.isEmpty) return -1;
        return int.tryParse(s) ?? -1;
      }
      return -1;
    }

    var maxChangeId = -1;
    for (final c in changes) {
      final id = parseInt(c['changeId']);
      if (id > maxChangeId) maxChangeId = id;
    }

    final serverNext = parseInt(nextChangeIdFromServer);

    var next = previousCursor;
    if (serverNext > next) next = serverNext;
    if (maxChangeId > next) next = maxChangeId;
    return next;
  }
}
