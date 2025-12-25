package com.remark.money.mapper;

import com.remark.money.entity.BudgetInfo;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface BudgetInfoMapper {
  BudgetInfo findByUserIdAndBookId(@Param("userId") Long userId, @Param("bookId") String bookId);

  int insertNew(BudgetInfo budgetInfo);

  int updateWithExpectedSyncVersion(
      @Param("budget") BudgetInfo budgetInfo, @Param("expectedSyncVersion") Long expectedSyncVersion);
}
