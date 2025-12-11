import 'package:flutter/material.dart';
import '../services/user_stats_service.dart';

/// 用户统计卡片组件
class UserStatsCard extends StatefulWidget {
  const UserStatsCard({super.key});

  @override
  State<UserStatsCard> createState() => _UserStatsCardState();
}

class _UserStatsCardState extends State<UserStatsCard> {
  UserStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await UserStatsService.getStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCheckIn() async {
    // 先更新UI状态，显示"已签到"
    setState(() {
      _isLoading = true;
    });
    
    final success = await UserStatsService.checkIn();
    if (!mounted) return;
    
    if (success) {
      // 立即刷新统计数据
      await _loadStats();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('签到成功！'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      // 即使失败也要刷新状态
      await _loadStats();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('今天已经签到过了'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_stats == null) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final isCheckedIn = _stats!.lastCheckInDate != null &&
        DateTime.now().year == _stats!.lastCheckInDate!.year &&
        DateTime.now().month == _stats!.lastCheckInDate!.month &&
        DateTime.now().day == _stats!.lastCheckInDate!.day;

    return Card(
      color: cs.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '我的统计',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                ),
                // 签到按钮
                OutlinedButton.icon(
                  onPressed: isCheckedIn ? null : _handleCheckIn,
                  icon: Icon(
                    isCheckedIn ? Icons.check_circle : Icons.calendar_today,
                    size: 16,
                  ),
                  label: Text(isCheckedIn ? '已签到' : '签到'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: '连续记账',
                    value: '${_stats!.consecutiveDays}天',
                    icon: Icons.trending_up,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: '累计记账',
                    value: '${_stats!.totalDays}天',
                    icon: Icons.calendar_today,
                    color: cs.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: '本月记账',
                    value: '${_stats!.thisMonthCount}条',
                    icon: Icons.receipt_long,
                    color: cs.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: '累计记录',
                    value: '${_stats!.totalRecords}条',
                    icon: Icons.list_alt,
                    color: cs.primaryContainer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
