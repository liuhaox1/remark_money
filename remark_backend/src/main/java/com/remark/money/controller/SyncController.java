package com.remark.money.controller;

import com.remark.money.entity.AccountInfo;
import com.remark.money.entity.BillInfo;
import com.remark.money.entity.SyncRecord;
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

  /**
   * 从请求头获取JWT并解析userId
   */
  private Long getUserIdFromToken(String token) {
    if (token == null || !token.startsWith("Bearer ")) {
      throw new IllegalArgumentException("无效的Token");
    }
    String jwt = token.substring(7);
    return jwtUtil.parseUserId(jwt);
  }

  /**
   * 全量上传
   */
  @PostMapping("/full/upload")
  public ResponseEntity<Map<String, Object>> fullUpload(
      @RequestHeader("Authorization") String token,
      @RequestBody Map<String, Object> request) {
    try {
      Long userId = getUserIdFromToken(token);
      String deviceId = (String) request.get("deviceId");
      String bookId = (String) request.get("bookId");
      int batchNum = ((Number) request.get("batchNum")).intValue();
      int totalBatches = ((Number) request.get("totalBatches")).intValue();
      @SuppressWarnings("unchecked")
      List<Map<String, Object>> billsData = (List<Map<String, Object>>) request.get("bills");
      
      List<BillInfo> bills = billsData.stream()
          .map(this::mapToBillInfo)
          .collect(Collectors.toList());
      
      SyncService.SyncResult result = syncService.fullUpload(userId, bookId, deviceId, bills, batchNum, totalBatches);

      Map<String, Object> response = new HashMap<>();
      if (result.isSuccess()) {
        response.put("success", true);
        response.put("successCount", result.getSuccessCount());
        response.put("skipCount", result.getSkipCount());
        response.put("syncRecord", convertSyncRecord(result.getSyncRecord()));
        response.put("bills", result.getBills());
        if (result.getQuotaWarning() != null) {
          response.put("quotaWarning", result.getQuotaWarning());
        }
        return ResponseEntity.ok(response);
      } else {
        response.put("success", false);
        response.put("error", result.getError());
        return ResponseEntity.badRequest().body(response);
      }
    } catch (Exception e) {
      log.error("Full upload error", e);
      Map<String, Object> response = new HashMap<>();
      response.put("success", false);
      response.put("error", "服务器错误: " + e.getMessage());
      return ResponseEntity.status(500).body(response);
    }
  }

  /**
   * 全量拉取
   */
  @GetMapping("/full/download")
  public ResponseEntity<Map<String, Object>> fullDownload(
      @RequestHeader("Authorization") String token,
      @RequestParam("deviceId") String deviceId,
      @RequestParam("bookId") String bookId,
      @RequestParam(value = "offset", defaultValue = "0") int offset,
      @RequestParam(value = "limit", defaultValue = "100") int limit) {
    try {
      Long userId = getUserIdFromToken(token);
      SyncService.SyncResult result = syncService.fullDownload(userId, bookId, deviceId, offset, limit);

      Map<String, Object> response = new HashMap<>();
      if (result.isSuccess()) {
        response.put("success", true);
        response.put("bills", result.getBills());
        response.put("syncRecord", convertSyncRecord(result.getSyncRecord()));
        response.put("hasMore", result.getBills() != null && result.getBills().size() == limit);
        return ResponseEntity.ok(response);
      } else {
        response.put("success", false);
        response.put("error", result.getError());
        return ResponseEntity.badRequest().body(response);
      }
    } catch (Exception e) {
      log.error("Full download error", e);
      Map<String, Object> response = new HashMap<>();
      response.put("success", false);
      response.put("error", "服务器错误: " + e.getMessage());
      return ResponseEntity.status(500).body(response);
    }
  }

  /**
   * 增量上传
   */
  @PostMapping("/increment/upload")
  public ResponseEntity<Map<String, Object>> incrementalUpload(
      @RequestHeader("Authorization") String token,
      @RequestBody Map<String, Object> request) {
    try {
      Long userId = getUserIdFromToken(token);
      String deviceId = (String) request.get("deviceId");
      String bookId = (String) request.get("bookId");
      @SuppressWarnings("unchecked")
      List<Map<String, Object>> billsData = (List<Map<String, Object>>) request.get("bills");
      
      List<BillInfo> bills = billsData.stream()
          .map(this::mapToBillInfo)
          .collect(Collectors.toList());
      
      SyncService.SyncResult result = syncService.incrementalUpload(userId, bookId, deviceId, bills);

      Map<String, Object> response = new HashMap<>();
      if (result.isSuccess()) {
        response.put("success", true);
        response.put("successCount", result.getSuccessCount());
        response.put("skipCount", result.getSkipCount());
        response.put("syncRecord", convertSyncRecord(result.getSyncRecord()));
        response.put("bills", result.getBills());
        if (result.getQuotaWarning() != null) {
          response.put("quotaWarning", result.getQuotaWarning());
        }
        return ResponseEntity.ok(response);
      } else {
        response.put("success", false);
        response.put("error", result.getError());
        return ResponseEntity.badRequest().body(response);
      }
    } catch (Exception e) {
      log.error("Incremental upload error", e);
      Map<String, Object> response = new HashMap<>();
      response.put("success", false);
      response.put("error", "服务器错误: " + e.getMessage());
      return ResponseEntity.status(500).body(response);
    }
  }

  /**
   * 增量拉取
   */
  @GetMapping("/increment/download")
  public ResponseEntity<Map<String, Object>> incrementalDownload(
      @RequestHeader("Authorization") String token,
      @RequestParam("deviceId") String deviceId,
      @RequestParam("bookId") String bookId,
      @RequestParam(value = "lastSyncTime", required = false) String lastSyncTimeStr,
      @RequestParam(value = "lastSyncId", required = false) Long lastSyncId,
      @RequestParam(value = "offset", defaultValue = "0") int offset,
      @RequestParam(value = "limit", defaultValue = "100") int limit) {
    try {
      Long userId = getUserIdFromToken(token);
      LocalDateTime lastSyncTime = null;
      if (lastSyncTimeStr != null && !lastSyncTimeStr.isEmpty()) {
        lastSyncTime = LocalDateTime.parse(lastSyncTimeStr, DateTimeFormatter.ISO_LOCAL_DATE_TIME);
      }

      SyncService.SyncResult result = syncService.incrementalDownload(
          userId, bookId, deviceId, lastSyncTime, lastSyncId, offset, limit);

      Map<String, Object> response = new HashMap<>();
      if (result.isSuccess()) {
        response.put("success", true);
        response.put("bills", result.getBills());
        response.put("syncRecord", convertSyncRecord(result.getSyncRecord()));
        response.put("hasMore", result.getBills() != null && result.getBills().size() == limit);
        return ResponseEntity.ok(response);
      } else {
        response.put("success", false);
        response.put("error", result.getError());
        return ResponseEntity.badRequest().body(response);
      }
    } catch (Exception e) {
      log.error("Incremental download error", e);
      Map<String, Object> response = new HashMap<>();
      response.put("success", false);
      response.put("error", "服务器错误: " + e.getMessage());
      return ResponseEntity.status(500).body(response);
    }
  }

  /**
   * 查询同步状态
   */
  @GetMapping("/status/query")
  public ResponseEntity<Map<String, Object>> queryStatus(
      @RequestHeader("Authorization") String token,
      @RequestParam("deviceId") String deviceId,
      @RequestParam("bookId") String bookId) {
    try {
      Long userId = getUserIdFromToken(token);
      SyncService.SyncResult result = syncService.queryStatus(userId, bookId, deviceId);

      Map<String, Object> response = new HashMap<>();
      if (result.isSuccess()) {
        response.put("success", true);
        response.put("syncRecord", convertSyncRecord(result.getSyncRecord()));
        if (result.getUser() != null) {
          Map<String, Object> userInfo = new HashMap<>();
          userInfo.put("payType", result.getUser().getPayType());
          userInfo.put("payExpire", result.getUser().getPayExpire());
          response.put("user", userInfo);
        }
        return ResponseEntity.ok(response);
      } else {
        response.put("success", false);
        response.put("error", result.getError());
        return ResponseEntity.badRequest().body(response);
      }
    } catch (Exception e) {
      log.error("Query status error", e);
      Map<String, Object> response = new HashMap<>();
      response.put("success", false);
      response.put("error", "服务器错误: " + e.getMessage());
      return ResponseEntity.status(500).body(response);
    }
  }

  /**
   * 将Map转换为BillInfo
   */
  private BillInfo mapToBillInfo(Map<String, Object> map) {
    BillInfo bill = new BillInfo();
    // serverId 从客户端回传，用于幂等/更新
    Object serverIdObj = map.get("serverId");
    if (serverIdObj instanceof Number) {
      bill.setId(((Number) serverIdObj).longValue());
    }
    bill.setBookId((String) map.get("bookId"));
    bill.setAccountId((String) map.get("accountId"));
    bill.setCategoryKey((String) map.get("categoryKey"));
    
    Object amountObj = map.get("amount");
    if (amountObj instanceof Number) {
      bill.setAmount(java.math.BigDecimal.valueOf(((Number) amountObj).doubleValue()));
    }
    
    Object directionObj = map.get("direction");
    if (directionObj instanceof Number) {
      bill.setDirection(((Number) directionObj).intValue());
    }
    
    bill.setRemark((String) map.get("remark"));
    bill.setAttachmentUrl((String) map.get("attachmentUrl"));
    
    String billDateStr = (String) map.get("billDate");
    if (billDateStr != null) {
      bill.setBillDate(java.time.LocalDateTime.parse(billDateStr));
    }
    
    Object includeInStatsObj = map.get("includeInStats");
    if (includeInStatsObj instanceof Number) {
      bill.setIncludeInStats(((Number) includeInStatsObj).intValue());
    }
    
    bill.setPairId((String) map.get("pairId"));
    
    Object isDeleteObj = map.get("isDelete");
    if (isDeleteObj instanceof Number) {
      bill.setIsDelete(((Number) isDeleteObj).intValue());
    }
    
    String updateTimeStr = (String) map.get("updateTime");
    if (updateTimeStr != null) {
      bill.setUpdateTime(java.time.LocalDateTime.parse(updateTimeStr));
    }
    
    return bill;
  }

  /**
   * 转换SyncRecord为Map（便于JSON序列化）
   */
  private Map<String, Object> convertSyncRecord(SyncRecord record) {
    if (record == null) {
      return null;
    }
    Map<String, Object> map = new HashMap<>();
    map.put("userId", record.getUserId());
    map.put("bookId", record.getBookId());
    map.put("deviceId", record.getDeviceId());
    map.put("lastSyncId", record.getLastSyncId());
    map.put("lastSyncTime", record.getLastSyncTime() != null
        ? record.getLastSyncTime().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME) : null);
    map.put("cloudBillCount", record.getCloudBillCount());
    map.put("syncDeviceId", record.getSyncDeviceId());
    map.put("dataVersion", record.getDataVersion());
    return map;
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
      List<Map<String, Object>> accountsData = (List<Map<String, Object>>) request.get("accounts");

      List<AccountInfo> accounts = accountsData.stream()
          .map(this::mapToAccountInfo)
          .collect(Collectors.toList());

      SyncService.AccountSyncResult result = syncService.uploadAccounts(userId, accounts);

      Map<String, Object> response = new HashMap<>();
      if (result.isSuccess()) {
        response.put("success", true);
        response.put("accounts", result.getAccounts().stream()
            .map(this::convertAccountInfo)
            .collect(Collectors.toList()));
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
      response.put("error", "服务器错误: " + e.getMessage());
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
        response.put("accounts", result.getAccounts().stream()
            .map(this::convertAccountInfo)
            .collect(Collectors.toList()));
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
      response.put("error", "服务器错误: " + e.getMessage());
      return ResponseEntity.status(500).body(response);
    }
  }

  private AccountInfo mapToAccountInfo(Map<String, Object> map) {
    AccountInfo account = new AccountInfo();
    // serverId 从客户端回传，用于更新
    Object serverIdObj = map.get("serverId");
    if (serverIdObj instanceof Number) {
      account.setId(((Number) serverIdObj).longValue());
    }
    // accountId 是客户端临时ID（首次上传时使用）
    account.setAccountId((String) map.get("id"));
    account.setName((String) map.get("name"));
    account.setKind((String) map.get("kind"));
    account.setSubtype((String) map.get("subtype"));
    account.setType((String) map.get("type"));
    account.setIcon((String) map.get("icon"));
    account.setIncludeInTotal(((Number) map.getOrDefault("includeInTotal", 1)).intValue());
    account.setIncludeInOverview(((Number) map.getOrDefault("includeInOverview", 1)).intValue());
    account.setCurrency((String) map.getOrDefault("currency", "CNY"));
    account.setSortOrder(((Number) map.getOrDefault("sortOrder", 0)).intValue());
    account.setInitialBalance(new java.math.BigDecimal(map.getOrDefault("initialBalance", 0).toString()));
    account.setCurrentBalance(new java.math.BigDecimal(map.getOrDefault("currentBalance", 0).toString()));
    account.setCounterparty((String) map.get("counterparty"));
    if (map.get("interestRate") != null) {
      account.setInterestRate(new java.math.BigDecimal(map.get("interestRate").toString()));
    }
    if (map.get("dueDate") != null) {
      account.setDueDate(LocalDateTime.parse((String) map.get("dueDate"), DateTimeFormatter.ISO_LOCAL_DATE_TIME));
    }
    account.setNote((String) map.get("note"));
    account.setBrandKey((String) map.get("brandKey"));
    if (map.get("updateTime") != null) {
      account.setUpdateTime(LocalDateTime.parse((String) map.get("updateTime"), DateTimeFormatter.ISO_LOCAL_DATE_TIME));
    }
    return account;
  }

  private Map<String, Object> convertAccountInfo(AccountInfo account) {
    Map<String, Object> map = new HashMap<>();
    map.put("id", account.getId()); // 服务器ID（serverId）
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

