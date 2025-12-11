package com.remark.money.mapper;

import com.remark.money.entity.BillInfo;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.time.LocalDateTime;
import java.util.List;

@Mapper
public interface BillInfoMapper {

  // 根据bill_id查询
  BillInfo findByBillId(@Param("billId") String billId);

  // 根据id查询
  BillInfo findById(@Param("id") Long id);

  // 插入账单
  void insert(BillInfo billInfo);

  // 批量插入（MyBatis-Plus batch）
  void batchInsert(@Param("list") List<BillInfo> list);

  // 更新账单（Upsert逻辑）
  void update(BillInfo billInfo);

  // 根据id更新账单
  void updateById(BillInfo billInfo);

  // 批量更新
  void batchUpdate(@Param("list") List<BillInfo> list);

  // 查询用户的有效账单数量（is_delete=0）
  int countByUserIdAndBookId(@Param("userId") Long userId, @Param("bookId") String bookId);

  // 全量拉取：查询用户所有有效账单，按update_time排序
  List<BillInfo> findAllByUserIdAndBookId(
      @Param("userId") Long userId,
      @Param("bookId") String bookId,
      @Param("offset") int offset,
      @Param("limit") int limit
  );

  // 增量拉取：查询update_time > lastSyncTime 且 bill_id > lastSyncBillId 的账单
  List<BillInfo> findIncrementalByUserIdAndBookId(
      @Param("userId") Long userId,
      @Param("bookId") String bookId,
      @Param("lastSyncTime") LocalDateTime lastSyncTime,
      @Param("lastSyncBillId") String lastSyncBillId,
      @Param("offset") int offset,
      @Param("limit") int limit
  );

  // 查询用户的最大bill_id（用于全量同步）
  String findMaxBillIdByUserIdAndBookId(@Param("userId") Long userId, @Param("bookId") String bookId);
}

