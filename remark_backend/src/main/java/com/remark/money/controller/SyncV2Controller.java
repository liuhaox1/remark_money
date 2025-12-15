package com.remark.money.controller;

import com.remark.money.service.SyncV2Service;
import com.remark.money.util.JwtUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/sync/v2")
public class SyncV2Controller {

  private static final Logger log = LoggerFactory.getLogger(SyncV2Controller.class);

  private final SyncV2Service syncV2Service;
  private final JwtUtil jwtUtil;

  public SyncV2Controller(SyncV2Service syncV2Service, JwtUtil jwtUtil) {
    this.syncV2Service = syncV2Service;
    this.jwtUtil = jwtUtil;
  }

  private Long getUserIdFromToken(String token) {
    if (token == null || !token.startsWith("Bearer ")) {
      throw new IllegalArgumentException("invalid token");
    }
    String jwt = token.substring(7);
    return jwtUtil.parseUserId(jwt);
  }

  @PostMapping("/push")
  public ResponseEntity<Map<String, Object>> push(
      @RequestHeader("Authorization") String token,
      @RequestBody Map<String, Object> request) {
    try {
      Long userId = getUserIdFromToken(token);
      String bookId = (String) request.get("bookId");
      @SuppressWarnings("unchecked")
      List<Map<String, Object>> ops = (List<Map<String, Object>>) request.get("ops");

      Map<String, Object> resp = syncV2Service.push(userId, bookId, ops);
      return ResponseEntity.ok(resp);
    } catch (Exception e) {
      log.error("Sync v2 push error", e);
      Map<String, Object> resp = new HashMap<>();
      resp.put("success", false);
      resp.put("error", e.getMessage());
      return ResponseEntity.status(500).body(resp);
    }
  }

  @GetMapping("/pull")
  public ResponseEntity<Map<String, Object>> pull(
      @RequestHeader("Authorization") String token,
      @RequestParam("bookId") String bookId,
      @RequestParam(value = "afterChangeId", required = false) Long afterChangeId,
      @RequestParam(value = "limit", defaultValue = "200") int limit) {
    try {
      Long userId = getUserIdFromToken(token);
      Map<String, Object> resp = syncV2Service.pull(userId, bookId, afterChangeId, limit);
      return ResponseEntity.ok(resp);
    } catch (Exception e) {
      log.error("Sync v2 pull error", e);
      Map<String, Object> resp = new HashMap<>();
      resp.put("success", false);
      resp.put("error", e.getMessage());
      return ResponseEntity.status(500).body(resp);
    }
  }
}

