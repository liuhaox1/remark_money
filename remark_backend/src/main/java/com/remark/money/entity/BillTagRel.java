package com.remark.money.entity;

import java.time.LocalDateTime;

public class BillTagRel {
  private String bookId;
  private Long scopeUserId;
  private Long billId;
  private String tagId;
  private Integer sortOrder;
  private LocalDateTime createdAt;

  public BillTagRel() {}

  public BillTagRel(String bookId, Long scopeUserId, Long billId, String tagId) {
    this.bookId = bookId;
    this.scopeUserId = scopeUserId;
    this.billId = billId;
    this.tagId = tagId;
    this.sortOrder = 0;
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

  public String getTagId() {
    return tagId;
  }

  public void setTagId(String tagId) {
    this.tagId = tagId;
  }

  public Integer getSortOrder() {
    return sortOrder;
  }

  public void setSortOrder(Integer sortOrder) {
    this.sortOrder = sortOrder;
  }

  public LocalDateTime getCreatedAt() {
    return createdAt;
  }

  public void setCreatedAt(LocalDateTime createdAt) {
    this.createdAt = createdAt;
  }
}
