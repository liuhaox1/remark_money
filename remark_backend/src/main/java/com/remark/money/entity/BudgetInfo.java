package com.remark.money.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public class BudgetInfo {
  private Long id;
  private Long userId;
  private String bookId;
  private BigDecimal total;
  private String categoryBudgets; // JSON text
  private Integer periodStartDay;
  private BigDecimal annualTotal;
  private String annualCategoryBudgets; // JSON text
  private LocalDateTime updateTime;
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

  public BigDecimal getTotal() {
    return total;
  }

  public void setTotal(BigDecimal total) {
    this.total = total;
  }

  public String getCategoryBudgets() {
    return categoryBudgets;
  }

  public void setCategoryBudgets(String categoryBudgets) {
    this.categoryBudgets = categoryBudgets;
  }

  public Integer getPeriodStartDay() {
    return periodStartDay;
  }

  public void setPeriodStartDay(Integer periodStartDay) {
    this.periodStartDay = periodStartDay;
  }

  public BigDecimal getAnnualTotal() {
    return annualTotal;
  }

  public void setAnnualTotal(BigDecimal annualTotal) {
    this.annualTotal = annualTotal;
  }

  public String getAnnualCategoryBudgets() {
    return annualCategoryBudgets;
  }

  public void setAnnualCategoryBudgets(String annualCategoryBudgets) {
    this.annualCategoryBudgets = annualCategoryBudgets;
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

