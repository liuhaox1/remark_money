package com.remark.money.controller;

import com.remark.money.entity.AccountInfo;
import com.remark.money.service.SyncService;
import com.remark.money.util.JwtUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/sync")
public class SyncController {

  private static final Logger log = LoggerFactory.getLogger(SyncController.class);

  private final SyncService syncService;
  private final JwtUtil jwtUtil;

  public SyncController(SyncService syncService, JwtUtil jwtUtil) {
    this.syncService = syncService;
    this.jwtUtil = jwtUtil;
  }

  private Long getUserIdFromToken(String token) {
    if (token == null || !token.startsWith("Bearer ")) {
      throw new IllegalArgumentException("invalid token");
    }
    String jwt = token.substring(7);
    return jwtUtil.parseUserId(jwt);
  }

  /**
   * 上传账户数据
   */
  @PostMapping("/account/upload")
  public ResponseEntity<Map<String, Object>> uploadAccounts(
      @RequestHeader("Authorization") String token,
      @RequestBody Map<String, Object> request) {
    try {
      Long userId = getUserIdFromToken(token);
      @SuppressWarnings("unchecked")
      List<Map<String, Object>> accountsData =
          (List<Map<String, Object>>) request.get("accounts");

      List<AccountInfo> accounts =
          accountsData.stream().map(this::mapToAccountInfo).collect(Collectors.toList());

      SyncService.AccountSyncResult result = syncService.uploadAccounts(userId, accounts);

      Map<String, Object> response = new HashMap<>();
      if (result.isSuccess()) {
        response.put("success", true);
        response.put(
            "accounts",
            result.getAccounts().stream().map(this::convertAccountInfo).collect(Collectors.toList()));
        return ResponseEntity.ok(response);
      } else {
        response.put("success", false);
        response.put("error", result.getError());
        return ResponseEntity.badRequest().body(response);
      }
    } catch (Exception e) {
      log.error("Account upload error", e);
      Map<String, Object> response = new HashMap<>();
      response.put("success", false);
      response.put("error", "server error: " + e.getMessage());
      return ResponseEntity.status(500).body(response);
    }
  }

  /**
   * 下载账户数据
   */
  @GetMapping("/account/download")
  public ResponseEntity<Map<String, Object>> downloadAccounts(
      @RequestHeader("Authorization") String token) {
    try {
      Long userId = getUserIdFromToken(token);
      SyncService.AccountSyncResult result = syncService.downloadAccounts(userId);

      Map<String, Object> response = new HashMap<>();
      if (result.isSuccess()) {
        response.put("success", true);
        response.put(
            "accounts",
            result.getAccounts().stream().map(this::convertAccountInfo).collect(Collectors.toList()));
        return ResponseEntity.ok(response);
      } else {
        response.put("success", false);
        response.put("error", result.getError());
        return ResponseEntity.badRequest().body(response);
      }
    } catch (Exception e) {
      log.error("Account download error", e);
      Map<String, Object> response = new HashMap<>();
      response.put("success", false);
      response.put("error", "server error: " + e.getMessage());
      return ResponseEntity.status(500).body(response);
    }
  }

  private AccountInfo mapToAccountInfo(Map<String, Object> map) {
    AccountInfo account = new AccountInfo();
    Object serverIdObj = map.get("serverId");
    if (serverIdObj instanceof Number) {
      account.setId(((Number) serverIdObj).longValue());
    }
    account.setAccountId((String) map.get("id"));
    account.setName((String) map.get("name"));
    account.setKind((String) map.get("kind"));
    account.setSubtype((String) map.get("subtype"));
    account.setType((String) map.get("type"));
    account.setIcon((String) map.get("icon"));
    account.setIncludeInTotal(asInt(map.get("includeInTotal"), 1));
    account.setIncludeInOverview(asInt(map.get("includeInOverview"), 1));
    account.setCurrency((String) map.getOrDefault("currency", "CNY"));
    account.setSortOrder(asInt(map.get("sortOrder"), 0));
    account.setInitialBalance(
        new java.math.BigDecimal(map.getOrDefault("initialBalance", 0).toString()));
    account.setCurrentBalance(
        new java.math.BigDecimal(map.getOrDefault("currentBalance", 0).toString()));
    account.setCounterparty((String) map.get("counterparty"));
    if (map.get("interestRate") != null) {
      account.setInterestRate(new java.math.BigDecimal(map.get("interestRate").toString()));
    }
    if (map.get("dueDate") != null) {
      account.setDueDate(
          LocalDateTime.parse((String) map.get("dueDate"), DateTimeFormatter.ISO_LOCAL_DATE_TIME));
    }
    account.setNote((String) map.get("note"));
    account.setBrandKey((String) map.get("brandKey"));
    if (map.get("updateTime") != null) {
      account.setUpdateTime(
          LocalDateTime.parse(
              (String) map.get("updateTime"), DateTimeFormatter.ISO_LOCAL_DATE_TIME));
    }
    return account;
  }

  private int asInt(Object value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value instanceof Number) {
      return ((Number) value).intValue();
    }
    if (value instanceof Boolean) {
      return ((Boolean) value) ? 1 : 0;
    }
    if (value instanceof String) {
      String s = ((String) value).trim();
      if (s.isEmpty()) return defaultValue;
      if ("true".equalsIgnoreCase(s)) return 1;
      if ("false".equalsIgnoreCase(s)) return 0;
      try {
        return Integer.parseInt(s);
      } catch (NumberFormatException ignored) {
        return defaultValue;
      }
    }
    return defaultValue;
  }

  private Map<String, Object> convertAccountInfo(AccountInfo account) {
    Map<String, Object> map = new HashMap<>();
    // 客户端用于关联账单的稳定账户ID（account_info.account_id）
    map.put("id", account.getAccountId());
    // 服务器自增ID（用于客户端去重/更新）
    map.put("serverId", account.getId());
    map.put("name", account.getName());
    map.put("kind", account.getKind());
    map.put("subtype", account.getSubtype());
    map.put("type", account.getType());
    map.put("icon", account.getIcon());
    map.put("includeInTotal", account.getIncludeInTotal());
    map.put("includeInOverview", account.getIncludeInOverview());
    map.put("currency", account.getCurrency());
    map.put("sortOrder", account.getSortOrder());
    map.put("initialBalance", account.getInitialBalance());
    map.put("currentBalance", account.getCurrentBalance());
    map.put("counterparty", account.getCounterparty());
    map.put("interestRate", account.getInterestRate());
    if (account.getDueDate() != null) {
      map.put("dueDate", account.getDueDate().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
    }
    map.put("note", account.getNote());
    map.put("brandKey", account.getBrandKey());
    if (account.getUpdateTime() != null) {
      map.put("updateTime", account.getUpdateTime().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
    }
    if (account.getCreatedAt() != null) {
      map.put("createdAt", account.getCreatedAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
    }
    return map;
  }
}
