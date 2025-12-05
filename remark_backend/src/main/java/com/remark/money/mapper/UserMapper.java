package com.remark.money.mapper;

import com.remark.money.entity.User;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

  @Mapper
  public interface UserMapper {

  @Select("SELECT id, phone, nickname, wechat_open_id, created_at, updated_at FROM user WHERE id = #{id}")
  User findById(@Param("id") Long id);

  @Select("SELECT id, phone, nickname, wechat_open_id, created_at, updated_at FROM user WHERE phone = #{phone}")
  User findByPhone(@Param("phone") String phone);

  @Select("SELECT id, phone, nickname, wechat_open_id, created_at, updated_at FROM user WHERE wechat_open_id = #{openId}")
  User findByWechatOpenId(@Param("openId") String openId);

  void insert(User user);

  void updateWechatOpenId(@Param("id") Long id, @Param("openId") String openId);
}
