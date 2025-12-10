package com.remark.money.mapper;

import com.remark.money.entity.BookMember;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface BookMemberMapper {

  @Insert("INSERT INTO book_member (book_id, user_id, role, status, joined_at) "
      + "VALUES (#{bookId}, #{userId}, #{role}, #{status}, NOW())")
  @Options(useGeneratedKeys = true, keyProperty = "id")
  int insert(BookMember member);

  @Select("SELECT id, book_id, user_id, role, status, joined_at FROM book_member WHERE book_id = #{bookId} AND user_id = #{userId}")
  BookMember find(@Param("bookId") Long bookId, @Param("userId") Long userId);

  @Select("SELECT id, book_id, user_id, role, status, joined_at "
      + "FROM book_member WHERE user_id = #{userId} AND status = 1")
  List<BookMember> listByUser(@Param("userId") Long userId);
}

