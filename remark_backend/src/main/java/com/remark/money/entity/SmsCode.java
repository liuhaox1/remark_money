package com.remark.money.entity;

import java.time.LocalDateTime;

public class SmsCode {

  private Long id;
  private String phone;
  private String code;
  private LocalDateTime expiresAt;
  private Boolean used;

  public Long getId() {
    return id;
  }

  public void setId(Long id) {
    this.id = id;
  }

  public String getPhone() {
    return phone;
  }

  public void setPhone(String phone) {
    this.phone = phone;
  }

  public String getCode() {
    return code;
  }

  public void setCode(String code) {
    this.code = code;
  }

  public LocalDateTime getExpiresAt() {
    return expiresAt;
  }

  public void setExpiresAt(LocalDateTime expiresAt) {
    this.expiresAt = expiresAt;
  }

  public Boolean getUsed() {
    return used;
  }

  public void setUsed(Boolean used) {
    this.used = used;
  }
}

