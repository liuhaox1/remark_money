import 'package:flutter/material.dart';
import '../utils/error_handler.dart';

/// VIP购买页面
class VipPurchasePage extends StatefulWidget {
  const VipPurchasePage({super.key});

  @override
  State<VipPurchasePage> createState() => _VipPurchasePageState();
}

class _VipPurchasePageState extends State<VipPurchasePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedPlanIndex = 0; // 默认选择连续包年
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 会员套餐数据
  final List<Map<String, dynamic>> _plans = [
    {
      'name': '连续包年',
      'price': 119,
      'originalPrice': 216,
      'monthlyPrice': 9.92,
      'discount': '限时5.5折',
      'isRecommended': true,
      'duration': 12,
      'type': 'annual',
    },
    {
      'name': '季卡会员',
      'price': 50,
      'monthlyPrice': 16.67,
      'duration': 3,
      'type': 'quarterly',
    },
    {
      'name': '月卡会员',
      'price': 18,
      'monthlyPrice': 18,
      'duration': 1,
      'type': 'monthly',
    },
    {
      'name': '连续包季',
      'price': 38,
      'monthlyPrice': 12.67,
      'duration': 3,
      'type': 'quarterly_auto',
    },
  ];

  /// VIP特权列表
  final List<Map<String, dynamic>> _privileges = [
    {'icon': Icons.block, 'name': '去除广告'},
    {'icon': Icons.lock_open, 'name': '解锁密码'},
    {'icon': Icons.file_download, 'name': '导出数据'},
    {'icon': Icons.account_balance_wallet, 'name': '分类预算'},
    {'icon': Icons.book, 'name': '分账本'},
    {'icon': Icons.people, 'name': '多人记账'},
    {'icon': Icons.home, 'name': '家庭账单'},
    {'icon': Icons.timer, 'name': '自定义周期'},
    {'icon': Icons.calendar_today, 'name': '记账日历'},
    {'icon': Icons.list, 'name': '每日收支'},
  ];

  Future<void> _handlePurchase() async {
    if (!_agreedToTerms) {
      ErrorHandler.showWarning(context, '请先同意《会员服务协议》和《自动续费服务规则》');
      return;
    }

    // TODO: 调用支付接口
    ErrorHandler.showSuccess(context, '支付功能开发中，请稍后...');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('我的VIP'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              // TODO: 恢复购买
              ErrorHandler.showInfo(context, '恢复购买功能开发中');
            },
            child: Text(
              '恢复购买',
              style: TextStyle(color: cs.primary),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标签栏
            Container(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: cs.primary,
                unselectedLabelColor: cs.onSurface.withOpacity(0.6),
                indicatorColor: cs.primary,
                tabs: const [
                  Tab(text: 'VIP会员'),
                  Tab(text: '免广告会员'),
                  Tab(text: '体验版会员'),
                ],
              ),
            ),

            // VIP会员卡片
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VIP会员',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '开通VIP，畅享高级功能',
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          ...List.generate(3, (index) => Container(
                                margin: const EdgeInsets.only(left: 4),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  size: 18,
                                  color: cs.onPrimaryContainer,
                                ),
                              )),
                          const SizedBox(width: 8),
                          Text(
                            '40w+人已开通VIP',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // VIP特权
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '30项VIP专享超级特权',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // TODO: 显示详情
                        },
                        child: Text(
                          '详情 >',
                          style: TextStyle(color: cs.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _privileges.length,
                    itemBuilder: (context, index) {
                      final privilege = _privileges[index];
                      return Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              privilege['icon'] as IconData,
                              color: cs.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            privilege['name'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withOpacity(0.8),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        // TODO: 查看更多
                      },
                      child: Text(
                        '查看更多',
                        style: TextStyle(color: cs.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 套餐选择
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择套餐',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_plans.length, (index) {
                    final plan = _plans[index];
                    final isSelected = _selectedPlanIndex == index;
                    final isRecommended = plan['isRecommended'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? cs.primary
                              : cs.outline.withOpacity(0.3),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? cs.primaryContainer.withOpacity(0.2)
                            : Colors.transparent,
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedPlanIndex = index);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              if (isRecommended)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    plan['discount'] as String,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (isRecommended) const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plan['name'] as String,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    if (plan['monthlyPrice'] != null)
                                      Text(
                                        '折合¥${plan['monthlyPrice']}/月',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                '¥${plan['price']}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Radio<int>(
                                value: index,
                                groupValue: _selectedPlanIndex,
                                onChanged: (value) {
                                  setState(() => _selectedPlanIndex = value!);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_selectedPlanIndex == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '到期以¥119/年自动续费，可随时取消',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 用户评价
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '用户评价(140万+)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '天**甲：非常好用，推荐！',
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 支付按钮
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_plans[_selectedPlanIndex]['originalPrice'] != null)
                        Text(
                          '¥${_plans[_selectedPlanIndex]['originalPrice']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurface.withOpacity(0.5),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      if (_plans[_selectedPlanIndex]['originalPrice'] != null)
                        const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '已优惠${(_plans[_selectedPlanIndex]['originalPrice'] as int? ?? 0) - (_plans[_selectedPlanIndex]['price'] as int)}元',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _agreedToTerms ? _handlePurchase : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '立即支付 ¥${_plans[_selectedPlanIndex]['price']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _agreedToTerms,
                        onChanged: (value) {
                          setState(() => _agreedToTerms = value ?? false);
                        },
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      Expanded(
                        child: Wrap(
                          children: [
                            Text(
                              '开通前请确认',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withOpacity(0.7),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                // TODO: 显示会员服务协议
                              },
                              child: Text(
                                '《会员服务协议》',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                            Text(
                              '和',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withOpacity(0.7),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                // TODO: 显示自动续费服务规则
                              },
                              child: Text(
                                '《自动续费服务规则》',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.primary,
                                ),
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
          ],
        ),
      ),
    );
  }
}
