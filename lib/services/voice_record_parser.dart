import '../models/category.dart';

/// 语音记账文本解析器
///
/// 目标：把语音识别出来的文本解析为可保存的记账草稿。
/// 设计原则：宁可少解析，也不要把金额解析错。
///
/// 支持示例：
/// - "我今天吃饭花了30，喝水花50"
/// - "昨天工资5000，买咖啡18"
/// - "12月17日 买咖啡 18"
class VoiceRecordParser {
  /// 解析为多条记录（支持日期口语 / 显式日期）。
  static List<ParsedRecordItem> parseMany(
    String text, {
    DateTime? now,
  }) {
    final baseNow = now ?? DateTime.now();
    final normalized = text.trim();
    if (normalized.isEmpty) return const [];

    final globalDate = _extractGlobalDate(normalized, baseNow);

    final roughParts = normalized
        .split(RegExp(r'[，,。;；、\n]+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    // 如果一句里出现多次金额且包含连接词，尝试进一步拆分（避免只解析一条）
    final parts = <String>[];
    for (final part in roughParts) {
      final dateCleaned = _extractDateAndClean(part, baseNow).cleanedText;
      final hasConjunction = RegExp(r'(和|跟|以及|还有|再|然后)').hasMatch(dateCleaned);
      if (hasConjunction && _countAmountCandidates(dateCleaned) >= 2) {
        parts.addAll(
          part
              .split(RegExp(r'(?:和|跟|以及|还有|再|然后)'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
      } else {
        parts.add(part);
      }
    }

    final items = <ParsedRecordItem>[];
    for (final rawPart in parts) {
      final dateResult = _extractDateAndClean(rawPart, baseNow);
      final itemDate = dateResult.date ?? globalDate ?? baseNow;

      final amountResult = _extractAmount(dateResult.cleanedText);
      if (amountResult == null || amountResult.amount <= 0) continue;

      final isExpense = _isExpense(dateResult.cleanedText);
      final remarkAndCategory =
          _extractRemarkAndCategory(dateResult.cleanedText, amountResult.amount);

      items.add(
        ParsedRecordItem(
          amount: amountResult.amount,
          isExpense: isExpense,
          remark: remarkAndCategory['remark'] ?? '',
          categoryHint: remarkAndCategory['categoryHint'] ?? '',
          date: _applyTime(itemDate, baseNow),
        ),
      );
    }

    return items;
  }

  /// 兼容旧接口：只取第一条。
  static ParsedRecord? parse(String text) {
    final items = parseMany(text);
    if (items.isEmpty) return null;
    final first = items.first;
    return ParsedRecord(
      amount: first.amount,
      isExpense: first.isExpense,
      remark: first.remark,
      categoryHint: first.categoryHint,
    );
  }

  static DateTime? _extractGlobalDate(String text, DateTime now) {
    final dates = _extractAllDates(text, now);
    if (dates.isEmpty) return null;
    final unique = <String>{};
    DateTime? last;
    for (final d in dates) {
      unique.add('${d.year}-${d.month}-${d.day}');
      last = d;
    }
    if (unique.length == 1) return last == null ? null : _applyTime(last, now);
    return null;
  }

  static List<DateTime> _extractAllDates(String text, DateTime now) {
    final matches = <DateTime>[];

    // 显式日期：YYYY-MM-DD / YYYY年MM月DD日
    final ymd = RegExp(
      r'(\d{4})\s*(?:年|[-/])\s*(\d{1,2})\s*(?:月|[-/])\s*(\d{1,2})\s*(?:日|号)?',
    );
    for (final m in ymd.allMatches(text)) {
      final year = int.tryParse(m.group(1) ?? '');
      final month = int.tryParse(m.group(2) ?? '');
      final day = int.tryParse(m.group(3) ?? '');
      if (year == null || month == null || day == null) continue;
      final dt = _safeDate(year, month, day, now);
      if (dt != null) matches.add(dt);
    }

    // 显式日期：MM-DD / MM月DD日
    final md = RegExp(r'(\d{1,2})\s*(?:月|[-/])\s*(\d{1,2})\s*(?:日|号)?');
    for (final m in md.allMatches(text)) {
      // 避免把 YYYY-MM-DD / YYYY年MM月DD日 的后半段再匹配一遍（导致年份歧义）
      final before = text.substring(0, m.start);
      if (RegExp(r'\d{4}\s*(?:年|[-/])\s*$').hasMatch(before)) continue;

      final month = int.tryParse(m.group(1) ?? '');
      final day = int.tryParse(m.group(2) ?? '');
      if (month == null || day == null) continue;
      final dt = _safeDate(now.year, month, day, now);
      if (dt != null) matches.add(dt);
    }

    // 口语相对日期
    const relative = <String, int>{
      '大前天': -3,
      '前天': -2,
      '昨天': -1,
      '今天': 0,
      '明天': 1,
      '后天': 2,
    };
    for (final entry in relative.entries) {
      if (text.contains(entry.key)) {
        matches.add(now.add(Duration(days: entry.value)));
      }
    }

    return matches;
  }

  static _ExtractDateResult _extractDateAndClean(String text, DateTime now) {
    var cleaned = text;

    // 显式日期优先
    final ymd = RegExp(
      r'(\d{4})\s*(?:年|[-/])\s*(\d{1,2})\s*(?:月|[-/])\s*(\d{1,2})\s*(?:日|号)?',
    ).firstMatch(cleaned);
    if (ymd != null) {
      final raw = cleaned.substring(ymd.start, ymd.end);
      final year = int.tryParse(ymd.group(1) ?? '');
      final month = int.tryParse(ymd.group(2) ?? '');
      final day = int.tryParse(ymd.group(3) ?? '');
      final dt = (year != null && month != null && day != null)
          ? _safeDate(year, month, day, now)
          : null;
      cleaned = cleaned.replaceFirst(raw, ' ');
      return _ExtractDateResult(dt, cleaned.trim());
    }

    final md = RegExp(r'(\d{1,2})\s*(?:月|[-/])\s*(\d{1,2})\s*(?:日|号)?')
        .firstMatch(cleaned);
    if (md != null) {
      final raw = cleaned.substring(md.start, md.end);
      final month = int.tryParse(md.group(1) ?? '');
      final day = int.tryParse(md.group(2) ?? '');
      final dt =
          (month != null && day != null) ? _safeDate(now.year, month, day, now) : null;
      cleaned = cleaned.replaceFirst(raw, ' ');
      return _ExtractDateResult(dt, cleaned.trim());
    }

    // 相对日期（长词优先）
    const relative = <String, int>{
      '大前天': -3,
      '前天': -2,
      '昨天': -1,
      '今天': 0,
      '明天': 1,
      '后天': 2,
    };
    for (final entry in relative.entries) {
      if (cleaned.contains(entry.key)) {
        cleaned = cleaned.replaceFirst(entry.key, ' ');
        return _ExtractDateResult(
          now.add(Duration(days: entry.value)),
          cleaned.trim(),
        );
      }
    }

    return _ExtractDateResult(null, cleaned.trim());
  }

  static DateTime? _safeDate(int year, int month, int day, DateTime now) {
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    try {
      return DateTime(
        year,
        month,
        day,
        now.hour,
        now.minute,
        now.second,
        now.millisecond,
        now.microsecond,
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime _applyTime(DateTime date, DateTime now) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }

  static int _countAmountCandidates(String text) {
    final arabic = RegExp(r'(\d+(?:\.\d+)?)\s*(?:万|千)?\s*(?:元|块|￥|¥)?');
    final chinese =
        RegExp(r'([一二三四五六七八九零两十百千万]+)\s*(?:万|千)?\s*(?:元|块)?');
    return arabic.allMatches(text).length + chinese.allMatches(text).length;
  }

  static _AmountResult? _extractAmount(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return null;

    final candidates = <_AmountCandidate>[];

    // 中文金额（可能不带单位）
    final chineseAmountReg =
        RegExp(r'([一二三四五六七八九零两十百千万]+)\s*(万|千)?\s*(?:元|块)?');
    for (final m in chineseAmountReg.allMatches(normalized)) {
      final raw = m.group(1);
      if (raw == null || raw.isEmpty) continue;
      final base = _chineseToNumber(raw);
      if (base == null || base <= 0) continue;
      final unit = m.group(2);
      final multiplier = unit == '万'
          ? 10000.0
          : unit == '千'
              ? 1000.0
              : 1.0;
      final amount = base * multiplier;
      candidates.add(_AmountCandidate(amount, m.start, 2));
    }

    // 阿拉伯数字金额，优先带货币单位/万千
    final arabicAmountReg =
        RegExp(r'(\d+(?:\.\d+)?)\s*(万|千)?\s*(?:元|块|￥|¥)?');
    for (final m in arabicAmountReg.allMatches(normalized)) {
      final numStr = m.group(1);
      if (numStr == null || numStr.isEmpty) continue;
      final base = double.tryParse(numStr);
      if (base == null || base <= 0) continue;

      final unit = m.group(2);
      final multiplier = unit == '万'
          ? 10000.0
          : unit == '千'
              ? 1000.0
              : 1.0;
      final amount = base * multiplier;

      final matchedText = normalized.substring(m.start, m.end);
      var score = 0;
      if (matchedText.contains('元') ||
          matchedText.contains('块') ||
          matchedText.contains('￥') ||
          matchedText.contains('¥') ||
          unit != null) {
        score += 2;
      }

      // 前后文加权
      final leftStart = m.start >= 6 ? m.start - 6 : 0;
      final left = normalized.substring(leftStart, m.start);
      if (RegExp(r'(花|支出|收入|买|付|收|转|消费)').hasMatch(left)) {
        score += 1;
      }

      // 过滤时间/周次/序号等低置信数字
      final rightChar = m.end < normalized.length ? normalized[m.end] : '';
      final leftChar = m.start > 0 ? normalized[m.start - 1] : '';
      if (rightChar.isNotEmpty &&
          RegExp(r'(年|月|日|号|周|点|时|分|秒)').hasMatch(rightChar)) {
        score -= 2;
      }
      if (leftChar == '第') score -= 2;

      candidates.add(_AmountCandidate(amount, m.start, score));
    }

    if (candidates.isEmpty) return null;

    // 选分数最高且位置靠后的候选（更符合中文口语：描述在前，金额在后）
    candidates.sort((a, b) {
      if (a.score != b.score) return a.score.compareTo(b.score);
      return a.start.compareTo(b.start);
    });
    final best = candidates.last;
    return _AmountResult(best.amount);
  }

  static bool _isExpense(String text) {
    const expenseKeywords = [
      '支出',
      '花了',
      '花费',
      '消费',
      '买',
      '付款',
      '支付',
      '转出',
      '扣款',
    ];

    const incomeKeywords = [
      '收入',
      '赚',
      '收到',
      '收到了',
      '获得',
      '工资',
      '奖金',
      '红包',
      '退款',
      '报销',
    ];

    final lowerText = text.toLowerCase();

    for (final keyword in incomeKeywords) {
      if (lowerText.contains(keyword)) return false;
    }
    for (final keyword in expenseKeywords) {
      if (lowerText.contains(keyword)) return true;
    }
    return true;
  }

  static Map<String, String> _extractRemarkAndCategory(String text, double amount) {
    var cleaned = text
        // 移除阿拉伯金额
        .replaceAll(RegExp(r'\d+(?:\.\d+)?\s*(?:万|千)?\s*(?:人民币|rmb|RMB)?\s*(?:元|块钱|块|钱|￥|¥)?'), ' ')
        // 移除中文金额
        .replaceAll(RegExp(r'[一二三四五六七八九零两十百千万]+\s*(?:万|千)?\s*(?:人民币)?\s*(?:元|块钱|块|钱)?'), ' ')
        .trim();

    const stopWords = [
      '支出',
      '收入',
      '花了',
      '花费',
      '消费',
      '付款',
      '支付',
      '转账',
      '转出',
      '转入',
      '收到',
      '获得',
      '的',
      '了',
      '在',
      '一下',
      '一笔',
      '记账',
      '记录',
      '我',
      '帮我',
    ];

    for (final word in stopWords) {
      cleaned = cleaned.replaceAll(word, ' ');
    }

    cleaned = cleaned.replaceAll(RegExp(r'[，,。;；、]'), ' ');
    // Remove leftover currency tokens (e.g. leading "¥" before number, or "毛钱").
    cleaned = cleaned.replaceAll(RegExp('[\\u00A5\\uFFE5]'), ' ');
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(?:(?<=\s)|^)(?:\u4eba\u6c11\u5e01|rmb|RMB|\u5143|\u5757\u94b1|\u5757|\u94b1|\u6bdb\u94b1|\u6bdb|\u89d2)(?=\s|$)',
      ),
      ' ',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 处理口语里“花100/用100”这种结构：金额被移除后，尾部会残留动词（如：打车花）。
    cleaned = cleaned.replaceAll(
      RegExp(r'(?:花了|花费|消费|用了|支付|付款|花|用|付)\s*$'),
      ' ',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return {'remark': '', 'categoryHint': ''};

    final categoryHint = words.first;
    final remark = words.length > 1 ? words.sublist(1).join(' ') : words.first;
    return {'remark': remark, 'categoryHint': categoryHint};
  }

  static double? _chineseToNumber(String chinese) {
    final digits = <String, int>{
      '零': 0,
      '一': 1,
      '二': 2,
      '两': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };
    final units = <String, int>{
      '十': 10,
      '百': 100,
      '千': 1000,
    };

    var result = 0;
    var section = 0;
    var number = 0;

    for (final rune in chinese.runes) {
      final ch = String.fromCharCode(rune);
      if (digits.containsKey(ch)) {
        number = digits[ch]!;
        continue;
      }

      if (units.containsKey(ch)) {
        final unit = units[ch]!;
        final n = number == 0 ? 1 : number;
        section += n * unit;
        number = 0;
        continue;
      }

      if (ch == '万') {
        section += number;
        result += section * 10000;
        section = 0;
        number = 0;
        continue;
      }
    }

    return (result + section + number).toDouble();
  }

  /// 根据分类提示词匹配分类
  static Category? matchCategory(String categoryHint, List<Category> categories) {
    if (categoryHint.trim().isEmpty) return null;
    final hint = categoryHint.toLowerCase();

    // 精确/包含匹配
    for (final category in categories) {
      final name = category.name.toLowerCase();
      if (name.contains(hint) || hint.contains(name)) return category;
    }

    // 模糊匹配（关键字映射）
    final keywordMap = <String, List<String>>{
      '吃饭': ['餐饮', '餐', '外卖', '早餐', '午餐', '晚餐', '宵夜', '食物'],
      '喝水': ['餐饮', '饮料', '水', '咖啡', '奶茶'],
      '咖啡': ['餐饮', '饮料', '咖啡'],
      '奶茶': ['餐饮', '饮料', '奶茶'],
      '饮料': ['餐饮', '饮料'],
      '打车': ['出行', '交通', '打车', '滴滴'],
      '地铁': ['出行', '交通', '地铁'],
      '公交': ['出行', '交通', '公交'],
      '加油': ['交通', '出行', '油', '油费'],
      '购物': ['购物', '商品', '买'],
      // 个人护理/洗护：没有“洗澡”专属分类时，优先落到“美妆护肤”而不是误判为“餐饮”
      '洗澡': ['美妆', '护肤', '美容', '洗浴', '家政'],
      '洗浴': ['美妆', '护肤', '美容', '洗浴', '家政'],
      '沐浴': ['美妆', '护肤', '美容', '洗浴', '家政'],
      '理发': ['美妆', '护肤', '美容', '美发'],
      '美甲': ['美妆', '护肤', '美容'],
      'spa': ['美妆', '护肤', '美容', '健康'],
      '电影': ['娱乐', '电影'],
      '游戏': ['娱乐', '游戏'],
      '医疗': ['医疗', '医院', '看病', '药'],
      '教育': ['教育', '学习', '培训', '学费'],
      '工资': ['工资', '薪资', '收入'],
      '奖金': ['奖金', '收入'],
    };

    for (final entry in keywordMap.entries) {
      if (!hint.contains(entry.key)) continue;
      for (final keyword in entry.value) {
        for (final category in categories) {
          if (category.name.contains(keyword)) return category;
        }
      }
    }

    return null;
  }
}

class _ExtractDateResult {
  final DateTime? date;
  final String cleanedText;

  const _ExtractDateResult(this.date, this.cleanedText);
}

class _AmountResult {
  final double amount;

  const _AmountResult(this.amount);
}

class _AmountCandidate {
  final double amount;
  final int start;
  final int score;

  const _AmountCandidate(this.amount, this.start, this.score);
}

/// 兼容旧版本的单条解析结果
class ParsedRecord {
  final double amount;
  final bool isExpense;
  final String remark;
  final String categoryHint;

  const ParsedRecord({
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

/// 多条解析结果项（用于“发送解析→预览→批量保存”）
class ParsedRecordItem {
  final double amount;
  final bool isExpense;
  final String remark;
  final String categoryHint;
  final DateTime date;

  const ParsedRecordItem({
    required this.amount,
    required this.isExpense,
    required this.remark,
    required this.categoryHint,
    required this.date,
  });
}
