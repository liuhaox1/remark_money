package com.remark.money.mapper;

import com.remark.money.entity.SavingsPlanInfo;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface SavingsPlanInfoMapper {
  SavingsPlanInfo findByUserIdBookIdAndPlanId(
      @Param("userId") Long userId,
      @Param("bookId") String bookId,
      @Param("planId") String planId);

  List<SavingsPlanInfo> findAllByUserIdAndBookId(
      @Param("userId") Long userId, @Param("bookId") String bookId);

  int insertOne(SavingsPlanInfo plan);

  int updateWithExpectedSyncVersion(
      @Param("plan") SavingsPlanInfo plan, @Param("expectedSyncVersion") Long expectedSyncVersion);

  int softDeleteByPlanId(
      @Param("userId") Long userId,
      @Param("bookId") String bookId,
      @Param("planId") String planId);
}

