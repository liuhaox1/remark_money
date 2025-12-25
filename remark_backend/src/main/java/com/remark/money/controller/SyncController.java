package com.remark.money.controller;

import com.remark.money.entity.AccountInfo;
import com.remark.money.entity.BudgetInfo;
import com.remark.money.entity.CategoryInfo;
import com.remark.money.entity.TagInfo;
import com.remark.money.service.SyncService;
import com.remark.money.util.JwtUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Collections;
import java.util.ArrayList;
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

      @SuppressWarnings("unchecked")
      List<Map<String, Object>> deletedAccountsData =
          (List<Map<String, Object>>) request.get("deletedAccounts");

      List<Long> deletedServerIds = null;
      List<String> deletedAccountIds = null;
      if (deletedAccountsData != null && !deletedAccountsData.isEmpty()) {
        deletedServerIds = deletedAccountsData.stream()
            .map(m -> m.get("serverId"))
            .filter(v -> v instanceof Number)
            .map(v -> ((Number) v).longValue())
            .collect(Collectors.toList());
        deletedAccountIds = deletedAccountsData.stream()
            .map(m -> m.get("id"))
            .filter(v -> v instanceof String)
            .map(v -> ((String) v).trim())
            .filter(v -> !v.isEmpty())
            .collect(Collectors.toList());
      }

      SyncService.AccountSyncResult result;
      if (accountsData == null) {
        accountsData = Collections.emptyList();
      }

      if (accountsData.isEmpty()
          && (deletedServerIds == null || deletedServerIds.isEmpty())
          && (deletedAccountIds == null || deletedAccountIds.isEmpty())) {
        Map<String, Object> response = new HashMap<>();
        response.put("success", false);
        response.put("error", "missing accounts");
        return ResponseEntity.badRequest().body(response);
      }

      if (deletedServerIds != null || deletedAccountIds != null) {
        // Apply explicit deletions first (soft delete), then upsert remaining accounts.
        SyncService.AccountSyncResult del =
            syncService.deleteAccounts(userId, deletedServerIds, deletedAccountIds);
        if (!del.isSuccess()) {
          Map<String, Object> response = new HashMap<>();
          response.put("success", false);
          response.put("error", del.getError());
          return ResponseEntity.badRequest().body(response);
        }
        if (accountsData.isEmpty()) {
          result = del;
        } else {
          List<AccountInfo> accounts =
              accountsData.stream().map(this::mapToAccountInfo).collect(Collectors.toList());
          result = syncService.uploadAccounts(userId, accounts);
        }
      } else {
        List<AccountInfo> accounts =
            accountsData.stream().map(this::mapToAccountInfo).collect(Collectors.toList());
        result = syncService.uploadAccounts(userId, accounts);
      }

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
    account.setIsDelete(asInt(map.get("isDelete"), 0));
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
    map.put("isDelete", account.getIsDelete());
    if (account.getUpdateTime() != null) {
      map.put("updateTime", account.getUpdateTime().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
    }
    if (account.getCreatedAt() != null) {
      map.put("createdAt", account.getCreatedAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
    }
    return map;
  }

  /**
   * 上传预算数据
   */
  @PostMapping("/budget/upload")
  public ResponseEntity<Map<String, Object>> uploadBudget(
      @RequestHeader("Authorization") String token,
      @RequestBody Map<String, Object> request) {
    try {
      Long userId = getUserIdFromToken(token);
      String bookId = (String) request.get("bookId");
      Object budgetObj = request.get("budget");
      if (!(budgetObj instanceof Map)) {
        Map<String, Object> response = new HashMap<>();
        response.put("success", false);
        response.put("error", "missing budget");
        return ResponseEntity.badRequest().body(response);
      }
      @SuppressWarnings("unchecked")
      Map<String, Object> budgetMap = (Map<String, Object>) budgetObj;

      BudgetInfo budget = mapToBudgetInfo(budgetMap);
      SyncService.BudgetSyncResult result = syncService.uploadBudget(userId, bookId, budget);

      Map<String, Object> response = new HashMap<>();
      if (result.isSuccess()) {
        response.put("success", true);
        return ResponseEntity.ok(response);
      } else {
        response.put("success", false);
        response.put("error", result.getError());
        return ResponseEntity.badRequest().body(response);
      }
    } catch (Exception e) {
      log.error("Budget upload error", e);
      Map<String, Object> response = new HashMap<>();
      response.put("success", false);
      response.put("error", "server error: " + e.getMessage());
      return ResponseEntity.status(500).body(response);
    }
  }

  /**
   * 下载预算数据
   */
  @GetMapping("/budget/download")
  public ResponseEntity<Map<String, Object>> downloadBudget(
      @RequestHeader("Authorization") String token,
      @RequestParam("bookId") String bookId) {
    try {
      Long userId = getUserIdFromToken(token);
      SyncService.BudgetSyncResult result = syncService.downloadBudget(userId, bookId);

      Map<String, Object> response = new HashMap<>();
      if (result.isSuccess()) {
        response.put("success", true);
        response.put("budget", convertBudgetInfo(result.getBudget()));
        return ResponseEntity.ok(response);
      } else {
        response.put("success", false);
        response.put("error", result.getError());
        return ResponseEntity.badRequest().body(response);
      }
    } catch (Exception e) {
      log.error("Budget download error", e);
      Map<String, Object> response = new HashMap<>();
      response.put("success", false);
      response.put("error", "server error: " + e.getMessage());
      return ResponseEntity.status(500).body(response);
    }
  }

  /**
   * 上传分类数据（按用户）
   */
  @PostMapping("/category/upload")
  public ResponseEntity<Map<String, Object>> uploadCategories(
      @RequestHeader("Authorization") String token,
      @RequestBody Map<String, Object> request) {
    try {
      Long userId = getUserIdFromToken(token);

      @SuppressWarnings("unchecked")
      List<Map<String, Object>> categoriesData =
          (List<Map<String, Object>>) request.get("categories");
      @SuppressWarnings("unchecked")
      List<String> deletedKeys = (List<String>) request.get("deletedKeys");

      List<CategoryInfo> categories = new ArrayList<>();
      if (categoriesData != null) {
        categories = categoriesData.stream().map(this::mapToCategoryInfo).collect(Collectors.toList());
      }

      SyncService.CategorySyncResult result = syncService.uploadCategories(userId, categories, deletedKeys);
      Map<String, Object> response = new HashMap<>();
      if (result.isSuccess()) {
        response.put("success", true);
        response.put(
            "categories",
            result.getCategories().stream().map(this::convertCategoryInfo).collect(Collectors.toList()));
        return ResponseEntity.ok(response);
      } else {
        response.put("success", false);
        response.put("error", result.getError());
        return ResponseEntity.badRequest().body(response);
      }
    } catch (Exception e) {
      log.error("Category upload error", e);
      Map<String, Object> response = new HashMap<>();
      response.put("success", false);
      response.put("error", "server error: " + e.getMessage());
      return ResponseEntity.status(500).body(response);
    }
  }

  /**
   * 下载分类数据（按用户）
   */
  @GetMapping("/category/download")
  public ResponseEntity<Map<String, Object>> downloadCategories(
      @RequestHeader("Authorization") String token) {
    try {
      Long userId = getUserIdFromToken(token);
      SyncService.CategorySyncResult result = syncService.downloadCategories(userId);

      Map<String, Object> response = new HashMap<>();
      if (result.isSuccess()) {
        response.put("success", true);
        response.put(
            "categories",
            result.getCategories().stream().map(this::convertCategoryInfo).collect(Collectors.toList()));
        return ResponseEntity.ok(response);
      } else {
        response.put("success", false);
        response.put("error", result.getError());
        return ResponseEntity.badRequest().body(response);
      }
    } catch (Exception e) {
      log.error("Category download error", e);
      Map<String, Object> response = new HashMap<>();
      response.put("success", false);
      response.put("error", "server error: " + e.getMessage());
      return ResponseEntity.status(500).body(response);
    }
  }

  /**
   * 上传标签数据（按用户+账本）
   */
  @PostMapping("/tag/upload")
  public ResponseEntity<Map<String, Object>> uploadTags(
      @RequestHeader("Authorization") String token,
      @RequestBody Map<String, Object> request) {
    try {
      Long userId = getUserIdFromToken(token);
      String bookId = (String) request.get("bookId");

      @SuppressWarnings("unchecked")
      List<Map<String, Object>> tagsData = (List<Map<String, Object>>) request.get("tags");
      @SuppressWarnings("unchecked")
      List<String> deletedTagIds = (List<String>) request.get("deletedTagIds");

      List<TagInfo> tags = new ArrayList<>();
      if (tagsData != null) {
        tags = tagsData.stream().map(m -> mapToTagInfo(m, bookId)).collect(Collectors.toList());
      }

      SyncService.TagSyncResult result = syncService.uploadTags(userId, bookId, tags, deletedTagIds);
      Map<String, Object> response = new HashMap<>();
      if (result.isSuccess()) {
        response.put("success", true);
        response.put(
            "tags",
            result.getTags().stream().map(this::convertTagInfo).collect(Collectors.toList()));
        return ResponseEntity.ok(response);
      } else {
        response.put("success", false);
        response.put("error", result.getError());
        return ResponseEntity.badRequest().body(response);
      }
    } catch (Exception e) {
      log.error("Tag upload error", e);
      Map<String, Object> response = new HashMap<>();
      response.put("success", false);
      response.put("error", "server error: " + e.getMessage());
      return ResponseEntity.status(500).body(response);
    }
  }

  /**
   * 下载标签数据（按用户+账本）
   */
  @GetMapping("/tag/download")
  public ResponseEntity<Map<String, Object>> downloadTags(
      @RequestHeader("Authorization") String token,
      @RequestParam("bookId") String bookId) {
    try {
      Long userId = getUserIdFromToken(token);
      SyncService.TagSyncResult result = syncService.downloadTags(userId, bookId);

      Map<String, Object> response = new HashMap<>();
      if (result.isSuccess()) {
        response.put("success", true);
        response.put("tags", result.getTags().stream().map(this::convertTagInfo).collect(Collectors.toList()));
        return ResponseEntity.ok(response);
      } else {
        response.put("success", false);
        response.put("error", result.getError());
        return ResponseEntity.badRequest().body(response);
      }
    } catch (Exception e) {
      log.error("Tag download error", e);
      Map<String, Object> response = new HashMap<>();
      response.put("success", false);
      response.put("error", "server error: " + e.getMessage());
      return ResponseEntity.status(500).body(response);
    }
  }

  private BudgetInfo mapToBudgetInfo(Map<String, Object> map) {
    BudgetInfo budget = new BudgetInfo();
    budget.setTotal(asBigDecimal(map.get("total"), BigDecimal.ZERO));
    budget.setAnnualTotal(asBigDecimal(map.get("annualTotal"), BigDecimal.ZERO));
    budget.setCategoryBudgets(map.get("categoryBudgets") != null ? map.get("categoryBudgets").toString() : null);
    budget.setAnnualCategoryBudgets(map.get("annualCategoryBudgets") != null ? map.get("annualCategoryBudgets").toString() : null);
    budget.setPeriodStartDay(asInt(map.get("periodStartDay"), 1));
    // updateTime is optional; server will overwrite to NOW() on upsert.
    if (map.get("updateTime") instanceof String) {
      try {
        budget.setUpdateTime(LocalDateTime.parse((String) map.get("updateTime"), DateTimeFormatter.ISO_LOCAL_DATE_TIME));
      } catch (Exception ignored) {
      }
    }
    return budget;
  }

  private Map<String, Object> convertBudgetInfo(BudgetInfo budget) {
    Map<String, Object> map = new HashMap<>();
    if (budget == null) {
      map.put("total", 0);
      map.put("categoryBudgets", "{}");
      map.put("periodStartDay", 1);
      map.put("annualTotal", 0);
      map.put("annualCategoryBudgets", "{}");
      return map;
    }
    map.put("total", budget.getTotal());
    map.put("categoryBudgets", budget.getCategoryBudgets());
    map.put("periodStartDay", budget.getPeriodStartDay());
    map.put("annualTotal", budget.getAnnualTotal());
    map.put("annualCategoryBudgets", budget.getAnnualCategoryBudgets());
    if (budget.getUpdateTime() != null) {
      map.put("updateTime", budget.getUpdateTime().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
    }
    if (budget.getCreatedAt() != null) {
      map.put("createdAt", budget.getCreatedAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
    }
    return map;
  }

  private BigDecimal asBigDecimal(Object value, BigDecimal defaultValue) {
    if (value == null) return defaultValue;
    if (value instanceof BigDecimal) return (BigDecimal) value;
    try {
      return new BigDecimal(value.toString());
    } catch (Exception ignored) {
      return defaultValue;
    }
  }

  private LocalDateTime parseClientDateTime(String raw) {
    if (raw == null) return null;
    String trimmed = raw.trim();
    if (trimmed.isEmpty()) return null;
    try {
      return LocalDateTime.parse(trimmed);
    } catch (Exception ignored) {
    }
    try {
      return OffsetDateTime.parse(trimmed).toLocalDateTime();
    } catch (Exception ignored) {
    }
    try {
      return Instant.parse(trimmed).atZone(ZoneOffset.UTC).toLocalDateTime();
    } catch (Exception ignored) {
    }
    return null;
  }

  private CategoryInfo mapToCategoryInfo(Map<String, Object> map) {
    CategoryInfo c = new CategoryInfo();
    c.setCategoryKey(map.get("key") != null ? map.get("key").toString() : null);
    c.setName(map.get("name") != null ? map.get("name").toString() : null);
    Object icon = map.get("icon");
    if (icon instanceof Number) c.setIconCodePoint(((Number) icon).intValue());
    c.setIconFontFamily(map.get("fontFamily") != null ? map.get("fontFamily").toString() : null);
    c.setIconFontPackage(map.get("fontPackage") != null ? map.get("fontPackage").toString() : null);
    Object isExp = map.get("isExpense");
    if (isExp instanceof Boolean) c.setIsExpense(((Boolean) isExp) ? 1 : 0);
    if (isExp instanceof Number) c.setIsExpense(((Number) isExp).intValue());
    c.setParentKey(map.get("parentKey") != null ? map.get("parentKey").toString() : null);
    c.setIsDelete(0);

    if (map.get("updatedAt") instanceof String) {
      c.setUpdateTime(parseClientDateTime((String) map.get("updatedAt")));
    }
    if (map.get("createdAt") instanceof String) {
      c.setCreatedAt(parseClientDateTime((String) map.get("createdAt")));
    }
    if (c.getUpdateTime() == null) c.setUpdateTime(LocalDateTime.now());
    if (c.getCreatedAt() == null) c.setCreatedAt(c.getUpdateTime());
    return c;
  }

  private Map<String, Object> convertCategoryInfo(CategoryInfo c) {
    Map<String, Object> map = new HashMap<>();
    map.put("key", c.getCategoryKey());
    map.put("name", c.getName());
    map.put("icon", c.getIconCodePoint());
    map.put("fontFamily", c.getIconFontFamily());
    map.put("fontPackage", c.getIconFontPackage());
    map.put("isExpense", c.getIsExpense() != null && c.getIsExpense() == 1);
    map.put("parentKey", c.getParentKey());
    if (c.getUpdateTime() != null) map.put("updatedAt", c.getUpdateTime().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
    if (c.getCreatedAt() != null) map.put("createdAt", c.getCreatedAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
    return map;
  }

  private TagInfo mapToTagInfo(Map<String, Object> map, String bookId) {
    TagInfo t = new TagInfo();
    t.setBookId(bookId);
    t.setTagId(map.get("id") != null ? map.get("id").toString() : null);
    t.setName(map.get("name") != null ? map.get("name").toString() : null);
    Object color = map.get("colorValue");
    if (color instanceof Number) t.setColor(((Number) color).intValue());
    Object sortOrder = map.get("sortOrder");
    if (sortOrder instanceof Number) t.setSortOrder(((Number) sortOrder).intValue());
    t.setIsDelete(0);
    if (map.get("updatedAt") instanceof String) {
      t.setUpdateTime(parseClientDateTime((String) map.get("updatedAt")));
    }
    if (map.get("createdAt") instanceof String) {
      t.setCreatedAt(parseClientDateTime((String) map.get("createdAt")));
    }
    if (t.getUpdateTime() == null) t.setUpdateTime(LocalDateTime.now());
    if (t.getCreatedAt() == null) t.setCreatedAt(t.getUpdateTime());
    return t;
  }

  private Map<String, Object> convertTagInfo(TagInfo t) {
    Map<String, Object> map = new HashMap<>();
    map.put("id", t.getTagId());
    map.put("bookId", t.getBookId());
    map.put("name", t.getName());
    map.put("colorValue", t.getColor());
    map.put("sortOrder", t.getSortOrder());
    if (t.getUpdateTime() != null) map.put("updatedAt", t.getUpdateTime().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
    if (t.getCreatedAt() != null) map.put("createdAt", t.getCreatedAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
    return map;
  }
}
