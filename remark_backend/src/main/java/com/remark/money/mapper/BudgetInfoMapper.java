package com.remark.money.mapper;

import com.remark.money.entity.BudgetInfo;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface BudgetInfoMapper {
  BudgetInfo findByUserIdAndBookId(@Param("userId") Long userId, @Param("bookId") String bookId);

  void upsert(BudgetInfo budgetInfo);
}

