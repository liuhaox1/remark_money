package com.remark.money.mapper;

import com.remark.money.entity.SyncScopeState;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface SyncScopeStateMapper {

  SyncScopeState find(@Param("bookId") String bookId, @Param("scopeUserId") Long scopeUserId);

  int ensureExists(@Param("bookId") String bookId, @Param("scopeUserId") Long scopeUserId);

  int markInitialized(@Param("bookId") String bookId, @Param("scopeUserId") Long scopeUserId);
}

