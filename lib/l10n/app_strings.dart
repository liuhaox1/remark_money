import 'package:flutter/material.dart';

/// Centralized app strings for localization and reuse.
class AppStrings {
  // App / common
  static const appTitle = '指尖记账';
  static const unknown = '未知';
  static const ok = '确定';
  static const cancel = '取消';
  static const buttonOk = ok;
  static const buttonCancel = cancel;
  static const save = '保存';
  static const delete = '删除';
  static const add = '新增';
  static const close = '关闭';
  static const manage = '管理';
  static const edit = '编辑';
  static const today = '今天';
  static const selectBook = '选择账本';
  static const defaultBook = '默认账本';
  static const monthBudget = '月度结余';
  static const yearBudgetBalance = '年度结余';
  static const spent = '支出';
  static const remain = '剩余';
  static const income = '收入';
  static const expense = '支出';
  static const balance = '结余';
  static const remarkOptional = '备注（可选）';
  static const selectDate = '选择日期';
  static const inputAmount = '请输入金额';
  static const pleaseSelect = '请选择';
  static const emptyRemark = '暂无备注';
  static const confirmDeleteBook = '删除后不可恢复，确定删除该账本吗？';
  static const confirmDeleteAccount = '确定删除该账户吗？';
  static const bookNameRequired = '请输入账本名称';
  static const categoryNameRequired = '请填写分类名称';
  static const successBookSaved = '账本已保存';
  static const yearBudget = '年度预算';
  static const monthBudgetSummary = '本月小结';
  static const noDataThisMonth = '本月暂无记录';
  static const datePickerTitle = '日期选择';

  // Navigation
  static const navHome = '首页';
  static const navStats = '统计';
  static const navRecord = '记一笔';
  static const navAssets = '资产';
  static const navProfile = '我的';

  // Home / filters
  static const filter = '筛选';
  static const filterByCategory = '按分类筛选';
  static const filterByAmount = '按金额范围（最小-最大）';
  static const filterByType = '按收支类型';
  static const filterByDateRange = '按日期范围';
  static const minAmount = '最小金额';
  static const maxAmount = '最大金额';
  static const all = '全部';
  static const reset = '重置';
  static const confirm = '确认';
  static const startDate = '开始日期';
  static const endDate = '结束日期';
  static const dayIncome = '当日收入';
  static const dayExpense = '当日支出';
  static const dayBalance = '当日结余';
  static const monthBalance = '本月结余';
  static const bill = '账单';
  static const budget = '预算';
  static const emptyToday = '今天还没有记账';
  static const quickAddHint = '可以点底部加号，快速记一笔。';
  static const quickAdd = '快速记一笔';
  static const quickAddPrimary = '记一笔';
  static const pickDate = '选择日期';

  // Charts / stats
  static const stats = '统计';
  static const chartBar = '柱状图';
  static const chartPie = '饼图';
  static const viewByMonth = '按月';
  static const viewByYear = '按年';
  static const noYearData = '本年暂无支出记录';
  static const noMonthData = '本月暂无支出记录';
  static const report = '报表';
  static const reportOverview = '报表总览';
  static const monthReport = '月账单';
  static const yearReport = '年账单';
  static const expenseDistribution = '支出分布';
  static const expenseRanking = '支出排行';
  static const incomeDistribution = '收入分布';
  static const dailyTrend = '日趋势';
  static const recentMonthCompare = '近6个月支出对比';
  static const viewPeriodDetail = '查看该周期明细';
  static const reportAchievements = '记账成就';
  static const previousPeriod = '较上期';
  static const monthListTitle = '月度列表';
  static const recordCount = '记录笔数';
  static const activeDays = '活跃天数';
  static const streakDays = '连续记账天数';
  static String periodBillTitle(int year, {int? month}) => month != null
      ? '$year年${month.toString().padLeft(2, '0')}月账单'
      : '$year 年度账单';

  // Week labels
  static const tabMonth = '月';
  static const tabWeek = '周';
  static const tabYear = '年';
  static const weekdayShort = ['日', '一', '二', '三', '四', '五', '六'];

  // Budget page
  static const budgetSaved = '预算已保存';
  static const spendCategoryBudget = '支出分类预算';
  static const spendCategorySubtitle = '实时进度 · 点击查看明细';
  static const emptySpendCategory = '暂无支出分类，请在分类管理中新增';
  static const incomeCategoryBudget = '收入分类预算';
  static const incomeCategorySubtitle = '用于规划收入目标';
  static const emptyIncomeCategory = '暂无收入分类，请在分类管理中新增';
  static const saveBookBudget = '保存当前账本预算';
  static const monthTotalBudget = '月度总预算';
  static const monthBudgetHint = '为当前账本设置一个月度支出预算。';
  static const budgetDescription = '系统会实时对比本期支出与预算，并在首页与统计页展示进度。';
  static const budgetNotSet = '尚未设置预算';
  static const viewDetails = '查看明细';
  static const budgetInputHint = '输入预算';
  static const budgetTip = '合理的预算能帮助你更直观地控制支出。';
  static const budgetTodaySuggestionPrefix = '根据当前预算与剩余天数，建议今天控制在约 ';
  static const receivableThisMonthPrefix = '本月应收 ';
  static const expenseThisMonthPrefix = '本月支出 ';
  static const expenseThisPeriodPrefix = '本期支出 ';
  static const budgetOverspendTodayTip = '今日支出已超过建议金额，请注意控制消费。';

  // Home budget card
  static const homeBudgetTitle = '预算助手';
  static const homeBudgetDetail = '预算详情';
  static const homeBudgetNotSetTitle = '尚未设置账本预算';
  static const homeBudgetNotSetDesc = '去预算页设置预算后，这里会显示剩余额度与可用金额。';
  static const homeBudgetSetNow = '去设置预算';
  static const homeBudgetRemaining = '剩余预算';
  static const homeBudgetTodayAvailable = '今日可用';
  static const homeBudgetDaysLeft = '剩余天数';
  static const homeBudgetViewMonth = '月度';
  static const homeBudgetViewYear = '年度';
  static const homeBudgetMonthTitle = '本期预算（按月）';
  static const homeBudgetYearTitle = '年度预算';
  static const homeBudgetMonthlyEmptyTitle = '尚未设置月度预算';
  static const homeBudgetMonthlyEmptyDesc = '设置每月可支出的额度，帮助你控制当月花销。';
  static const homeBudgetMonthlyEmptyAction = '去设置月度预算';
  static const homeBudgetYearlyEmptyTitle = '尚未设置年度预算';
  static const homeBudgetYearlyEmptyDesc = '为全年规划一笔总预算，方便看今年是否超支。';
  static const homeBudgetYearlyEmptyAction = '去设置年度预算';

  static const avgDailySpend = '日均消费';
  static const avgWeeklySpend = '周均消费';
  static const avgMonthlySpend = '月均消费';
  static const remainingToday = '当日剩余';
  static const remainingWeek = '本周剩余';
  static const remainingMonth = '本月剩余';
  static const fullYear = '全年';
  static const addCategoryBudget = '增加分类预算';
  static const setBudget = '设置预算';
  static const deleteBudget = '删除预算';
  static const resetBookBudget = '重置本账本预算';
  static const resetBookBudgetConfirm = '将清空本账本的总预算和所有分类预算，不会删除任何记账记录，确认继续吗？';
  static const budgetPeriodSettingTitle = '预算周期设置';
  static const budgetPeriodSettingDesc = '选择每个月从哪一天开始统计预算，只影响统计范围，不会删除历史记录。';
  static const invalidAmount = '请输入有效的金额';
  static const categoryBudgetDeleted = '已删除该分类预算';
  static const categoryBudgetSaved = '分类预算已保存';
  static const spendCategorySubtitlePeriod = '实时进度，仅展示本期支出情况';
  static const budgetCategoryRelationHint = '分类预算是总预算的拆分，用于控制重点支出分类。';
  static const budgetCategoryEmptyHint =
      '当前尚未设置分类预算。建议先为高频支出（如餐饮、购物）设置预算，可点击下方“增加分类预算”。';
  static const budgetCategorySummaryPrefix = '分类预算合计';

  // Bill page
  static const billTitle = '账单';
  static const yearlyBill = '年度账单';
  static const monthlyBill = '月度账单';
  static const pickYear = '选择年份';
  static const pickMonth = '选择月份';

  // Category manager
  static const categoryManager = '分类管理';
  static const expenseCategory = '支出';
  static const incomeCategory = '收入';
  static const emptyCategoryHint = '暂无分类，请先新增一个分类。';
  static const deleteCategory = '删除分类';
  static const addCategory = '新增分类';
  static const editCategory = '编辑分类';
  static const categoryName = '分类名称';
  static const categoryNameHint = '例如：餐饮';
  static const categoryType = '类型';
  static const categoryIcon = '图标';
  static String deleteCategoryConfirm(String name) => '确定要删除 $name 吗？';

  // Add record / quick add
  static const addRecord = '新增记账';
  static const amountError = '请填写正确的金额';
  static const selectCategoryError = '请先选择分类';
  static const category = '分类';
  static const selectCategory = '选择分类';
  static const emptyCategoryForRecord = '暂无分类，请先去分类管理中添加。';
  static const recordSaved = '记账成功';
  static const goManage = '去管理';
  static const manageCategory = '管理分类';
  static const loadingSubtitle = '指尖记账 · 让记账更简单';

  // Profile
  static const profile = '我的';
  static const version = '指尖记账 1.0.0';
  static const theme = '主题';
  static const themeLight = '浅色';
  static const themeDark = '深色';
  static const themeSeed = '主题色';
  static const book = '账本';
  static const addBook = '新增账本';
  static const renameBook = '重命名账本';
  static const deleteBook = '删除账本';
  static const newBook = '新建账本';
  static const bookNameHint = '账本名称';

  // Assets
  static const assets = '资产';
  static const addAccount = '新增账户';
  static const editAccount = '编辑账户';
  static const newAccount = '新建账户';
  static const accountName = '账户名称';
  static const accountNameHint = '如：现金、银行卡';
  static const accountType = '账户类型';
  static const cashAndPay = '现金 / 支付';
  static const bankCard = '银行卡';
  static const investment = '投资资产';
  static const other = '其他';
  static const debt = '负债';
  static const cash = '现金';
  static const payAccount = '支付账户';
  static const borrow = '借贷';
  static const debtAccount = '负债账户';
  static const currentBalance = '当前余额';
  static const balanceHint = '例如：1000.00';
  static const debtAccountTitle = '这是一个负债账户';
  static const debtAccountSubtitle = '可用于记录信用卡、贷款等负债。';
  static const includeInTotal = '计入总资产 / 净资产';
  static const deleteAccount = '删除账户';
  static const emptyAccountsTitle = '还没有添加任何资产账户';
  static const emptyAccountsSubtitle = '可以新增“现金”“银行卡”等账户开始管理资产。';
  static const totalAssets = '总资产';
  static const totalDebts = '总负债';
  static const netWorth = '净资产';

  // Built-in category names
  static const catFood = '餐饮';
  static const catShopping = '购物';
  static const catTransport = '交通出行';
  static const catUtility = '水电费';
  static const catMedical = '医疗';
  static const catEducation = '教育';
  static const catHouse = '住房';
  static const catEntertainment = '娱乐';
  static const catDaily = '日用品';
  static const catPet = '宠物';
  static const catSalary = '工资';
  static const catBonus = '奖金';
  static const catParttime = '兼职';
  static const catInvest = '投资收益';

  // Home page date panel / summary
  static const summaryMonth = '月度小结';
  static const summaryYear = '年度小结';
  static const monthSummary = summaryMonth;
  static const annualSummary = summaryYear;

  // Misc formatting helpers
  static String currentBookLabel(String name) => '当前账本：$name';

  static String monthExpenseWithCount(double amount, int count) =>
      '本月支出 ¥${amount.toStringAsFixed(0)} · $count 笔';

  static String yearLabel(int year) => '$year年';

  static String monthLabel(int month) => '$month月';

  static String monthDayLabel(int month, int day) => '$month月$day日';

  static String yearMonthLabel(int year, int month) =>
      '$year年${month.toString().padLeft(2, '0')}月';

  static String yearExpenseTotal(int year, double total) =>
      '$year年支出合计：¥${total.toStringAsFixed(0)}';

  static String monthExpenseTotal(int year, int month, double total) =>
      '$year年${month.toString().padLeft(2, '0')}月支出合计：¥${total.toStringAsFixed(0)}';

  static String bookMonthBudgetTitle(DateTime month) =>
      '${month.year}年${month.month}月预算';

  static String bookYearBudgetTitle(int year) => '$year 年度预算';

  static String budgetRemainingLabel(double value, bool exceeded) => exceeded
      ? '已超支 ¥${value.abs().toStringAsFixed(0)}'
      : '剩余 ¥${value.toStringAsFixed(0)}';

  static String budgetUsedLabel(double spent, double? budget) =>
      '已用 ¥${spent.toStringAsFixed(0)} / 预算 '
      '${budget != null ? '¥${budget.toStringAsFixed(0)}' : '未设置'}';

  static String homeBudgetUsedAndTotal(double spent, double total) =>
      '已用 ¥${spent.toStringAsFixed(0)} · 预算 ¥${total.toStringAsFixed(0)}';

  static String homeBudgetTodaySuggestion(int daysLeft, double dailyLimit) =>
      '剩余 $daysLeft 天 · 今日建议 ≤ ¥${dailyLimit.toStringAsFixed(0)}';

  static String homeBudgetUsageVsTime(
    double usedPercent,
    double timePercent,
  ) =>
      '已用 ${usedPercent.toStringAsFixed(0)}% · 时间进度 ${timePercent.toStringAsFixed(0)}%';

  static String categoryMonthlyDetail(String name) => '$name 月度明细';

  static String monthDayWithCount(
    int month,
    int day,
    String weekday,
    int count,
  ) =>
      '$month月$day日 · $weekday · $count 笔';

  static String hoursInDays(int days) => '$days 天';

  static String selectMonthLabel(DateTime date) =>
      '${date.year}年${date.month}月';

  static String monthRangeTitle(int index, int startDay, int endDay) =>
      '第${index + 1}个周期：$startDay-$endDay 日';

  static String monthDayWithWeek(int month, int day, String week) =>
      '$month月$day日 $week';

  static String billTitleWithMonth(int month) => '$month 月账单';

  // Added for weekly / empty states
  static const weeklyBill = '周账单';
  static const weekReport = '周账单';
  static const pickWeek = '选择周次';
  static const previousPeriodNoData = '暂无对比数据';
  static const emptyYearRecords = '本年还没有记账记录，先去首页记一笔吧';
  static const emptyPeriodRecords = '这个周期还没有记账记录';
  static const goRecord = '去记一笔';
  static const currentMonthEmpty = '本月尚未记账';
  static const weekLabelShort = '周';
  static String weekRangeLabel(DateTimeRange range) =>
      '${_ymd(range.start)} - ${_ymd(range.end)}';

  static String _ymd(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static const unitYi = '亿';
  static const unitWan = '万';
}
