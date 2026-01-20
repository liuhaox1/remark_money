package com.remark.money.mapper;

import com.remark.money.entity.RecurringPlanInfo;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;
import java.util.Set;

@Mapper
public interface RecurringPlanInfoMapper {
  RecurringPlanInfo findByUserIdBookIdAndPlanId(
      @Param("userId") Long userId, @Param("bookId") String bookId, @Param("planId") String planId);

  List<RecurringPlanInfo> findByUserIdBookIdAndPlanIds(
      @Param("userId") Long userId, @Param("bookId") String bookId, @Param("planIds") Set<String> planIds);

  List<RecurringPlanInfo> findAllByUserIdAndBookId(
      @Param("userId") Long userId, @Param("bookId") String bookId);

  List<RecurringPlanInfo> findAllActive();

  void insertOne(@Param("plan") RecurringPlanInfo plan);

  int updateWithExpectedSyncVersion(
      @Param("plan") RecurringPlanInfo plan, @Param("expectedSyncVersion") Long expectedSyncVersion);

  void softDeleteByPlanId(
      @Param("userId") Long userId, @Param("bookId") String bookId, @Param("planId") String planId);

  int updatePayloadAndBumpVersion(
      @Param("userId") Long userId,
      @Param("bookId") String bookId,
      @Param("planId") String planId,
      @Param("payloadJson") String payloadJson);
}
