package com.remark.money.mapper;

import com.remark.money.entity.BillTagRel;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface BillTagRelMapper {
  List<BillTagRel> findByBillIds(
      @Param("bookId") String bookId,
      @Param("scopeUserId") Long scopeUserId,
      @Param("billIds") List<Long> billIds);

  int deleteByBillIdsForScope(
      @Param("bookId") String bookId,
      @Param("scopeUserId") Long scopeUserId,
      @Param("billIds") List<Long> billIds);

  int deleteByBillIdsAllScopes(@Param("bookId") String bookId, @Param("billIds") List<Long> billIds);

  int batchInsert(@Param("list") List<BillTagRel> list);
}
