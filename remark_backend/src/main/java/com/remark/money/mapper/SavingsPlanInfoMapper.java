package com.remark.money.mapper;

import com.remark.money.entity.SavingsPlanInfo;
import java.util.List;
import java.util.Set;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface SavingsPlanInfoMapper {
  SavingsPlanInfo findByUserIdBookIdAndPlanId(
      @Param("userId") Long userId,
      @Param("bookId") String bookId,
      @Param("planId") String planId);

  List<SavingsPlanInfo> findByUserIdBookIdAndPlanIds(
      @Param("userId") Long userId,
      @Param("bookId") String bookId,
      @Param("planIds") Set<String> planIds);

  List<SavingsPlanInfo> findAllByUserIdAndBookId(
      @Param("userId") Long userId, @Param("bookId") String bookId);

  List<SavingsPlanInfo> findAllActive();

  int insertOne(SavingsPlanInfo plan);

  int updateWithExpectedSyncVersion(
      @Param("plan") SavingsPlanInfo plan, @Param("expectedSyncVersion") Long expectedSyncVersion);

  int softDeleteByPlanId(
      @Param("userId") Long userId,
      @Param("bookId") String bookId,
      @Param("planId") String planId);

  int updatePayloadAndBumpVersion(
      @Param("userId") Long userId,
      @Param("bookId") String bookId,
      @Param("planId") String planId,
      @Param("payloadJson") String payloadJson);
}
