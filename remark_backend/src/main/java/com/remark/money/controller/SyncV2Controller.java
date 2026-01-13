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

  private Long tryGetUserIdFromToken(String token) {
    if (token == null || !token.startsWith("Bearer ")) {
      return null;
    }
    String jwt = token.substring(7);
    try {
      return jwtUtil.parseUserId(jwt);
    } catch (Exception e) {
      return null;
    }
  }

  private ResponseEntity<Map<String, Object>> error(int status, String message) {
    Map<String, Object> resp = new HashMap<>();
    resp.put("success", false);
    resp.put("error", message);
    return ResponseEntity.status(status).body(resp);
  }

  @PostMapping("/push")
  public ResponseEntity<Map<String, Object>> push(
      @RequestHeader("Authorization") String token,
      @RequestHeader(value = "X-Sync-Reason", required = false) String reason,
      @RequestHeader(value = "X-Client-Request-Id", required = false) String requestId,
      @RequestHeader(value = "X-Device-Id", required = false) String deviceId,
      @RequestBody Map<String, Object> request) {
    try {
      Long userId = tryGetUserIdFromToken(token);
      if (userId == null) return error(401, "unauthorized");
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
    } catch (IllegalArgumentException e) {
      final String msg = e.getMessage() != null ? e.getMessage() : "bad request";
      if (msg.toLowerCase().contains("no access")) {
        return error(403, msg);
      }
      return error(400, msg);
    } catch (Exception e) {
      log.error("Sync v2 push error", e);
      // Do not leak 500 to clients: keep response parseable so client can retry safely.
      return error(200, "server error");
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
      Long userId = tryGetUserIdFromToken(token);
      if (userId == null) return error(401, "unauthorized");
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
    } catch (IllegalArgumentException e) {
      final String msg = e.getMessage() != null ? e.getMessage() : "bad request";
      if (msg.toLowerCase().contains("no access")) {
        return error(403, msg);
      }
      return error(400, msg);
    } catch (Exception e) {
      log.error("Sync v2 pull error", e);
      return error(200, "server error");
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
      Long userId = tryGetUserIdFromToken(token);
      if (userId == null) return error(401, "unauthorized");
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
    } catch (IllegalArgumentException e) {
      final String msg = e.getMessage() != null ? e.getMessage() : "bad request";
      if (msg.toLowerCase().contains("no access")) {
        return error(403, msg);
      }
      return error(400, msg);
    } catch (Exception e) {
      log.error("Sync v2 summary error", e);
      return error(200, "server error");
    }
  }

  @PostMapping("/ids/allocate")
  public ResponseEntity<Map<String, Object>> allocateIds(
      @RequestHeader("Authorization") String token,
      @RequestHeader(value = "X-Client-Request-Id", required = false) String requestId,
      @RequestHeader(value = "X-Device-Id", required = false) String deviceId,
      @RequestBody Map<String, Object> request) {
    try {
      Long userId = tryGetUserIdFromToken(token); // validate token
      if (userId == null) return error(401, "unauthorized");
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
            requestId,
            deviceId);
      }
      return ResponseEntity.ok(resp);
    } catch (Exception e) {
      log.error("Sync v2 allocate ids error", e);
      return error(200, "server error");
    }
  }

  @GetMapping("/activity")
  public ResponseEntity<Map<String, Object>> activity(
      @RequestHeader("Authorization") String token,
      @RequestHeader(value = "X-Client-Request-Id", required = false) String requestId,
      @RequestHeader(value = "X-Device-Id", required = false) String deviceId,
      @RequestParam("bookId") String bookId,
      @RequestParam(value = "beforeChangeId", required = false) Long beforeChangeId,
      @RequestParam(value = "limit", defaultValue = "50") int limit) {
    try {
      Long userId = tryGetUserIdFromToken(token);
      if (userId == null) return error(401, "unauthorized");
      if (log.isDebugEnabled()) {
        log.debug(
            "SyncV2 activity userId={} bookId={} beforeChangeId={} limit={} reqId={} deviceId={}",
            userId,
            bookId,
            beforeChangeId,
            limit,
            requestId,
            deviceId);
      }
      Map<String, Object> resp = syncV2Service.activity(userId, bookId, beforeChangeId, limit);
      return ResponseEntity.ok(resp);
    } catch (IllegalArgumentException e) {
      final String msg = e.getMessage() != null ? e.getMessage() : "bad request";
      if (msg.toLowerCase().contains("no access")) {
        return error(403, msg);
      }
      return error(400, msg);
    } catch (Exception e) {
      log.error("Sync v2 activity error", e);
      return error(200, "server error");
    }
  }
}
