class DateUtilsX {
  /// 判断是否同一天
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 判断是否同一月
  static bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  /// 月份字符串：2025-03
  static String ym(DateTime d) {
    return "${d.year}-${_two(d.month)}";
  }

  /// 日期字符串：2025-03-12
  static String ymd(DateTime d) {
    return "${d.year}-${_two(d.month)}-${_two(d.day)}";
  }

  /// 返回 02 03 这样的格式
  static String _two(int v) => v.toString().padLeft(2, '0');

  /// 获取某月的第一天
  static DateTime firstDayOfMonth(DateTime d) {
    return DateTime(d.year, d.month, 1);
  }

  /// 获取某月的最后一天
  static DateTime lastDayOfMonth(DateTime d) {
    return DateTime(d.year, d.month + 1, 0);
  }

  /// 某月的所有日期
  static List<DateTime> daysInMonth(DateTime d) {
    final last = lastDayOfMonth(d);
    return List.generate(last.day, (i) => DateTime(d.year, d.month, i + 1));
  }

  /// 获取当前周的第一天（以周日为第一天）
  static DateTime startOfWeek(DateTime d) {
    final weekday = d.weekday % 7; // 周日=0
    return d.subtract(Duration(days: weekday));
  }

  /// 获取一整周 7 天
  static List<DateTime> daysInWeek(DateTime d) {
    final start = startOfWeek(d);
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  /// 格式化月名称（03 → 3 月）
  static String monthLabel(DateTime d) {
    return "${d.month}月";
  }

  /// 获取某年的所有月份（12 个 DateTime）
  static List<DateTime> monthsInYear(int year) {
    return List.generate(12, (i) => DateTime(year, i + 1, 1));
  }

  /// 获取年份区间（例如图表/账单需要）
  static List<int> yearRange({int past = 5, int future = 1}) {
    final now = DateTime.now().year;
    return List.generate(past + future + 1, (i) => now - past + i);
  }

  /// 返回简短星期文案：一/二/三...
  static String weekdayShort(DateTime d) {
    const values = ['日', '一', '二', '三', '四', '五', '六'];
    return values[d.weekday % 7];
  }

  /// 是否是今天
  static bool isToday(DateTime d) {
    final now = DateTime.now();
    return isSameDay(d, now);
  }
}
