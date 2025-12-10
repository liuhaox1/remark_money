package com.remark.money.entity;

import java.time.LocalDateTime;

public class BookMember {
  private Long id;
  private Long bookId;
  private Long userId;
  private String role;
  private Integer status;
  private LocalDateTime joinedAt;

  public Long getId() { return id; }
  public void setId(Long id) { this.id = id; }

  public Long getBookId() { return bookId; }
  public void setBookId(Long bookId) { this.bookId = bookId; }

  public Long getUserId() { return userId; }
  public void setUserId(Long userId) { this.userId = userId; }

  public String getRole() { return role; }
  public void setRole(String role) { this.role = role; }

  public Integer getStatus() { return status; }
  public void setStatus(Integer status) { this.status = status; }

  public LocalDateTime getJoinedAt() { return joinedAt; }
  public void setJoinedAt(LocalDateTime joinedAt) { this.joinedAt = joinedAt; }
}

