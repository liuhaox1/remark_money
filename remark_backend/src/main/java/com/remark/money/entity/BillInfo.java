package com.remark.money.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public class BillInfo {
  private Long id;
  private Long version; // optimistic lock version (server-managed)
  private Long userId;
  private String bookId;
  private String accountId;
  private String categoryKey;
  private BigDecimal amount;
  private Integer direction; // 0=out支出,1=income收入
  private String remark;
  private String attachmentUrl;
  private LocalDateTime billDate;
  private Integer includeInStats;
  private String pairId;
  private Integer isDelete; // 0=有效,1=已删除
  private LocalDateTime updateTime;
  private LocalDateTime createdAt;

  // Getters and Setters
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

  public String getAccountId() {
    return accountId;
  }

  public void setAccountId(String accountId) {
    this.accountId = accountId;
  }

  public String getCategoryKey() {
    return categoryKey;
  }

  public void setCategoryKey(String categoryKey) {
    this.categoryKey = categoryKey;
  }

  public BigDecimal getAmount() {
    return amount;
  }

  public void setAmount(BigDecimal amount) {
    this.amount = amount;
  }

  public Integer getDirection() {
    return direction;
  }

  public void setDirection(Integer direction) {
    this.direction = direction;
  }

  public String getRemark() {
    return remark;
  }

  public void setRemark(String remark) {
    this.remark = remark;
  }

  public String getAttachmentUrl() {
    return attachmentUrl;
  }

  public void setAttachmentUrl(String attachmentUrl) {
    this.attachmentUrl = attachmentUrl;
  }

  public LocalDateTime getBillDate() {
    return billDate;
  }

  public void setBillDate(LocalDateTime billDate) {
    this.billDate = billDate;
  }

  public Integer getIncludeInStats() {
    return includeInStats;
  }

  public void setIncludeInStats(Integer includeInStats) {
    this.includeInStats = includeInStats;
  }

  public String getPairId() {
    return pairId;
  }

  public void setPairId(String pairId) {
    this.pairId = pairId;
  }

  public Integer getIsDelete() {
    return isDelete;
  }

  public void setIsDelete(Integer isDelete) {
    this.isDelete = isDelete;
  }

  public Long getVersion() {
    return version;
  }

  public void setVersion(Long version) {
    this.version = version;
  }

  public LocalDateTime getUpdateTime() {
    return updateTime;
  }

  public void setUpdateTime(LocalDateTime updateTime) {
    this.updateTime = updateTime;
  }

  public LocalDateTime getCreatedAt() {
    return createdAt;
  }

  public void setCreatedAt(LocalDateTime createdAt) {
    this.createdAt = createdAt;
  }
}
