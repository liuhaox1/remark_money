package com.remark.money.controller;

import com.remark.money.service.GiftCodeService;
import com.remark.money.util.JwtUtil;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import javax.servlet.http.HttpServletRequest;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * 礼包码控制器
 */
@RestController
@RequestMapping("/api/gift")
public class GiftController {

  private final GiftCodeService giftCodeService;
  private final JwtUtil jwtUtil;

  public GiftController(GiftCodeService giftCodeService, JwtUtil jwtUtil) {
    this.giftCodeService = giftCodeService;
    this.jwtUtil = jwtUtil;
  }

  /**
   * 兑换礼包码
   * 
   * @param body 请求体，包含 code（礼包码，8位）
   * @param request HTTP请求
   * @return 兑换结果，包含新的付费到期时间
   */
  @PostMapping("/redeem")
  public ResponseEntity<Map<String, Object>> redeem(@RequestBody Map<String, String> body,
                                                    HttpServletRequest request) {
    String code = body.get("code");
    
    // 验证礼包码格式（8位数字）
    if (!StringUtils.hasText(code)) {
      return buildErrorResponse("礼包码不能为空", HttpStatus.BAD_REQUEST);
    }
    
    // 去除空格并转换为大写
    code = code.trim().toUpperCase();
    
    // 验证长度（8位）
    if (code.length() != 8) {
      return buildErrorResponse("礼包码格式不正确，请输入8位礼包码", HttpStatus.BAD_REQUEST);
    }
    
    // 验证是否为纯数字
    if (!code.matches("^[0-9]{8}$")) {
      return buildErrorResponse("礼包码格式不正确，只能包含数字", HttpStatus.BAD_REQUEST);
    }
    
    Long userId;
    try {
      userId = getUserId(request);
    } catch (IllegalArgumentException e) {
      return buildErrorResponse("未登录，请先登录", HttpStatus.UNAUTHORIZED);
    }
    
    try {
      LocalDateTime newExpire = giftCodeService.redeem(code, userId);
      Map<String, Object> resp = new HashMap<>();
      resp.put("success", true);
      resp.put("message", "兑换成功");
      resp.put("payExpire", newExpire.toString());
      resp.put("payType", 1); // 默认3元档
      return ResponseEntity.ok(resp);
    } catch (IllegalArgumentException e) {
      // 礼包码不存在、已过期、已被使用等
      return buildErrorResponse(e.getMessage(), HttpStatus.BAD_REQUEST);
    } catch (DuplicateKeyException e) {
      // 并发冲突：礼包码已被其他用户使用或version冲突
      return buildErrorResponse("礼包码兑换失败，请稍后重试", HttpStatus.CONFLICT);
    } catch (Exception e) {
      // 其他异常
      return buildErrorResponse("兑换失败，请稍后再试", HttpStatus.INTERNAL_SERVER_ERROR);
    }
  }

  /**
   * 从请求头中获取用户ID
   */
  private Long getUserId(HttpServletRequest request) {
    String auth = request.getHeader("Authorization");
    if (!StringUtils.hasText(auth) || !auth.startsWith("Bearer ")) {
      throw new IllegalArgumentException("未登录");
    }
    String token = auth.substring(7);
    return jwtUtil.parseUserId(token);
  }

  /**
   * 构建错误响应
   */
  private ResponseEntity<Map<String, Object>> buildErrorResponse(String message, HttpStatus status) {
    Map<String, Object> resp = new HashMap<>();
    resp.put("success", false);
    resp.put("error", message);
    return ResponseEntity.status(status).body(resp);
  }
}

