package com.remark.money.mapper;

import com.remark.money.entity.SyncRecord;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface SyncRecordMapper {

  // 根据user_id、book_id、device_id查询同步记录
  SyncRecord findByUserBookDevice(
      @Param("userId") Long userId,
      @Param("bookId") String bookId,
      @Param("deviceId") String deviceId
  );

  // 插入同步记录
  void insert(SyncRecord syncRecord);

  // 更新同步记录
  void update(SyncRecord syncRecord);

  // Upsert：存在则更新，不存在则插入
  void upsert(SyncRecord syncRecord);
}

