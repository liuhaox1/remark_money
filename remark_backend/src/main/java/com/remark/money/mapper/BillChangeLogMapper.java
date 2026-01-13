package com.remark.money.mapper;

import com.remark.money.entity.BillChangeLogRange;
import com.remark.money.entity.BillChangeLog;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.time.LocalDateTime;
import java.util.List;

@Mapper
public interface BillChangeLogMapper {
  void insert(@Param("bookId") String bookId,
              @Param("scopeUserId") Long scopeUserId,
              @Param("actorUserId") Long actorUserId,
              @Param("billId") Long billId,
              @Param("op") Integer op,
              @Param("billVersion") Long billVersion);

  void batchInsert(@Param("list") List<BillChangeLog> list);

  int countForScope(@Param("bookId") String bookId,
                    @Param("scopeUserId") Long scopeUserId);

  Integer existsAnyForScope(@Param("bookId") String bookId,
                            @Param("scopeUserId") Long scopeUserId);

  int bootstrapShared(@Param("bookId") String bookId,
                      @Param("scopeUserId") Long scopeUserId);

  int bootstrapPersonal(@Param("userId") Long userId,
                        @Param("bookId") String bookId,
                        @Param("scopeUserId") Long scopeUserId);

  int bootstrapTombstones(@Param("bookId") String bookId,
                          @Param("scopeUserId") Long scopeUserId);

  List<BillChangeLog> findAfter(@Param("bookId") String bookId,
                                @Param("scopeUserId") Long scopeUserId,
                                @Param("afterChangeId") Long afterChangeId,
                                @Param("limit") int limit);

  List<BillChangeLog> findRecent(@Param("bookId") String bookId,
                                 @Param("scopeUserId") Long scopeUserId,
                                 @Param("beforeChangeId") Long beforeChangeId,
                                 @Param("limit") int limit);

  Long findMaxChangeId(@Param("bookId") String bookId,
                       @Param("scopeUserId") Long scopeUserId);

  Long findMinChangeIdSince(@Param("bookId") String bookId,
                            @Param("scopeUserId") Long scopeUserId,
                            @Param("cutoff") LocalDateTime cutoff);

  BillChangeLogRange findRangeForScopeSince(@Param("bookId") String bookId,
                                            @Param("scopeUserId") Long scopeUserId,
                                            @Param("cutoff") LocalDateTime cutoff);

  int deleteBefore(@Param("cutoff") LocalDateTime cutoff);

  List<Long> findChangeIdsBefore(@Param("cutoff") LocalDateTime cutoff,
                                 @Param("limit") int limit);

  int deleteByChangeIds(@Param("ids") List<Long> ids);
}
