import 'validators.dart';

/// 数据验证工具类（别名，保持向后兼容）
/// 
/// ValidationUtils 作为 Validators 的别名，用于向后兼容现有代码
class ValidationUtils {
  ValidationUtils._();

  /// 验证金额
  static String? validateAmount(double? value) => Validators.validateAmount(value);

  /// 验证金额字符串
  static String? validateAmountString(String? value) => Validators.validateAmountString(value);

  /// 验证必填字段
  static String? validateRequired(String? value, String fieldName) => Validators.validateRequired(value, fieldName);

  /// 验证字符串长度
  static String? validateLength(String? value, String fieldName, int maxLength, {int? minLength}) =>
      Validators.validateLength(value, fieldName, maxLength, minLength: minLength);

  /// 验证备注
  static String? validateRemark(String? value) => Validators.validateRemark(value);

  /// 验证账户名称
  static String? validateAccountName(String? value) => Validators.validateAccountName(value);

  /// 验证分类名称
  static String? validateCategoryName(String? value) => Validators.validateCategoryName(value);

  /// 验证账本名称
  static String? validateBookName(String? value) => Validators.validateBookName(value);

  /// 验证日期
  static String? validateDate(DateTime? value) => Validators.validateDate(value);

  /// 验证日期范围
  static String? validateDateRange(DateTime? start, DateTime? end) => Validators.validateDateRange(start, end);

  /// 验证分类选择
  static String? validateCategory(String? categoryKey) => Validators.validateCategory(categoryKey);

  /// 验证账户选择
  static String? validateAccount(String? accountId) => Validators.validateAccount(accountId);
}
