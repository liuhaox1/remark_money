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
      @RequestHeader(value = "X-Sync-Reason", required = false) String reason,
      @RequestHeader(value = "X-Client-Request-Id", required = false) String requestId,
      @RequestHeader(value = "X-Device-Id", required = false) String deviceId,
      @RequestBody Map<String, Object> request) {
    try {
      Long userId = getUserIdFromToken(token);
      String bookId = (String) request.get("bookId");
      @SuppressWarnings("unchecked")
      List<Map<String, Object>> ops = (List<Map<String, Object>>) request.get("ops");

      if (log.isDebugEnabled()) {
        log.debug(
            "SyncV2 push userId={} bookId={} ops={} reason={} reqId={} deviceId={}",
            userId,
            bookId,
            ops == null ? 0 : ops.size(),
            reason,
            requestId,
            deviceId);
      }
      Map<String, Object> resp = syncV2Service.push(userId, bookId, ops, requestId, deviceId, reason);
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
      @RequestHeader(value = "X-Sync-Reason", required = false) String reason,
      @RequestHeader(value = "X-Client-Request-Id", required = false) String requestId,
      @RequestHeader(value = "X-Device-Id", required = false) String deviceId,
      @RequestParam("bookId") String bookId,
      @RequestParam(value = "afterChangeId", required = false) Long afterChangeId,
      @RequestParam(value = "limit", defaultValue = "200") int limit) {
    try {
      Long userId = getUserIdFromToken(token);
      if (log.isDebugEnabled()) {
        log.debug(
            "SyncV2 pull userId={} bookId={} afterChangeId={} limit={} reason={} reqId={} deviceId={}",
            userId,
            bookId,
            afterChangeId,
            limit,
            reason,
            requestId,
            deviceId);
      }
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

  @GetMapping("/summary")
  public ResponseEntity<Map<String, Object>> summary(
      @RequestHeader("Authorization") String token,
      @RequestHeader(value = "X-Sync-Reason", required = false) String reason,
      @RequestHeader(value = "X-Client-Request-Id", required = false) String requestId,
      @RequestHeader(value = "X-Device-Id", required = false) String deviceId,
      @RequestParam("bookId") String bookId) {
    try {
      Long userId = getUserIdFromToken(token);
      if (log.isDebugEnabled()) {
        log.debug(
            "SyncV2 summary userId={} bookId={} reason={} reqId={} deviceId={}",
            userId,
            bookId,
            reason,
            requestId,
            deviceId);
      }
      Map<String, Object> resp = syncV2Service.summary(userId, bookId);
      return ResponseEntity.ok(resp);
    } catch (Exception e) {
      log.error("Sync v2 summary error", e);
      Map<String, Object> resp = new HashMap<>();
      resp.put("success", false);
      resp.put("error", e.getMessage());
      return ResponseEntity.status(500).body(resp);
    }
  }

  @PostMapping("/ids/allocate")
  public ResponseEntity<Map<String, Object>> allocateIds(
      @RequestHeader("Authorization") String token,
      @RequestBody Map<String, Object> request) {
    try {
      getUserIdFromToken(token); // validate token
      Integer count = null;
      Object c = request.get("count");
      if (c instanceof Number) count = ((Number) c).intValue();
      if (c instanceof String) {
        try {
          count = Integer.parseInt(((String) c).trim());
        } catch (Exception ignored) {
        }
      }
      if (count == null) count = 200;
      Map<String, Object> resp = syncV2Service.allocateBillIds(count);
      if (log.isDebugEnabled()) {
        log.debug("SyncV2 allocateIds count={} startId={} endId={} reqId={} deviceId={}",
            resp.get("count"),
            resp.get("startId"),
            resp.get("endId"),
            request.get("reqId"),
            request.get("deviceId"));
      }
      return ResponseEntity.ok(resp);
    } catch (Exception e) {
      log.error("Sync v2 allocate ids error", e);
      Map<String, Object> resp = new HashMap<>();
      resp.put("success", false);
      resp.put("error", e.getMessage());
      return ResponseEntity.status(500).body(resp);
    }
  }
}
