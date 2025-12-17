package com.remark.money.mapper;

import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface IdSequenceMapper {

  /** Ensure bill_info sequence exists and does not go backwards. */
  int ensureBillInfo();

  /** Lock current next_id for update. */
  Long lockNextId(@Param("name") String name);

  /** Advance next_id by count. */
  int advance(@Param("name") String name, @Param("count") long count);
}

