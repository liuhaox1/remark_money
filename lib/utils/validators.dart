/// 数据验证工具类
/// 提供统一的数据验证方法
class Validators {
  Validators._();

  /// 金额最小值
  static const double minAmount = 0.01;

  /// 金额最大值
  static const double maxAmount = 999999999.99;

  /// 备注最大长度
  static const int maxRemarkLength = 200;

  /// 账户名称最大长度
  static const int maxAccountNameLength = 50;

  /// 分类名称最大长度
  static const int maxCategoryNameLength = 20;

  /// 账本名称最大长度
  static const int maxBookNameLength = 30;

  /// 日期最小值（1900-01-01）
  static final DateTime minDate = DateTime(1900, 1, 1);

  /// 日期最大值（2100-12-31）
  static final DateTime maxDate = DateTime(2100, 12, 31);

  /// 验证金额
  /// 
  /// [value] 金额值
  /// 返回验证结果，null 表示验证通过，否则返回错误消息
  static String? validateAmount(double? value) {
    if (value == null) {
      return '请输入金额';
    }

    if (value.isNaN || value.isInfinite) {
      return '金额格式错误';
    }

    if (value < minAmount) {
      return '金额不能小于 ${minAmount.toStringAsFixed(2)}';
    }

    if (value > maxAmount) {
      return '金额不能大于 ${(maxAmount / 10000).toStringAsFixed(2)} 万';
    }

    // 检查小数位数（最多2位）
    final str = value.toString();
    final dotIndex = str.indexOf('.');
    if (dotIndex != -1 && str.length - dotIndex - 1 > 2) {
      return '金额最多保留2位小数';
    }

    return null;
  }

  /// 验证金额字符串
  /// 
  /// [value] 金额字符串
  /// 返回验证结果，null 表示验证通过，否则返回错误消息
  static String? validateAmountString(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入金额';
    }

    final normalized = value.trim().startsWith('.') ? '0$value' : value.trim();
    final parsed = double.tryParse(normalized);

    if (parsed == null) {
      return '请输入有效的金额';
    }

    return validateAmount(parsed);
  }

  /// 验证必填字段
  /// 
  /// [value] 字段值
  /// [fieldName] 字段名称（用于错误消息）
  /// 返回验证结果，null 表示验证通过，否则返回错误消息
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '请输入$fieldName';
    }
    return null;
  }

  /// 验证字符串长度
  /// 
  /// [value] 字符串值
  /// [fieldName] 字段名称
  /// [maxLength] 最大长度
  /// [minLength] 最小长度（可选）
  /// 返回验证结果，null 表示验证通过，否则返回错误消息
  static String? validateLength(
    String? value,
    String fieldName,
    int maxLength, {
    int? minLength,
  }) {
    if (value == null) {
      return null; // 允许为空，使用 validateRequired 检查必填
    }

    if (minLength != null && value.length < minLength) {
      return '$fieldName至少需要 $minLength 个字符';
    }

    if (value.length > maxLength) {
      return '$fieldName不能超过 $maxLength 个字符';
    }

    return null;
  }

  /// 验证备注
  /// 
  /// [value] 备注内容
  /// 返回验证结果，null 表示验证通过，否则返回错误消息
  static String? validateRemark(String? value) {
    return validateLength(value, '备注', maxRemarkLength);
  }

  /// 验证账户名称
  /// 
  /// [value] 账户名称
  /// 返回验证结果，null 表示验证通过，否则返回错误消息
  static String? validateAccountName(String? value) {
    final requiredError = validateRequired(value, '账户名称');
    if (requiredError != null) return requiredError;

    return validateLength(value, '账户名称', maxAccountNameLength, minLength: 1);
  }

  /// 验证分类名称
  /// 
  /// [value] 分类名称
  /// 返回验证结果，null 表示验证通过，否则返回错误消息
  static String? validateCategoryName(String? value) {
    final requiredError = validateRequired(value, '分类名称');
    if (requiredError != null) return requiredError;

    return validateLength(value, '分类名称', maxCategoryNameLength, minLength: 1);
  }

  /// 验证账本名称
  /// 
  /// [value] 账本名称
  /// 返回验证结果，null 表示验证通过，否则返回错误消息
  static String? validateBookName(String? value) {
    final requiredError = validateRequired(value, '账本名称');
    if (requiredError != null) return requiredError;

    return validateLength(value, '账本名称', maxBookNameLength, minLength: 1);
  }

  /// 验证日期
  /// 
  /// [value] 日期值
  /// 返回验证结果，null 表示验证通过，否则返回错误消息
  static String? validateDate(DateTime? value) {
    if (value == null) {
      return '请选择日期';
    }

    if (value.isBefore(minDate)) {
      return '日期不能早于 ${minDate.year} 年';
    }

    if (value.isAfter(maxDate)) {
      return '日期不能晚于 ${maxDate.year} 年';
    }

    return null;
  }

  /// 验证日期范围
  /// 
  /// [start] 开始日期
  /// [end] 结束日期
  /// 返回验证结果，null 表示验证通过，否则返回错误消息
  static String? validateDateRange(DateTime? start, DateTime? end) {
    final startError = validateDate(start);
    if (startError != null) return startError;

    final endError = validateDate(end);
    if (endError != null) return endError;

    if (start != null && end != null && start.isAfter(end)) {
      return '开始日期不能晚于结束日期';
    }

    return null;
  }

  /// 验证分类选择
  /// 
  /// [categoryKey] 分类 key
  /// 返回验证结果，null 表示验证通过，否则返回错误消息
  static String? validateCategory(String? categoryKey) {
    if (categoryKey == null || categoryKey.isEmpty) {
      return '请选择分类';
    }
    return null;
  }

  /// 验证账户选择
  /// 
  /// [accountId] 账户 ID
  /// 返回验证结果，null 表示验证通过，否则返回错误消息
  static String? validateAccount(String? accountId) {
    if (accountId == null || accountId.isEmpty) {
      return '请选择账户';
    }
    return null;
  }
}

