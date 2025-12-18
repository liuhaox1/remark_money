package com.remark.money.mapper;

import com.remark.money.entity.Feedback;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

@Mapper
public interface FeedbackMapper {
  void insert(Feedback feedback);

  List<Feedback> listRecent(@Param("limit") int limit);
}

