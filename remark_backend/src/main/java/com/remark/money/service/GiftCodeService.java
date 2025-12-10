package com.remark.money.service;

import com.remark.money.entity.GiftCode;
import com.remark.money.mapper.GiftCodeMapper;
import com.remark.money.mapper.UserMapper;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

@Service
public class GiftCodeService {

  private final GiftCodeMapper giftCodeMapper;
  private final UserMapper userMapper;

  public GiftCodeService(GiftCodeMapper giftCodeMapper, UserMapper userMapper) {
    this.giftCodeMapper = giftCodeMapper;
    this.userMapper = userMapper;
  }

  public LocalDateTime redeem(String code, Long userId) {
    GiftCode gift = giftCodeMapper.findByCode(code);
    if (gift == null) {
      throw new IllegalArgumentException("礼包码不存在");
    }
    if (gift.getExpireAt() != null && gift.getExpireAt().isBefore(LocalDateTime.now())) {
      throw new IllegalArgumentException("礼包码已过期");
    }
    if (gift.getStatus() != null && gift.getStatus() != 0) {
      throw new IllegalArgumentException("礼包码已被使用");
    }

    int updated = giftCodeMapper.redeem(code, userId, LocalDateTime.now());
    if (updated <= 0) {
      // 并发下被其他人占用
      throw new DuplicateKeyException("礼包码已被使用");
    }

    // 计算新的到期时间（基于现有到期或当前时间）
    LocalDateTime base = gift.getExpireAt();
    if (base == null || base.isBefore(LocalDateTime.now())) {
      base = LocalDateTime.now();
    }
    LocalDateTime newExpire = base.plusMonths(
        gift.getDurationMonths() == null ? 12 : gift.getDurationMonths());

    // plan_type 对应档位：1=3元档，2=5元档，3=10元档，默认 1
    Integer payType = gift.getPlanType() == null ? 1 : gift.getPlanType();
    userMapper.updatePay(userId, payType, newExpire);

    return newExpire;
  }
}

