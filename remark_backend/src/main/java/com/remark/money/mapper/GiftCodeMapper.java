package com.remark.money.mapper;

import com.remark.money.entity.GiftCode;
import org.apache.ibatis.annotations.*;

import java.time.LocalDateTime;

@Mapper
public interface GiftCodeMapper {

  /**
   * 根据礼包码查询（普通查询，不加锁，依赖唯一索引和乐观锁保证并发安全）
   */
  @Select("SELECT id, code, status, used_by, used_at, expire_at, plan_type, duration_months, version, created_at " +
          "FROM gift_code WHERE code = #{code}")
  GiftCode findByCode(@Param("code") String code);

  /**
   * 兑换礼包码（使用乐观锁，通过 version 字段防止并发冲突）
   * 条件：status = 0（未使用）且 version 匹配
   * 返回更新的行数，如果为0说明已被其他线程占用或状态已改变
   */
  @Update("UPDATE gift_code SET status = 1, used_by = #{userId}, used_at = #{usedAt}, version = version + 1 " +
          "WHERE code = #{code} AND status = 0 AND version = #{version}")
  int redeemWithVersion(@Param("code") String code,
                        @Param("userId") Long userId,
                        @Param("usedAt") LocalDateTime usedAt,
                        @Param("version") Integer version);
}

