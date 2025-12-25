package com.remark.money.entity;

import java.time.LocalDateTime;

public class BillDeleteTombstone {
  private String bookId;
  private Long scopeUserId;
  private Long billId;
  private Long billVersion;
  private LocalDateTime deletedAt;
  private LocalDateTime createdAt;

  public BillDeleteTombstone() {}

  public BillDeleteTombstone(String bookId, Long scopeUserId, Long billId, Long billVersion) {
    this.bookId = bookId;
    this.scopeUserId = scopeUserId;
    this.billId = billId;
    this.billVersion = billVersion;
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

  public Long getBillVersion() {
    return billVersion;
  }

  public void setBillVersion(Long billVersion) {
    this.billVersion = billVersion;
  }

  public LocalDateTime getDeletedAt() {
    return deletedAt;
  }

  public void setDeletedAt(LocalDateTime deletedAt) {
    this.deletedAt = deletedAt;
  }

  public LocalDateTime getCreatedAt() {
    return createdAt;
  }

  public void setCreatedAt(LocalDateTime createdAt) {
    this.createdAt = createdAt;
  }
}

