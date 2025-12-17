package com.remark.money.mapper;

import com.remark.money.entity.SyncOpDedup;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.time.LocalDateTime;
import java.util.List;

@Mapper
public interface SyncOpDedupMapper {
  SyncOpDedup find(@Param("userId") Long userId,
                   @Param("bookId") String bookId,
                   @Param("opId") String opId);

  List<SyncOpDedup> findByOpIds(@Param("userId") Long userId,
                                @Param("bookId") String bookId,
                                @Param("opIds") List<String> opIds);

  void insert(SyncOpDedup record);

  void batchInsert(@Param("list") List<SyncOpDedup> list);

  int deleteBefore(@Param("cutoff") LocalDateTime cutoff);
}
