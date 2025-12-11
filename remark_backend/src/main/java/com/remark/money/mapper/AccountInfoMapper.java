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

  // 根据userId和accountId查询（用于匹配客户端临时ID）
  AccountInfo findByUserIdAndAccountId(@Param("userId") Long userId, @Param("accountId") String accountId);

  // 查询用户所有账户
  List<AccountInfo> findAllByUserId(@Param("userId") Long userId);

  // 插入账户
  void insert(AccountInfo accountInfo);

  // 批量插入
  void batchInsert(@Param("list") List<AccountInfo> list);

  // 更新账户（按id）
  void updateById(AccountInfo accountInfo);

  // 批量更新
  void batchUpdate(@Param("list") List<AccountInfo> list);
}

