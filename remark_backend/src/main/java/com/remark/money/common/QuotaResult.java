package com.remark.money.common;

/**
 * 配额检查结果
 */
public class QuotaResult {
  private final ErrorCode errorCode;
  private final Object[] messageArgs;

  private QuotaResult(ErrorCode errorCode, Object... messageArgs) {
    this.errorCode = errorCode;
    this.messageArgs = messageArgs;
  }

  public static QuotaResult success() {
    return new QuotaResult(ErrorCode.SUCCESS);
  }

  public static QuotaResult warning(ErrorCode code, Object... args) {
    return new QuotaResult(code, args);
  }

  public static QuotaResult error(ErrorCode code, Object... args) {
    return new QuotaResult(code, args);
  }

  public boolean isSuccess() {
    return errorCode == ErrorCode.SUCCESS;
  }

  public boolean isWarning() {
    return errorCode != null && errorCode.isWarning();
  }

  public boolean isError() {
    return errorCode != null && !isSuccess() && !isWarning();
  }

  public ErrorCode getErrorCode() {
    return errorCode;
  }

  public String getMessage() {
    if (errorCode == null || errorCode == ErrorCode.SUCCESS) {
      return null;
    }
    return errorCode.getMessage(messageArgs);
  }
}

