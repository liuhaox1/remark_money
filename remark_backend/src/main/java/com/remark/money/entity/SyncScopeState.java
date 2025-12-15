package com.remark.money.entity;

import java.time.LocalDateTime;

/**
 * v2 sync scope bootstrap state.
 * One row per (book_id, scope_user_id).
 */
public class SyncScopeState {
  private Long id;
  private String bookId;
  private Long scopeUserId;
  private Integer initialized; // 0/1
  private LocalDateTime createdAt;
  private LocalDateTime updatedAt;

  public Long getId() {
    return id;
  }

  public void setId(Long id) {
    this.id = id;
  }

  public String getBookId() {
    return bookId;
  }

  public void setBookId(String bookId) {
    this.bookId = bookId;
  }

  public Long getScopeUserId() {
    return scopeUserId;
  }

  public void setScopeUserId(Long scopeUserId) {
    this.scopeUserId = scopeUserId;
  }

  public Integer getInitialized() {
    return initialized;
  }

  public void setInitialized(Integer initialized) {
    this.initialized = initialized;
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
}

