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

  // Report / chart descriptions (new)
  static const reportSummaryPrefix = '本期共记账 ';
  static const reportSummaryMiddleRecords = ' 笔，支出 ';
  static const reportSummarySuffixYuan = ' 元';
  static const reportSummaryComparePrefix = '，较上一期 ';
  static const reportSummaryCompareUp = '增加约 ';
  static const reportSummaryCompareDown = '减少约 ';
  static const reportSummaryCompareFlat = '与上一期大致持平';
  static const reportSummaryMaxCategoryPrefix = '最大支出类别是「';
  static const reportSummaryMaxCategorySuffix = '」，约占本期支出的 ';
  static const chartCategoryDesc =
      '按分类统计本期收支分布，帮助你看清钱花在哪些地方。';
  static const chartDailyTrendDesc =
      '展示本期每天的支出趋势，方便你了解消费高峰和低谷。';
  static const chartRecentCompareDesc =
      '展示最近若干周期的支出对比，帮助你判断支出是在上升还是下降。';

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

  // Built-in category names (hierarchical)
  // 一级：支出
  static const catTopFood = '餐饮';
  static const catTopShopping = '购物';
  static const catTopTransport = '出行';
  static const catTopLiving = '居住与账单';
  static const catTopLeisure = '娱乐休闲';
  static const catTopEducation = '教育成长';
  static const catTopHealth = '健康医疗';
  static const catTopFamily = '家庭与人情';
  static const catTopFinance = '金融与其他';

  // 餐饮 - 二级
  static const catFoodMeal = '正餐/工作餐';
  static const catFoodBreakfast = '早餐';
  static const catFoodSnack = '零食小吃';
  static const catFoodDrink = '饮料/奶茶/咖啡';
  static const catFoodTakeout = '外卖';
  static const catFoodSupper = '夜宵';

  // 购物 - 二级
  static const catShopDaily = '日用百货';
  static const catShopSupermarket = '超市采购';
  static const catShopClothes = '服饰鞋包';
  static const catShopDigital = '数码家电';
  static const catShopBeauty = '美妆护肤';
  static const catShopOther = '其他购物';

  // 出行 - 二级
  static const catTransCommute = '通勤交通';
  static const catTransTaxi = '打车/网约车';
  static const catTransDrive = '自驾油费/停车';
  static const catTransLongTrip = '长途交通';
  static const catTransShare = '共享出行';

  // 居住与账单 - 二级
  static const catLivingRent = '房租/房贷';
  static const catLivingProperty = '物业管理费';
  static const catLivingUtility = '水电燃气';
  static const catLivingInternet = '网费/电视/宽带';
  static const catLivingService = '家政/维修';
  static const catLivingDecorate = '装修/家居';

  // 娱乐休闲 - 二级
  static const catFunOnline = '线上娱乐';
  static const catFunOffline = '线下娱乐';
  static const catFunSport = '运动健身';
  static const catFunTravel = '旅游度假';
  static const catFunHobby = '兴趣爱好';

  // 教育成长 - 二级
  static const catEduCourse = '课程培训';
  static const catEduBook = '书籍/电子书';
  static const catEduExam = '考试/证书';
  static const catEduLanguage = '语言学习';
  static const catEduOnline = '线上学习会员';

  // 健康医疗 - 二级
  static const catHealthClinic = '门诊/手术';
  static const catHealthMedicine = '药品';
  static const catHealthCheck = '体检';
  static const catHealthDental = '牙科/视力';
  static const catHealthInsurance = '健康保险';

  // 家庭与人情 - 二级
  static const catFamilyChild = '孩子相关';
  static const catFamilyElder = '长辈孝敬';
  static const catFamilyMeal = '家庭聚餐';
  static const catFamilyGift = '礼金/红包';
  static const catFamilySocial = '社交应酬';
  static const catFamilyPet = '宠物';

  // 金融与其他 - 二级
  static const catFinRepay = '还贷/还信用卡';
  static const catFinFee = '利息/手续费';
  static const catFinInvestLoss = '投资亏损';
  static const catFinAdjust = '其他调账';

  // 一级：收入
  static const catTopIncomeSalary = '工资收入';
  static const catTopIncomeParttime = '兼职副业';
  static const catTopIncomeInvest = '投资理财';
  static const catTopIncomeOther = '其他收入';

  // 收入 - 二级
  static const catIncomeBasicSalary = '基本工资';
  static const catIncomeBonus = '奖金/提成';
  static const catIncomeYearEnd = '年终奖';
  static const catIncomeParttimeOnline = '线上副业';
  static const catIncomeParttimeOffline = '线下兼职';
  static const catIncomeInvestInterest = '利息收入';
  static const catIncomeInvestStock = '股基收益';
  static const catIncomeRedPacket = '红包礼金';
  static const catIncomeRefund = '退款/报销';

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
