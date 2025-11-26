import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../models/recurring_record.dart';
import '../models/record_template.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../providers/account_provider.dart';
import '../providers/saving_goal_provider.dart';
import '../theme/app_tokens.dart';
import '../utils/date_utils.dart';
import '../widgets/account_select_bottom_sheet.dart';
import '../repository/record_template_repository.dart';
import '../repository/recurring_record_repository.dart';
import 'add_account_type_page.dart';

class AddRecordPage extends StatefulWidget {
  const AddRecordPage({
    super.key,
    this.isExpense = true,
    this.initialRecord,
  });

  /// 默认记一笔时的收支方向
  final bool isExpense;

  /// 如果传入，则进入「编辑记录」模式
  final Record? initialRecord;

  @override
  State<AddRecordPage> createState() => _AddRecordPageState();
}

class _AddRecordPageState extends State<AddRecordPage> {
  static const double _kCategoryIconSize = 20;
  static const double _kCategoryItemWidth = 84;
  static const double _kCategoryItemHeight = 72;
  static const BorderRadius _kCategoryBorderRadius =
      BorderRadius.all(Radius.circular(16));

  static const Map<String, String> _kCategoryNameShortMap = {
    // 一级分类：控制字数，避免挤不下
    AppStrings.catTopLiving: '居住账单',
    AppStrings.catTopFamily: '家庭人情',
    AppStrings.catTopFinance: '金融其他',
    // 容易过长的二级分类
    AppStrings.catFoodMeal: '正餐工作',
    AppStrings.catFinRepay: '还贷卡费',
    AppStrings.catFinFee: '利息手续费',
  };

  static bool _lastIsExpense = true;
  static String? _lastAccountId;
  static bool _lastIncludeInStats = true;
  static String? _lastSavingGoalId;

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();

  late bool _isExpense;
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryKey;
  String? _selectedAccountId;
  bool _includeInStats = true;
  String? _selectedGoalId;
  bool _saveAsTemplate = false;
  bool _isRecurring = false;
  RecurringPeriodType _recurringPeriodType = RecurringPeriodType.monthly;
  String? _activeRecurringPlanId;
  bool _showRemarkInput = false;
  String _amountExpression = '';

  final RecordTemplateRepository _templateRepository =
      RecordTemplateRepository();
  final RecurringRecordRepository _recurringRepository =
      RecurringRecordRepository();

  List<RecordTemplate> _templates = const [];
  List<RecurringRecordPlan> _duePlans = const [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRecord;
    if (initial != null) {
      // 编辑模式：用原记录初始化各字段
      _isExpense = initial.isExpense;
      _selectedDate = initial.date;
      _selectedCategoryKey = initial.categoryKey;
      _selectedAccountId = initial.accountId;
      _includeInStats = initial.includeInStats;
      _selectedGoalId = initial.targetId;
      _amountCtrl.text = initial.amount.toStringAsFixed(2);
      _remarkCtrl.text = initial.remark;
    } else {
      // 新增模式：沿用上一次的记账偏好
      _isExpense = _lastIsExpense = widget.isExpense;
      _includeInStats = _lastIncludeInStats;
      _selectedGoalId = _lastSavingGoalId;
    }
    _loadTemplatesAndPlans();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().categories;
    final filtered =
        categories.where((c) => c.isExpense == _isExpense).toList();
    _ensureCategorySelection(filtered);
    _ensureAccountSelection();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111418) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 44,
        title: Text(
          widget.initialRecord == null
              ? AppStrings.addRecord
              : AppStrings.edit,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
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
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_duePlans.isNotEmpty)
                              _buildRecurringBanner(),
                            if (_duePlans.isNotEmpty)
                              const SizedBox(height: 12),
                            _buildAmountAndTypeRow(),
                            const SizedBox(height: 4),
                            if (_templates.isNotEmpty) ...[
                              _buildTemplateChips(),
                              const SizedBox(height: 16),
                            ],
                            _buildCategorySection(filtered),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                    _buildBottomAccountDateBar(),
                    _buildNumberPad(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAccountDateBar() {
    final dividerColor =
        Theme.of(context).dividerColor.withOpacity(0.15);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: dividerColor),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickToolItem(
                icon: Icons.account_balance_wallet_outlined,
                label: '账户',
                onTap: _onQuickAccountTap,
              ),
              _buildQuickToolItem(
                icon: Icons.tune_outlined,
                label: '更多',
                onTap: _onQuickMoreTap,
              ),
              _buildQuickToolItem(
                icon: Icons.calendar_today_outlined,
                label: '日期',
                onTap: _pickDate,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildRemarkField(),
        ],
      ),
    );
  }

  Widget _buildQuickToolItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onQuickAccountTap() async {
    final accounts = context.read<AccountProvider>().accounts;
    if (accounts.isEmpty) {
      await Navigator.push<AccountKind>(
        context,
        MaterialPageRoute(
          builder: (_) => const AddAccountTypePage(),
        ),
      );
      if (!mounted) return;
      setState(() => _selectedAccountId = null);
      return;
    }

    final selectedId = await showAccountSelectBottomSheet(
      context,
      accounts,
      selectedAccountId: _selectedAccountId,
    );
    if (!mounted || selectedId == null) return;
    setState(() {
      _selectedAccountId = selectedId;
      _selectedGoalId = null;
    });
  }

  Future<void> _onQuickMoreTap() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SingleChildScrollView(
              child: _buildAdvancedSheetContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmountAndTypeRow() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 160,
        child: _buildTypeSwitcher(),
      ),
    );
  }

  Widget _buildAmountField() {
    return TextField(
      controller: _amountCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: AppColors.textMain,
      ),
      textAlign: TextAlign.right,
      readOnly: true,
      decoration: const InputDecoration(
        prefixText: '¥ ',
        hintText: '0.00',
        border: InputBorder.none,
      ),
    );
  }

  Widget _buildTypeSwitcher() {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      style: ButtonStyle(
        padding: MaterialStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        textStyle: MaterialStateProperty.all(
          const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      segments: const [
        ButtonSegment(value: true, label: Text(AppStrings.expense)),
        ButtonSegment(value: false, label: Text(AppStrings.income)),
      ],
      selected: {_isExpense},
      onSelectionChanged: (set) {
        setState(() {
          _isExpense = set.first;
          _lastIsExpense = _isExpense;
          if (_isExpense) {
            _selectedGoalId = null;
          }
        });
      },
    );
  }

  Widget _buildCategoryPicker(List<Category> categories) {
    // 如果存在二级分类（parentKey 不为空），优先展示二级；
    // 否则回退到旧版的一层分类，保持兼容旧数据。
    final secondLevel =
        categories.where((c) => c.parentKey != null).toList();
    final effective = secondLevel.isNotEmpty ? secondLevel : categories;
    return _buildCategoryQuickPicker(effective);
  }

  Widget _buildCategoryQuickPicker(List<Category> categories) {
    if (categories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            AppStrings.category,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            AppStrings.emptyCategoryForRecord,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.category,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: categories.map((cat) {
            final selected = cat.key == _selectedCategoryKey;
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() => _selectedCategoryKey = cat.key);
              },
              child: Container(
                width: _kCategoryItemWidth,
                height: _kCategoryItemHeight,
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: _kCategoryBorderRadius,
                  color: selected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.08)
                      : Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      cat.icon,
                      size: _kCategoryIconSize,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displayCategoryName(cat),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAdvancedSheetContent() {
    final statsLabel = _isExpense ? '计入支出统计' : '计入收入统计';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '更多设置',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text(
          '记账习惯、统计和循环记账',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _includeInStats,
          title: Text(statsLabel),
          onChanged: (v) => setState(() => _includeInStats = v),
        ),
        if (_showSavingGoalSection())
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildSavingGoalPicker(),
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _saveAsTemplate,
          title: const Text('保存为常用模板'),
          subtitle: const Text(
            '保存当前分类、账户和备注，方便下次快速填写',
            style: TextStyle(fontSize: 12),
          ),
          onChanged: (v) => setState(() => _saveAsTemplate = v ?? false),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _isRecurring,
          title: const Text('设为循环记账'),
          subtitle: const Text(
            '每周或每月提醒你再次记这笔账，不会自动生成记录',
            style: TextStyle(fontSize: 12),
          ),
          onChanged: (v) => setState(() => _isRecurring = v),
        ),
        if (_isRecurring)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Row(
              children: [
                const Text(
                  '循环周期',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                DropdownButton<RecurringPeriodType>(
                  value: _recurringPeriodType,
                  items: const [
                    DropdownMenuItem(
                      value: RecurringPeriodType.weekly,
                      child: Text('每周'),
                    ),
                    DropdownMenuItem(
                      value: RecurringPeriodType.monthly,
                      child: Text('每月'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _recurringPeriodType = v);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _displayCategoryName(Category category) {
    final original = category.name;
    final short = _kCategoryNameShortMap[original];
    return short ?? original;
  }

  /// 新版分类区域：上方一级分类，点击后下方展示对应的二级分类
  Widget _buildCategorySection(List<Category> categories) {
    // 是否存在二级分类（有 parentKey）
    final hasSecondLevel =
        categories.any((c) => c.parentKey != null);

    // 没有层级信息时，退回老的单层分类样式（兼容旧数据）
    if (!hasSecondLevel) {
      return _buildCategoryQuickPicker(categories);
    }

    // 一级分类：parentKey 为空
    final topCategories =
        categories.where((c) => c.parentKey == null).toList();

    // 二级分类：按 parentKey 分组
    final Map<String, List<Category>> childrenMap = {};
    for (final cat in categories) {
      final parent = cat.parentKey;
      if (parent == null) continue;
      childrenMap.putIfAbsent(parent, () => []).add(cat);
    }

    // 当前选中的分类（一般是二级）
    Category? selectedCategory;
    if (_selectedCategoryKey != null) {
      for (final c in categories) {
        if (c.key == _selectedCategoryKey) {
          selectedCategory = c;
          break;
        }
      }
    }

    // 当前激活的一级：优先用已选分类的 parent，否则用第一个一级
    String? activeTopKey = selectedCategory?.parentKey;
    activeTopKey ??= topCategories.isNotEmpty ? topCategories.first.key : null;

    final currentChildren = activeTopKey != null
        ? (childrenMap[activeTopKey] ?? const <Category>[])
        : const <Category>[];

    // 万一某个一级下面没有二级（极端兼容），退回单层样式
    if (currentChildren.isEmpty) {
      final secondLevel =
          categories.where((c) => c.parentKey != null).toList();
      if (secondLevel.isEmpty) {
        return _buildCategoryQuickPicker(categories);
      }
      return _buildCategoryQuickPicker(secondLevel);
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final List<Widget> children = [
      const Text(
        AppStrings.category,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
    ];

    const itemsPerRow = 4;
    final activeIndex =
        activeTopKey == null ? 0 : topCategories.indexWhere((t) => t.key == activeTopKey);
    final activeRow = activeIndex < 0 ? 0 : activeIndex ~/ itemsPerRow;
    final rows =
        (topCategories.length + itemsPerRow - 1) ~/ itemsPerRow;

    for (var row = 0; row < rows; row++) {
      final rowChildren = <Widget>[];
      final start = row * itemsPerRow;
      final end = (start + itemsPerRow).clamp(0, topCategories.length);
      for (var i = start; i < end; i++) {
        final top = topCategories[i];
        final selected = top.key == activeTopKey;
        rowChildren.add(
          SizedBox(
            width: _kCategoryItemWidth,
            height: _kCategoryItemHeight,
            child: InkWell(
              borderRadius: _kCategoryBorderRadius,
              onTap: () {
                setState(() {
                  final childrenList = childrenMap[top.key] ?? const [];
                  if (childrenList.isNotEmpty) {
                    _selectedCategoryKey = childrenList.first.key;
                  } else {
                    _selectedCategoryKey = top.key;
                  }
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: _kCategoryBorderRadius,
                  color: selected
                      ? cs.primary.withOpacity(0.12)
                      : cs.surface,
                  border: Border.all(
                    color: selected
                        ? cs.primary
                        : cs.outlineVariant.withOpacity(0.6),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      top.icon,
                      size: _kCategoryIconSize,
                      color: selected
                          ? cs.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displayCategoryName(top),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? cs.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      children.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: rowChildren,
        ),
      );

      // 紧贴在当前行下面展示该行激活的二级分类
      if (row == activeRow) {
        children.add(const SizedBox(height: 10));
        children.add(
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: currentChildren.map((cat) {
                final selected = cat.key == _selectedCategoryKey;
                return SizedBox(
                  width: _kCategoryItemWidth,
                  height: _kCategoryItemHeight,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _selectedCategoryKey = cat.key;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: _kCategoryBorderRadius,
                        color: selected
                            ? cs.primary.withOpacity(0.12)
                            : cs.surface,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            cat.icon,
                            size: _kCategoryIconSize,
                            color: selected
                                ? cs.primary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _displayCategoryName(cat),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
        children.add(const SizedBox(height: 4));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildAccountPicker() {
    final accountProvider = context.watch<AccountProvider>();
    final accounts = accountProvider.accounts;
    Account? selectedAccount;
    if (_selectedAccountId != null) {
      for (final a in accounts) {
        if (a.id == _selectedAccountId) {
          selectedAccount = a;
          break;
        }
      }
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '账户',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final selectedId = await showAccountSelectBottomSheet(
              context,
              accounts,
              selectedAccountId: _selectedAccountId,
            );
            if (!mounted || selectedId == null) return;
            setState(() {
              _selectedAccountId = selectedId;
              _selectedGoalId = null;
            });
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: colorScheme.surfaceVariant.withOpacity(0.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    selectedAccount != null
                        ? '${selectedAccount.name} · ${selectedAccount.currentBalance.toStringAsFixed(2)}'
                        : '选择账户',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: selectedAccount != null
                          ? AppColors.textMain
                          : Theme.of(context).hintColor,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              ],
            ),
          ),
        ),
        if (accounts.isEmpty)
          TextButton(
            onPressed: () async {
              await Navigator.push<AccountKind>(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddAccountTypePage(),
                ),
              );
              if (!mounted) return;
              setState(() => _selectedAccountId = null);
            },
            child: const Text('去添加账户'),
          ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.selectDate,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _pickDate,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Theme.of(context)
                  .colorScheme
                  .surfaceVariant
                  .withOpacity(0.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateUtilsX.ymd(_selectedDate),
                  style: const TextStyle(fontSize: 15),
                ),
                const Icon(Icons.calendar_today_outlined, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemarkField() {
    final cs = Theme.of(context).colorScheme;
    final amountText =
        _amountCtrl.text.isEmpty ? '0.00' : _amountCtrl.text;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: cs.surface,
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.6),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _remarkCtrl,
              minLines: 1,
              maxLines: 1,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: AppStrings.remarkOptional,
              ),
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '¥ $amountText',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberPad() {
    final bottom = MediaQuery.of(context).padding.bottom;
    final cs = Theme.of(context).colorScheme;
    final keyBackground = cs.surfaceVariant.withOpacity(0.25);

    Widget buildKey({
      required String label,
      VoidCallback? onTap,
      Color? background,
      Color? textColor,
      FontWeight fontWeight = FontWeight.w500,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            color: background ?? keyBackground,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                color: textColor ?? AppColors.textMain,
                fontWeight: fontWeight,
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(0, 4, 0, bottom > 0 ? 0 : 4),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.35),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                buildKey(label: '7', onTap: () => _onDigitTap('7')),
                buildKey(label: '8', onTap: () => _onDigitTap('8')),
                buildKey(label: '9', onTap: () => _onDigitTap('9')),
                buildKey(
                  label: '今天',
                  fontWeight: FontWeight.w600,
                  onTap: _onTodayTap,
                  textColor: AppColors.textSecondary,
                ),
              ],
            ),
            Row(
              children: [
                buildKey(label: '4', onTap: () => _onDigitTap('4')),
                buildKey(label: '5', onTap: () => _onDigitTap('5')),
                buildKey(label: '6', onTap: () => _onDigitTap('6')),
                buildKey(
                  label: '+',
                  onTap: () => _onOperatorTap('+'),
                  textColor: AppColors.textSecondary,
                ),
              ],
            ),
            Row(
              children: [
                buildKey(label: '1', onTap: () => _onDigitTap('1')),
                buildKey(label: '2', onTap: () => _onDigitTap('2')),
                buildKey(label: '3', onTap: () => _onDigitTap('3')),
                buildKey(
                  label: '-',
                  onTap: () => _onOperatorTap('-'),
                  textColor: AppColors.textSecondary,
                ),
              ],
            ),
            Row(
              children: [
                buildKey(label: '.', onTap: _onDotTap),
                buildKey(label: '0', onTap: () => _onDigitTap('0')),
                buildKey(
                  label: '⌫',
                  onTap: _onBackspace,
                  textColor: AppColors.textSecondary,
                ),
                Expanded(
                  child: InkWell(
                    onTap: _onPadSubmit,
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      color: Theme.of(context).colorScheme.primary,
                      child: const Text(
                        '完成',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onDigitTap(String digit) {
    setState(() {
      _amountExpression += digit;
      _amountCtrl.text = _amountExpression;
    });
  }

  void _onDotTap() {
    setState(() {
      _amountExpression += '.';
      _amountCtrl.text = _amountExpression;
    });
  }

  void _onOperatorTap(String op) {
    setState(() {
      if (_amountExpression.isEmpty) {
        if (op == '-') {
          _amountExpression = '-';
        }
      } else {
        final last = _amountExpression[_amountExpression.length - 1];
        if (last == '+' || last == '-') {
          _amountExpression =
              _amountExpression.substring(0, _amountExpression.length - 1) +
                  op;
        } else {
          _amountExpression += op;
        }
      }
      _amountCtrl.text = _amountExpression;
    });
  }

  void _onBackspace() {
    if (_amountExpression.isEmpty) return;
    setState(() {
      _amountExpression =
          _amountExpression.substring(0, _amountExpression.length - 1);
      _amountCtrl.text = _amountExpression;
    });
  }

  void _onTodayTap() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  double? _evaluateAmount() {
    var exp = _amountExpression.trim();
    if (exp.isEmpty) return null;
    final last = exp[exp.length - 1];
    if (last == '+' || last == '-') {
      exp = exp.substring(0, exp.length - 1);
    }
    if (exp.isEmpty) return null;

    final regex = RegExp(r'([+-])|([0-9]*\.?[0-9]+)');
    double total = 0;
    var op = '+';
    for (final match in regex.allMatches(exp)) {
      final token = match.group(0)!;
      if (token == '+' || token == '-') {
        op = token;
      } else {
        final value = double.tryParse(token);
        if (value == null) return null;
        if (op == '+') {
          total += value;
        } else {
          total -= value;
        }
      }
    }
    return total;
  }

  Future<void> _onPadSubmit() async {
    final amount = _evaluateAmount();
    if (amount == null || amount <= 0) {
      _showMessage(AppStrings.amountError);
      return;
    }
    _amountCtrl.text = amount.toStringAsFixed(2);
    // 清空表达式，后续若再次编辑会从结果继续
    _amountExpression = _amountCtrl.text;
    await _handleSubmit();
  }

  Widget _buildSavingGoalPicker() {
    final goalProvider = context.watch<SavingGoalProvider>();
    final accountId = _selectedAccountId;
    final goals =
        goalProvider.goals.where((g) => g.accountId == accountId).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '这笔钱关联到哪个存钱目标？',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedGoalId,
          items: goals
              .map(
                (g) => DropdownMenuItem(
                  value: g.id,
                  child: Text(
                    '${g.name} · 目标 ¥${g.targetAmount.toStringAsFixed(0)}',
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedGoalId = v),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '选择目标（可选）',
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedSection() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(
        '更多设置',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: const Text(
        '记账习惯、统计和循环记账',
        style: TextStyle(fontSize: 12),
      ),
      childrenPadding: const EdgeInsets.only(top: 4),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _includeInStats,
          title: const Text('计入统计'),
          onChanged: (v) => setState(() => _includeInStats = v),
        ),
        if (_showSavingGoalSection())
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildSavingGoalPicker(),
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _saveAsTemplate,
          title: const Text('保存为常用模板'),
          subtitle: const Text(
            '保存当前分类、账户和备注，方便下次快速填写。',
            style: TextStyle(fontSize: 12),
          ),
          onChanged: (v) => setState(() => _saveAsTemplate = v ?? false),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _isRecurring,
          title: const Text('设为循环记账'),
          subtitle: const Text(
            '每周或每月提醒你再次记这笔账，不会自动生成记录。',
            style: TextStyle(fontSize: 12),
          ),
          onChanged: (v) => setState(() => _isRecurring = v),
        ),
        if (_isRecurring)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Row(
              children: [
                const Text(
                  '循环周期',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                DropdownButton<RecurringPeriodType>(
                  value: _recurringPeriodType,
                  items: const [
                    DropdownMenuItem(
                      value: RecurringPeriodType.weekly,
                      child: Text('每周'),
                    ),
                    DropdownMenuItem(
                      value: RecurringPeriodType.monthly,
                      child: Text('每月'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _recurringPeriodType = v);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTemplateChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '常用模板',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _templates
              .map(
                (t) => ChoiceChip(
                  label: Text(
                    t.remark.isNotEmpty ? t.remark : t.categoryKey,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: false,
                  onSelected: (_) => _applyTemplate(t),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildRecurringBanner() {
    final plan = _duePlans.first;
    return InkWell(
      onTap: () => _applyRecurringPlan(plan),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.refresh_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '有循环记账待记录，点击一键带出草稿。',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }

  void _ensureCategorySelection(List<Category> categories) {
    if (categories.isEmpty) {
      _selectedCategoryKey = null;
      return;
    }
    final exists = categories.any((c) => c.key == _selectedCategoryKey);
    if (!exists) {
      _selectedCategoryKey = categories.first.key;
    }
  }

  void _ensureAccountSelection() {
    if (_selectedAccountId != null) return;
    final accounts = context.read<AccountProvider>().accounts;
    if (accounts.isEmpty) return;
    final exists = accounts.any((a) => a.id == _lastAccountId);
    if (_lastAccountId != null && exists) {
      _selectedAccountId = _lastAccountId;
      return;
    }
    _selectedAccountId = accounts.first.id;
  }

  Future<void> _loadTemplatesAndPlans() async {
    final templates = await _templateRepository.loadTemplates();
    final plans = await _recurringRepository.loadPlans();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final due = plans
        .where((p) => !p.nextDate.isAfter(todayDate))
        .toList(growable: false);
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _duePlans = due;
    });
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    // 扩大可选年份范围：向前 20 年，向后 5 年
    final startYear = today.year - 20;
    final endYear = today.year + 5;

    // 初始化临时值
    int tempYear = _selectedDate.year.clamp(startYear, endYear);
    int tempMonth = _selectedDate.month;
    int tempDay = _selectedDate.day;

    final years =
        List<int>.generate(endYear - startYear + 1, (i) => startYear + i);
    final months = List<int>.generate(12, (i) => i + 1);
    final days = List<int>.generate(31, (i) => i + 1);

    int yearIndex = years.indexOf(tempYear);
    int monthIndex = tempMonth - 1;
    int dayIndex = tempDay - 1;

    final yearController =
        FixedExtentScrollController(initialItem: yearIndex);
    final monthController =
        FixedExtentScrollController(initialItem: monthIndex);
    final dayController =
        FixedExtentScrollController(initialItem: dayIndex);

    final result = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SizedBox(
          height: 260,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(AppStrings.cancel),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          AppStrings.selectDate,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // 修正天数，避免 2 月 30 日这类非法日期
                        final lastDayOfMonth =
                            DateTime(tempYear, tempMonth + 1, 0).day;
                        if (tempDay > lastDayOfMonth) {
                          tempDay = lastDayOfMonth;
                        }
                        final picked =
                            DateTime(tempYear, tempMonth, tempDay);
                        Navigator.pop(context, picked);
                      },
                      child: const Text(AppStrings.confirm),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: yearController,
                        itemExtent: 32,
                        onSelectedItemChanged: (index) {
                          tempYear = years[index];
                        },
                        children: years
                            .map(
                              (y) => Center(
                                child: Text('$y年'),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: monthController,
                        itemExtent: 32,
                        onSelectedItemChanged: (index) {
                          tempMonth = months[index];
                        },
                        children: months
                            .map(
                              (m) => Center(
                                child: Text(m.toString().padLeft(2, '0')),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: dayController,
                        itemExtent: 32,
                        onSelectedItemChanged: (index) {
                          tempDay = days[index];
                        },
                        children: days
                            .map(
                              (d) => Center(
                                child: Text(d.toString().padLeft(2, '0')),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      setState(() => _selectedDate = result);
    }
  }

  Future<void> _handleSubmit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _showMessage(AppStrings.amountError);
      return;
    }
    if (_selectedCategoryKey == null) {
      _showMessage(AppStrings.selectCategoryError);
      return;
    }
    if (_selectedAccountId == null) {
      _showMessage('请选择账户');
      return;
    }

    final direction =
        _isExpense ? TransactionDirection.out : TransactionDirection.income;
    final bookId = context.read<BookProvider>().activeBookId;
    final accountProvider = context.read<AccountProvider>();
    final savingGoalProvider = context.read<SavingGoalProvider>();
    final targetId = _showSavingGoalSection() ? _selectedGoalId : null;

    final recordProvider = context.read<RecordProvider>();

    if (widget.initialRecord != null) {
      // 编辑已有记录
      final updated = widget.initialRecord!.copyWith(
        amount: amount.abs(),
        remark: _remarkCtrl.text.trim(),
        date: _selectedDate,
        categoryKey: _selectedCategoryKey!,
        accountId: _selectedAccountId!,
        direction: direction,
        includeInStats: _includeInStats,
        targetId: targetId,
      );

      await recordProvider.updateRecord(
        updated,
        accountProvider: accountProvider,
        savingGoalProvider: savingGoalProvider,
      );
    } else {
      // 新增记录
      final record = await recordProvider.addRecord(
        amount: amount,
        remark: _remarkCtrl.text.trim(),
        date: _selectedDate,
        categoryKey: _selectedCategoryKey!,
        bookId: bookId,
        accountId: _selectedAccountId!,
        direction: direction,
        includeInStats: _includeInStats,
        targetId: targetId,
        accountProvider: accountProvider,
        savingGoalProvider: savingGoalProvider,
      );

      _lastAccountId = _selectedAccountId;
      _lastIncludeInStats = _includeInStats;
      _lastSavingGoalId = _selectedGoalId;

      await _maybeSaveTemplate(record);
      await _maybeSaveOrUpdateRecurring(record);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  bool _showSavingGoalSection() {
    if (_selectedAccountId == null) return false;
    if (_isExpense) return false;
    final account =
        context.read<AccountProvider>().byId(_selectedAccountId!);
    return account?.kind == AccountKind.asset;
  }

  Future<void> _maybeSaveTemplate(Record record) async {
    if (!_saveAsTemplate) return;
    final template = RecordTemplate(
      id: record.id,
      categoryKey: record.categoryKey,
      accountId: record.accountId,
      direction: record.direction,
      includeInStats: record.includeInStats,
      remark: record.remark,
      createdAt: DateTime.now(),
      lastUsedAt: DateTime.now(),
    );
    await _templateRepository.upsertTemplate(template);
  }

  Future<void> _maybeSaveOrUpdateRecurring(Record record) async {
    if (!_isRecurring) return;

    final nextDate = _recurringPeriodType == RecurringPeriodType.weekly
        ? record.date.add(const Duration(days: 7))
        : DateTime(record.date.year, record.date.month + 1, record.date.day);

    final planId = _activeRecurringPlanId ?? record.id;
    final plan = RecurringRecordPlan(
      id: planId,
      bookId: record.bookId,
      categoryKey: record.categoryKey,
      accountId: record.accountId,
      direction: record.direction,
      includeInStats: record.includeInStats,
      amount: record.amount,
      remark: record.remark,
      periodType: _recurringPeriodType,
      nextDate: nextDate,
    );
    await _recurringRepository.upsert(plan);
  }

  Future<void> _applyTemplate(RecordTemplate template) async {
    setState(() {
      _isExpense = template.direction == TransactionDirection.out;
      _lastIsExpense = _isExpense;
      _selectedCategoryKey = template.categoryKey;
      _selectedAccountId = template.accountId;
      _includeInStats = template.includeInStats;
      if (template.remark.isNotEmpty) {
        _remarkCtrl.text = template.remark;
      }
    });
    await _templateRepository.markUsed(template.id);
  }

  void _applyRecurringPlan(RecurringRecordPlan plan) {
    setState(() {
      _activeRecurringPlanId = plan.id;
      _isRecurring = true;
      _recurringPeriodType = plan.periodType;
      _isExpense = plan.direction == TransactionDirection.out;
      _lastIsExpense = _isExpense;
      _selectedCategoryKey = plan.categoryKey;
      _selectedAccountId = plan.accountId;
      _includeInStats = plan.includeInStats;
      _amountCtrl.text = plan.amount.toStringAsFixed(2);
      _remarkCtrl.text = plan.remark;
      _selectedDate = plan.nextDate;
    });
  }
}
