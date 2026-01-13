import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/category_provider.dart';
import '../services/book_service.dart';
import '../services/sync_v2_activity_service.dart';
import '../theme/app_tokens.dart';
import '../utils/error_handler.dart';
import '../widgets/app_scaffold.dart';

class FamilyActivityPage extends StatefulWidget {
  const FamilyActivityPage({super.key, required this.bookId});

  final String bookId;

  @override
  State<FamilyActivityPage> createState() => _FamilyActivityPageState();
}

class _FamilyActivityPageState extends State<FamilyActivityPage> {
  final SyncV2ActivityService _service = SyncV2ActivityService();
  final BookService _bookService = BookService();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int? _nextBeforeChangeId;
  List<Map<String, dynamic>> _items = const [];

  Map<int, String> _memberNameById = const {};

  @override
  void initState() {
    super.initState();
    _reload();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final bid = int.tryParse(widget.bookId);
    if (bid == null) return;
    try {
      final members = await _bookService.listMembers(widget.bookId);
      final next = <int, String>{};
      for (final m in members) {
        final uid = (m['userId'] as num?)?.toInt();
        if (uid == null || uid <= 0) continue;
        final nickname = (m['nickname'] as String?)?.trim();
        final username = (m['username'] as String?)?.trim();
        final name = (nickname != null && nickname.isNotEmpty)
            ? nickname
            : (username != null && username.isNotEmpty)
                ? username
                : '用户$uid';
        next[uid] = name;
      }
      if (!mounted) return;
      setState(() => _memberNameById = next);
    } catch (_) {}
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _items = const [];
      _nextBeforeChangeId = null;
      _hasMore = false;
    });
    try {
      final resp = await _service.fetchActivity(bookId: widget.bookId);
      final items = (resp['items'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _items = items;
        _hasMore = resp['hasMore'] == true;
        final next = resp['nextBeforeChangeId'];
        _nextBeforeChangeId = (next is num) ? next.toInt() : int.tryParse(next?.toString() ?? '');
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ErrorHandler.handleAsyncError(context, e);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final before = _nextBeforeChangeId;
    if (before == null || before <= 0) return;

    setState(() => _loadingMore = true);
    try {
      final resp = await _service.fetchActivity(
        bookId: widget.bookId,
        beforeChangeId: before,
      );
      final items = (resp['items'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _items = <Map<String, dynamic>>[..._items, ...items];
        _hasMore = resp['hasMore'] == true;
        final next = resp['nextBeforeChangeId'];
        _nextBeforeChangeId = (next is num) ? next.toInt() : int.tryParse(next?.toString() ?? '');
      });
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleAsyncError(context, e);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$mi';
  }

  String _actionLabel(Map<String, dynamic> item) {
    final op = item['op']?.toString() ?? '';
    if (op == 'delete') return '删除';
    final v = item['version'];
    final ver = (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    return ver <= 1 ? '新增' : '修改';
  }

  String _memberName(int? userId) {
    if (userId == null || userId <= 0) return '未知';
    return _memberNameById[userId] ?? '用户$userId';
  }

  String _categoryLabel(BuildContext context, String? categoryKey) {
    if (categoryKey == null || categoryKey.isEmpty) return '';
    try {
      final provider = context.read<CategoryProvider>();
      for (final c in provider.categories) {
        if (c.key == categoryKey) return c.name;
      }
    } catch (_) {}
    return categoryKey;
  }

  double _amountFromBill(Map<String, dynamic>? bill) {
    final v = bill?['amount'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppScaffold(
      title: '家庭动态',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            '暂无动态',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemBuilder: (ctx, i) {
                        if (i == _items.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: FilledButton(
                              onPressed: _loadingMore ? null : _loadMore,
                              child: Text(_loadingMore ? '加载中…' : (_hasMore ? '加载更多' : '没有更多了')),
                            ),
                          );
                        }

                        final item = _items[i];
                        final actor = item['actorUserId'];
                        final actorId = (actor is num) ? actor.toInt() : int.tryParse(actor?.toString() ?? '');
                        final bill = (item['bill'] as Map?)?.cast<String, dynamic>();

                        final direction = (bill?['direction'] as int? ?? 0) == 1 ? 1 : 0;
                        final amt = _amountFromBill(bill).abs();
                        final amountColor = direction == 1 ? AppColors.success : AppColors.danger;
                        final signed = '${direction == 1 ? '+' : '-'}${amt.toStringAsFixed(2)}';

                        final categoryKey = bill?['categoryKey']?.toString();
                        final category = _categoryLabel(ctx, categoryKey);
                        final remark = (bill?['remark'] as String?)?.trim() ?? '';

                        return Card(
                          elevation: 0,
                          color: cs.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: cs.primary.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        Icons.notifications_none_rounded,
                                        size: 18,
                                        color: cs.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${_memberName(actorId)} ${_actionLabel(item)}了一笔记账',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      _fmtTime(item['time']?.toString()),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: cs.onSurface.withOpacity(0.55),
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        category.isEmpty ? '—' : category,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: cs.onSurface.withOpacity(0.85),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      signed,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: amountColor,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                                if (remark.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    remark,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: cs.onSurface.withOpacity(0.65),
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemCount: _items.length + 1,
                    ),
            ),
    );
  }
}
