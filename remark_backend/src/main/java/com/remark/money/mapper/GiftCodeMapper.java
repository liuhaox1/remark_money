package com.remark.money.mapper;

import com.remark.money.entity.GiftCode;
import org.apache.ibatis.annotations.*;

import java.time.LocalDateTime;

@Mapper
public interface GiftCodeMapper {

  @Select("SELECT id, code, status, used_by, used_at, expire_at, plan_type, duration_months, version, created_at FROM gift_code WHERE code = #{code}")
  GiftCode findByCode(@Param("code") String code);

  @Update("UPDATE gift_code SET status = 1, used_by = #{userId}, used_at = #{usedAt}, version = version + 1 "
      + "WHERE code = #{code} AND status = 0")
  int redeem(@Param("code") String code,
             @Param("userId") Long userId,
             @Param("usedAt") LocalDateTime usedAt);
}

