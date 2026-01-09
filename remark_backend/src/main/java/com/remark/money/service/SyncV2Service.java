package com.remark.money.service;

import com.remark.money.entity.BillChangeLog;
import com.remark.money.entity.BillChangeLogRange;
import com.remark.money.entity.BillDeleteTombstone;
import com.remark.money.entity.BillInfo;
import com.remark.money.entity.BillTagRel;
import com.remark.money.entity.BillInfoSyncSummary;
import com.remark.money.entity.BookMember;
import com.remark.money.entity.SyncOpDedup;
import com.remark.money.entity.SyncScopeState;
import com.remark.money.mapper.BillChangeLogMapper;
import com.remark.money.mapper.BillDeleteTombstoneMapper;
import com.remark.money.mapper.BillInfoMapper;
import com.remark.money.mapper.BillTagRelMapper;
import com.remark.money.mapper.BookMemberMapper;
import com.remark.money.mapper.IdSequenceMapper;
import com.remark.money.mapper.SyncOpDedupMapper;
import com.remark.money.mapper.SyncScopeStateMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class SyncV2Service {
  private static final int RETENTION_DAYS = 30;

  private final BillInfoMapper billInfoMapper;
  private final BillChangeLogMapper billChangeLogMapper;
  private final BillTagRelMapper billTagRelMapper;
  private final BillDeleteTombstoneMapper billDeleteTombstoneMapper;
  private final SyncOpDedupMapper syncOpDedupMapper;
  private final SyncScopeStateMapper syncScopeStateMapper;
  private final BookMemberMapper bookMemberMapper;
  private final com.remark.money.mapper.BookMapper bookMapper;
  private final IdSequenceMapper idSequenceMapper;

  public SyncV2Service(BillInfoMapper billInfoMapper,
                       BillChangeLogMapper billChangeLogMapper,
                       BillTagRelMapper billTagRelMapper,
                       BillDeleteTombstoneMapper billDeleteTombstoneMapper,
                       SyncOpDedupMapper syncOpDedupMapper,
                       SyncScopeStateMapper syncScopeStateMapper,
                       BookMemberMapper bookMemberMapper,
                       com.remark.money.mapper.BookMapper bookMapper,
                       IdSequenceMapper idSequenceMapper) {
    this.billInfoMapper = billInfoMapper;
    this.billChangeLogMapper = billChangeLogMapper;
    this.billTagRelMapper = billTagRelMapper;
    this.billDeleteTombstoneMapper = billDeleteTombstoneMapper;
    this.syncOpDedupMapper = syncOpDedupMapper;
    this.syncScopeStateMapper = syncScopeStateMapper;
    this.bookMemberMapper = bookMemberMapper;
    this.bookMapper = bookMapper;
    this.idSequenceMapper = idSequenceMapper;
  }

  public Map<String, Object> summary(Long userId, String bookId) {
    final Long serverBid = assertBookMemberAndGetBidIfServer(userId, bookId);
    final boolean sharedBook = serverBid != null;
    Long scopeUserId = sharedBook ? 0L : userId;

    LocalDateTime cutoff = LocalDateTime.now().minusDays(RETENTION_DAYS);
    BillInfoSyncSummary billSummary =
        sharedBook
            ? billInfoMapper.summaryNonDeletedByBookId(bookId)
            : billInfoMapper.summaryNonDeletedByUserIdAndBookId(userId, bookId);
    int billCount = billSummary != null && billSummary.getBillCount() != null ? billSummary.getBillCount() : 0;
    long sumIds = billSummary != null && billSummary.getSumIds() != null ? billSummary.getSumIds() : 0L;
    long sumVersions = billSummary != null && billSummary.getSumVersions() != null ? billSummary.getSumVersions() : 0L;

    BillChangeLogRange range = billChangeLogMapper.findRangeForScopeSince(bookId, scopeUserId, cutoff);
    long maxChangeId = range != null && range.getMaxChangeId() != null ? range.getMaxChangeId() : 0L;
    long minKeptChangeId = range != null && range.getMinKeptChangeId() != null ? range.getMinKeptChangeId() : 0L;

    Map<String, Object> summary = new HashMap<>();
    summary.put("billCount", billCount);
    summary.put("sumIds", sumIds);
    summary.put("sumVersions", sumVersions);
    summary.put("maxChangeId", maxChangeId);
    summary.put("minKeptChangeId", minKeptChangeId);
    summary.put("retentionDays", RETENTION_DAYS);

    Map<String, Object> resp = new HashMap<>();
    resp.put("success", true);
    resp.put("summary", summary);
    return resp;
  }

  @Transactional
  public Map<String, Object> allocateBillIds(int count) {
    int realCount = Math.max(1, Math.min(count, 5000));
    idSequenceMapper.ensureBillInfo();

    int updated = idSequenceMapper.advanceWithLastInsertId("bill_info", realCount);
    if (updated != 1) {
      throw new IllegalStateException("failed to advance id sequence");
    }
    Long endId = idSequenceMapper.lastInsertId();
    if (endId == null || endId <= 0) {
      throw new IllegalStateException("failed to read allocated id range");
    }
    long startId = endId - realCount + 1L;
    Map<String, Object> resp = new HashMap<>();
    resp.put("success", true);
    resp.put("startId", startId);
    resp.put("endId", endId);
    resp.put("count", realCount);
    return resp;
  }

  /**
   * If {@code bookId} is a server book (numeric + exists in {@code book} table), assert membership and return bid.
   * Otherwise return null (treated as a local/personal book id).
   */
  private Long assertBookMemberAndGetBidIfServer(Long userId, String bookId) {
    if (bookId == null) return null;
    final Long bid;
    try {
      bid = Long.parseLong(bookId);
    } catch (NumberFormatException e) {
      return null;
    }
    if (bookMapper.findById(bid) == null) return null;
    BookMember m = bookMemberMapper.find(bid, userId);
    if (m == null) {
      throw new IllegalArgumentException("no access to shared book");
    }
    return bid;
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
      try {
        bill.setAmount(new BigDecimal(amountObj.toString()));
      } catch (Exception ignored) {
        bill.setAmount(BigDecimal.valueOf(((Number) amountObj).doubleValue()));
      }
    } else if (amountObj instanceof String) {
      try {
        bill.setAmount(new BigDecimal((String) amountObj));
      } catch (Exception ignored) {
      }
    }
    if (bill.getAmount() != null) {
      bill.setAmount(bill.getAmount().setScale(2, RoundingMode.HALF_UP));
    }

    bill.setDirection(asInt(map.get("direction")));
    bill.setRemark((String) map.get("remark"));
    bill.setAttachmentUrl((String) map.get("attachmentUrl"));

    Object billDateObj = map.get("billDate");
    if (billDateObj instanceof String) {
      LocalDateTime parsed = parseClientDateTime((String) billDateObj);
      if (parsed == null) {
        throw new IllegalArgumentException("invalid billDate");
      }
      bill.setBillDate(parsed);
    }

    bill.setIncludeInStats(asInt(map.get("includeInStats")));
    bill.setPairId((String) map.get("pairId"));
    bill.setIsDelete(asInt(map.get("isDelete")));
    return bill;
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

  private List<String> normalizeTagIds(Object value) {
    if (value == null) return new ArrayList<>();
    if (value instanceof List) {
      @SuppressWarnings("unchecked")
      List<Object> list = (List<Object>) value;
      List<String> out = new ArrayList<>();
      for (Object o : list) {
        if (o == null) continue;
        String s = o.toString().trim();
        if (s.isEmpty()) continue;
        out.add(s);
      }
      return out;
    }
    if (value instanceof String) {
      // Backward compatible: accept JSON-string form like ["a","b"]
      List<String> decoded = decodeTagIds((String) value);
      return decoded != null ? decoded : new ArrayList<>();
    }
    return new ArrayList<>();
  }

  private List<String> decodeTagIds(String encoded) {
    if (encoded == null) return null;
    String s = encoded.trim();
    if (s.isEmpty() || "[]".equals(s)) return new ArrayList<>();
    List<String> out = new ArrayList<>();
    int i = 0;
    if (s.charAt(i) != '[') return out;
    i++;
    while (i < s.length()) {
      while (i < s.length() && Character.isWhitespace(s.charAt(i))) i++;
      if (i >= s.length()) break;
      char c = s.charAt(i);
      if (c == ']') break;
      if (c == ',') { i++; continue; }
      if (c != '\"') { i++; continue; }
      i++;
      StringBuilder cur = new StringBuilder();
      while (i < s.length()) {
        char ch = s.charAt(i);
        if (ch == '\\' && i + 1 < s.length()) {
          char nxt = s.charAt(i + 1);
          cur.append(nxt);
          i += 2;
          continue;
        }
        if (ch == '\"') { i++; break; }
        cur.append(ch);
        i++;
      }
      out.add(cur.toString());
    }
    return out;
  }

  private Map<String, Object> toBillMap(BillInfo bill, List<String> tagIds) {
    Map<String, Object> map = new HashMap<>();
    map.put("serverId", bill.getId());
    map.put("userId", bill.getUserId());
    map.put("bookId", bill.getBookId());
    map.put("accountId", bill.getAccountId());
    map.put("categoryKey", bill.getCategoryKey());
    // Serialize amount as string to avoid JSON number precision/scientific-notation issues.
    BigDecimal amt = bill.getAmount();
    if (amt != null) {
      map.put("amount", amt.setScale(2, RoundingMode.HALF_UP).toPlainString());
    } else {
      map.put("amount", "0.00");
    }
    map.put("direction", bill.getDirection());
    map.put("remark", bill.getRemark());
    map.put("attachmentUrl", bill.getAttachmentUrl());
    map.put("billDate", bill.getBillDate() != null ? bill.getBillDate().toString() : null);
    map.put("includeInStats", bill.getIncludeInStats());
    map.put("pairId", bill.getPairId());
    map.put("tagIds", tagIds);
    map.put("isDelete", bill.getIsDelete());
    map.put("version", bill.getVersion());
    map.put("updateTime", bill.getUpdateTime() != null ? bill.getUpdateTime().toString() : null);
    return map;
  }

  private Map<Long, List<String>> loadTagIdsByBillIds(
      String bookId, Long scopeUserId, List<Long> billIds) {
    Map<Long, List<String>> out = new HashMap<>();
    if (billIds == null || billIds.isEmpty()) return out;

    List<BillTagRel> rels = billTagRelMapper.findByBillIds(bookId, scopeUserId, billIds);
    if (rels == null || rels.isEmpty()) return out;
    for (BillTagRel r : rels) {
      if (r == null || r.getBillId() == null) continue;
      String tid = r.getTagId();
      if (tid == null) continue;
      tid = tid.trim();
      if (tid.isEmpty()) continue;
      out.computeIfAbsent(r.getBillId(), k -> new ArrayList<>()).add(tid);
    }
    return out;
  }

  private void upsertDeleteTombstone(String bookId, Long scopeUserId, Long billId, Long billVersion) {
    if (bookId == null || scopeUserId == null || billId == null || billVersion == null) return;
    billDeleteTombstoneMapper.upsert(new BillDeleteTombstone(bookId, scopeUserId, billId, billVersion));
  }

  private void clearDeleteTombstone(String bookId, Long scopeUserId, Long billId) {
    if (bookId == null || scopeUserId == null || billId == null) return;
    billDeleteTombstoneMapper.deleteOne(bookId, scopeUserId, billId);
  }

  private SyncOpDedup buildDedup(Long userId, String bookId, String opId, int status, Long billId, Long billVersion, String error) {
    return buildDedup(userId, bookId, opId, status, billId, billVersion, error, null, null, null);
  }

  private SyncOpDedup buildDedup(Long userId,
                                 String bookId,
                                 String opId,
                                 int status,
                                 Long billId,
                                 Long billVersion,
                                 String error,
                                 String requestId,
                                 String deviceId,
                                 String syncReason) {
    SyncOpDedup record = new SyncOpDedup();
    record.setUserId(userId);
    record.setBookId(bookId);
    record.setOpId(opId);
    record.setRequestId(requestId);
    record.setDeviceId(deviceId);
    record.setSyncReason(syncReason);
    record.setStatus(status);
    record.setBillId(billId);
    record.setBillVersion(billVersion);
    record.setError(error);
    return record;
  }

  @Transactional
  public Map<String, Object> push(Long userId, String bookId, List<Map<String, Object>> ops) {
    return push(userId, bookId, ops, null, null, null);
  }

  @Transactional
  public Map<String, Object> push(Long userId,
                                 String bookId,
                                 List<Map<String, Object>> ops,
                                 String requestId,
                                 String deviceId,
                                 String syncReason) {
    final Long serverBid = assertBookMemberAndGetBidIfServer(userId, bookId);
    final boolean sharedBook = serverBid != null;
    Long scopeUserId = sharedBook ? 0L : userId;

    List<Map<String, Object>> results = new ArrayList<>();
    if (ops == null) ops = new ArrayList<>();

    // 批量查询去重记录：避免每条 op 都单独 SELECT（非常影响吞吐与成本）
    Set<String> opIds = ops.stream()
        .map(op -> op.get("opId") != null ? op.get("opId").toString() : null)
        .filter(s -> s != null && !s.trim().isEmpty())
        .collect(Collectors.toSet());
    Map<String, SyncOpDedup> dedupByOpId = new HashMap<>();
    if (!opIds.isEmpty()) {
      List<SyncOpDedup> existing = syncOpDedupMapper.findByOpIds(userId, bookId, new ArrayList<>(opIds));
      for (SyncOpDedup d : existing) {
        if (d.getOpId() != null) dedupByOpId.put(d.getOpId(), d);
      }
    }

    // 本次请求内的写入先聚合，减少 SQL 次数（尤其是批量新增/删除）
    List<BillChangeLog> pendingLogs = new ArrayList<>();
    List<SyncOpDedup> pendingDedups = new ArrayList<>();
    Map<String, Map<String, Object>> resultsByOpId = new HashMap<>();
    Map<Long, List<String>> pendingTagUpdates = new HashMap<>();
    Set<Long> pendingTagDeletes = new java.util.HashSet<>();
    Set<Long> newlyInsertedBillIds = new java.util.HashSet<>();

    // v2: 批量新增（显式 serverId + expectedVersion=0）
    class PendingCreate {
      final String opId;
      final BillInfo bill;
      final List<String> tagIds;
      final Map<String, Object> item;

      PendingCreate(String opId, BillInfo bill, List<String> tagIds, Map<String, Object> item) {
        this.opId = opId;
        this.bill = bill;
        this.tagIds = tagIds;
        this.item = item;
      }
    }
    List<PendingCreate> pendingCreates = new ArrayList<>();

    for (Map<String, Object> op : ops) {
      String opId = op.get("opId") != null ? op.get("opId").toString() : null;
      String type = op.get("type") != null ? op.get("type").toString() : null;
      Long expectedVersion = asLong(op.get("expectedVersion"));

      if (opId != null) {
        Map<String, Object> existingResult = resultsByOpId.get(opId);
        if (existingResult != null) {
          results.add(existingResult);
          continue;
        }
      }

      Map<String, Object> item = new HashMap<>();
      item.put("opId", opId);

      if (opId == null || opId.trim().isEmpty()) {
        item.put("status", "error");
        item.put("error", "missing opId");
        item.put("retryable", false);
        results.add(item);
        continue;
      }

      SyncOpDedup dedup = dedupByOpId.get(opId);
      if (dedup != null) {
        item.put("status", statusName(dedup.getStatus()));
        item.put("serverId", dedup.getBillId());
        item.put("version", dedup.getBillVersion());
        item.put("retryable", false);
        if (dedup.getStatus() != null && dedup.getStatus() == 1 && dedup.getBillId() != null) {
          BillInfo serverBill = sharedBook
              ? billInfoMapper.findByIdForBook(bookId, dedup.getBillId())
              : billInfoMapper.findByIdForUserAndBook(userId, bookId, dedup.getBillId());
          if (serverBill != null) {
            List<String> tagIds =
                loadTagIdsByBillIds(
                        bookId,
                        userId,
                        java.util.Collections.singletonList(serverBill.getId()))
                    .get(serverBill.getId());
            if (tagIds == null) tagIds = new ArrayList<>();
            item.put("serverBill", toBillMap(serverBill, tagIds));
          }
        }
        if (dedup.getError() != null) item.put("error", dedup.getError());
        results.add(item);
        resultsByOpId.put(opId, item);
        continue;
      }

      try {
        if ("delete".equalsIgnoreCase(type)) {
          handleDelete(userId, bookId, scopeUserId, sharedBook, op, item, pendingLogs, pendingDedups, requestId, deviceId, syncReason);
          if ("applied".equals(item.get("status")) && item.get("serverId") instanceof Number) {
            pendingTagDeletes.add(((Number) item.get("serverId")).longValue());
          }
        } else {
          if (expectedVersion != null && expectedVersion == 0L) {
            Object billObj = op.get("bill");
            if (!(billObj instanceof Map)) {
              throw new IllegalArgumentException("missing bill");
            }
            @SuppressWarnings("unchecked")
            Map<String, Object> billMap = (Map<String, Object>) billObj;
            List<String> tagIds = normalizeTagIds(billMap.get("tagIds"));
            BillInfo bill = mapToBillInfo(billMap);
            bill.setUserId(userId);
            bill.setBookId(bookId);
            if (bill.getIncludeInStats() == null) bill.setIncludeInStats(1);
            if (bill.getIsDelete() == null) bill.setIsDelete(0);
            if (bill.getId() == null) {
              throw new IllegalArgumentException("missing serverId for batch create");
            }
            pendingCreates.add(new PendingCreate(opId, bill, tagIds, item));
          } else {
            handleUpsert(userId, bookId, scopeUserId, sharedBook, op, item, pendingLogs, pendingDedups, newlyInsertedBillIds, requestId, deviceId, syncReason);
            if ("applied".equals(item.get("status")) && item.get("serverId") instanceof Number) {
              Object billObj = op.get("bill");
              if (billObj instanceof Map) {
                @SuppressWarnings("unchecked")
                Map<String, Object> billMap = (Map<String, Object>) billObj;
                pendingTagUpdates.put(
                    ((Number) item.get("serverId")).longValue(),
                    normalizeTagIds(billMap.get("tagIds")));
              }
            }
          }
        }
      } catch (Exception e) {
        item.put("status", "error");
        item.put("error", e.getMessage());
        if (e instanceof IllegalArgumentException) {
          item.put("retryable", false);
          pendingDedups.add(buildDedup(userId, bookId, opId, 2, null, null, e.getMessage(), requestId, deviceId, syncReason));
        } else {
          // Unexpected server-side failure: abort whole batch so the transaction rolls back.
          throw new RuntimeException("sync v2 push failed opId=" + opId + " msg=" + e.getMessage(), e);
        }
      }

      results.add(item);
      resultsByOpId.put(opId, item);
    }

    if (!pendingCreates.isEmpty()) {
      List<BillInfo> newBills = pendingCreates.stream().map(p -> p.bill).collect(Collectors.toList());
      billInfoMapper.batchInsertWithId(newBills);
      for (PendingCreate p : pendingCreates) {
        long newVersion = 1L;
        newlyInsertedBillIds.add(p.bill.getId());
        pendingLogs.add(new BillChangeLog(bookId, scopeUserId, p.bill.getId(), 0, newVersion));
        pendingDedups.add(buildDedup(userId, bookId, p.opId, 0, p.bill.getId(), newVersion, null, requestId, deviceId, syncReason));
        p.item.put("status", "applied");
        p.item.put("serverId", p.bill.getId());
        p.item.put("version", newVersion);
        pendingTagUpdates.put(p.bill.getId(), p.tagIds);
      }
    }

    // 批量落库：把 N 次 insert 合并成 1 次
    if (!pendingLogs.isEmpty()) {
      billChangeLogMapper.batchInsert(pendingLogs);
    }
    if (!pendingDedups.isEmpty()) {
      syncOpDedupMapper.batchInsert(pendingDedups);
    }

    // v2: update bill-tag relations (replace semantics)
    if (!pendingTagUpdates.isEmpty() || !pendingTagDeletes.isEmpty()) {
      // Personal tags are stored per-user, but bill deletions should clear tags for all users.
      List<Long> updateBillIds = pendingTagUpdates.keySet().stream().distinct().collect(Collectors.toList());
      List<Long> deleteBillIds = pendingTagDeletes.stream().distinct().collect(Collectors.toList());

      // Avoid redundant deletes for newly created bills (no prior relations), except when this op is a delete.
      if (!updateBillIds.isEmpty() && !newlyInsertedBillIds.isEmpty()) {
        updateBillIds = updateBillIds.stream()
            .filter(id -> !newlyInsertedBillIds.contains(id))
            .collect(Collectors.toList());
      }

      if (!deleteBillIds.isEmpty()) {
        billTagRelMapper.deleteByBillIdsAllScopes(bookId, deleteBillIds);
      }
      if (!updateBillIds.isEmpty()) {
        billTagRelMapper.deleteByBillIdsForScope(bookId, userId, updateBillIds);
      }

      List<BillTagRel> rels = new ArrayList<>();
      for (Map.Entry<Long, List<String>> e : pendingTagUpdates.entrySet()) {
        Long billId = e.getKey();
        List<String> tagIds = e.getValue();
        if (billId == null || tagIds == null) continue;
        if (tagIds.isEmpty()) continue;
        int idx = 0;
        for (String tid : tagIds) {
          if (tid == null || tid.trim().isEmpty()) continue;
          BillTagRel r = new BillTagRel(bookId, userId, billId, tid.trim());
          r.setSortOrder(idx++);
          rels.add(r);
        }
      }
      if (!rels.isEmpty()) {
        billTagRelMapper.batchInsert(rels);
      }
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
  private void handleUpsert(Long userId,
                            String bookId,
                            Long scopeUserId,
                            boolean sharedBook,
                            Map<String, Object> op,
                            Map<String, Object> item,
                            List<BillChangeLog> pendingLogs,
                            List<SyncOpDedup> pendingDedups,
                            Set<Long> newlyInsertedBillIds,
                            String requestId,
                            String deviceId,
                            String syncReason) {
    String opId = op.get("opId").toString();
    Object expectedVersionObj = op.get("expectedVersion");
    Long expectedVersion = asLong(expectedVersionObj);

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
      if (bill.getId() != null) {
        newlyInsertedBillIds.add(bill.getId());
      }
      long newVersion = 1L;
      pendingLogs.add(new BillChangeLog(bookId, scopeUserId, bill.getId(), 0, newVersion));
      pendingDedups.add(buildDedup(userId, bookId, opId, 0, bill.getId(), newVersion, null, requestId, deviceId, syncReason));
      item.put("status", "applied");
      item.put("serverId", bill.getId());
      item.put("version", newVersion);
      if (bill.getIsDelete() != null && bill.getIsDelete() == 1) {
        upsertDeleteTombstone(bookId, scopeUserId, bill.getId(), newVersion);
      } else {
        clearDeleteTombstone(bookId, scopeUserId, bill.getId());
      }
      return;
    }

    if (expectedVersion == null) {
      BillInfo latest = sharedBook
          ? billInfoMapper.findByIdForBook(bookId, bill.getId())
          : billInfoMapper.findByIdForUserAndBook(userId, bookId, bill.getId());
      if (latest == null) {
        pendingDedups.add(buildDedup(userId, bookId, opId, 2, bill.getId(), null, "not found", requestId, deviceId, syncReason));
        item.put("status", "error");
        item.put("error", "not found");
        item.put("retryable", false);
      } else {
        pendingDedups.add(buildDedup(userId, bookId, opId, 1, bill.getId(), latest.getVersion(), null, requestId, deviceId, syncReason));
        item.put("status", "conflict");
        item.put("serverId", bill.getId());
        item.put("version", latest.getVersion());
        List<String> tagIds =
            loadTagIdsByBillIds(bookId, userId, java.util.Collections.singletonList(latest.getId()))
                .get(latest.getId());
        if (tagIds == null) tagIds = new ArrayList<>();
        item.put("serverBill", toBillMap(latest, tagIds));
        item.put("retryable", false);
      }
      return;
    }

    int updated = sharedBook
        ? billInfoMapper.updateWithExpectedVersionByBookId(bookId, expectedVersion, bill)
        : billInfoMapper.updateWithExpectedVersionByUserIdAndBookId(userId, bookId, expectedVersion, bill);
    if (updated <= 0) {
      BillInfo latest = sharedBook
          ? billInfoMapper.findByIdForBook(bookId, bill.getId())
          : billInfoMapper.findByIdForUserAndBook(userId, bookId, bill.getId());
      if (latest == null) {
        pendingDedups.add(buildDedup(userId, bookId, opId, 2, bill.getId(), null, "not found", requestId, deviceId, syncReason));
        item.put("status", "error");
        item.put("error", "not found");
        item.put("retryable", false);
      } else {
        pendingDedups.add(buildDedup(userId, bookId, opId, 1, bill.getId(), latest.getVersion(), null, requestId, deviceId, syncReason));
        item.put("status", "conflict");
        item.put("serverId", bill.getId());
        item.put("version", latest.getVersion());
        List<String> tagIds =
            loadTagIdsByBillIds(bookId, userId, java.util.Collections.singletonList(latest.getId()))
                .get(latest.getId());
        if (tagIds == null) tagIds = new ArrayList<>();
        item.put("serverBill", toBillMap(latest, tagIds));
        item.put("retryable", false);
      }
      return;
    }

    long newVersion = expectedVersion + 1;
    pendingLogs.add(new BillChangeLog(bookId, scopeUserId, bill.getId(), 0, newVersion));
    pendingDedups.add(buildDedup(userId, bookId, opId, 0, bill.getId(), newVersion, null, requestId, deviceId, syncReason));
    item.put("status", "applied");
    item.put("serverId", bill.getId());
    item.put("version", newVersion);
    if (bill.getIsDelete() != null && bill.getIsDelete() == 1) {
      upsertDeleteTombstone(bookId, scopeUserId, bill.getId(), newVersion);
    } else {
      clearDeleteTombstone(bookId, scopeUserId, bill.getId());
    }
  }

  private void handleDelete(Long userId,
                            String bookId,
                            Long scopeUserId,
                            boolean sharedBook,
                            Map<String, Object> op,
                            Map<String, Object> item,
                            List<BillChangeLog> pendingLogs,
                            List<SyncOpDedup> pendingDedups,
                            String requestId,
                            String deviceId,
                            String syncReason) {
    String opId = op.get("opId").toString();
    Long billId = asLong(op.get("serverId"));
    if (billId == null) billId = asLong(op.get("billId"));
    Long expectedVersion = asLong(op.get("expectedVersion"));
    if (billId == null) {
      throw new IllegalArgumentException("missing serverId");
    }

    if (expectedVersion == null) {
      BillInfo latest = sharedBook
          ? billInfoMapper.findByIdForBook(bookId, billId)
          : billInfoMapper.findByIdForUserAndBook(userId, bookId, billId);
      if (latest == null) {
        pendingDedups.add(buildDedup(userId, bookId, opId, 2, billId, null, "not found", requestId, deviceId, syncReason));
        item.put("status", "error");
        item.put("error", "not found");
        item.put("retryable", false);
      } else {
        pendingDedups.add(buildDedup(userId, bookId, opId, 1, billId, latest.getVersion(), null, requestId, deviceId, syncReason));
        item.put("status", "conflict");
        item.put("serverId", billId);
        item.put("version", latest.getVersion());
        List<String> tagIds =
            loadTagIdsByBillIds(bookId, userId, java.util.Collections.singletonList(latest.getId()))
                .get(latest.getId());
        if (tagIds == null) tagIds = new ArrayList<>();
        item.put("serverBill", toBillMap(latest, tagIds));
        item.put("retryable", false);
      }
      return;
    }

    int updated = sharedBook
        ? billInfoMapper.softDeleteWithExpectedVersionByBookId(bookId, billId, expectedVersion)
        : billInfoMapper.softDeleteWithExpectedVersionByUserIdAndBookId(userId, bookId, billId, expectedVersion);
    if (updated <= 0) {
      BillInfo latest = sharedBook
          ? billInfoMapper.findByIdForBook(bookId, billId)
          : billInfoMapper.findByIdForUserAndBook(userId, bookId, billId);
      if (latest == null) {
        pendingDedups.add(buildDedup(userId, bookId, opId, 2, billId, null, "not found", requestId, deviceId, syncReason));
        item.put("status", "error");
        item.put("error", "not found");
        item.put("retryable", false);
      } else {
        pendingDedups.add(buildDedup(userId, bookId, opId, 1, billId, latest.getVersion(), null, requestId, deviceId, syncReason));
        item.put("status", "conflict");
        item.put("serverId", billId);
        item.put("version", latest.getVersion());
        List<String> tagIds =
            loadTagIdsByBillIds(bookId, userId, java.util.Collections.singletonList(latest.getId()))
                .get(latest.getId());
        if (tagIds == null) tagIds = new ArrayList<>();
        item.put("serverBill", toBillMap(latest, tagIds));
        item.put("retryable", false);
      }
      return;
    }

    long newVersion = expectedVersion + 1;
    pendingLogs.add(new BillChangeLog(bookId, scopeUserId, billId, 1, newVersion));
    pendingDedups.add(buildDedup(userId, bookId, opId, 0, billId, newVersion, null, requestId, deviceId, syncReason));
    item.put("status", "applied");
    item.put("serverId", billId);
    item.put("version", newVersion);
    upsertDeleteTombstone(bookId, scopeUserId, billId, newVersion);
  }

  public Map<String, Object> pull(Long userId, String bookId, Long afterChangeId, int limit) {
    final Long serverBid = assertBookMemberAndGetBidIfServer(userId, bookId);
    final boolean sharedBook = serverBid != null;
    Long scopeUserId = sharedBook ? 0L : userId;

    long cursor = afterChangeId != null ? afterChangeId : 0L;
    int realLimit = limit > 0 ? Math.min(limit, 500) : 200;
    int fetchLimit = Math.min(realLimit + 1, 501);
    LocalDateTime cutoff = LocalDateTime.now().minusDays(30);

    if (cursor == 0L) {
      // Avoid repeated COUNT(*) + heavy bootstrap for every fresh device.
      syncScopeStateMapper.ensureExists(bookId, scopeUserId);
      SyncScopeState state = syncScopeStateMapper.find(bookId, scopeUserId);
      boolean initialized = state != null && state.getInitialized() != null && state.getInitialized() == 1;
      boolean bootstrapExpired = state == null || state.getUpdatedAt() == null || state.getUpdatedAt().isBefore(cutoff);
      if (!initialized || bootstrapExpired) {
        boolean skipBootstrap = !bootstrapExpired && !initialized
            && billChangeLogMapper.existsAnyForScope(bookId, scopeUserId) != null;
        if (!skipBootstrap) {
          if (sharedBook) {
            billChangeLogMapper.bootstrapShared(bookId, scopeUserId);
          } else {
            billChangeLogMapper.bootstrapPersonal(userId, bookId, scopeUserId);
          }
          billChangeLogMapper.bootstrapTombstones(bookId, scopeUserId);
        }
        syncScopeStateMapper.markInitialized(bookId, scopeUserId);
      }
    } else {
      // If the cursor points to a pruned range, ask client to reset to 0 so we can re-bootstrap.
      Long minKept = billChangeLogMapper.findMinChangeIdSince(bookId, scopeUserId, cutoff);
      if (minKept == null || cursor < minKept) {
        syncScopeStateMapper.ensureExists(bookId, scopeUserId);
        syncScopeStateMapper.resetInitialized(bookId, scopeUserId);
        Map<String, Object> resp = new HashMap<>();
        resp.put("success", true);
        resp.put("cursorExpired", true);
        resp.put("minKeptChangeId", minKept);
        resp.put("changes", new ArrayList<>());
        resp.put("nextChangeId", 0);
        resp.put("hasMore", false);
        return resp;
      }
    }

    List<BillChangeLog> logs = billChangeLogMapper.findAfter(bookId, scopeUserId, cursor, fetchLimit);
    boolean hasMore = logs.size() > realLimit;
    if (hasMore) {
      logs = logs.subList(0, realLimit);
    }
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
      Map<Long, List<String>> tagIdsByBillId = loadTagIdsByBillIds(bookId, userId, billIds);

      for (BillChangeLog log : logs) {
        Map<String, Object> c = new HashMap<>();
        c.put("changeId", log.getChangeId());
        c.put("op", log.getOp() != null && log.getOp() == 1 ? "delete" : "upsert");
        c.put("version", log.getBillVersion());
        BillInfo bill = billMap.get(log.getBillId());
        if (bill != null) {
          List<String> tagIds = tagIdsByBillId.get(log.getBillId());
          if (tagIds == null) tagIds = new ArrayList<>();
          c.put("bill", toBillMap(bill, tagIds));
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
    resp.put("hasMore", hasMore);
    return resp;
  }
}
