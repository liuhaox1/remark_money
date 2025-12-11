package com.remark.money.entity;

import java.time.LocalDateTime;

public class SyncRecord {
  private Long id;
  private Long userId;
  private String bookId;
  private String deviceId;
  private Long lastSyncId;
  private LocalDateTime lastSyncTime;
  private Integer cloudBillCount;
  private String syncDeviceId;
  private Long dataVersion; // 数据版本号
  private LocalDateTime createdAt;
  private LocalDateTime updatedAt;

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

  public String getDeviceId() {
    return deviceId;
  }

  public void setDeviceId(String deviceId) {
    this.deviceId = deviceId;
  }

  public Long getLastSyncId() {
    return lastSyncId;
  }

  public void setLastSyncId(Long lastSyncId) {
    this.lastSyncId = lastSyncId;
  }

  public LocalDateTime getLastSyncTime() {
    return lastSyncTime;
  }

  public void setLastSyncTime(LocalDateTime lastSyncTime) {
    this.lastSyncTime = lastSyncTime;
  }

  public Integer getCloudBillCount() {
    return cloudBillCount;
  }

  public void setCloudBillCount(Integer cloudBillCount) {
    this.cloudBillCount = cloudBillCount;
  }

  public String getSyncDeviceId() {
    return syncDeviceId;
  }

  public void setSyncDeviceId(String syncDeviceId) {
    this.syncDeviceId = syncDeviceId;
  }

  public LocalDateTime getCreatedAt() {
    return createdAt;
  }

  public void setCreatedAt(LocalDateTime createdAt) {
    this.createdAt = createdAt;
  }

  public LocalDateTime getUpdatedAt() {
    return updatedAt;
  }

  public void setUpdatedAt(LocalDateTime updatedAt) {
    this.updatedAt = updatedAt;
  }

  public Long getDataVersion() {
    return dataVersion;
  }

  public void setDataVersion(Long dataVersion) {
    this.dataVersion = dataVersion;
  }
}

