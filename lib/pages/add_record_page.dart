import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/record.dart';
import '../models/record_template.dart';
import '../providers/book_provider.dart';
import '../providers/category_provider.dart';
import '../providers/record_provider.dart';
import '../providers/account_provider.dart';
import '../utils/date_utils.dart';
import '../utils/category_name_helper.dart';
import '../utils/validators.dart';
import '../utils/error_handler.dart';
import '../widgets/account_select_bottom_sheet.dart';
import '../repository/repository_factory.dart';
import 'add_account_type_page.dart';
import 'voice_record_page.dart';
import '../widgets/app_top_bar.dart';

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

  static String? _lastAccountId;
  static bool _lastIncludeInStats = true;

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();

  late bool _isExpense;
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryKey;
  String? _selectedAccountId;
  bool _includeInStats = true;
  String _amountExpression = '';

  // SharedPreferences / 数据库 两种实现共用相同方法签名
  final dynamic _templateRepository =
      RepositoryFactory.createRecordTemplateRepository();

  List<RecordTemplate> _templates = const [];

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
      _amountCtrl.text = initial.amount.toStringAsFixed(2);
      _amountExpression = _amountCtrl.text;
      _remarkCtrl.text = initial.remark;
    } else {
      // 新增模式：沿用上一次的记账偏好
      _isExpense = widget.isExpense;
      _includeInStats = _lastIncludeInStats;
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
      backgroundColor: cs.surface,
      appBar: AppTopBar(
        title: widget.initialRecord == null ? AppStrings.addRecord : AppStrings.edit,
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
                            color: cs.shadow.withOpacity(0.06),
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
                icon: Icons.mic_outlined,
                label: '语音',
                onTap: _onVoiceInputTap,
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
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.75)),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withOpacity(0.87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onVoiceInputTap() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VoiceRecordPage()),
    );
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _onQuickAccountTap() async {
    final accounts = context.read<AccountProvider>().accounts;
    if (accounts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已默认使用“默认钱包”，可在资产页中管理账户')),
      );
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
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: _amountCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontSize: 30,
        color: cs.onSurface,
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
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        textStyle: WidgetStateProperty.all(
          Theme.of(context).textTheme.bodyLarge,
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
    final cs = Theme.of(context).colorScheme;
    if (categories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.category,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.emptyCategoryForRecord,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.75),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.category,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
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
                      : Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withOpacity(0.5),
                  ),
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
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.75),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displayCategoryName(cat),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.85),
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
    final cs = Theme.of(context).colorScheme;
    final statsLabel = _isExpense ? '计入支出统计' : '计入收入统计';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '更多设置',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '记账习惯和统计',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withOpacity(0.87),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _includeInStats,
          title: Text(
            statsLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                ),
          ),
          onChanged: (v) => setState(() => _includeInStats = v),
        ),
      ],
    );
  }

  String _displayCategoryName(Category category) {
    return CategoryNameHelper.getDisplayName(category.name);
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
      Text(
        AppStrings.category,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
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
                          : cs.onSurface.withOpacity(0.75),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displayCategoryName(top),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? cs.primary
                                : cs.onSurface.withOpacity(0.75),
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
              color: cs.surface,
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
                                : cs.onSurface.withOpacity(0.75),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _displayCategoryName(cat),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: selected
                                      ? cs.primary
                                      : cs.onSurface.withOpacity(0.87),
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
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '账户',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
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
            });
          },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: cs.surface,
            border: Border.all(
              color: cs.outlineVariant.withOpacity(0.5),
            ),
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selectedAccount != null
                              ? cs.onSurface
                              : cs.onSurface.withOpacity(0.55),
                        ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: cs.onSurface.withOpacity(0.7),
                ),
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
        Text(
          AppStrings.selectDate,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
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
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateUtilsX.ymd(_selectedDate),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
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
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: AppStrings.remarkOptional,
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withOpacity(0.6),
                    ),
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '¥ $amountText',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberPad() {
    final bottom = MediaQuery.of(context).padding.bottom;
    final cs = Theme.of(context).colorScheme;
    final keyBackground = cs.surfaceContainerHighest.withOpacity(0.25);

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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    color: textColor ?? cs.onSurface,
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
                  textColor: cs.onSurface.withOpacity(0.75),
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
                  textColor: cs.onSurface.withOpacity(0.75),
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
                  textColor: cs.onSurface.withOpacity(0.75),
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
                  textColor: cs.onSurface.withOpacity(0.75),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _onPadSubmit,
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      color: Theme.of(context).colorScheme.primary,
                      child: Text(
                        '完成',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onPrimary,
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
      ErrorHandler.showError(context, AppStrings.amountError);
      return;
    }
    _amountCtrl.text = amount.toStringAsFixed(2);
    // 清空表达式，后续若再次编辑会从结果继续
    _amountExpression = _amountCtrl.text;
    await _handleSubmit();
  }

  Widget _buildAdvancedSection() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        '更多设置',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: Text(
        '记账习惯和统计',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      childrenPadding: const EdgeInsets.only(top: 4),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _includeInStats,
          title: const Text('计入统计'),
          onChanged: (v) => setState(() => _includeInStats = v),
        ),
      ],
    );
  }

  Widget _buildTemplateChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '常用模板',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
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
    try {
      final templates = await _templateRepository.loadTemplates();
      if (!mounted) return;
      setState(() {
        _templates = templates;
      });
    } catch (e) {
      // 模板加载失败不影响主要功能，静默处理
      if (mounted) {
        debugPrint('[AddRecordPage] Failed to load templates: $e');
      }
    }
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
                    Expanded(
                      child: Center(
                        child: Text(
                          AppStrings.selectDate,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                            .asMap()
                            .entries
                            .map(
                              (entry) => GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  yearController.animateToItem(
                                    entry.key,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                  );
                                  tempYear = entry.value;
                                },
                                child: Center(
                                  child: Text('${entry.value}年'),
                                ),
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
                            .asMap()
                            .entries
                            .map(
                              (entry) => GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  monthController.animateToItem(
                                    entry.key,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                  );
                                  tempMonth = entry.value;
                                },
                                child: Center(
                                  child: Text(entry.value.toString().padLeft(2, '0')),
                                ),
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
                            .asMap()
                            .entries
                            .map(
                              (entry) => GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  dayController.animateToItem(
                                    entry.key,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                  );
                                  tempDay = entry.value;
                                },
                                child: Center(
                                  child: Text(entry.value.toString().padLeft(2, '0')),
                                ),
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
    // 数据验证
    final amountStr = _amountCtrl.text.trim();
    final amountError = Validators.validateAmountString(amountStr);
    if (amountError != null) {
      ErrorHandler.showError(context, amountError);
      return;
    }

    final amount = double.parse(amountStr.startsWith('.') ? '0$amountStr' : amountStr);

    final categoryError = Validators.validateCategory(_selectedCategoryKey);
    if (categoryError != null) {
      ErrorHandler.showError(context, categoryError);
      return;
    }

    // 记一笔不强制用户先创建/选择账户：为空时由 RecordProvider 自动兜底到“默认钱包”

    final remark = _remarkCtrl.text.trim();
    final remarkError = Validators.validateRemark(remark);
    if (remarkError != null) {
      ErrorHandler.showError(context, remarkError);
      return;
    }

    final dateError = Validators.validateDate(_selectedDate);
    if (dateError != null) {
      ErrorHandler.showError(context, dateError);
      return;
    }

    final direction =
        _isExpense ? TransactionDirection.out : TransactionDirection.income;
    final bookId = context.read<BookProvider>().activeBookId;
    final accountProvider = context.read<AccountProvider>();
    final recordProvider = context.read<RecordProvider>();

    try {
      if (widget.initialRecord != null) {
        // 编辑已有记录
        final updated = widget.initialRecord!.copyWith(
          amount: amount.abs(),
          remark: remark,
          date: _selectedDate,
          categoryKey: _selectedCategoryKey!,
          accountId: (_selectedAccountId != null && _selectedAccountId!.isNotEmpty)
              ? _selectedAccountId!
              : widget.initialRecord!.accountId,
          direction: direction,
          includeInStats: _includeInStats,
        );

        await recordProvider.updateRecord(
          updated,
          accountProvider: accountProvider,
        );

        if (!mounted) return;
        ErrorHandler.showSuccess(context, '记录已更新');
      } else {
        // 新增记录
        await recordProvider.addRecord(
          amount: amount,
          remark: remark,
          date: _selectedDate,
          categoryKey: _selectedCategoryKey!,
          bookId: bookId,
          accountId: _selectedAccountId ?? '',
          direction: direction,
          includeInStats: _includeInStats,
          accountProvider: accountProvider,
        );

        if (_selectedAccountId != null && _selectedAccountId!.isNotEmpty) {
          _lastAccountId = _selectedAccountId;
        }
        _lastIncludeInStats = _includeInStats;

        if (!mounted) return;
        ErrorHandler.showSuccess(context, '记录已保存');
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleAsyncError(
        context,
        e,
        onRetry: () => _handleSubmit(),
      );
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }



  Future<void> _applyTemplate(RecordTemplate template) async {
    setState(() {
      _isExpense = template.direction == TransactionDirection.out;
      _selectedCategoryKey = template.categoryKey;
      _selectedAccountId = template.accountId;
      _includeInStats = template.includeInStats;
      if (template.remark.isNotEmpty) {
        _remarkCtrl.text = template.remark;
      }
    });
    await _templateRepository.markUsed(template.id);
  }

}
