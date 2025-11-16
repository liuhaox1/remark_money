import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/record.dart';
import '../providers/book_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../utils/date_utils.dart';
import '../widgets/timeline_item.dart';
import '../widgets/week_strip.dart';
import '../widgets/quick_add_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final start = DateTime.now();
    final recordProvider = context.watch<RecordProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final bookProvider = context.watch<BookProvider>();
    final bookId = bookProvider.activeBookId;

    final selectedMonth = DateTime(_selectedDay.year, _selectedDay.month, 1);
    final monthIncome = recordProvider.monthIncome(selectedMonth, bookId);
    final monthExpense = recordProvider.monthExpense(selectedMonth, bookId);
    final monthBalance = monthIncome - monthExpense;

    final dayRecords = recordProvider.recordsForDay(bookId, _selectedDay);
    final hasRecords = recordProvider.recordsForBook(bookId).isNotEmpty;
    final categoryMap = {
      for (final c in categoryProvider.categories) c.key: c,
    };

    debugPrint(
      'HomePage build duration: '
      '${DateTime.now().difference(start).inMilliseconds}ms',
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isToday = DateUtilsX.isToday(_selectedDay);
    final dateLabel =
        isToday ? '今天 ${DateUtilsX.ymd(_selectedDay)}' : DateUtilsX.ymd(_selectedDay);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _BalanceCard(
                  income: monthIncome,
                  expense: monthExpense,
                  balance: monthBalance,
                  dateLabel: dateLabel,
                  onTapDate: _pickDate,
                  bookProvider: bookProvider,
                ),
                const SizedBox(height: 8),
                WeekStrip(
                  selectedDay: _selectedDay,
                  onSelected: (day) {
                    setState(() => _selectedDay = day);
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Column(
                    children: [
                      const _BudgetBanner(),
                      const SizedBox(height: 4),
                      Expanded(
                        child: hasRecords
                            ? _buildTimeline(dayRecords, categoryMap)
                            : _buildEmptyState(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(
    List<Record> records,
    Map<String, dynamic> categoryMap,
  ) {
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }

    final day = records.first.date;
    final dateLabel = '${day.month}月${day.day}日';
    final weekdayLabel = DateUtilsX.weekdayShort(day); // 日 / 一 / 二 ...
    final totalExpense = records
        .where((r) => r.isExpense)
        .fold<double>(0, (sum, r) => sum + r.absAmount);
    final totalIncome = records
        .where((r) => !r.isExpense)
        .fold<double>(0, (sum, r) => sum + r.absAmount);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _DayHeader(
            dateLabel: '$dateLabel  周$weekdayLabel',
            income: totalIncome,
            expense: totalExpense,
          );
        }
        final record = records[index - 1];
        return TimelineItem(
          record: record,
          category: categoryMap[record.categoryKey],
          leftSide: index.isEven,
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemCount: records.length + 1,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 72, color: cs.outline),
          const SizedBox(height: 12),
          const Text(
            '今天还没有记账',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('可以点击下方按钮快速记一笔'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openQuickAddSheet,
            icon: const Icon(Icons.add),
            label: const Text('快捷记一笔'),
          ),
        ],
      ),
    );
  }

  Future<void> _openQuickAddSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const QuickAddSheet(),
    );
  }

  Future<void> _pickDate() async {
    final initial = _selectedDay;
    final first = DateTime(initial.year - 2, 1, 1);
    final last = DateTime(initial.year + 2, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() => _selectedDay = picked);
    }
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.dateLabel,
    required this.income,
    required this.expense,
  });

  final String dateLabel;
  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final expenseColor = Colors.redAccent;
    final incomeColor = cs.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dateLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (income > 0)
            Text(
              '收入 ${income.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: incomeColor,
              ),
            ),
          if (income > 0) const SizedBox(width: 12),
          Text(
            '支出 ${expense.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              color: expenseColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.income,
    required this.expense,
    required this.balance,
    required this.dateLabel,
    required this.onTapDate,
    required this.bookProvider,
  });

  final double income;
  final double expense;
  final double balance;
  final String dateLabel;
  final VoidCallback onTapDate;
  final BookProvider bookProvider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final netColor = balance >= 0 ? Colors.green.shade700 : Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isDark
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.primary.withOpacity(0.18),
                    Colors.white,
                  ],
                ),
          color: isDark ? cs.surface : null,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: GestureDetector(
                    onTap: onTapDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(isDark ? 0.04 : 0.7),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: cs.primary.withOpacity(0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule, size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              dateLabel,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.expand_more, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: _BookSelector(bookProvider: bookProvider),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '本月结余',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        balance.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: netColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _BalanceMiniItem(
                          label: '收入',
                          value: income,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BalanceMiniItem(
                          label: '支出',
                          value: expense,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ShortcutButton(
                      icon: Icons.receipt_long,
                      label: '账单',
                      onTap: () => Navigator.pushNamed(context, '/bill'),
                    ),
                    const SizedBox(width: 8),
                    _ShortcutButton(
                      icon: Icons.account_balance_wallet_outlined,
                      label: '预算',
                      onTap: () => Navigator.pushNamed(context, '/budget'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceMiniItem extends StatelessWidget {
  const _BalanceMiniItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: cs.primary, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookSelector extends StatelessWidget {
  const _BookSelector({required this.bookProvider});

  final BookProvider bookProvider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activeName = bookProvider.activeBook?.name ?? '默认账本';
    return InkWell(
      onTap: () => _showBookPicker(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? cs.surface : Colors.white,
          border: Border.all(color: cs.primary.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              activeName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showBookPicker(BuildContext context) async {
    final button = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final selectedId = await showMenu<String>(
      context: context,
      position: position,
      items: [
        for (final book in bookProvider.books)
          PopupMenuItem<String>(
            value: book.id,
            child: Row(
              children: [
                if (book.id == bookProvider.activeBookId)
                  Icon(
                    Icons.check,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  )
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 4),
                Text(book.name),
              ],
            ),
          ),
      ],
    );

    if (selectedId != null && selectedId != bookProvider.activeBookId) {
      bookProvider.selectBook(selectedId);
    }
  }
}

class _BudgetBanner extends StatelessWidget {
  const _BudgetBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final budget = context.watch<BudgetProvider>().budget;
    if (budget.total > 0) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.amber.withOpacity(0.18)
            : Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: cs.primary, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '预算尚未设置，可前往「预算」添加上限，及时掌握支出节奏。',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
