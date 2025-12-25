package com.remark.money.mapper;

import com.remark.money.entity.TagInfo;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;
import java.util.Set;

@Mapper
public interface TagInfoMapper {
  List<TagInfo> findAllByUserIdAndBookId(@Param("userId") Long userId, @Param("bookId") String bookId);

  List<TagInfo> findByUserIdBookIdAndTagIds(@Param("userId") Long userId, @Param("bookId") String bookId, @Param("tagIds") Set<String> tagIds);

  int batchInsert(@Param("list") List<TagInfo> list);

  int batchUpdate(@Param("list") List<TagInfo> list);

  int softDeleteByTagId(@Param("userId") Long userId, @Param("bookId") String bookId, @Param("tagId") String tagId);
}

