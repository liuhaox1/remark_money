import 'package:flutter/material.dart';

import '../services/book_service.dart';

class BookMembersPage extends StatefulWidget {
  const BookMembersPage({
    super.key,
    required this.bookId,
    required this.bookName,
  });

  final String bookId;
  final String bookName;

  @override
  State<BookMembersPage> createState() => _BookMembersPageState();
}

class _BookMembersPageState extends State<BookMembersPage> {
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final service = BookService();
    return service.listMembers(widget.bookId);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('成员 · ${widget.bookName}'),
        actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: () {
                setState(() {
                  _future = BookService().listMembers(widget.bookId, forceRefresh: true);
                });
              },
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '加载失败：${snapshot.error}',
                  style: tt.bodyMedium?.copyWith(color: cs.error),
                ),
              ),
            );
          }
          final list = snapshot.data ?? const [];
          if (list.isEmpty) {
            return Center(
              child: Text(
                '暂无成员',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.65),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final m = list[i];
              final userId = (m['userId'] as num?)?.toInt();
              final nickname = (m['nickname'] as String?)?.trim();
              final username = (m['username'] as String?)?.trim();
              final role = (m['role'] as String?)?.trim();
              final display = (nickname != null && nickname.isNotEmpty)
                  ? nickname
                  : (username != null && username.isNotEmpty)
                      ? username
                      : (userId != null ? '用户#$userId' : '未知用户');
              final roleLabel = role == 'owner' ? '创建者' : '成员';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primary.withOpacity(0.12),
                    child: Text(
                      display.isNotEmpty ? display.substring(0, 1) : '?',
                      style: tt.titleMedium?.copyWith(color: cs.primary),
                    ),
                  ),
                  title: Text(display),
                  subtitle: userId == null ? null : Text('ID：$userId'),
                  trailing: Text(
                    roleLabel,
                    style: tt.labelMedium?.copyWith(
                      color: role == 'owner' ? cs.primary : cs.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
