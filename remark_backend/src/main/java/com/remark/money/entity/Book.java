package com.remark.money.entity;

import java.time.LocalDateTime;

public class Book {
  private Long id;
  private Long ownerId;
  private String name;
  private String inviteCode;
  private Boolean isMulti;
  private Integer status;
  private LocalDateTime createdAt;
  private LocalDateTime updatedAt;

  public Long getId() { return id; }
  public void setId(Long id) { this.id = id; }

  public Long getOwnerId() { return ownerId; }
  public void setOwnerId(Long ownerId) { this.ownerId = ownerId; }

  public String getName() { return name; }
  public void setName(String name) { this.name = name; }

  public String getInviteCode() { return inviteCode; }
  public void setInviteCode(String inviteCode) { this.inviteCode = inviteCode; }

  public Boolean getIsMulti() { return isMulti; }
  public void setIsMulti(Boolean multi) { isMulti = multi; }

  public Integer getStatus() { return status; }
  public void setStatus(Integer status) { this.status = status; }

  public LocalDateTime getCreatedAt() { return createdAt; }
  public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

  public LocalDateTime getUpdatedAt() { return updatedAt; }
  public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
}

