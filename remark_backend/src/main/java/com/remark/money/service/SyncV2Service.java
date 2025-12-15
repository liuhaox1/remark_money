package com.remark.money.service;

import com.remark.money.entity.BillChangeLog;
import com.remark.money.entity.BillInfo;
import com.remark.money.entity.BookMember;
import com.remark.money.entity.SyncOpDedup;
import com.remark.money.entity.SyncScopeState;
import com.remark.money.mapper.BillChangeLogMapper;
import com.remark.money.mapper.BillInfoMapper;
import com.remark.money.mapper.BookMemberMapper;
import com.remark.money.mapper.SyncOpDedupMapper;
import com.remark.money.mapper.SyncScopeStateMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class SyncV2Service {

  private final BillInfoMapper billInfoMapper;
  private final BillChangeLogMapper billChangeLogMapper;
  private final SyncOpDedupMapper syncOpDedupMapper;
  private final SyncScopeStateMapper syncScopeStateMapper;
  private final BookMemberMapper bookMemberMapper;

  private volatile long lastDedupCleanupMs = 0L;
  private static final long DEDUP_CLEANUP_MIN_INTERVAL_MS = 6L * 60L * 60L * 1000L; // 6h
  private static final int DEDUP_RETENTION_DAYS = 30;

  public SyncV2Service(BillInfoMapper billInfoMapper,
                       BillChangeLogMapper billChangeLogMapper,
                       SyncOpDedupMapper syncOpDedupMapper,
                       SyncScopeStateMapper syncScopeStateMapper,
                       BookMemberMapper bookMemberMapper) {
    this.billInfoMapper = billInfoMapper;
    this.billChangeLogMapper = billChangeLogMapper;
    this.syncOpDedupMapper = syncOpDedupMapper;
    this.syncScopeStateMapper = syncScopeStateMapper;
    this.bookMemberMapper = bookMemberMapper;
  }

  private boolean isServerBook(String bookId) {
    if (bookId == null) return false;
    try {
      Long.parseLong(bookId);
      return true;
    } catch (NumberFormatException e) {
      return false;
    }
  }

  private void assertBookMember(Long userId, String bookId) {
    if (!isServerBook(bookId)) return;
    Long bid = Long.parseLong(bookId);
    BookMember m = bookMemberMapper.find(bid, userId);
    if (m == null) {
      throw new IllegalArgumentException("no access to shared book");
    }
  }

  private Long asLong(Object value) {
    if (value == null) return null;
    if (value instanceof Number) return ((Number) value).longValue();
    if (value instanceof String) {
      String s = ((String) value).trim();
      if (s.isEmpty()) return null;
      try {
        return Long.parseLong(s);
      } catch (NumberFormatException ignored) {
        return null;
      }
    }
    return null;
  }

  private Integer asInt(Object value) {
    if (value == null) return null;
    if (value instanceof Number) return ((Number) value).intValue();
    if (value instanceof String) {
      String s = ((String) value).trim();
      if (s.isEmpty()) return null;
      try {
        return Integer.parseInt(s);
      } catch (NumberFormatException ignored) {
        return null;
      }
    }
    if (value instanceof Boolean) return ((Boolean) value) ? 1 : 0;
    return null;
  }

  private BillInfo mapToBillInfo(Map<String, Object> map) {
    BillInfo bill = new BillInfo();
    Object serverIdObj = map.get("serverId");
    if (serverIdObj instanceof Number) {
      bill.setId(((Number) serverIdObj).longValue());
    } else if (serverIdObj instanceof String) {
      bill.setId(asLong(serverIdObj));
    }
    bill.setAccountId((String) map.get("accountId"));
    bill.setCategoryKey((String) map.get("categoryKey"));

    Object amountObj = map.get("amount");
    if (amountObj instanceof Number) {
      bill.setAmount(BigDecimal.valueOf(((Number) amountObj).doubleValue()));
    } else if (amountObj instanceof String) {
      try {
        bill.setAmount(new BigDecimal((String) amountObj));
      } catch (Exception ignored) {
      }
    }

    bill.setDirection(asInt(map.get("direction")));
    bill.setRemark((String) map.get("remark"));
    bill.setAttachmentUrl((String) map.get("attachmentUrl"));

    Object billDateObj = map.get("billDate");
    if (billDateObj instanceof String) {
      bill.setBillDate(LocalDateTime.parse((String) billDateObj));
    }

    bill.setIncludeInStats(asInt(map.get("includeInStats")));
    bill.setPairId((String) map.get("pairId"));
    bill.setIsDelete(asInt(map.get("isDelete")));
    return bill;
  }

  private Map<String, Object> toBillMap(BillInfo bill) {
    Map<String, Object> map = new HashMap<>();
    map.put("serverId", bill.getId());
    map.put("bookId", bill.getBookId());
    map.put("accountId", bill.getAccountId());
    map.put("categoryKey", bill.getCategoryKey());
    map.put("amount", bill.getAmount());
    map.put("direction", bill.getDirection());
    map.put("remark", bill.getRemark());
    map.put("attachmentUrl", bill.getAttachmentUrl());
    map.put("billDate", bill.getBillDate() != null ? bill.getBillDate().toString() : null);
    map.put("includeInStats", bill.getIncludeInStats());
    map.put("pairId", bill.getPairId());
    map.put("isDelete", bill.getIsDelete());
    map.put("version", bill.getVersion());
    map.put("updateTime", bill.getUpdateTime() != null ? bill.getUpdateTime().toString() : null);
    return map;
  }

  private void insertDedup(Long userId, String bookId, String opId, int status, Long billId, Long billVersion, String error) {
    SyncOpDedup record = new SyncOpDedup();
    record.setUserId(userId);
    record.setBookId(bookId);
    record.setOpId(opId);
    record.setStatus(status);
    record.setBillId(billId);
    record.setBillVersion(billVersion);
    record.setError(error);
    syncOpDedupMapper.insert(record);

    maybeCleanupDedup();
  }

  private void maybeCleanupDedup() {
    long now = System.currentTimeMillis();
    if (now - lastDedupCleanupMs < DEDUP_CLEANUP_MIN_INTERVAL_MS) return;
    lastDedupCleanupMs = now;
    try {
      LocalDateTime cutoff = LocalDateTime.now().minusDays(DEDUP_RETENTION_DAYS);
      syncOpDedupMapper.deleteBefore(cutoff);
    } catch (Exception ignored) {
      // best-effort cleanup; never break sync path
    }
  }

  @Transactional
  public Map<String, Object> push(Long userId, String bookId, List<Map<String, Object>> ops) {
    assertBookMember(userId, bookId);
    Long scopeUserId = isServerBook(bookId) ? 0L : userId;
    final boolean sharedBook = isServerBook(bookId);

    List<Map<String, Object>> results = new ArrayList<>();
    if (ops == null) ops = new ArrayList<>();

    for (Map<String, Object> op : ops) {
      String opId = op.get("opId") != null ? op.get("opId").toString() : null;
      String type = op.get("type") != null ? op.get("type").toString() : null;

      Map<String, Object> item = new HashMap<>();
      item.put("opId", opId);

      if (opId == null || opId.trim().isEmpty()) {
        item.put("status", "error");
        item.put("error", "missing opId");
        results.add(item);
        continue;
      }

      SyncOpDedup dedup = syncOpDedupMapper.find(userId, bookId, opId);
      if (dedup != null) {
        item.put("status", statusName(dedup.getStatus()));
        item.put("serverId", dedup.getBillId());
        item.put("version", dedup.getBillVersion());
        if (dedup.getStatus() != null && dedup.getStatus() == 1 && dedup.getBillId() != null) {
          BillInfo serverBill = sharedBook
              ? billInfoMapper.findByIdForBook(bookId, dedup.getBillId())
              : billInfoMapper.findByIdForUserAndBook(userId, bookId, dedup.getBillId());
          if (serverBill != null) item.put("serverBill", toBillMap(serverBill));
        }
        if (dedup.getError() != null) item.put("error", dedup.getError());
        results.add(item);
        continue;
      }

      try {
        if ("delete".equalsIgnoreCase(type)) {
          handleDelete(userId, bookId, scopeUserId, op, item);
        } else {
          handleUpsert(userId, bookId, scopeUserId, op, item);
        }
      } catch (Exception e) {
        item.put("status", "error");
        item.put("error", e.getMessage());
        try {
          insertDedup(userId, bookId, opId, 2, null, null, e.getMessage());
        } catch (Exception ignored) {
        }
      }

      results.add(item);
    }

    Map<String, Object> resp = new HashMap<>();
    resp.put("success", true);
    resp.put("results", results);
    return resp;
  }

  private String statusName(Integer status) {
    if (status == null) return "error";
    switch (status) {
      case 0:
        return "applied";
      case 1:
        return "conflict";
      default:
        return "error";
    }
  }

  @SuppressWarnings("unchecked")
  private void handleUpsert(Long userId, String bookId, Long scopeUserId, Map<String, Object> op, Map<String, Object> item) {
    String opId = op.get("opId").toString();
    Object expectedVersionObj = op.get("expectedVersion");
    Long expectedVersion = asLong(expectedVersionObj);
    final boolean sharedBook = isServerBook(bookId);

    Object billObj = op.get("bill");
    if (!(billObj instanceof Map)) {
      throw new IllegalArgumentException("missing bill");
    }
    BillInfo bill = mapToBillInfo((Map<String, Object>) billObj);

    bill.setUserId(userId);
    bill.setBookId(bookId);
    if (bill.getIncludeInStats() == null) bill.setIncludeInStats(1);
    if (bill.getIsDelete() == null) bill.setIsDelete(0);

    if (bill.getId() == null) {
      billInfoMapper.insert(bill);
      long newVersion = 1L;
      billChangeLogMapper.insert(bookId, scopeUserId, bill.getId(), 0, newVersion);
      insertDedup(userId, bookId, opId, 0, bill.getId(), newVersion, null);
      item.put("status", "applied");
      item.put("serverId", bill.getId());
      item.put("version", newVersion);
      return;
    }

    BillInfo existing = sharedBook
        ? billInfoMapper.findByIdForBook(bookId, bill.getId())
        : billInfoMapper.findByIdForUserAndBook(userId, bookId, bill.getId());
    if (existing == null) {
      insertDedup(userId, bookId, opId, 2, bill.getId(), null, "not found");
      item.put("status", "error");
      item.put("error", "not found");
      return;
    }

    if (expectedVersion == null || existing.getVersion() == null || !existing.getVersion().equals(expectedVersion)) {
      insertDedup(userId, bookId, opId, 1, existing.getId(), existing.getVersion(), null);
      item.put("status", "conflict");
      item.put("serverId", existing.getId());
      item.put("version", existing.getVersion());
      item.put("serverBill", toBillMap(existing));
      return;
    }

    int updated = isServerBook(bookId)
        ? billInfoMapper.updateWithExpectedVersionByBookId(bookId, expectedVersion, bill)
        : billInfoMapper.updateWithExpectedVersionByUserIdAndBookId(userId, bookId, expectedVersion, bill);
    if (updated <= 0) {
      BillInfo latest = sharedBook
          ? billInfoMapper.findByIdForBook(bookId, bill.getId())
          : billInfoMapper.findByIdForUserAndBook(userId, bookId, bill.getId());
      insertDedup(userId, bookId, opId, 1, bill.getId(), latest != null ? latest.getVersion() : null, null);
      item.put("status", "conflict");
      item.put("serverId", bill.getId());
      item.put("version", latest != null ? latest.getVersion() : null);
      if (latest != null) item.put("serverBill", toBillMap(latest));
      return;
    }

    long newVersion = expectedVersion + 1;
    billChangeLogMapper.insert(bookId, scopeUserId, bill.getId(), 0, newVersion);
    insertDedup(userId, bookId, opId, 0, bill.getId(), newVersion, null);
    item.put("status", "applied");
    item.put("serverId", bill.getId());
    item.put("version", newVersion);
  }

  private void handleDelete(Long userId, String bookId, Long scopeUserId, Map<String, Object> op, Map<String, Object> item) {
    String opId = op.get("opId").toString();
    Long billId = asLong(op.get("serverId"));
    if (billId == null) billId = asLong(op.get("billId"));
    Long expectedVersion = asLong(op.get("expectedVersion"));
    final boolean sharedBook = isServerBook(bookId);

    if (billId == null) {
      throw new IllegalArgumentException("missing serverId");
    }

    BillInfo existing = sharedBook
        ? billInfoMapper.findByIdForBook(bookId, billId)
        : billInfoMapper.findByIdForUserAndBook(userId, bookId, billId);
    if (existing == null) {
      insertDedup(userId, bookId, opId, 2, billId, null, "not found");
      item.put("status", "error");
      item.put("error", "not found");
      return;
    }

    if (expectedVersion == null || existing.getVersion() == null || !existing.getVersion().equals(expectedVersion)) {
      insertDedup(userId, bookId, opId, 1, existing.getId(), existing.getVersion(), null);
      item.put("status", "conflict");
      item.put("serverId", existing.getId());
      item.put("version", existing.getVersion());
      item.put("serverBill", toBillMap(existing));
      return;
    }

    int updated = isServerBook(bookId)
        ? billInfoMapper.softDeleteWithExpectedVersionByBookId(bookId, billId, expectedVersion)
        : billInfoMapper.softDeleteWithExpectedVersionByUserIdAndBookId(userId, bookId, billId, expectedVersion);
    if (updated <= 0) {
      BillInfo latest = sharedBook
          ? billInfoMapper.findByIdForBook(bookId, billId)
          : billInfoMapper.findByIdForUserAndBook(userId, bookId, billId);
      insertDedup(userId, bookId, opId, 1, billId, latest != null ? latest.getVersion() : null, null);
      item.put("status", "conflict");
      item.put("serverId", billId);
      item.put("version", latest != null ? latest.getVersion() : null);
      if (latest != null) item.put("serverBill", toBillMap(latest));
      return;
    }

    long newVersion = expectedVersion + 1;
    billChangeLogMapper.insert(bookId, scopeUserId, billId, 1, newVersion);
    insertDedup(userId, bookId, opId, 0, billId, newVersion, null);
    item.put("status", "applied");
    item.put("serverId", billId);
    item.put("version", newVersion);
  }

  public Map<String, Object> pull(Long userId, String bookId, Long afterChangeId, int limit) {
    assertBookMember(userId, bookId);
    Long scopeUserId = isServerBook(bookId) ? 0L : userId;
    final boolean sharedBook = isServerBook(bookId);

    long cursor = afterChangeId != null ? afterChangeId : 0L;
    int realLimit = limit > 0 ? Math.min(limit, 500) : 200;

    if (cursor == 0L) {
      // Avoid repeated COUNT(*) + heavy bootstrap for every fresh device.
      syncScopeStateMapper.ensureExists(bookId, scopeUserId);
      SyncScopeState state = syncScopeStateMapper.find(bookId, scopeUserId);
      boolean initialized = state != null && state.getInitialized() != null && state.getInitialized() == 1;
      if (!initialized) {
        if (sharedBook) {
          billChangeLogMapper.bootstrapShared(bookId, scopeUserId);
        } else {
          billChangeLogMapper.bootstrapPersonal(userId, bookId, scopeUserId);
        }
        syncScopeStateMapper.markInitialized(bookId, scopeUserId);
      }
    }

    List<BillChangeLog> logs = billChangeLogMapper.findAfter(bookId, scopeUserId, cursor, realLimit);
    List<Map<String, Object>> changes = new ArrayList<>();

    long nextCursor = cursor;
    if (!logs.isEmpty()) {
      nextCursor = logs.get(logs.size() - 1).getChangeId();
      List<Long> billIds = logs.stream().map(BillChangeLog::getBillId).distinct().collect(Collectors.toList());
      List<BillInfo> scopedBills = sharedBook
          ? billInfoMapper.findByIdsForBook(bookId, billIds)
          : billInfoMapper.findByIdsForUserAndBook(userId, bookId, billIds);
      Map<Long, BillInfo> billMap = scopedBills.stream()
          .collect(Collectors.toMap(BillInfo::getId, b -> b));

      for (BillChangeLog log : logs) {
        Map<String, Object> c = new HashMap<>();
        c.put("changeId", log.getChangeId());
        c.put("op", log.getOp() != null && log.getOp() == 1 ? "delete" : "upsert");
        c.put("version", log.getBillVersion());
        BillInfo bill = billMap.get(log.getBillId());
        if (bill != null) {
          c.put("bill", toBillMap(bill));
        } else {
          Map<String, Object> stub = new HashMap<>();
          stub.put("serverId", log.getBillId());
          stub.put("bookId", bookId);
          stub.put("isDelete", 1);
          stub.put("version", log.getBillVersion());
          c.put("bill", stub);
        }
        changes.add(c);
      }
    }

    Map<String, Object> resp = new HashMap<>();
    resp.put("success", true);
    resp.put("changes", changes);
    resp.put("nextChangeId", nextCursor);
    resp.put("hasMore", logs.size() == realLimit);
    return resp;
  }
}
