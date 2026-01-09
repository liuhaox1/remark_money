package com.remark.money.controller;

import com.remark.money.entity.User;
import com.remark.money.mapper.UserMapper;
import com.remark.money.util.JwtUtil;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.servlet.http.HttpServletRequest;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/users")
public class UserController {

  private final UserMapper userMapper;
  private final JwtUtil jwtUtil;

  public UserController(UserMapper userMapper, JwtUtil jwtUtil) {
    this.userMapper = userMapper;
    this.jwtUtil = jwtUtil;
  }

  @GetMapping("/{id}")
  public User getById(@PathVariable("id") Long id) {
    return userMapper.findById(id);
  }

  @PostMapping("/me/nickname")
  public Map<String, Object> updateNickname(
      @RequestBody Map<String, Object> body, HttpServletRequest request) {
    Long userId = getUserId(request);
    String nickname = body.get("nickname") != null ? body.get("nickname").toString() : null;
    if (!StringUtils.hasText(nickname)) {
      throw new IllegalArgumentException("昵称不能为空");
    }
    nickname = nickname.trim();
    if (nickname.length() > 20) {
      throw new IllegalArgumentException("昵称最多20个字符");
    }
    int updated = userMapper.updateNickname(userId, nickname);
    if (updated <= 0) {
      throw new IllegalArgumentException("更新失败");
    }

    User user = userMapper.findById(userId);
    if (user != null) {
      user.setPassword(null);
    }
    Map<String, Object> resp = new HashMap<>();
    resp.put("success", true);
    resp.put("user", user);
    return resp;
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
