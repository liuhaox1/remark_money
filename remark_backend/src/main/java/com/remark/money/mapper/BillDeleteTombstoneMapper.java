package com.remark.money.mapper;

import com.remark.money.entity.BillDeleteTombstone;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.time.LocalDateTime;
import java.util.List;

@Mapper
public interface BillDeleteTombstoneMapper {
  int upsert(BillDeleteTombstone tombstone);

  int deleteOne(@Param("bookId") String bookId,
                @Param("scopeUserId") Long scopeUserId,
                @Param("billId") Long billId);

  List<BillDeleteTombstone> findKeysBefore(@Param("cutoff") LocalDateTime cutoff,
                                           @Param("limit") int limit);

  int deleteByKeys(@Param("list") List<BillDeleteTombstone> list);
}

