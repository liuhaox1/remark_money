package com.remark.money.mapper;

import com.remark.money.entity.SmsCode;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface SmsCodeMapper {

  @Insert("INSERT INTO sms_code(phone, code, expires_at, used) VALUES(#{phone}, #{code}, #{expiresAt}, #{used})")
  void insert(SmsCode smsCode);

  @Select("SELECT id, phone, code, expires_at, used FROM sms_code WHERE phone = #{phone} AND code = #{code} ORDER BY id DESC LIMIT 1")
  SmsCode findLatest(@Param("phone") String phone, @Param("code") String code);

  @Update("UPDATE sms_code SET used = 1 WHERE id = #{id}")
  void markUsed(@Param("id") Long id);
}

