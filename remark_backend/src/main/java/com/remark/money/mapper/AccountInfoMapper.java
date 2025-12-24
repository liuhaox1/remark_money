package com.remark.money.mapper;

import com.remark.money.entity.AccountInfo;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;
import java.util.Set;

@Mapper
public interface AccountInfoMapper {

  // 根据id查询（服务器ID）
  AccountInfo findById(@Param("id") Long id);

  // 批量根据id查询
  List<AccountInfo> findByIds(@Param("ids") Set<Long> ids);

  // 批量根据 userId + ids 查询（防止越权/误匹配）
  List<AccountInfo> findByUserIdAndIds(@Param("userId") Long userId, @Param("ids") Set<Long> ids);

  // 根据userId和accountId查询（用于匹配客户端临时ID）
  AccountInfo findByUserIdAndAccountId(@Param("userId") Long userId, @Param("accountId") String accountId);

  // 批量根据 userId + accountId 查询（用于去 N+1）
  List<AccountInfo> findByUserIdAndAccountIds(@Param("userId") Long userId, @Param("accountIds") Set<String> accountIds);

  // 查询用户所有账户
  List<AccountInfo> findAllByUserId(@Param("userId") Long userId);

  // 删除：当客户端上传“全量账户列表”时，服务端删除不在列表中的旧账户（以 account_id 为准）
  void deleteByUserIdAndAccountIdsNotIn(
      @Param("userId") Long userId, @Param("accountIds") Set<String> accountIds);

  int softDeleteById(@Param("userId") Long userId, @Param("id") Long id);

  int softDeleteByAccountId(@Param("userId") Long userId, @Param("accountId") String accountId);

  // 插入账户
  void insert(AccountInfo accountInfo);

  // 批量插入
  void batchInsert(@Param("list") List<AccountInfo> list);

  // 更新账户（按id）
  void updateById(AccountInfo accountInfo);

  // 批量更新
  void batchUpdate(@Param("list") List<AccountInfo> list);
}
