package com.remark.money.mapper;

import com.remark.money.entity.User;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

  @Mapper
  public interface UserMapper {

  @Select("SELECT id, username, password, phone, nickname, wechat_open_id, created_at, updated_at FROM user WHERE id = #{id}")
  User findById(@Param("id") Long id);

  @Select("SELECT id, username, password, phone, nickname, wechat_open_id, created_at, updated_at FROM user WHERE username = #{username}")
  User findByUsername(@Param("username") String username);

  @Select("SELECT id, username, password, phone, nickname, wechat_open_id, created_at, updated_at FROM user WHERE phone = #{phone}")
  User findByPhone(@Param("phone") String phone);

  @Select("SELECT id, username, password, phone, nickname, wechat_open_id, created_at, updated_at FROM user WHERE wechat_open_id = #{openId}")
  User findByWechatOpenId(@Param("openId") String openId);

  @org.apache.ibatis.annotations.Insert("INSERT INTO user (username, password, phone, nickname, wechat_open_id, created_at, updated_at) VALUES (#{username}, #{password}, #{phone}, #{nickname}, #{wechatOpenId}, NOW(), NOW())")
  @org.apache.ibatis.annotations.Options(useGeneratedKeys = true, keyProperty = "id")
  void insert(User user);

  void updateWechatOpenId(@Param("id") Long id, @Param("openId") String openId);
}
