package com.remark.money.mapper;

import com.remark.money.entity.BillInfo;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.time.LocalDateTime;
import java.util.List;

@Mapper
public interface BillInfoMapper {

  // 根据id查询
  BillInfo findById(@Param("id") Long id);

  // v2 scoped lookups (avoid cross-book/user leakage)
  BillInfo findByIdForUserAndBook(@Param("userId") Long userId, @Param("bookId") String bookId, @Param("id") Long id);

  BillInfo findByIdForBook(@Param("bookId") String bookId, @Param("id") Long id);

  // 批量根据id查询
  List<BillInfo> findByIds(@Param("ids") List<Long> ids);

  // v2 scoped batch lookup
  List<BillInfo> findByIdsForUserAndBook(@Param("userId") Long userId, @Param("bookId") String bookId, @Param("ids") List<Long> ids);

  List<BillInfo> findByIdsForBook(@Param("bookId") String bookId, @Param("ids") List<Long> ids);

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

  int countByBookId(@Param("bookId") String bookId);

  // 全量拉取：查询用户所有有效账单，按update_time排序
  List<BillInfo> findAllByUserIdAndBookId(
      @Param("userId") Long userId,
      @Param("bookId") String bookId,
      @Param("offset") int offset,
      @Param("limit") int limit
  );

  List<BillInfo> findAllByBookId(
      @Param("bookId") String bookId,
      @Param("offset") int offset,
      @Param("limit") int limit
  );

  // 增量拉取：查询update_time > lastSyncTime 且 id > lastSyncId 的账单
  List<BillInfo> findIncrementalByUserIdAndBookId(
      @Param("userId") Long userId,
      @Param("bookId") String bookId,
      @Param("lastSyncTime") LocalDateTime lastSyncTime,
      @Param("lastSyncId") Long lastSyncId,
      @Param("offset") int offset,
      @Param("limit") int limit
  );

  List<BillInfo> findIncrementalByBookId(
      @Param("bookId") String bookId,
      @Param("lastSyncTime") LocalDateTime lastSyncTime,
      @Param("lastSyncId") Long lastSyncId,
      @Param("offset") int offset,
      @Param("limit") int limit
  );

  // 查询用户的最大id（用于全量同步）
  Long findMaxIdByUserIdAndBookId(@Param("userId") Long userId, @Param("bookId") String bookId);

  Long findMaxIdByBookId(@Param("bookId") String bookId);

  // v2: optimistic-lock update (single-user book)
  int updateWithExpectedVersionByUserIdAndBookId(
      @Param("userId") Long userId,
      @Param("bookId") String bookId,
      @Param("expectedVersion") Long expectedVersion,
      @Param("bill") BillInfo bill
  );

  // v2: optimistic-lock update (multi-user/shared book)
  int updateWithExpectedVersionByBookId(
      @Param("bookId") String bookId,
      @Param("expectedVersion") Long expectedVersion,
      @Param("bill") BillInfo bill
  );

  // v2: optimistic-lock soft delete (single-user book)
  int softDeleteWithExpectedVersionByUserIdAndBookId(
      @Param("userId") Long userId,
      @Param("bookId") String bookId,
      @Param("id") Long id,
      @Param("expectedVersion") Long expectedVersion
  );

  // v2: optimistic-lock soft delete (multi-user/shared book)
  int softDeleteWithExpectedVersionByBookId(
      @Param("bookId") String bookId,
      @Param("id") Long id,
      @Param("expectedVersion") Long expectedVersion
  );
}
