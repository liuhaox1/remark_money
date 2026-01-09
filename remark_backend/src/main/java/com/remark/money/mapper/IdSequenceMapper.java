package com.remark.money.mapper;

import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface IdSequenceMapper {

  /** Ensure bill_info sequence exists and does not go backwards. */
  int ensureBillInfo();

  /** Atomically advance next_id by count and store the resulting value in LAST_INSERT_ID(). */
  int advanceWithLastInsertId(@Param("name") String name, @Param("count") long count);

  /** Advance next_id by count. */
  int advance(@Param("name") String name, @Param("count") long count);

  /** Read last insert id for this connection (used with advanceWithLastInsertId). */
  Long lastInsertId();
}
