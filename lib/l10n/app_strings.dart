import 'package:flutter/material.dart';
import '../utils/date_utils.dart';

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
  static const navStats = '账单';
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
  
  // Search
  static const searchHint = '搜索备注、分类、金额（支持跨月）';
  static const recentSearches = '最近搜索';
  static const clearHistory = '清空';
  static const matchedCategories = '匹配的分类';
  
  // Filter
  static const filterByAccount = '按账户筛选';
  static const selectedConditions = '已选条件';
  static const foundRecords = '找到 {count} 条记录';
  static const searchCategory = '搜索分类';
  static const quickAmountOptions = '快捷金额';
  static const customAmount = '自定义金额';
  static const quickDateOptions = '快捷日期';
  static const customDate = '自定义日期';
  static const minAmountGreaterThanMax = '最小金额不能大于最大金额';
  static const startDateGreaterThanEnd = '开始日期不能大于结束日期';
  static const amountLessThan100 = '< 100';
  static const amount100To500 = '100 - 500';
  static const amount500To1000 = '500 - 1000';
  static const amountGreaterThan1000 = '> 1000';
  static const dateToday = '今天';
  static const dateThisWeek = '本周';
  static const dateThisMonth = '本月';
  static const dateLastMonth = '上月';
  static const dateThisYear = '今年';
  static const clearAllFilters = '清空筛选';
  static const expand = '展开';
  static const collapse = '收起';
  static const selectAll = '全选';
  static const deselectAll = '全不选';
  static const noAccounts = '暂无账户';
  static const noSearchResults = '暂无搜索结果';
  static const searchHistoryEmpty = '暂无搜索历史';

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
  static const yearlyBill = '年账单';
  static const monthlyBill = '月账单';
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
  // 收入一级
  static const catTopIncomeSalary = '工资收入';
  static const catTopIncomeParttime = '兼职收入';
  static const catTopIncomeInvest = '投资理财';
  static const catTopIncomeOther = '其他收入';

  // 工资收入 - 二级
  static const catIncomeBasicSalary = '基本工资';
  static const catIncomeBonus = '奖金提成';
  static const catIncomeYearEnd = '年终奖';

  // 兼职收入 - 二级
  static const catIncomeParttimeOnline = '线上兼职';
  static const catIncomeParttimeOffline = '线下兼职';

  // 投资理财 - 二级
  static const catIncomeInvestFund = '基金';
  static const catIncomeInvestStock = '股票';
  static const catIncomeInvestBond = '债券';
  static const catIncomeInvestInterest = '理财收益';
  static const catIncomeRental = '租金收入';

  // 其他收入 - 二级
  static const catIncomeRedPacket = '红包收入';
  static const catIncomeRefund = '退费报销';

  // ????
  static const unitYi = '亿';
  static const unitWan = '万';

  // 动态文案 / 标签
  static String yearLabel(int year) => '${year}年';
  static String monthLabel(int month) => '${month}月';
  static String yearMonthLabel(int year, int month) => '${year}年${month}月';
  static String monthDayLabel(dynamic value, [int? day]) {
    if (value is DateTime) {
      return '${value.month}月${value.day}日';
    }
    if (value is int && day != null) {
      return '${value}月${day}日';
    }
    return value.toString();
  }
  static String weekRangeLabel(DateTimeRange range) =>
      '${DateUtilsX.ymd(range.start)} ~ ${DateUtilsX.ymd(range.end)}';
  static String selectMonthLabel(DateTime month) =>
      '${month.year}年${month.month}月';
  static String monthRangeTitle(int index, int startDay, int endDay) =>
      '第${index + 1}周（${startDay}日-${endDay}日）';
  static String monthDayWithCount(int month, int day, String weekday, int count) =>
      '${month}月${day}日 ${weekday} · ${count}笔';
  static String monthExpenseWithCount(double expense, int count) =>
      '本月支出 ¥${expense.toStringAsFixed(2)} · ${count}笔';
  static String homeBudgetUsedAndTotal(double used, double total) =>
      '已用 ¥${used.toStringAsFixed(2)} / 预算 ¥${total.toStringAsFixed(2)}';
  static String homeBudgetUsageVsTime(double usedPercent, double timePercent) =>
      '用掉 ${usedPercent.toStringAsFixed(0)}% · 进度 ${timePercent.toStringAsFixed(0)}%';
  static String homeBudgetTodaySuggestion(int daysLeft, double allowance) =>
      '剩余${daysLeft}天，日均可用 ¥${allowance.toStringAsFixed(2)}';

  // 通用提示文案
  static const weekReport = '周报';
  static const weeklyBill = '周账单';
  static const pickWeek = '选择周';
  static const monthSummary = '月度汇总';
  static const annualSummary = '年度汇总';
  static const currentMonthEmpty = '本月暂无数据';
  static const emptyYearRecords = '该年份暂无记录';
  static const emptyPeriodRecords = '当前周期暂无记录';
  static const previousPeriodNoData = '上一周期暂无数据';
  static const goRecord = '去记一笔';
  static String currentBookLabel(String bookName) => '当前账本：$bookName';
  static const monthDayLabelTitle = '日账单';
  static String bookYearBudgetTitle(int year) => '$year 年度预算';
  static String bookMonthBudgetTitle(DateTime month) =>
      '${month.year}年${month.month}月预算';
  static String budgetRemainingLabel(double remaining, bool overspend) =>
      overspend
          ? '已超支 ¥${remaining.abs().toStringAsFixed(2)}'
          : '剩余额度 ¥${remaining.toStringAsFixed(2)}';
  static String budgetUsedLabel(double used, double? total) =>
      total == null
          ? '已用 ¥${used.toStringAsFixed(2)}'
          : '已用 ¥${used.toStringAsFixed(2)} / 预算 ¥${total.toStringAsFixed(2)}';
  static const selectMonthLabelTitle = '选择月份';
  static const selectMonthLabelText = '选择月份';

  // 分类名称（覆盖防丢失）
  static const catUncategorized = '其他';
  static const catTopFood = '餐饮';
  static const catFoodBreakfast = '早餐';
  static const catFoodLunch = '午餐';
  static const catFoodDinner = '晚餐';
  static const catFoodAfternoonTea = '下午茶';
  static const catFoodDrink = '饮品';
  static const catFoodSupper = '夜宵';
  static const catFoodTakeout = '外卖';

  static const catTopShopping = '购物';
  static const catShopClothes = '服饰鞋包';
  static const catShopDigital = '数码家电';
  static const catShopBeauty = '美妆护肤';
  static const catShopOther = '其他购物';

  static const catTopTransport = '出行';
  static const catTransCommute = '公共交通';
  static const catTransTaxi = '打车';
  static const catTransShare = '共享出行';
  static const catTransFuel = '油费';
  static const catTransCharging = '充电';
  static const catTransParking = '停车费';
  static const catTransToll = '过路费';
  static const catTransMaintenance = '车辆保养';
  static const catTransLongTrip = '机票火车';

  static const catTopLiving = '居住与账单';
  static const catLivingRent = '住房支出';
  static const catLivingProperty = '物业管理费';
  static const catLivingUtility = '水电燃气';
  static const catLivingInternet = '网络';
  static const catLivingTv = '电视';
  static const catLivingCleaning = '家政服务';
  static const catLivingRepair = '维修服务';
  static const catLivingDecorate = '装修';
  static const catLivingFurniture = '家居用品';

  static const catTopLeisure = '娱乐休闲';
  static const catFunGame = '游戏';
  static const catFunMedia = '影音';
  static const catFunMovie = '电影';
  static const catFunShow = '演出';
  static const catFunSport = '运动健身';
  static const catFunTravel = '旅游度假';
  static const catFunParty = '聚会';
  static const catFunHobby = '兴趣爱好';

  static const catTopEducation = '教育成长';
  static const catEduCourse = '课程培训';
  static const catEduBook = '书籍';
  static const catEduExam = '考试';
  static const catEduCertificate = '证书';
  static const catEduLanguage = '语言学习';
  static const catEduOnline = '在线课程';
  static const catEduTuition = '学费';

  static const catTopHealth = '健康医疗';
  static const catHealthClinic = '门诊';
  static const catHealthCheck = '检查';
  static const catHealthMedicine = '药品';
  static const catHealthSurgery = '手术';
  static const catHealthTreatment = '治疗';
  static const catHealthDental = '牙科';
  static const catHealthVision = '视力';
  static const catHealthInsurance = '健康保险';

  static const catTopFamily = '家庭与人情';
  static const catFamilyChild = '孩子相关';
  static const catFamilyElder = '长辈孝敬';
  static const catFamilyMeal = '家庭聚餐';
  static const catFamilyGift = '人情礼金';
  static const catFamilyFriends = '朋友聚会';
  static const catFamilyPet = '宠物';

  static const catTopFinance = '金融与其他';
  static const catFinLoan = '借贷还款';
  static const catFinCredit = '信用卡还款';
  static const catFinInterest = '利息';
  static const catFinFee = '手续费';
  static const catFinInvestLoss = '投资亏损';
  static const catFinAdjust = '账户调整';
}
