class AppTextTemplates {
  // Natural language summaries
  static String weeklySummary({
    required double expense,
    required double diff,
    required String topCategory,
  }) {
    final moreOrLess = diff >= 0 ? '多' : '少';
    return '本周支出 ${expense.toStringAsFixed(2)} 元，较上一周$moreOrLess ${diff.abs().toStringAsFixed(2)} 元，主要花在【$topCategory】。';
  }

  static String singleCategoryFullSummary({
    required String label,
    required double amount,
  }) =>
      '本期支出全部在【$label】 ${amount.toStringAsFixed(2)} (100%)';

  static String weekEmptyDaysHint(int count) => '本周有 $count 天未记账';

  static String monthEmptyDaysHint(int count) => '本月有 $count 天未记账';

  static const String showEmptyDays = '显示空白日期';

  // Chart descriptions
  static const String chartCategoryDistributionDesc =
      '按分类比例展示本期支出构成，帮助你看清钱花在哪些地方。';

  static const String chartExpenseRankingDesc =
      '按金额从高到低列出本期支出排行，方便你找出最大的花销项。';

  // Export and actions
  static String exportSuccess(String fileName) => '已导出：$fileName';

  static const String exportFailed = '导出失败，请稍后重试';

  static const String exportNoData = '当前时间范围内暂无记账';

  static String exportNotSupportedHint(String target) =>
      '当前视图暂不支持导出，请切换到 $target 后再试';

  static const String viewBillList = '查看本期流水明细';
}
