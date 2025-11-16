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
    final categoryMap = {for (final c in categoryProvider.categories) c.key: c};

    debugPrint(
        'HomePage build duration: ${DateTime.now().difference(start).inMilliseconds}ms');

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isToday = DateUtilsX.isToday(_selectedDay);
    final dateLabel = isToday
        ? '今天 ${DateUtilsX.ymd(_selectedDay)}'
        : DateUtilsX.ymd(_selectedDay);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _showDatePanel,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.primary.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.expand_more, size: 14),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _BookSelector(bookProvider: bookProvider),
          ],
        ),
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
                ),
                const SizedBox(height: 8),
                WeekStrip(
                  selectedDay: _selectedDay,
                  onSelected: (day) {
                    setState(() => _selectedDay = day);
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            onTap: () =>
                                Navigator.pushNamed(context, '/budget'),
                          ),
                          // 以后如果再加入口，就直接在这里继续加按钮即可，
                          // 都保持横向排列，多了可以左右滑动，不会竖着排。
                        ],
                      ),
                    ),
                  ),
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
                            : _buildEmptyStateV2(context),
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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemBuilder: (context, index) {
        final record = records[index];
        return TimelineItem(
          record: record,
          category: categoryMap[record.categoryKey],
          leftSide: index.isEven,
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: records.length,
    );
  }

  Widget _buildEmptyStateV2(BuildContext context) {
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
          const Text('点底部“记一笔”开始记录吧'),
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

  Future<void> _showDatePanel() async {
    final bookId = context.read<BookProvider>().activeBookId;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DatePanel(
        bookId: bookId,
        selectedDay: _selectedDay,
        onDayChanged: (day) {
          setState(() => _selectedDay = day);
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.income,
    required this.expense,
    required this.balance,
  });

  final double income;
  final double expense;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final netColor = balance >= 0 ? Colors.green.shade700 : Colors.redAccent;
    return Padding(
      // 外层整体留白压低一些高度
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        // 内部上下 padding 也做收紧
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          // 顶部用一点主色调，卡片主体仍然是浅色，形成类似“黄色头部 + 白色内容”的层次感
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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

class _DatePanel extends StatefulWidget {
  const _DatePanel({
    required this.bookId,
    required this.selectedDay,
    required this.onDayChanged,
  });

  final String bookId;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayChanged;

  @override
  State<_DatePanel> createState() => _DatePanelState();
}

class _DatePanelState extends State<_DatePanel> {
  late DateTime _selectedDay;
  late DateTime _visibleMonth;
  late int _visibleYear;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDay;
    _visibleMonth = DateTime(_selectedDay.year, _selectedDay.month, 1);
    _visibleYear = _selectedDay.year;
  }

  @override
  void didUpdateWidget(covariant _DatePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtilsX.isSameDay(widget.selectedDay, oldWidget.selectedDay)) {
      setState(() {
        _selectedDay = widget.selectedDay;
        _visibleMonth = DateTime(_selectedDay.year, _selectedDay.month, 1);
        _visibleYear = _selectedDay.year;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordProvider = context.watch<RecordProvider>();

    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.black54,
              tabs: const [
                Tab(text: '月'),
                Tab(text: '年'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 420,
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  Column(
                    children: [
                      _CalendarHeader(
                        label:
                            '${_visibleMonth.year}年${_visibleMonth.month.toString().padLeft(2, '0')}月',
                        onPrev: () => _changeMonth(-1),
                        onNext: () => _changeMonth(1),
                        onPick: _pickMonth,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _DayNetGrid(
                          month: _visibleMonth,
                          selectedDay: _selectedDay,
                          bookId: widget.bookId,
                          recordProvider: recordProvider,
                          onSelectDay: _handleSelectDay,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      _CalendarHeader(
                        label: '$_visibleYear年',
                        onPrev: () => _changeYear(-1),
                        onNext: () => _changeYear(1),
                        onPick: _pickYear,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _MonthNetGrid(
                          year: _visibleYear,
                          bookId: widget.bookId,
                          recordProvider: recordProvider,
                          onSelectMonth: _handleSelectMonth,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSelectDay(DateTime day) {
    setState(() {
      _selectedDay = day;
      _visibleMonth = DateTime(day.year, day.month, 1);
      _visibleYear = day.year;
    });
    widget.onDayChanged(day);
  }

  void _handleSelectMonth(int month) {
    final newDay = DateTime(_visibleYear, month, 1);
    setState(() {
      _visibleMonth = DateTime(_visibleYear, month, 1);
      _selectedDay = newDay;
    });
    widget.onDayChanged(newDay);
  }

  void _changeMonth(int delta) {
    final newMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1);
    final now = DateTime.now();
    final monthKey = newMonth.year * 100 + newMonth.month;
    final nowKey = now.year * 100 + now.month;
    DateTime? updatedSelectedDay;
    if (monthKey <= nowKey) {
      final maxDay = DateUtils.getDaysInMonth(newMonth.year, newMonth.month);
      var currentDay = _selectedDay.day;
      if (currentDay > maxDay) {
        currentDay = maxDay;
      }
      updatedSelectedDay = DateTime(newMonth.year, newMonth.month, currentDay);
    }
    setState(() {
      _visibleMonth = newMonth;
      _visibleYear = newMonth.year;
      if (updatedSelectedDay != null) {
        _selectedDay = updatedSelectedDay;
      }
    });
    if (updatedSelectedDay != null) {
      widget.onDayChanged(updatedSelectedDay);
    }
  }

  void _changeYear(int delta) {
    setState(() {
      _visibleYear += delta;
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visibleMonth,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (!mounted || picked == null) return;
    final now = DateTime.now();
    final pickedKey = picked.year * 100 + picked.month;
    final nowKey = now.year * 100 + now.month;
    if (pickedKey > nowKey) return;
    final monthStart = DateTime(picked.year, picked.month, 1);
    setState(() {
      _visibleMonth = monthStart;
      _visibleYear = picked.year;
      _selectedDay = monthStart;
    });
    widget.onDayChanged(monthStart);
  }

  Future<void> _pickYear() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_visibleYear, 1, 1),
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _visibleYear = picked.year;
    });
  }
}

class _DayNetGrid extends StatelessWidget {
  const _DayNetGrid({
    required this.month,
    required this.selectedDay,
    required this.bookId,
    required this.recordProvider,
    required this.onSelectDay,
  });

  final DateTime month;
  final DateTime selectedDay;
  final String bookId;
  final RecordProvider recordProvider;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final days = DateUtilsX.daysInMonth(month);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final firstWeekday = days.first.weekday % 7;
    final items = <Widget>[];

    for (int i = 0; i < firstWeekday; i++) {
      items.add(const SizedBox.shrink());
    }
    for (final day in days) {
      final income = recordProvider.dayIncome(bookId, day);
      final expense = recordProvider.dayExpense(bookId, day);
      final net = income - expense;
      final hasData = recordProvider.recordsForDay(bookId, day).isNotEmpty;
      final disabled = day.isAfter(todayDate);
      items.add(_DayCell(
        day: day,
        net: net,
        hasData: hasData,
        disabled: disabled,
        selected: DateUtilsX.isSameDay(day, selectedDay),
        onTap: () => onSelectDay(day),
      ));
    }

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 0.9,
      children: items,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.net,
    required this.hasData,
    required this.disabled,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final double net;
  final bool hasData;
  final bool disabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final color = net > 0
        ? Colors.redAccent
        : net < 0
            ? Colors.lightGreen
            : (isDark ? cs.onSurface.withOpacity(0.6) : Colors.grey.shade500);
    final effectiveColor =
        disabled ? cs.onSurface.withOpacity(0.35) : color;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: disabled
              ? (isDark
                  ? cs.surfaceVariant.withOpacity(0.4)
                  : Colors.grey.shade200)
              : selected
                  ? effectiveColor.withOpacity(0.22)
                  : (isDark ? cs.surface : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? effectiveColor
                : (isDark
                    ? cs.outline.withOpacity(0.4)
                    : Colors.grey.shade300),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (hasData)
              Text(
                net > 0
                    ? '+${net.toStringAsFixed(2)}'
                    : net < 0
                        ? net.toStringAsFixed(2)
                        : '0.00',
                style: TextStyle(
                  fontSize: 11,
                  color: effectiveColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthNetGrid extends StatelessWidget {
  const _MonthNetGrid({
    required this.year,
    required this.bookId,
    required this.recordProvider,
    required this.onSelectMonth,
  });

  final int year;
  final String bookId;
  final RecordProvider recordProvider;
  final ValueChanged<int> onSelectMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final months = List.generate(12, (i) => i + 1);

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.4,
      children: months.map((month) {
        final monthRecords =
            recordProvider.recordsForMonth(bookId, year, month);
        double income = 0;
        double expense = 0;
        for (final record in monthRecords) {
          if (record.isIncome) {
            income += record.incomeValue;
          } else {
            expense += record.expenseValue;
          }
        }
        final net = income - expense;
        final hasData = monthRecords.isNotEmpty;
        final disabled = DateTime(year, month, 1).isAfter(DateTime.now());
        final color = net > 0
            ? Colors.redAccent
            : net < 0
                ? Colors.lightGreen
                : cs.outline;
        final showNet = hasData || net != 0;

        return InkWell(
          onTap: disabled ? null : () => onSelectMonth(month),
          child: Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: disabled
                  ? (isDark
                      ? cs.surfaceVariant.withOpacity(0.4)
                      : Colors.grey.shade200)
                  : (isDark ? cs.surface : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: disabled
                    ? (isDark
                        ? cs.outline.withOpacity(0.3)
                        : Colors.grey.shade300)
                    : net >= 0
                        ? Colors.redAccent.withOpacity(0.4)
                        : Colors.lightGreen.withOpacity(0.4),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  month.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                if (showNet)
                  Text(
                    net > 0
                        ? '+${net.toStringAsFixed(2)}'
                        : net < 0
                            ? net.toStringAsFixed(2)
                            : '0.00',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.label,
    required this.onPrev,
    required this.onNext,
    this.onPick,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onPick,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
          if (onPick != null)
            IconButton(
              icon: const Icon(Icons.date_range_outlined),
              onPressed: onPick,
            ),
        ],
      ),
    );
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
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
