package com.remark.money.controller;

import com.remark.money.service.GiftCodeService;
import com.remark.money.util.JwtUtil;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import javax.servlet.http.HttpServletRequest;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/gift")
public class GiftController {

  private final GiftCodeService giftCodeService;
  private final JwtUtil jwtUtil;

  public GiftController(GiftCodeService giftCodeService, JwtUtil jwtUtil) {
    this.giftCodeService = giftCodeService;
    this.jwtUtil = jwtUtil;
  }

  @PostMapping("/redeem")
  public ResponseEntity<Map<String, Object>> redeem(@RequestBody Map<String, String> body,
                                                    HttpServletRequest request) {
    String code = body.get("code");
    if (!StringUtils.hasText(code) || code.length() != 6) {
      throw new IllegalArgumentException("礼包码格式不正确");
    }
    Long userId = getUserId(request);
    try {
      LocalDateTime newExpire = giftCodeService.redeem(code, userId);
      Map<String, Object> resp = new HashMap<>();
      resp.put("message", "兑换成功");
      resp.put("payExpire", newExpire);
      return ResponseEntity.ok(resp);
    } catch (DuplicateKeyException e) {
      throw new IllegalArgumentException("礼包码已被使用或无效");
    }
  }

  private Long getUserId(HttpServletRequest request) {
    String auth = request.getHeader("Authorization");
    if (!StringUtils.hasText(auth) || !auth.startsWith("Bearer ")) {
      throw new IllegalArgumentException("未登录");
    }
    String token = auth.substring(7);
    return jwtUtil.parseUserId(token);
  }
}

