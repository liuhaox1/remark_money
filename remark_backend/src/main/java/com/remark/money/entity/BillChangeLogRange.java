package com.remark.money.entity;

public class BillChangeLogRange {
  private Long maxChangeId;
  private Long minKeptChangeId;

  public Long getMaxChangeId() {
    return maxChangeId;
  }

  public void setMaxChangeId(Long maxChangeId) {
    this.maxChangeId = maxChangeId;
  }

  public Long getMinKeptChangeId() {
    return minKeptChangeId;
  }

  public void setMinKeptChangeId(Long minKeptChangeId) {
    this.minKeptChangeId = minKeptChangeId;
  }
}

