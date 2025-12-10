package com.remark.money.dto;

import java.util.List;
import java.util.Map;

public class SyncRequest {
  private String deviceId;
  private String bookId;
  private Integer batchNum;
  private Integer totalBatches;
  private List<Map<String, Object>> bills;

  public String getDeviceId() {
    return deviceId;
  }

  public void setDeviceId(String deviceId) {
    this.deviceId = deviceId;
  }

  public String getBookId() {
    return bookId;
  }

  public void setBookId(String bookId) {
    this.bookId = bookId;
  }

  public Integer getBatchNum() {
    return batchNum;
  }

  public void setBatchNum(Integer batchNum) {
    this.batchNum = batchNum;
  }

  public Integer getTotalBatches() {
    return totalBatches;
  }

  public void setTotalBatches(Integer totalBatches) {
    this.totalBatches = totalBatches;
  }

  public List<Map<String, Object>> getBills() {
    return bills;
  }

  public void setBills(List<Map<String, Object>> bills) {
    this.bills = bills;
  }
}

