package com.remark.money.entity;

import java.time.LocalDateTime;

public class CategoryInfo {
  private Long id;
  private Long userId;
  private String categoryKey;
  private String name;
  private Integer iconCodePoint;
  private String iconFontFamily;
  private String iconFontPackage;
  private Integer isExpense;
  private String parentKey;
  private Integer isDelete;
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

  public String getCategoryKey() {
    return categoryKey;
  }

  public void setCategoryKey(String categoryKey) {
    this.categoryKey = categoryKey;
  }

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }

  public Integer getIconCodePoint() {
    return iconCodePoint;
  }

  public void setIconCodePoint(Integer iconCodePoint) {
    this.iconCodePoint = iconCodePoint;
  }

  public String getIconFontFamily() {
    return iconFontFamily;
  }

  public void setIconFontFamily(String iconFontFamily) {
    this.iconFontFamily = iconFontFamily;
  }

  public String getIconFontPackage() {
    return iconFontPackage;
  }

  public void setIconFontPackage(String iconFontPackage) {
    this.iconFontPackage = iconFontPackage;
  }

  public Integer getIsExpense() {
    return isExpense;
  }

  public void setIsExpense(Integer isExpense) {
    this.isExpense = isExpense;
  }

  public String getParentKey() {
    return parentKey;
  }

  public void setParentKey(String parentKey) {
    this.parentKey = parentKey;
  }

  public Integer getIsDelete() {
    return isDelete;
  }

  public void setIsDelete(Integer isDelete) {
    this.isDelete = isDelete;
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

