package com.remark.money.mapper;

import com.remark.money.entity.SyncOpDedup;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.time.LocalDateTime;

@Mapper
public interface SyncOpDedupMapper {
  SyncOpDedup find(@Param("userId") Long userId,
                   @Param("bookId") String bookId,
                   @Param("opId") String opId);

  void insert(SyncOpDedup record);

  int deleteBefore(@Param("cutoff") LocalDateTime cutoff);
}
