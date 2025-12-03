import '../l10n/app_strings.dart';

/// 分类名称统一管理工具类
/// 集中管理所有分类名称相关的映射和显示逻辑，避免硬编码分散在各处
class CategoryNameHelper {
  CategoryNameHelper._();

  /// 分类名称缩短映射表
  /// 用于在UI空间有限时显示更短的名称
  static const Map<String, String> shortNameMap = {
    // 一级分类：控制字数，避免挤不下
    AppStrings.catTopLiving: '居住账单',
    AppStrings.catTopFamily: '家庭人情',
    AppStrings.catTopFinance: '金融其他',
    // 容易过长的二级分类
    AppStrings.catFinLoan: '借贷还款',
    AppStrings.catFinCredit: '信用卡还款',
    AppStrings.catFinFee: '手续费',
    AppStrings.catFinTransferFee: '转账手续费',
  };

  /// 英文分类key到中文名称的映射表
  /// 用于处理导入数据或旧数据中的英文key
  static const Map<String, String> englishKeyToChineseMap = {
    // 一级分类
    'food': '餐饮',
    'shopping': '购物',
    'transport': '出行',
    'living': '居住与账单',
    'leisure': '娱乐休闲',
    'education': '教育成长',
    'health': '健康医疗',
    'family': '家庭与人情',
    'finance': '金融与其他',

    // 餐饮相关
    'meal': '正餐',
    'breakfast': '早餐',
    'snack': '零食小吃',
    'drink': '饮品',
    'takeout': '外卖',
    'supper': '夜宵',

    // 购物相关
    'daily': '日用百货',
    'supermarket': '超市采购',
    'clothes': '服饰鞋包',
    'digital': '数码家电',
    'beauty': '美妆护肤',

    // 出行相关
    'commute': '公共交通',
    'taxi': '打车',
    'drive': '油费',
    'parking': '停车费',
    'toll': '过路费',
    'maintenance': '车辆保养',
    'longtrip': '长途出行',

    // 居住相关
    'rent': '住房支出',
    'property': '物业管理费',
    'utility': '水电燃气',
    'internet': '网络',
    'tv': '电视',
    'cleaning': '家政服务',
    'repair': '维修服务',
    'decorate': '装修',
    'furniture': '家居用品',

    // 娱乐相关
    'game': '游戏',
    'media': '影音',
    'movie': '电影',
    'show': '演出',
    'sport': '运动健身',
    'travel': '旅游度假',
    'party': '聚会',
    'social': '社交',
    'hobby': '兴趣爱好',

    // 教育相关
    'course': '课程培训',
    'book': '书籍',
    'ebook': '电子书',
    'exam': '考试',
    'certificate': '证书',
    'language': '语言学习',
    'online': '在线课程',
    'tuition': '学费',
    'misc': '学杂费',

    // 健康相关
    'clinic': '门诊',
    'registration': '挂号',
    'check': '检查',
    'physical': '体检',
    'medicine': '药品',
    'surgery': '手术',
    'treatment': '治疗',
    'dental': '牙科',
    'vision': '视力',
    'insurance': '健康保险',

    // 家庭相关
    'child': '孩子相关',
    'elder': '长辈孝敬',
    'family_meal': '家庭聚餐',
    'gift': '人情礼金',
    'friends': '朋友聚会',
    'pet': '宠物',

    // 金融相关
    'loan': '借贷还款',
    'credit': '信用卡还款',
    'interest': '利息',
    'fee': '手续费',
    'transfer_fee': '转账手续费',
    'invest_loss': '投资亏损',
    'adjust': '资金调账',
  };

  /// 获取分类的显示名称（优先使用缩短版本）
  /// 
  /// [categoryName] 分类的原始名称（来自 AppStrings 或 Category.name）
  /// 返回缩短后的名称，如果没有缩短版本则返回原始名称
  static String getDisplayName(String categoryName) {
    return shortNameMap[categoryName] ?? categoryName;
  }

  /// 未分类的默认名称
  static const String unknownCategoryName = '未分类';

  /// 将英文分类key转换为中文名称
  /// 
  /// [key] 英文分类key（可能是完整的key或部分匹配）
  /// 返回对应的中文名称，如果找不到则返回"未分类"
  static String mapEnglishKeyToChinese(String key) {
    // 如果 key 完全匹配，直接返回
    if (englishKeyToChineseMap.containsKey(key)) {
      return englishKeyToChineseMap[key]!;
    }

    // 如果 key 包含常见前缀，尝试匹配
    for (final entry in englishKeyToChineseMap.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }

    // 如果都找不到，返回"未分类"
    return unknownCategoryName;
  }
}

