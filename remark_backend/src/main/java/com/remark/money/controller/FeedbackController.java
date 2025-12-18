package com.remark.money.controller;

import com.remark.money.dto.FeedbackSubmitRequest;
import com.remark.money.entity.Feedback;
import com.remark.money.service.FeedbackService;
import com.remark.money.util.JwtUtil;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import javax.servlet.http.HttpServletRequest;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/feedback")
public class FeedbackController {

  private final FeedbackService feedbackService;
  private final JwtUtil jwtUtil;

  public FeedbackController(FeedbackService feedbackService, JwtUtil jwtUtil) {
    this.feedbackService = feedbackService;
    this.jwtUtil = jwtUtil;
  }

  @PostMapping("/submit")
  public ResponseEntity<Map<String, Object>> submit(
      @RequestBody FeedbackSubmitRequest body,
      HttpServletRequest request
  ) {
    final String content = body == null ? null : body.getContent();
    if (!StringUtils.hasText(content)) {
      return buildErrorResponse("反馈内容不能为空", HttpStatus.BAD_REQUEST);
    }
    if (content.length() > 2000) {
      return buildErrorResponse("反馈内容最多 2000 字", HttpStatus.BAD_REQUEST);
    }

    Long userId = tryGetUserId(request);

    Feedback feedback = new Feedback();
    feedback.setUserId(userId);
    feedback.setContent(content.trim());
    if (body != null && StringUtils.hasText(body.getContact())) {
      feedback.setContact(body.getContact().trim());
    }
    feedback.setIp(resolveClientIp(request));
    feedback.setUserAgent(request.getHeader("User-Agent"));

    final Long id = feedbackService.submit(feedback);
    Map<String, Object> resp = new HashMap<>();
    resp.put("success", true);
    resp.put("id", id);
    return ResponseEntity.ok(resp);
  }

  // 简易管理接口：拉取最近 N 条（后续可加鉴权/分页）
  @GetMapping("/recent")
  public ResponseEntity<Map<String, Object>> recent(@RequestParam(value = "limit", defaultValue = "50") int limit) {
    int safeLimit = Math.max(1, Math.min(limit, 200));
    List<Feedback> list = feedbackService.listRecent(safeLimit);
    Map<String, Object> resp = new HashMap<>();
    resp.put("success", true);
    resp.put("items", list);
    return ResponseEntity.ok(resp);
  }

  private Long tryGetUserId(HttpServletRequest request) {
    try {
      String auth = request.getHeader("Authorization");
      if (!StringUtils.hasText(auth) || !auth.startsWith("Bearer ")) {
        return null;
      }
      String token = auth.substring(7);
      return jwtUtil.parseUserId(token);
    } catch (Exception ignored) {
      return null;
    }
  }

  private String resolveClientIp(HttpServletRequest request) {
    String xff = request.getHeader("X-Forwarded-For");
    if (StringUtils.hasText(xff)) {
      String first = xff.split(",")[0].trim();
      if (!first.isEmpty()) return first;
    }
    String realIp = request.getHeader("X-Real-IP");
    if (StringUtils.hasText(realIp)) return realIp.trim();
    return request.getRemoteAddr();
  }

  private ResponseEntity<Map<String, Object>> buildErrorResponse(String message, HttpStatus status) {
    Map<String, Object> resp = new HashMap<>();
    resp.put("success", false);
    resp.put("error", message);
    return ResponseEntity.status(status).body(resp);
  }
}

