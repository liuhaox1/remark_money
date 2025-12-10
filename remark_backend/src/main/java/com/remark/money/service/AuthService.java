package com.remark.money.service;

import com.remark.money.entity.SmsCode;
import com.remark.money.entity.User;
import com.remark.money.mapper.SmsCodeMapper;
import com.remark.money.mapper.UserMapper;
import com.remark.money.util.JwtUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.client.RestTemplate;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;

@Service
public class AuthService {

  private static final Logger log = LoggerFactory.getLogger(AuthService.class);

  private final UserMapper userMapper;
  private final SmsCodeMapper smsCodeMapper;
  private final JwtUtil jwtUtil;

  @Value("${weixin.app-id}")
  private String wxAppId;

  @Value("${weixin.app-secret}")
  private String wxSecret;

  @Value("${weixin.jscode2session-url}")
  private String wxCode2SessionUrl;

  public AuthService(UserMapper userMapper, SmsCodeMapper smsCodeMapper, JwtUtil jwtUtil) {
    this.userMapper = userMapper;
    this.smsCodeMapper = smsCodeMapper;
    this.jwtUtil = jwtUtil;
  }

  public void sendSmsCode(String phone) {
    // 简化实现：生成 6 位验证码，打印到日志，实际环境请接入短信服务商
    String code = String.format("%06d", new Random().nextInt(1_000_000));
    SmsCode smsCode = new SmsCode();
    smsCode.setPhone(phone);
    smsCode.setCode(code);
    smsCode.setExpiresAt(LocalDateTime.now().plusMinutes(5));
    smsCode.setUsed(false);
    smsCodeMapper.insert(smsCode);

    log.info("Send SMS code {} to phone {} (dev mode: not actually sent)", code, phone);
  }

  public Map<String, Object> loginWithSms(String phone, String code) {
    SmsCode smsCode = smsCodeMapper.findLatest(phone, code);
    if (smsCode == null || Boolean.TRUE.equals(smsCode.getUsed())
        || smsCode.getExpiresAt().isBefore(LocalDateTime.now())) {
      throw new IllegalArgumentException("验证码错误或已过期");
    }

    smsCodeMapper.markUsed(smsCode.getId());

    User user = userMapper.findByPhone(phone);
    if (user == null) {
      user = new User();
      user.setPhone(phone);
      user.setNickname("用户" + phone.substring(Math.max(0, phone.length() - 4)));
      userMapper.insert(user);
    }

    String token = jwtUtil.generateToken(user.getId());
    Map<String, Object> result = new HashMap<>();
    result.put("token", token);
    result.put("user", user);
    return result;
  }

  @SuppressWarnings("unchecked")
  public Map<String, Object> loginWithWeixinCode(String code) {
    if (!StringUtils.hasText(wxAppId) || !StringUtils.hasText(wxSecret)) {
      throw new IllegalStateException("微信 AppId/AppSecret 未配置");
    }

    RestTemplate restTemplate = new RestTemplate();
    String url = wxCode2SessionUrl +
        "?appid=" + wxAppId +
        "&secret=" + wxSecret +
        "&code=" + code +
        "&grant_type=authorization_code";

    Map<String, Object> resp = restTemplate.getForObject(url, Map.class);
    if (resp == null || resp.get("openid") == null) {
      log.warn("Weixin login failed, response: {}", resp);
      throw new IllegalArgumentException("微信登录失败");
    }

    String openId = (String) resp.get("openid");
    User user = userMapper.findByWechatOpenId(openId);
    if (user == null) {
      user = new User();
      user.setWechatOpenId(openId);
      user.setNickname("微信用户");
      userMapper.insert(user);
    }

    String token = jwtUtil.generateToken(user.getId());
    Map<String, Object> result = new HashMap<>();
    result.put("token", token);
    result.put("user", user);
    return result;
  }

  /**
   * 注册：使用账号和密码注册
   */
  public void register(String username, String password) {
    // 检查用户名是否已存在
    User existingUser = userMapper.findByUsername(username);
    if (existingUser != null) {
      throw new IllegalArgumentException("账号已存在");
    }

    // 密码加密（使用 SHA-256，生产环境建议使用 BCrypt）
    String hashedPassword = hashPassword(password);

    // 创建新用户
    User user = new User();
    user.setUsername(username);
    user.setPassword(hashedPassword);
    user.setNickname(username); // 默认昵称为用户名
    userMapper.insert(user);

    log.info("User registered: {}", username);
  }

  /**
   * 登录：使用账号和密码登录
   */
  public Map<String, Object> login(String username, String password) {
    User user = userMapper.findByUsername(username);
    if (user == null) {
      throw new IllegalArgumentException("账号或密码错误");
    }

    // 验证密码
    String hashedPassword = hashPassword(password);
    if (!hashedPassword.equals(user.getPassword())) {
      throw new IllegalArgumentException("账号或密码错误");
    }

    // 生成 token
    String token = jwtUtil.generateToken(user.getId());

    Map<String, Object> result = new HashMap<>();
    result.put("token", token);
    // 不返回密码
    user.setPassword(null);
    result.put("user", user);

    log.info("User logged in: {}", username);
    return result;
  }

  /**
   * 密码加密（SHA-256，生产环境建议使用 BCrypt）
   */
  private String hashPassword(String password) {
    try {
      MessageDigest md = MessageDigest.getInstance("SHA-256");
      byte[] hash = md.digest(password.getBytes());
      StringBuilder hexString = new StringBuilder();
      for (byte b : hash) {
        String hex = Integer.toHexString(0xff & b);
        if (hex.length() == 1) {
          hexString.append('0');
        }
        hexString.append(hex);
      }
      return hexString.toString();
    } catch (NoSuchAlgorithmException e) {
      throw new RuntimeException("密码加密失败", e);
    }
  }
}
