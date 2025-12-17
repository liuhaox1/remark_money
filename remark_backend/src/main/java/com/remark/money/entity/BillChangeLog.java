package com.remark.money.entity;

import java.time.LocalDateTime;

public class BillChangeLog {
  private Long changeId;
  private String bookId;
  private Long scopeUserId;
  private Long billId;
  private Integer op; // 0=upsert,1=delete
  private Long billVersion;
  private LocalDateTime createdAt;

  public BillChangeLog() {
  }

  public BillChangeLog(String bookId, Long scopeUserId, Long billId, Integer op, Long billVersion) {
    this.bookId = bookId;
    this.scopeUserId = scopeUserId;
    this.billId = billId;
    this.op = op;
    this.billVersion = billVersion;
  }

  public Long getChangeId() {
    return changeId;
  }

  public void setChangeId(Long changeId) {
    this.changeId = changeId;
  }

  public String getBookId() {
    return bookId;
  }

  public void setBookId(String bookId) {
    this.bookId = bookId;
  }

  public Long getScopeUserId() {
    return scopeUserId;
  }

  public void setScopeUserId(Long scopeUserId) {
    this.scopeUserId = scopeUserId;
  }

  public Long getBillId() {
    return billId;
  }

  public void setBillId(Long billId) {
    this.billId = billId;
  }

  public Integer getOp() {
    return op;
  }

  public void setOp(Integer op) {
    this.op = op;
  }

  public Long getBillVersion() {
    return billVersion;
  }

  public void setBillVersion(Long billVersion) {
    this.billVersion = billVersion;
  }

  public LocalDateTime getCreatedAt() {
    return createdAt;
  }

  public void setCreatedAt(LocalDateTime createdAt) {
    this.createdAt = createdAt;
  }
}
