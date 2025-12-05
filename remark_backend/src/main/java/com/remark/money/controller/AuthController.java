package com.remark.money.controller;

import com.remark.money.service.AuthService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

  private final AuthService authService;

  public AuthController(AuthService authService) {
    this.authService = authService;
  }

  @PostMapping("/send-sms-code")
  public ResponseEntity<?> sendSmsCode(@RequestBody Map<String, String> body) {
    String phone = body.get("phone");
    if (phone == null || phone.trim().isEmpty()) {
      return ResponseEntity.badRequest().body("手机号不能为空");
    }
    authService.sendSmsCode(phone.trim());
    return ResponseEntity.ok().build();
  }

  @PostMapping("/login/sms")
  public ResponseEntity<?> loginWithSms(@RequestBody Map<String, String> body) {
    String phone = body.get("phone");
    String code = body.get("code");
    if (phone == null || code == null) {
      return ResponseEntity.badRequest().body("手机号和验证码不能为空");
    }
    try {
      Map<String, Object> result = authService.loginWithSms(phone.trim(), code.trim());
      return ResponseEntity.ok(result);
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.badRequest().body(ex.getMessage());
    }
  }

  @PostMapping("/login/wechat")
  public ResponseEntity<?> loginWithWeixin(@RequestBody Map<String, String> body) {
    String code = body.get("code");
    if (code == null || code.trim().isEmpty()) {
      return ResponseEntity.badRequest().body("code 不能为空");
    }
    try {
      Map<String, Object> result = authService.loginWithWeixinCode(code.trim());
      return ResponseEntity.ok(result);
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.badRequest().body(ex.getMessage());
    }
  }
}

