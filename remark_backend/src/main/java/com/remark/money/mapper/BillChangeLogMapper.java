package com.remark.money.mapper;

import com.remark.money.entity.BillChangeLog;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface BillChangeLogMapper {
  void insert(@Param("bookId") String bookId,
              @Param("scopeUserId") Long scopeUserId,
              @Param("billId") Long billId,
              @Param("op") Integer op,
              @Param("billVersion") Long billVersion);

  int countForScope(@Param("bookId") String bookId,
                    @Param("scopeUserId") Long scopeUserId);

  int bootstrapShared(@Param("bookId") String bookId,
                      @Param("scopeUserId") Long scopeUserId);

  int bootstrapPersonal(@Param("userId") Long userId,
                        @Param("bookId") String bookId,
                        @Param("scopeUserId") Long scopeUserId);

  List<BillChangeLog> findAfter(@Param("bookId") String bookId,
                                @Param("scopeUserId") Long scopeUserId,
                                @Param("afterChangeId") Long afterChangeId,
                                @Param("limit") int limit);
}
