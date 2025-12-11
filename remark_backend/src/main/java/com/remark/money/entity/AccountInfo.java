package com.remark.money.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public class AccountInfo {
  private Long id; // 服务器自增ID
  private Long userId;
  private String accountId; // 客户端临时ID（可选，用于首次上传匹配）
  private String name;
  private String kind; // asset, liability, lend
  private String subtype; // cash, saving_card, etc.
  private String type; // cash, bankCard, eWallet, etc.
  private String icon;
  private Integer includeInTotal;
  private Integer includeInOverview;
  private String currency;
  private Integer sortOrder;
  private BigDecimal initialBalance;
  private BigDecimal currentBalance;
  private String counterparty;
  private BigDecimal interestRate;
  private LocalDateTime dueDate;
  private String note;
  private String brandKey;
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

  public String getAccountId() {
    return accountId;
  }

  public void setAccountId(String accountId) {
    this.accountId = accountId;
  }

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }

  public String getKind() {
    return kind;
  }

  public void setKind(String kind) {
    this.kind = kind;
  }

  public String getSubtype() {
    return subtype;
  }

  public void setSubtype(String subtype) {
    this.subtype = subtype;
  }

  public String getType() {
    return type;
  }

  public void setType(String type) {
    this.type = type;
  }

  public String getIcon() {
    return icon;
  }

  public void setIcon(String icon) {
    this.icon = icon;
  }

  public Integer getIncludeInTotal() {
    return includeInTotal;
  }

  public void setIncludeInTotal(Integer includeInTotal) {
    this.includeInTotal = includeInTotal;
  }

  public Integer getIncludeInOverview() {
    return includeInOverview;
  }

  public void setIncludeInOverview(Integer includeInOverview) {
    this.includeInOverview = includeInOverview;
  }

  public String getCurrency() {
    return currency;
  }

  public void setCurrency(String currency) {
    this.currency = currency;
  }

  public Integer getSortOrder() {
    return sortOrder;
  }

  public void setSortOrder(Integer sortOrder) {
    this.sortOrder = sortOrder;
  }

  public BigDecimal getInitialBalance() {
    return initialBalance;
  }

  public void setInitialBalance(BigDecimal initialBalance) {
    this.initialBalance = initialBalance;
  }

  public BigDecimal getCurrentBalance() {
    return currentBalance;
  }

  public void setCurrentBalance(BigDecimal currentBalance) {
    this.currentBalance = currentBalance;
  }

  public String getCounterparty() {
    return counterparty;
  }

  public void setCounterparty(String counterparty) {
    this.counterparty = counterparty;
  }

  public BigDecimal getInterestRate() {
    return interestRate;
  }

  public void setInterestRate(BigDecimal interestRate) {
    this.interestRate = interestRate;
  }

  public LocalDateTime getDueDate() {
    return dueDate;
  }

  public void setDueDate(LocalDateTime dueDate) {
    this.dueDate = dueDate;
  }

  public String getNote() {
    return note;
  }

  public void setNote(String note) {
    this.note = note;
  }

  public String getBrandKey() {
    return brandKey;
  }

  public void setBrandKey(String brandKey) {
    this.brandKey = brandKey;
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

