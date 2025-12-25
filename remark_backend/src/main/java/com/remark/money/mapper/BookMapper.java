package com.remark.money.mapper;

import com.remark.money.entity.Book;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface BookMapper {

  @Insert("INSERT INTO book (owner_id, name, invite_code, is_multi, status, created_at, updated_at) "
      + "VALUES (#{ownerId}, #{name}, #{inviteCode}, #{isMulti}, #{status}, NOW(), NOW())")
  @Options(useGeneratedKeys = true, keyProperty = "id")
  int insert(Book book);

  @Select("SELECT id, owner_id, name, invite_code, is_multi, status, created_at, updated_at FROM book WHERE invite_code = #{inviteCode}")
  Book findByInviteCode(@Param("inviteCode") String inviteCode);

  @Select("SELECT id, owner_id, name, invite_code, is_multi, status, created_at, updated_at FROM book WHERE id = #{id}")
  Book findById(@Param("id") Long id);

  @Update("UPDATE book SET invite_code = #{inviteCode}, updated_at = NOW() WHERE id = #{id}")
  int updateInviteCode(@Param("id") Long id, @Param("inviteCode") String inviteCode);

  @Select("SELECT b.id, b.owner_id, b.name, b.invite_code, b.is_multi, b.status, b.created_at, b.updated_at "
      + "FROM book b JOIN book_member m ON b.id = m.book_id "
      + "WHERE m.user_id = #{userId} AND m.status = 1")
  List<Book> listByUser(@Param("userId") Long userId);
}

