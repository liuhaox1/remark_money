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

  int insertOne(CategoryInfo categoryInfo);

  int updateWithExpectedSyncVersion(
      @Param("category") CategoryInfo categoryInfo, @Param("expectedSyncVersion") Long expectedSyncVersion);

  int softDeleteByKey(@Param("userId") Long userId, @Param("key") String key);
}
