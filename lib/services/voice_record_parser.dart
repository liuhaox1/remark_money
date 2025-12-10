import '../models/category.dart';

/// 语音记账文本解析器
/// 
/// 解析语音识别的文本，提取金额、分类、备注等信息
/// 支持的语音格式示例：
/// - "支出 50 元 吃饭"
/// - "收入 1000 工资"
/// - "50 块 买咖啡"
/// - "今天花了 30 元 打车"
class VoiceRecordParser {
  /// 解析语音文本
  /// 
  /// 返回解析结果，包含：
  /// - amount: 金额
  /// - isExpense: 是否为支出（true=支出，false=收入）
  /// - remark: 备注
  /// - categoryHint: 分类提示词（用于匹配分类）
  static ParsedRecord? parse(String text) {
    if (text.trim().isEmpty) return null;

    final normalized = text.trim();

    // 提取金额
    final amount = _extractAmount(normalized);
    if (amount == null || amount <= 0) {
      return null;
    }

    // 判断是收入还是支出
    final isExpense = _isExpense(normalized);

    // 提取备注和分类提示
    final remarkAndCategory = _extractRemarkAndCategory(normalized, amount);

    return ParsedRecord(
      amount: amount,
      isExpense: isExpense,
      remark: remarkAndCategory['remark'] ?? '',
      categoryHint: remarkAndCategory['categoryHint'] ?? '',
    );
  }

  /// 提取金额
  static double? _extractAmount(String text) {
    // 匹配数字（支持小数）
    // 例如：50、50.5、50元、50块、五十、五十块等
    final patterns = [
      // 阿拉伯数字 + 单位
      RegExp(r'(\d+\.?\d*)\s*[元块]'),
      // 纯阿拉伯数字
      RegExp(r'(\d+\.?\d*)'),
      // 中文数字（简化版，只处理常见情况）
      RegExp(r'([一二三四五六七八九十百千万]+)\s*[元块]'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amountStr = match.group(1);
        if (amountStr != null) {
          // 如果是中文数字，转换为阿拉伯数字
          if (RegExp(r'[一二三四五六七八九十百千万]').hasMatch(amountStr)) {
            final amount = _chineseToNumber(amountStr);
            if (amount != null) return amount;
          } else {
            return double.tryParse(amountStr);
          }
        }
      }
    }

    return null;
  }

  /// 判断是收入还是支出
  static bool _isExpense(String text) {
    // 支出关键词
    final expenseKeywords = [
      '支出',
      '花了',
      '花费',
      '消费',
      '买',
      '付',
      '支付',
      '用',
      '花',
    ];

    // 收入关键词
    final incomeKeywords = [
      '收入',
      '赚',
      '收到',
      '获得',
      '工资',
      '奖金',
      '红包',
    ];

    final lowerText = text.toLowerCase();

    // 优先检查收入关键词
    for (final keyword in incomeKeywords) {
      if (lowerText.contains(keyword)) {
        return false; // 收入
      }
    }

    // 检查支出关键词
    for (final keyword in expenseKeywords) {
      if (lowerText.contains(keyword)) {
        return true; // 支出
      }
    }

    // 默认是支出
    return true;
  }

  /// 提取备注和分类提示
  static Map<String, String> _extractRemarkAndCategory(String text, double amount) {
    // 移除金额和单位
    String cleaned = text
        .replaceAll(RegExp(r'\d+\.?\d*\s*[元块]'), '')
        .replaceAll(RegExp(r'\d+\.?\d*'), '')
        .replaceAll(RegExp(r'[一二三四五六七八九十百千万]+\s*[元块]'), '')
        .trim();

    // 移除常见动词和助词
    final stopWords = [
      '支出',
      '收入',
      '花了',
      '花费',
      '消费',
      '买',
      '付',
      '支付',
      '用',
      '花',
      '赚',
      '收到',
      '获得',
      '的',
      '了',
      '元',
      '块',
      '钱',
    ];

    for (final word in stopWords) {
      cleaned = cleaned.replaceAll(word, ' ').trim();
    }

    // 提取分类提示词（通常是第一个或第二个词）
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    String categoryHint = '';
    String remark = '';

    if (words.isNotEmpty) {
      // 第一个词作为分类提示
      categoryHint = words[0];
      // 剩余作为备注
      remark = words.length > 1 ? words.sublist(1).join(' ') : words[0];
    } else {
      remark = cleaned;
    }

    return {
      'remark': remark.isEmpty ? cleaned : remark,
      'categoryHint': categoryHint,
    };
  }

  /// 中文数字转阿拉伯数字（简化版）
  static double? _chineseToNumber(String chinese) {
    final map = {
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
      '十': 10,
      '百': 100,
      '千': 1000,
      '万': 10000,
    };

    // 简化处理：只处理简单的数字
    // 例如：五十 = 50，一百 = 100
    if (chinese.contains('十')) {
      if (chinese.startsWith('十')) {
        return 10.0;
      }
      // 五十、六十等
      for (final entry in map.entries) {
        if (chinese.startsWith(entry.key) && chinese.contains('十')) {
          return (entry.value * 10).toDouble();
        }
      }
    }

    // 处理百、千、万
    for (final entry in map.entries) {
      if (chinese.contains(entry.key)) {
        return entry.value.toDouble();
      }
    }

    return null;
  }

  /// 根据分类提示词匹配分类
  static Category? matchCategory(String categoryHint, List<Category> categories) {
    if (categoryHint.isEmpty) return null;

    final hint = categoryHint.toLowerCase();

    // 精确匹配
    for (final category in categories) {
      if (category.name.toLowerCase().contains(hint) ||
          hint.contains(category.name.toLowerCase())) {
        return category;
      }
    }

    // 模糊匹配（关键词映射）
    final keywordMap = {
      '吃饭': ['餐饮', '食物', '餐厅', '外卖'],
      '交通': ['出行', '打车', '地铁', '公交', '油费'],
      '购物': ['购物', '买', '商品'],
      '娱乐': ['娱乐', '电影', '游戏', 'KTV'],
      '医疗': ['医疗', '医院', '看病', '药'],
      '教育': ['教育', '学习', '培训', '学费'],
      '工资': ['工资', '薪资', '收入'],
      '奖金': ['奖金', '奖励'],
    };

    for (final entry in keywordMap.entries) {
      if (hint.contains(entry.key)) {
        for (final keyword in entry.value) {
          for (final category in categories) {
            if (category.name.contains(keyword)) {
              return category;
            }
          }
        }
      }
    }

    return null;
  }
}

/// 解析结果
class ParsedRecord {
  final double amount;
  final bool isExpense;
  final String remark;
  final String categoryHint;

  ParsedRecord({
    required this.amount,
    required this.isExpense,
    required this.remark,
    required this.categoryHint,
  });

  @override
  String toString() {
    return 'ParsedRecord(amount: $amount, isExpense: $isExpense, remark: $remark, categoryHint: $categoryHint)';
  }
}

