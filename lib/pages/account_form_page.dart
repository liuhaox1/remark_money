import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/bank_brands.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';

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
    final nameText = account?.name ?? 
        (isOtherBank || isOtherVirtual ? '' : (widget.presetName ?? _defaultName()));
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
        kind == AccountKind.asset && !isBankCard && !isVirtual && !isCash;

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
      } else {
        appBarTitle = _customTitle ?? (isEditing ? '编辑账户' : '添加账户');
      }
    } else if (isVirtual) {
      // 虚拟账户：支付宝和微信显示对应名称
      if (widget.presetName == '支付宝' || widget.presetName == '微信') {
        appBarTitle = widget.presetName!;
      } else {
        appBarTitle = _customTitle ?? (isEditing ? '编辑账户' : '添加账户');
      }
    } else {
      appBarTitle = _customTitle ?? (isEditing ? '编辑账户' : '添加账户');
    }

    return Scaffold(
      backgroundColor: (isBankCard || isVirtual || isCash)
          ? const Color(0xFFFFFCEF)
          : null,
      appBar: AppBar(
        backgroundColor:
            (isBankCard || isVirtual || isCash) ? const Color(0xFFFFD54F) : null,
        foregroundColor: (isBankCard || isVirtual || isCash) ? Colors.black : null,
        elevation: (isBankCard || isVirtual || isCash) ? 0 : null,
        title: Text(appBarTitle),
      ),
      body: isBankCard
          ? _buildBankCardForm(context, kind, subtype, isEditing)
          : isVirtual
              ? _buildVirtualForm(context, kind, subtype, isEditing)
              : isCash
                  ? _buildCashForm(context, kind, subtype, isEditing)
              : isSimpleAsset
                  ? _buildSimpleAssetForm(context, kind, subtype, isEditing)
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
    final hideSubtypeLabel = subtype == AccountSubtype.virtual;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kindLabel,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        if (!hideSubtypeLabel) ...[
          const SizedBox(height: 4),
          Text(
            _subtypeLabel(subtype),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '账户名称',
              hintText: '例如：招商银行(尾号1234)',
            ),
          ),
          if (!isEditing) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: false),
              decoration: InputDecoration(
                labelText: _amountLabel(kind),
                hintText: '0.00',
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              enabled: false,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: false),
              decoration: InputDecoration(
                labelText: _amountLabel(kind),
                hintText: '0.00',
                helperText: '编辑账户时不能修改余额，请在账户详情页使用"调整余额"功能',
              ),
            ),
          ],
          if (_shouldShowBrandSelector(subtype)) ...[
            const SizedBox(height: 12),
            _buildBrandSelector(context),
          ],
          const SizedBox(height: 12),
          if (_showCounterparty(kind, subtype)) ...[
            TextField(
              controller: _counterpartyCtrl,
              decoration: const InputDecoration(
                labelText: '对方名称（可选）',
                hintText: '如：银行/朋友姓名',
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '预计还清/收回日期（可选）',
                  border: OutlineInputBorder(),
                ),
                child: Text(_dueDate == null ? '未设置' : _formatDate(_dueDate!)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '备注（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.showAdvancedSettings)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                '高级设置',
                style: TextStyle(fontWeight: FontWeight.w700),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
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
                  child: _buildPlainTextField(
                    controller: _counterpartyCtrl,
                    hintText: '选填',
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                  ),
                ),
                _buildBankInputRow(
                  context,
                  label: '备注',
                  child: _buildPlainTextField(
                    controller: _noteCtrl,
                    hintText: '（选填）',
                    textAlign: TextAlign.right,
                  ),
                ),
                _buildBankInputRow(
                  context,
                  label: '余额',
                  child: _buildPlainTextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    enabled: !isEditing,
                    helperText:
                        isEditing ? '请前往账户详情页>调整余额进行修改' : null,
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
                backgroundColor: const Color(0xFFFFD54F),
                foregroundColor: Colors.black87,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTypeHeader(kind, subtype),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
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
                    hintText: '（选填）',
                    textAlign: TextAlign.right,
                  ),
                ),
                const Divider(height: 1),
                _buildBankInputRow(
                  context,
                  label: '余额',
                  child: _buildPlainTextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
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
                backgroundColor: const Color(0xFFFFD54F),
                foregroundColor: Colors.black87,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTypeHeader(kind, subtype),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
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
                    hintText: '（选填）',
                    textAlign: TextAlign.right,
                  ),
                ),
                const Divider(height: 1),
                _buildBankInputRow(
                  context,
                  label: '余额',
                  child: _buildPlainTextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
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
                backgroundColor: const Color(0xFFFFD54F),
                foregroundColor: Colors.black87,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildBankInputRow(
                  context,
                  label: '名称',
                  child: Text(
                    '现金',
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                const Divider(height: 1),
                _buildBankInputRow(
                  context,
                  label: '备注',
                  child: _buildPlainTextField(
                    controller: _noteCtrl,
                    hintText: '（选填）',
                    textAlign: TextAlign.right,
                  ),
                ),
                const Divider(height: 1),
                _buildBankInputRow(
                  context,
                  label: '余额',
                  child: _buildPlainTextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    autofocus: true,
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
                backgroundColor: const Color(0xFFFFD54F),
                foregroundColor: Colors.black87,
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
          style: TextStyle(
            fontSize: 14,
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
                    style: TextStyle(
                      fontSize: 15,
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: labelColor),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: brand != null && 
                        brand.key != 'custom' && 
                        brand.key != 'other_credit' && 
                        brand.key != 'other_bank'
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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

  Widget _buildBankInputRow(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
    final labelColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 15, color: labelColor, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          Expanded(child: Align(alignment: Alignment.centerRight, child: child)),
        ],
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
  }) {
    return Column(
    crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          textAlign: textAlign,
        autofocus: autofocus,
          decoration: InputDecoration(
            hintText: hintText,
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (helperText != null)
          Text(
            helperText,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
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
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (name.isEmpty) {
      _showSnack('请填写账户名称');
      return;
    }
    final normalizedAmount = amount.abs();
    final provider = context.read<AccountProvider>();
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
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      await provider.updateAccount(updated);
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
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      await provider.addAccount(account);
    }

    if (!mounted) return;
    Navigator.pop(context, kind);
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
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
