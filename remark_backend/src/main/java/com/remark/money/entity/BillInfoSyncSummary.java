package com.remark.money.entity;

public class BillInfoSyncSummary {
  private Integer billCount;
  private Long sumIds;
  private Long sumVersions;

  public Integer getBillCount() {
    return billCount;
  }

  public void setBillCount(Integer billCount) {
    this.billCount = billCount;
  }

  public Long getSumIds() {
    return sumIds;
  }

  public void setSumIds(Long sumIds) {
    this.sumIds = sumIds;
  }

  public Long getSumVersions() {
    return sumVersions;
  }

  public void setSumVersions(Long sumVersions) {
    this.sumVersions = sumVersions;
  }
}

