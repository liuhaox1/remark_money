package com.remark.money.service;

import com.remark.money.entity.GiftCode;
import com.remark.money.mapper.GiftCodeMapper;
import com.remark.money.mapper.UserMapper;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

/**
 * 礼包码服务
 * 并发安全策略：
 * 1. 使用事务保证原子性
 * 2. 使用唯一索引（uk_gift_code）防止重复插入
 * 3. 使用乐观锁（version字段）防止并发更新冲突
 * 4. 不使用 FOR UPDATE，通过乐观锁和错误捕获处理并发
 */
@Service
public class GiftCodeService {

  private final GiftCodeMapper giftCodeMapper;
  private final UserMapper userMapper;

  public GiftCodeService(GiftCodeMapper giftCodeMapper, UserMapper userMapper) {
    this.giftCodeMapper = giftCodeMapper;
    this.userMapper = userMapper;
  }

  /**
   * 兑换礼包码
   * 使用事务和乐观锁确保并发安全，不使用 FOR UPDATE
   * 
   * @param code 礼包码（8位）
   * @param userId 用户ID
   * @return 新的付费到期时间
   * @throws IllegalArgumentException 礼包码不存在、已过期、已被使用等
   * @throws DuplicateKeyException 并发冲突：礼包码已被其他用户使用
   */
  @Transactional(rollbackFor = Exception.class)
  public LocalDateTime redeem(String code, Long userId) {
    // 普通查询（不加锁），依赖唯一索引和乐观锁保证并发安全
    GiftCode gift = giftCodeMapper.findByCode(code);
    
    if (gift == null) {
      throw new IllegalArgumentException("礼包码不存在");
    }
    
    // 检查是否已过期
    if (gift.getExpireAt() != null && gift.getExpireAt().isBefore(LocalDateTime.now())) {
      throw new IllegalArgumentException("礼包码已过期");
    }
    
    // 检查是否已被使用
    if (gift.getStatus() != null && gift.getStatus() != 0) {
      throw new IllegalArgumentException("礼包码已被使用");
    }
    
    // 使用乐观锁更新（通过 version 字段）
    // WHERE 条件：code = ? AND status = 0 AND version = ?
    // 如果 version 不匹配或 status 已改变，更新返回0
    LocalDateTime usedAt = LocalDateTime.now();
    int currentVersion = gift.getVersion() == null ? 0 : gift.getVersion();
    int updated = giftCodeMapper.redeemWithVersion(
        code, 
        userId, 
        usedAt, 
        currentVersion
    );
    
    if (updated <= 0) {
      // 并发冲突：version 不匹配或已被其他线程占用
      // 重新查询一次，确认是否真的已被使用
      GiftCode updatedGift = giftCodeMapper.findByCode(code);
      if (updatedGift != null && updatedGift.getStatus() != null && updatedGift.getStatus() != 0) {
        throw new IllegalArgumentException("礼包码已被使用");
      }
      // 如果状态还是0，说明是version冲突，抛出并发异常
      throw new DuplicateKeyException("礼包码兑换失败，请稍后重试");
    }

    // 计算新的到期时间
    // 如果用户已有付费且未过期，则在现有到期时间基础上延长
    // 否则从当前时间开始计算
    LocalDateTime base = LocalDateTime.now();
    
    // 查询用户当前付费信息
    com.remark.money.entity.User user = userMapper.findById(userId);
    if (user != null && user.getPayExpire() != null && user.getPayExpire().isAfter(LocalDateTime.now())) {
      // 用户已有未过期的付费，在现有到期时间基础上延长
      base = user.getPayExpire();
    }
    
    LocalDateTime newExpire = base.plusMonths(
        gift.getDurationMonths() == null ? 12 : gift.getDurationMonths());

    // plan_type 对应档位：1=3元档，2=5元档，3=10元档，默认 1
    Integer payType = gift.getPlanType() == null ? 1 : gift.getPlanType();
    userMapper.updatePay(userId, payType, newExpire);

    return newExpire;
  }
}

