package com.remark.money.entity;

import java.time.LocalDateTime;

public class SyncOpDedup {
  private Long id;
  private Long userId;
  private String bookId;
  private String opId;
  private Integer status; // 0=applied,1=conflict,2=error
  private Long billId;
  private Long billVersion;
  private String error;
  private LocalDateTime createdAt;

  public Long getId() {
    return id;
  }

  public void setId(Long id) {
    this.id = id;
  }

  public Long getUserId() {
    return userId;
  }

  public void setUserId(Long userId) {
    this.userId = userId;
  }

  public String getBookId() {
    return bookId;
  }

  public void setBookId(String bookId) {
    this.bookId = bookId;
  }

  public String getOpId() {
    return opId;
  }

  public void setOpId(String opId) {
    this.opId = opId;
  }

  public Integer getStatus() {
    return status;
  }

  public void setStatus(Integer status) {
    this.status = status;
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

  public String getError() {
    return error;
  }

  public void setError(String error) {
    this.error = error;
  }

  public LocalDateTime getCreatedAt() {
    return createdAt;
  }

  public void setCreatedAt(LocalDateTime createdAt) {
    this.createdAt = createdAt;
  }
}

