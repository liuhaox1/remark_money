import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/bank_brands.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import '../providers/book_provider.dart';
import '../utils/validators.dart';
import '../utils/error_handler.dart';
import '../widgets/app_top_bar.dart';

class AccountFormPage extends StatefulWidget {
  const AccountFormPage({
    super.key,
    required this.kind,
    required this.subtype,
    this.account,
    this.initialBrandKey,
    this.presetName,
    this.customTitle,
    this.showAdvancedSettings = true,
  });

  final AccountKind kind;
  final AccountSubtype subtype;
  final Account? account;
  final String? initialBrandKey;
  final String? presetName;
  final String? customTitle;
  final bool showAdvancedSettings;

  @override
  State<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends State<AccountFormPage> {
  static const double _kFormLabelWidth = 104;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _counterpartyCtrl;
  bool _includeInOverview = true;
  DateTime? _dueDate;
  String? _brandKey;
  String? _customTitle;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    // 如果是"其他银行"或"其他信用卡"，名称输入框应该为空，让用户自己输入
    final isOtherBank = (widget.initialBrandKey == 'other_bank' || 
                        widget.initialBrandKey == 'other_credit');
    // 如果是"其他虚拟账户"，名称输入框应该为空，让用户自己输入
    // 支付宝和微信使用预设名称，不需要用户输入
    final isVirtual = widget.subtype == AccountSubtype.virtual;
    final isOtherVirtual = isVirtual && widget.presetName == '虚拟账户';
    // 如果是"其他投资账户"，名称输入框应该为空，让用户自己输入
    // 股票和基金使用预设名称，不需要用户输入
    final isInvest = widget.subtype == AccountSubtype.invest;
    final isOtherInvest = isInvest && widget.presetName == '投资账户';
    // 负债和自定义资产名称输入框应该为空，让用户自己输入
    final isLoan = widget.subtype == AccountSubtype.loan;
    final isCustomAsset = widget.subtype == AccountSubtype.customAsset;
    final nameText = account?.name ?? 
        (isOtherBank || isOtherVirtual || isOtherInvest || isLoan || isCustomAsset ? '' : (widget.presetName ?? _defaultName()));
    _nameCtrl = TextEditingController(text: nameText);
    // 编辑时显示当前余额，新建时显示0
    _amountCtrl = TextEditingController(
      text: account != null ? account.currentBalance.toStringAsFixed(2) : '',
    );
    _noteCtrl = TextEditingController(text: account?.note ?? '');
    _counterpartyCtrl = TextEditingController(text: account?.counterparty ?? '');
    _includeInOverview = account?.includeInOverview ?? true;
    _dueDate = account?.dueDate;
    _brandKey = account?.brandKey ?? widget.initialBrandKey;
    _customTitle = widget.customTitle;

    if (_brandKey == null && widget.subtype == AccountSubtype.virtual) {
      final preset = widget.presetName ?? account?.name;
      if (preset == '支付宝') _brandKey = 'alipay';
      if (preset == '微信') _brandKey = 'wechat';
    }

    // 如果是新建账户，在页面构建后自动聚焦到金额输入框
    // 金额/卡号输入使用自定义数字键盘（与“记一笔”一致），不依赖系统软键盘
  }

  Future<void> _openNumberPad({
    required TextEditingController controller,
    bool allowDecimal = true,
    int? maxLength,
    bool formatFixed2 = false,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();

    var expression = controller.text.trim();

    void setExpression(void Function(void Function()) setState, String next) {
      setState(() {
        if (maxLength != null && next.length > maxLength) return;
        expression = next;
      });
      controller.value = controller.value.copyWith(
        text: expression,
        selection: TextSelection.collapsed(offset: expression.length),
        composing: TextRange.empty,
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).padding.bottom;
        final cs = Theme.of(ctx).colorScheme;
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
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        color: textColor ?? cs.onSurface,
                        fontWeight: fontWeight,
                      ),
                ),
              ),
            ),
          );
        }

        return StatefulBuilder(
          builder: (ctx, setState) {
            void onDigit(String d) {
              setExpression(setState, '$expression$d');
            }

            void onDot() {
              if (!allowDecimal) return;
              if (expression.contains('.')) return;
              if (expression.isEmpty) {
                setExpression(setState, '0.');
              } else {
                setExpression(setState, '$expression.');
              }
            }

            void onBackspace() {
              if (expression.isEmpty) return;
              setExpression(
                setState,
                expression.substring(0, expression.length - 1),
              );
            }

            void onClear() {
              setExpression(setState, '');
            }

            return SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(0, 4, 0, bottom > 0 ? 0 : 4),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(ctx).dividerColor.withOpacity(0.35),
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          expression.isEmpty ? '0' : expression,
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        buildKey(label: '7', onTap: () => onDigit('7')),
                        buildKey(label: '8', onTap: () => onDigit('8')),
                        buildKey(label: '9', onTap: () => onDigit('9')),
                        buildKey(
                          label: '清空',
                          onTap: onClear,
                          textColor: cs.onSurface.withOpacity(0.75),
                          fontWeight: FontWeight.w600,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        buildKey(label: '4', onTap: () => onDigit('4')),
                        buildKey(label: '5', onTap: () => onDigit('5')),
                        buildKey(label: '6', onTap: () => onDigit('6')),
                        buildKey(
                          label: '⌫',
                          onTap: onBackspace,
                          textColor: cs.onSurface.withOpacity(0.75),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        buildKey(label: '1', onTap: () => onDigit('1')),
                        buildKey(label: '2', onTap: () => onDigit('2')),
                        buildKey(label: '3', onTap: () => onDigit('3')),
                        buildKey(
                          label: allowDecimal ? '.' : '',
                          onTap: allowDecimal ? onDot : null,
                          textColor: cs.onSurface.withOpacity(0.75),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () => onDigit('0'),
                            child: Container(
                              height: 56,
                              alignment: Alignment.center,
                              color: keyBackground,
                              child: Text(
                                '0',
                                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                      fontSize: 18,
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!formatFixed2) return;
    final raw = controller.text.trim();
    if (raw.isEmpty) return;
    final normalized = raw.startsWith('.') ? '0$raw' : raw;
    final value = double.tryParse(normalized);
    if (value == null) return;
    final text = value.toStringAsFixed(2);
    controller.value = controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _counterpartyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.account != null;
    final kind = widget.account?.kind ?? widget.kind;
    final subtype = widget.account != null
        ? AccountSubtype.fromCode(widget.account!.subtype)
        : widget.subtype;
    final isBankCard = subtype == AccountSubtype.savingCard ||
        subtype == AccountSubtype.creditCard;
    final isVirtual = subtype == AccountSubtype.virtual;
    final isCash = subtype == AccountSubtype.cash;
    final isSimpleAsset =
        kind == AccountKind.asset && !isBankCard && !isVirtual && !isCash && subtype != AccountSubtype.customAsset;
    final isLoan = subtype == AccountSubtype.loan;
    final isCustomAsset = subtype == AccountSubtype.customAsset;

    // 动态计算标题：如果是储蓄卡/信用卡，优先显示银行名称
    // 如果是虚拟账户（支付宝、微信），显示对应的名称
    String appBarTitle;
    if (isCash) {
      appBarTitle = '现金';
    } else if (isBankCard) {
      // 根据账户类型选择查找函数
      final brand = subtype == AccountSubtype.creditCard
          ? findCreditCardBrand(_brandKey ?? widget.initialBrandKey)
          : findBankBrand(_brandKey ?? widget.initialBrandKey);
      if (brand != null && brand.key != 'custom' && brand.key != 'other_credit' && brand.key != 'other_bank') {
        appBarTitle = brand.displayName;
      } else if (brand != null && brand.key == 'other_credit') {
        appBarTitle = '其他信用卡';
      } else if (brand != null && brand.key == 'other_bank') {
        appBarTitle = '其他银行';
      } else {
        appBarTitle = _customTitle ?? (isEditing ? '编辑账户' : '添加账户');
      }
    } else if (isVirtual) {
      // 虚拟账户：支付宝和微信显示对应名称，"其他虚拟账户"显示"其他虚拟账户"
      if (widget.presetName == '支付宝' || widget.presetName == '微信') {
        appBarTitle = widget.presetName!;
      } else if (widget.presetName == '虚拟账户') {
        appBarTitle = '其他虚拟账户';
      } else {
        appBarTitle = _customTitle ?? (isEditing ? '编辑账户' : '添加账户');
      }
    } else if (subtype == AccountSubtype.invest) {
      // 投资账户：股票、基金显示对应名称，"其他投资账户"显示"其他投资账户"
      if (widget.presetName == '股票' || widget.presetName == '基金') {
        appBarTitle = widget.presetName!;
      } else if (widget.presetName == '投资账户') {
        appBarTitle = _customTitle ?? '其他投资账户';
      } else {
        appBarTitle = _customTitle ?? (isEditing ? '编辑账户' : '添加账户');
      }
    } else if (subtype == AccountSubtype.loan) {
      appBarTitle = '负债';
    } else if (subtype == AccountSubtype.customAsset) {
      appBarTitle = '自定义资产';
    } else {
      appBarTitle = _customTitle ?? (isEditing ? '编辑账户' : '添加账户');
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppTopBar(title: appBarTitle),
      body: isBankCard
          ? _buildBankCardForm(context, kind, subtype, isEditing)
          : isVirtual
              ? _buildVirtualForm(context, kind, subtype, isEditing)
              : isCash
                  ? _buildCashForm(context, kind, subtype, isEditing)
              : isSimpleAsset
                  ? _buildSimpleAssetForm(context, kind, subtype, isEditing)
              : isLoan || isCustomAsset
                  ? _buildSimpleForm(context, kind, subtype, isEditing)
                  : _buildDefaultForm(context, kind, subtype, isEditing),
    );
  }

  Widget _buildTypeHeader(AccountKind kind, AccountSubtype subtype) {
    final kindLabel = () {
      switch (kind) {
        case AccountKind.asset:
          return '资产账户';
        case AccountKind.liability:
          return '负债账户';
        case AccountKind.lend:
          return '借出/应收账户';
      }
    }();
    // 虚拟账户和投资账户都不显示 subtype 标签
    final hideSubtypeLabel = subtype == AccountSubtype.virtual || 
                            subtype == AccountSubtype.invest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kindLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
        ),
        if (!hideSubtypeLabel) ...[
          const SizedBox(height: 4),
          Text(
            _subtypeLabel(subtype),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ],
    );
  }

  bool _showCounterparty(AccountKind kind, AccountSubtype subtype) {
    if (kind == AccountKind.liability) return true;
    return subtype == AccountSubtype.receivable;
  }

  Widget _buildDefaultForm(
    BuildContext context,
    AccountKind kind,
    AccountSubtype subtype,
    bool isEditing,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTypeHeader(kind, subtype),
          const SizedBox(height: 12),
          Container(
            decoration: _iosFormSectionDecoration(context),
            child: Column(
              children: [
                _buildBankInputRow(
                  context,
                  label: '名称',
                  child: _buildPlainTextField(
                    controller: _nameCtrl,
                    hintText: '请输入名称',
                    textAlign: TextAlign.right,
                  ),
                ),
                const Divider(height: 1),
                _buildBankInputRow(
                  context,
                  label: _amountLabel(kind),
                  onTap: !isEditing
                      ? () => _openNumberPad(
                            controller: _amountCtrl,
                            allowDecimal: true,
                            formatFixed2: true,
                          )
                      : null,
                  child: _buildPlainTextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    autofocus: !isEditing,
                    enabled: !isEditing,
                    hintText: '0.00',
                    helperText: isEditing
                        ? '编辑账户时不能修改余额，请在账户详情页使用“调整余额”'
                        : null,
                    readOnly: true,
                    onTap: !isEditing
                        ? () => _openNumberPad(
                              controller: _amountCtrl,
                              allowDecimal: true,
                              formatFixed2: true,
                            )
                        : null,
                  ),
                ),
                if (_showCounterparty(kind, subtype)) ...[
                  const Divider(height: 1),
                  _buildBankInputRow(
                    context,
                    label: '对方',
                    child: _buildPlainTextField(
                      controller: _counterpartyCtrl,
                      hintText: '选填',
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const Divider(height: 1),
                  _buildTapValueRow(
                    context,
                    label: '到期日',
                    value: _dueDate == null ? '未设置' : _formatDate(_dueDate!),
                    placeholderOpacity: _dueDate == null ? 0.55 : 1.0,
                    onTap: _pickDate,
                  ),
                ],
                const Divider(height: 1),
                _buildBankInputRow(
                  context,
                  label: '备注',
                  child: _buildPlainTextField(
                    controller: _noteCtrl,
                    hintText: '选填',
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          if (_shouldShowBrandSelector(subtype)) ...[
            const SizedBox(height: 12),
            _buildBrandSelector(context),
          ],
          const SizedBox(height: 12),
          if (widget.showAdvancedSettings)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                '高级设置',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              children: [
                SwitchListTile(
                  title: const Text('计入资产汇总'),
                  value: _includeInOverview,
                  onChanged: (v) => setState(() => _includeInOverview = v),
                ),
              ],
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _handleSubmit(kind, subtype, isEditing),
              child: Text(isEditing ? '保存' : '添加账户'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankCardForm(
    BuildContext context,
    AccountKind kind,
    AccountSubtype subtype,
    bool isEditing,
  ) {
    // 根据账户类型选择查找函数
    final brand = subtype == AccountSubtype.creditCard
        ? findCreditCardBrand(_brandKey)
        : findBankBrand(_brandKey);
    final title = brand != null && 
            brand.key != 'custom' && 
            brand.key != 'other_credit' && 
            brand.key != 'other_bank'
        ? brand.displayName
        : null;
    if (title != null) {
      _customTitle ??= title;
    }
    final showBankSelectorRow =
        widget.account != null || widget.initialBrandKey == null;
    // 检查是否是"其他银行"或"其他信用卡"
    final isOtherBank = (_brandKey ?? widget.initialBrandKey) == 'other_bank' ||
        (_brandKey ?? widget.initialBrandKey) == 'other_credit';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: _iosFormSectionDecoration(context),
            child: Column(
              children: [
                if (showBankSelectorRow) ...[
                  _buildBankInfoRow(context),
                  const Divider(height: 1),
                ],
                // 如果是"其他银行"或"其他信用卡"，在最上面显示名称输入框
                if (isOtherBank) ...[
                  _buildBankInputRow(
                    context,
                    label: '名称',
                    child: _buildPlainTextField(
                      controller: _nameCtrl,
                      textAlign: TextAlign.right,
                      hintText: '请输入银行名称',
                    ),
                  ),
                  const Divider(height: 1),
                ],
                _buildBankInputRow(
                  context,
                  label: '卡号（后四位）',
                  onTap: () => _openNumberPad(
                    controller: _counterpartyCtrl,
                    allowDecimal: false,
                    maxLength: 4,
                  ),
                  child: _buildPlainTextField(
                    controller: _counterpartyCtrl,
                    hintText: '选填',
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    readOnly: true,
                    onTap: () => _openNumberPad(
                      controller: _counterpartyCtrl,
                      allowDecimal: false,
                      maxLength: 4,
                    ),
                  ),
                ),
                const Divider(height: 1),
                _buildBankInputRow(
                  context,
                  label: '备注',
                  child: _buildPlainTextField(
                    controller: _noteCtrl,
                    hintText: '选填',
                    textAlign: TextAlign.right,
                  ),
                ),
                const Divider(height: 1),
                _buildBankInputRow(
                  context,
                  label: subtype == AccountSubtype.creditCard ? '金额' : '余额',
                  onTap: !isEditing
                      ? () => _openNumberPad(
                            controller: _amountCtrl,
                            allowDecimal: true,
                            formatFixed2: true,
                          )
                      : null,
                  child: _buildPlainTextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    autofocus: !isEditing,
                    enabled: !isEditing,
                    helperText:
                        isEditing ? '请前往账户详情页>调整余额进行修改' : null,
                    readOnly: true,
                    onTap: !isEditing
                        ? () => _openNumberPad(
                              controller: _amountCtrl,
                              allowDecimal: true,
                              formatFixed2: true,
                            )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _handleSubmit(kind, subtype, isEditing),
              child: Text(isEditing ? '保存' : '添加账户'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVirtualForm(
    BuildContext context,
    AccountKind kind,
    AccountSubtype subtype,
    bool isEditing,
  ) {
    // 支付宝和微信不需要名称输入框，只有"其他虚拟账户"才需要
    final isOtherVirtual = widget.presetName == '虚拟账户';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: _iosFormSectionDecoration(context),
            child: Column(
              children: [
                // 只有"其他虚拟账户"才显示名称输入框
                if (isOtherVirtual) ...[
                  _buildBankInputRow(
                    context,
                    label: '名称',
                    child: _buildPlainTextField(
                      controller: _nameCtrl,
                      textAlign: TextAlign.right,
                      hintText: '请输入账户名称',
                    ),
                  ),
                  const Divider(height: 1),
                ],
                _buildBankInputRow(
                  context,
                  label: '备注',
                  child: _buildPlainTextField(
                    controller: _noteCtrl,
                    hintText: '选填',
                    textAlign: TextAlign.right,
                  ),
                ),
                const Divider(height: 1),
                _buildBankInputRow(
                  context,
                  label: '余额',
                  onTap: !isEditing
                      ? () => _openNumberPad(
                            controller: _amountCtrl,
                            allowDecimal: true,
                            formatFixed2: true,
                          )
                      : null,
                  child: _buildPlainTextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    autofocus: !isEditing,
                    readOnly: true,
                    onTap: !isEditing
                        ? () => _openNumberPad(
                              controller: _amountCtrl,
                              allowDecimal: true,
                              formatFixed2: true,
                            )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _handleSubmit(kind, subtype, isEditing),
              child: Text(isEditing ? '保存' : '添加账户'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleForm(
    BuildContext context,
    AccountKind kind,
    AccountSubtype subtype,
    bool isEditing,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: _iosFormSectionDecoration(context),
            child: Column(
              children: [
                _buildBankInputRow(
                  context,
                  label: '名称',
                  child: _buildPlainTextField(
                    controller: _nameCtrl,
                    textAlign: TextAlign.right,
                  ),
                ),
                const Divider(height: 1),
                _buildBankInputRow(
                  context,
                  label: '备注',
                  child: _buildPlainTextField(
                    controller: _noteCtrl,
                    hintText: '选填',
                    textAlign: TextAlign.right,
                  ),
                ),
                const Divider(height: 1),
                _buildBankInputRow(
                  context,
                  label: '金额',
                  onTap: !isEditing
                      ? () => _openNumberPad(
                            controller: _amountCtrl,
                            allowDecimal: true,
                            formatFixed2: true,
                          )
                      : null,
                  child: _buildPlainTextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    autofocus: !isEditing,
                    enabled: !isEditing,
                    helperText:
                        isEditing ? '请前往账户详情页>调整余额进行修改' : null,
                    readOnly: true,
                    onTap: !isEditing
                        ? () => _openNumberPad(
                              controller: _amountCtrl,
                              allowDecimal: true,
                              formatFixed2: true,
                            )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _handleSubmit(kind, subtype, isEditing),
              child: Text(isEditing ? '保存' : '添加账户'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleAssetForm(
    BuildContext context,
    AccountKind kind,
    AccountSubtype subtype,
    bool isEditing,
  ) {
    // 投资账户：股票和基金不需要名称输入框，只有"其他投资账户"才需要
    final isInvest = subtype == AccountSubtype.invest;
    final isOtherInvest = isInvest && widget.presetName == '投资账户';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 投资账户不显示类型标签
          if (!isInvest) ...[
            _buildTypeHeader(kind, subtype),
            const SizedBox(height: 12),
          ],
          Container(
            decoration: _iosFormSectionDecoration(context),
            child: Column(
              children: [
                // 只有"其他投资账户"才显示名称输入框
                if (isOtherInvest) ...[
                  _buildBankInputRow(
                    context,
                    label: '名称',
                    child: _buildPlainTextField(
                      controller: _nameCtrl,
                      textAlign: TextAlign.right,
                      hintText: '请输入账户名称',
                    ),
                  ),
                  const Divider(height: 1),
                ],
                _buildBankInputRow(
                  context,
                  label: '备注',
                  child: _buildPlainTextField(
                    controller: _noteCtrl,
                    hintText: '选填',
                    textAlign: TextAlign.right,
                  ),
                ),
                const Divider(height: 1),
                _buildBankInputRow(
                  context,
                  label: '余额',
                  onTap: !isEditing
                      ? () => _openNumberPad(
                            controller: _amountCtrl,
                            allowDecimal: true,
                            formatFixed2: true,
                          )
                      : null,
                  child: _buildPlainTextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    autofocus: !isEditing,
                    readOnly: true,
                    onTap: !isEditing
                        ? () => _openNumberPad(
                              controller: _amountCtrl,
                              allowDecimal: true,
                              formatFixed2: true,
                            )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _handleSubmit(kind, subtype, isEditing),
              child: Text(isEditing ? '保存' : '添加账户'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashForm(
    BuildContext context,
    AccountKind kind,
    AccountSubtype subtype,
    bool isEditing,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: _iosFormSectionDecoration(context),
            child: Column(
              children: [
                _buildBankInputRow(
                  context,
                  label: '名称',
                  child: _buildPlainTextField(
                    controller: _nameCtrl,
                    hintText: '现金',
                    textAlign: TextAlign.right,
                  ),
                ),
                const Divider(height: 1),
                _buildBankInputRow(
                  context,
                  label: '备注',
                  child: _buildPlainTextField(
                    controller: _noteCtrl,
                    hintText: '选填',
                    textAlign: TextAlign.right,
                  ),
                ),
                const Divider(height: 1),
                _buildBankInputRow(
                  context,
                  label: '余额',
                  onTap: !isEditing
                      ? () => _openNumberPad(
                            controller: _amountCtrl,
                            allowDecimal: true,
                            formatFixed2: true,
                          )
                      : null,
                  child: _buildPlainTextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    autofocus: !isEditing,
                    readOnly: true,
                    onTap: !isEditing
                        ? () => _openNumberPad(
                              controller: _amountCtrl,
                              allowDecimal: true,
                              formatFixed2: true,
                            )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _handleSubmit(kind, subtype, isEditing),
              child: Text(isEditing ? '保存' : '添加账户'),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowBrandSelector(AccountSubtype subtype) {
    return subtype == AccountSubtype.savingCard || subtype == AccountSubtype.creditCard;
  }

  Widget _buildBrandSelector(BuildContext context) {
    final subtype = widget.account != null
        ? AccountSubtype.fromCode(widget.account!.subtype)
        : widget.subtype;
    final isCreditCard = subtype == AccountSubtype.creditCard;
    final brand = isCreditCard
        ? findCreditCardBrand(_brandKey)
        : findBankBrand(_brandKey);
    final hasBrand = _brandKey != null && 
            brand != null && 
            brand.key != 'custom' && 
            brand.key != 'other_credit' && 
            brand.key != 'other_bank';
    final labelColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '银行品牌',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
        ),
        const SizedBox(height: 6),
        InkWell(
      onTap: () async {
        final selected = await _pickBankBrand(context);
        if (!mounted) return;
        setState(() {
          _brandKey = selected;
          final subtype = widget.account != null
              ? AccountSubtype.fromCode(widget.account!.subtype)
              : widget.subtype;
          final isCreditCard = subtype == AccountSubtype.creditCard;
          final pickedBrand = isCreditCard
              ? findCreditCardBrand(selected)
              : findBankBrand(selected);
          // 如果选择了"其他银行"或"其他信用卡"，清空名称输入框，让用户自己输入
          if (selected == 'other_bank' || selected == 'other_credit') {
            _nameCtrl.clear();
            _customTitle = null;
          } else if (pickedBrand != null && 
              pickedBrand.key != 'custom' && 
              pickedBrand.key != 'other_credit' && 
              pickedBrand.key != 'other_bank') {
            _customTitle = pickedBrand.displayName;
          }
        });
      },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasBrand ? brand.displayName : '选择银行（可选）',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: hasBrand
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                        ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<String?> _pickBankBrand(BuildContext context) async {
    final subtype = widget.account != null
        ? AccountSubtype.fromCode(widget.account!.subtype)
        : widget.subtype;
    final isCreditCard = subtype == AccountSubtype.creditCard;
    final brands = isCreditCard ? kSupportedCreditCardBrands : kSupportedBankBrands;
    final title = isCreditCard ? '选择信用卡' : '选择银行';
    
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: brands.length,
                  itemBuilder: (context, index) {
                    final brand = brands[index];
                    final selected = brand.key == _brandKey;
                    return ListTile(
                      title: Text(brand.displayName),
                      trailing: selected
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, brand.key),
                    );
                  },
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              ListTile(
                title: Text(isCreditCard ? '不指定信用卡' : '不指定银行'),
                onTap: () => Navigator.pop(context, null),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBankInfoRow(BuildContext context) {
    final subtype = widget.account != null
        ? AccountSubtype.fromCode(widget.account!.subtype)
        : widget.subtype;
    final isCreditCard = subtype == AccountSubtype.creditCard;
    final brand = isCreditCard
        ? findCreditCardBrand(_brandKey)
        : findBankBrand(_brandKey);
    final defaultTitle = isCreditCard ? '选择信用卡' : '选择银行';
    final title = brand != null && 
            brand.key != 'custom' && 
            brand.key != 'other_credit' && 
            brand.key != 'other_bank'
        ? brand.displayName
        : defaultTitle;
    final labelColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    return InkWell(
      onTap: () async {
        final selected = await _pickBankBrand(context);
        if (!mounted) return;
        setState(() {
          _brandKey = selected;
          final pickedBrand = isCreditCard
              ? findCreditCardBrand(selected)
              : findBankBrand(selected);
          if (pickedBrand != null && 
              pickedBrand.key != 'custom' && 
              pickedBrand.key != 'other_credit' && 
              pickedBrand.key != 'other_bank') {
            _customTitle = pickedBrand.displayName;
          }
        });
      },
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Text(
              '所在银行',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
            ),
            const Spacer(),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: brand != null &&
                            brand.key != 'custom' &&
                            brand.key != 'other_credit' &&
                            brand.key != 'other_bank'
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                  ),
            ),
            Icon(
              Icons.chevron_right,
              color: labelColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTapValueRow(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onTap,
    double placeholderOpacity = 1.0,
  }) {
    final cs = Theme.of(context).colorScheme;
    final labelColor = cs.onSurface.withOpacity(0.7);
    final valueColor = cs.onSurface.withOpacity(placeholderOpacity);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: _kFormLabelWidth,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor,
                  ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              color: labelColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankInputRow(
    BuildContext context, {
    required String label,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final labelColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: _kFormLabelWidth,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  BoxDecoration _iosFormSectionDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return BoxDecoration(
      color: cs.surface,
      border: Border(
        top: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
        bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
      ),
    );
  }

  Widget _buildPlainTextField({
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    bool enabled = true,
    String? helperText,
    TextAlign textAlign = TextAlign.right,
    bool autofocus = false,
    FocusNode? focusNode,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
    crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          readOnly: readOnly,
          keyboardType: keyboardType,
          textAlign: textAlign,
          textAlignVertical: TextAlignVertical.center,
          maxLines: 1,
          autofocus: autofocus,
          focusNode: focusNode,
          onTap: onTap,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
              ),
          decoration: InputDecoration(
            hintText: hintText,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            filled: false,
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.55),
                ),
          ),
        ),
        if (helperText != null)
          Text(
            helperText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.65),
                ),
          ),
      ],
    );
  }

  String _amountLabel(AccountKind kind) {
    if (kind == AccountKind.liability) return '初始欠款金额';
    if (kind == AccountKind.lend) return '初始应收金额';
    return '初始余额';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (result != null) {
      setState(() => _dueDate = result);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _handleSubmit(
    AccountKind kind,
    AccountSubtype subtype,
    bool isEditing,
  ) async {
    // 数据验证
    final name = _nameCtrl.text.trim();
    final nameError = Validators.validateAccountName(name);
    if (nameError != null) {
      ErrorHandler.showError(context, nameError);
      return;
    }

    final amountStr = _amountCtrl.text.trim();
    double normalizedAmount = 0;
    if (!isEditing && amountStr.isNotEmpty) {
      final amountError = Validators.validateAmountString(amountStr);
      if (amountError != null) {
        ErrorHandler.showError(context, amountError);
        return;
      }
      normalizedAmount = double.parse(amountStr.startsWith('.') ? '0$amountStr' : amountStr).abs();
    }

    final note = _noteCtrl.text.trim();
    final noteError = Validators.validateRemark(note);
    if (noteError != null) {
      ErrorHandler.showError(context, noteError);
      return;
    }

    try {
    final provider = context.read<AccountProvider>();
    final bookId = context.read<BookProvider>().activeBookId;
      final accountType = _mapSubtypeToLegacy(subtype);

      if (isEditing && widget.account != null) {
        // 编辑账户时，只更新账户信息，不修改余额
        // 余额调整应该通过专门的"调整余额"功能进行
        final updated = widget.account!.copyWith(
          name: name,
          kind: kind,
          subtype: subtype.code,
          type: accountType,
          includeInTotal: _includeInOverview,
          includeInOverview: _includeInOverview,
          // 保持原有的 initialBalance 和 currentBalance 不变
          counterparty: _counterpartyCtrl.text.trim().isEmpty
              ? null
              : _counterpartyCtrl.text.trim(),
          brandKey: _brandKey,
          dueDate: _dueDate,
          note: note.isEmpty ? null : note,
        );
        await provider.updateAccount(updated, bookId: bookId);
        if (!mounted) return;
        ErrorHandler.showSuccess(context, '账户已更新');
      } else {
        final account = Account(
          id: '',
          name: name,
          kind: kind,
          subtype: subtype.code,
          type: accountType,
          icon: 'wallet',
          includeInTotal: _includeInOverview,
          includeInOverview: _includeInOverview,
          initialBalance: normalizedAmount,
          currentBalance: normalizedAmount,
          brandKey: _brandKey,
          counterparty: _counterpartyCtrl.text.trim().isEmpty
              ? null
              : _counterpartyCtrl.text.trim(),
          dueDate: _dueDate,
          note: note.isEmpty ? null : note,
        );
        await provider.addAccount(account, bookId: bookId);
        if (!mounted) return;
        ErrorHandler.showSuccess(context, '账户已添加');
      }

      if (!mounted) return;
      Navigator.pop(context, kind);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.handleAsyncError(context, e);
    }
  }

  String _defaultName() {
    switch (widget.subtype) {
      case AccountSubtype.cash:
        return '现金';
      case AccountSubtype.savingCard:
        return '储蓄卡';
      case AccountSubtype.creditCard:
        return '信用卡';
      case AccountSubtype.virtual:
        return '支付宝/微信';
      case AccountSubtype.invest:
        return '投资账户';
      case AccountSubtype.loan:
        return '贷款账户';
      case AccountSubtype.receivable:
        return '应收/借出';
      case AccountSubtype.customAsset:
        return '自定义资产';
    }
  }

  String _subtypeLabel(AccountSubtype subtype) {
    switch (subtype) {
      case AccountSubtype.cash:
        return '现金';
      case AccountSubtype.savingCard:
        return '储蓄卡';
      case AccountSubtype.creditCard:
        return '信用卡 / 花呗';
      case AccountSubtype.virtual:
        return '虚拟账户';
      case AccountSubtype.invest:
        return '投资账户';
      case AccountSubtype.loan:
        return '贷款/借入';
      case AccountSubtype.receivable:
        return '债权 / 借出';
      case AccountSubtype.customAsset:
        return '自定义资产';
    }
  }
}

AccountType _mapSubtypeToLegacy(AccountSubtype subtype) {
  switch (subtype) {
    case AccountSubtype.cash:
      return AccountType.cash;
    case AccountSubtype.savingCard:
      return AccountType.bankCard;
    case AccountSubtype.creditCard:
      return AccountType.loan;
    case AccountSubtype.virtual:
      return AccountType.eWallet;
    case AccountSubtype.invest:
      return AccountType.investment;
    case AccountSubtype.loan:
      return AccountType.loan;
    case AccountSubtype.receivable:
      return AccountType.lend;
    case AccountSubtype.customAsset:
      return AccountType.other;
  }
}
