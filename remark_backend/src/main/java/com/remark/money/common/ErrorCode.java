package com.remark.money.common;

/**
 * 错误码定义
 */
public enum ErrorCode {
  SUCCESS(0, "成功"),
  
  // 权限相关 1000-1999
  NO_SYNC_PERMISSION(1001, "无云端同步权限，请先开通付费服务"),
  PAYMENT_EXPIRED(1002, "付费已过期，请续费"),
  
  // 配额相关 2000-2999
  QUOTA_EXCEEDED(2001, "数据量超限，当前套餐最多%d条，请升级套餐"),
  QUOTA_WARNING(2002, "云存储已使用80%%，考虑升级以避免上传受限"), // 预警，不阻止操作
  
  // 数据相关 3000-3999
  USER_NOT_FOUND(3001, "用户不存在"),
  USER_INFO_ERROR(3002, "用户信息异常"),
  PLAN_TYPE_ERROR(3003, "套餐类型异常"),
  
  // 系统错误 9000-9999
  SYSTEM_ERROR(9001, "系统错误"),
  DATABASE_ERROR(9002, "数据库错误");

  private final int code;
  private final String message;

  ErrorCode(int code, String message) {
    this.code = code;
    this.message = message;
  }

  public int getCode() {
    return code;
  }

  public String getMessage() {
    return message;
  }

  public String getMessage(Object... args) {
    return String.format(message, args);
  }

  /**
   * 判断是否为预警（不阻止操作）
   */
  public boolean isWarning() {
    return this == QUOTA_WARNING;
  }
}

