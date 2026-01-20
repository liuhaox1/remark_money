package com.remark.money.mapper;

import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface PlanExecLogMapper {
  int insertIgnore(
      @Param("kind") String kind,
      @Param("userId") Long userId,
      @Param("bookId") String bookId,
      @Param("planId") String planId,
      @Param("periodKey") String periodKey);
}
