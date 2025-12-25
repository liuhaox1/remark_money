package com.remark.money.mapper;

import com.remark.money.entity.CategoryInfo;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;
import java.util.Set;

@Mapper
public interface CategoryInfoMapper {
  List<CategoryInfo> findAllByUserId(@Param("userId") Long userId);

  List<CategoryInfo> findByUserIdAndKeys(@Param("userId") Long userId, @Param("keys") Set<String> keys);

  int batchInsert(@Param("list") List<CategoryInfo> list);

  int batchUpdate(@Param("list") List<CategoryInfo> list);

  int softDeleteByKey(@Param("userId") Long userId, @Param("key") String key);
}

