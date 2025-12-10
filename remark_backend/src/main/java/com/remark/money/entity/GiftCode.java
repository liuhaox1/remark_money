package com.remark.money.entity;

import java.time.LocalDateTime;

public class GiftCode {
  private Long id;
  private String code;
  private Integer status; // 0 unused,1 used,2 expired
  private Long usedBy;
  private LocalDateTime usedAt;
  private LocalDateTime expireAt;
  private Integer planType; // 1=3元档
  private Integer durationMonths;
  private Integer version;
  private LocalDateTime createdAt;

  public Long getId() { return id; }
  public void setId(Long id) { this.id = id; }

  public String getCode() { return code; }
  public void setCode(String code) { this.code = code; }

  public Integer getStatus() { return status; }
  public void setStatus(Integer status) { this.status = status; }

  public Long getUsedBy() { return usedBy; }
  public void setUsedBy(Long usedBy) { this.usedBy = usedBy; }

  public LocalDateTime getUsedAt() { return usedAt; }
  public void setUsedAt(LocalDateTime usedAt) { this.usedAt = usedAt; }

  public LocalDateTime getExpireAt() { return expireAt; }
  public void setExpireAt(LocalDateTime expireAt) { this.expireAt = expireAt; }

  public Integer getPlanType() { return planType; }
  public void setPlanType(Integer planType) { this.planType = planType; }

  public Integer getDurationMonths() { return durationMonths; }
  public void setDurationMonths(Integer durationMonths) { this.durationMonths = durationMonths; }

  public Integer getVersion() { return version; }
  public void setVersion(Integer version) { this.version = version; }

  public LocalDateTime getCreatedAt() { return createdAt; }
  public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}

