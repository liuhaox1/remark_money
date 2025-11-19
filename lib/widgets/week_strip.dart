import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../utils/date_utils.dart';

/// 顶部日期“时间轴”
///
/// 设计目标：
/// - 占用高度很薄；
/// - 可以左右滑动整个月；
/// - 有明显的滚动条，手指拖一下就能快速移动；
/// - 一键回到「今天」。
class WeekStrip extends StatefulWidget {
  const WeekStrip({
    super.key,
    required this.selectedDay,
    required this.onSelected,
  });

  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelected;

  @override
  State<WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<WeekStrip> {
  static const double _itemWidth = 44;
  static const double _itemSpacing = 8;

  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDay(widget.selectedDay, jump: true);
    });
  }

  @override
  void didUpdateWidget(covariant WeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtilsX.isSameDay(oldWidget.selectedDay, widget.selectedDay)) {
      _scrollToDay(widget.selectedDay);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToDay(DateTime day, {bool jump = false}) {
    if (!_controller.hasClients) return;

    final targetDay = DateTime(day.year, day.month, day.day);
    final index = targetDay.day - 1;
    if (index < 0) return;

    const double itemExtent = _itemWidth + _itemSpacing;
    final double rawOffset = (index * itemExtent) - (_itemWidth * 1.5);
    final position = _controller.position;
    final double offset = rawOffset.clamp(0.0, position.maxScrollExtent);

    if (jump) {
      _controller.jumpTo(offset);
    } else {
      _controller.animateTo(
        offset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final today = DateTime.now();
    final current = DateTime(
      widget.selectedDay.year,
      widget.selectedDay.month,
      widget.selectedDay.day,
    );
    final days = DateUtilsX.daysInMonth(current);

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 16),
          _TodayPill(
            isTodaySelected: DateUtilsX.isSameDay(current, today),
            onTap: () {
              final now = DateTime.now();
              final normalized = DateTime(now.year, now.month, now.day);
              widget.onSelected(normalized);
              _scrollToDay(normalized);
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _scrollByItems(-5),
                  child: Opacity(
                    opacity: 0.35,
                    child: Icon(
                      Icons.chevron_left,
                      size: 16,
                      color: cs.onSurface.withOpacity(isDark ? 0.6 : 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        _handlePointerScroll(event);
                      }
                    },
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: const {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.trackpad,
                        },
                      ),
                      child: ListView.separated(
                        controller: _controller,
                        padding: EdgeInsets.zero,
                        scrollDirection: Axis.horizontal,
                        itemCount: days.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: _itemSpacing),
                        itemBuilder: (context, index) {
                          final day = days[index];
                          final isSelected = DateUtilsX.isSameDay(day, current);
                          final isToday = DateUtilsX.isToday(day);
                          final isFuture = day.isAfter(DateTime(
                            today.year,
                            today.month,
                            today.day,
                          ));

                          Color bg;
                          Color fg;
                          if (isSelected) {
                            bg = cs.primary;
                            fg = cs.onPrimary;
                          } else if (isFuture) {
                            bg = Colors.transparent;
                            fg = cs.onSurface.withOpacity(0.25);
                          } else {
                            bg = Colors.transparent;
                            fg = cs.onSurface.withOpacity(isDark ? 0.7 : 0.6);
                          }

                          return InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap:
                                isFuture ? null : () => widget.onSelected(day),
                            child: Container(
                              width: _itemWidth,
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 4,
                              ),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateUtilsX.weekdayShort(day),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: fg.withOpacity(
                                        isToday && !isSelected ? 0.8 : 1.0,
                                      ),
                                      fontWeight: isToday || isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: fg,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  AnimatedOpacity(
                                    opacity: isSelected ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 160),
                                    child: Container(
                                      height: 2,
                                      width: 18,
                                      decoration: BoxDecoration(
                                        color: fg,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _scrollByItems(5),
                  child: Opacity(
                    opacity: 0.35,
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: cs.onSurface.withOpacity(isDark ? 0.6 : 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  void _scrollByItems(int count) {
    if (!_controller.hasClients) return;
    const double itemExtent = _itemWidth + _itemSpacing;
    final double target = (_controller.offset + count * itemExtent).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePointerScroll(PointerScrollEvent event) {
    if (!_controller.hasClients) return;
    final delta = event.scrollDelta.dy;
    if (delta == 0) return;
    final double target = (_controller.offset + delta).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    _controller.jumpTo(target);
  }
}

class _TodayPill extends StatelessWidget {
  const _TodayPill({
    required this.isTodaySelected,
    required this.onTap,
  });

  final bool isTodaySelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isTodaySelected
              ? cs.primary.withOpacity(0.12)
              : cs.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '今天',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isTodaySelected ? cs.primary : cs.onSurface.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}
