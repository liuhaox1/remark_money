package com.remark.money.job;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.remark.money.entity.AccountInfo;
import com.remark.money.entity.BillChangeLog;
import com.remark.money.entity.BillInfo;
import com.remark.money.entity.BillTagRel;
import com.remark.money.entity.Book;
import com.remark.money.entity.RecurringPlanInfo;
import com.remark.money.entity.SavingsPlanInfo;
import com.remark.money.mapper.AccountInfoMapper;
import com.remark.money.mapper.BillChangeLogMapper;
import com.remark.money.mapper.BillInfoMapper;
import com.remark.money.mapper.BillTagRelMapper;
import com.remark.money.mapper.BookMapper;
import com.remark.money.mapper.PlanExecLogMapper;
import com.remark.money.mapper.RecurringPlanInfoMapper;
import com.remark.money.mapper.SavingsPlanInfoMapper;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Server-side execution for:
 * - Savings plans (monthly/weekly fixed)
 * - Recurring records (weekly/monthly)
 *
 * Designed for safety:
 * - plan_exec_log provides idempotency per (plan, period)
 * - for savings plans, also checks pairId existence to avoid double-creating after migrations
 */
@Component
public class AutoPlanExecutionJob {
  private static final Logger log = LoggerFactory.getLogger(AutoPlanExecutionJob.class);
  private static final DateTimeFormatter YYYYMM = DateTimeFormatter.ofPattern("yyyyMM");
  private static final DateTimeFormatter YYYYMMDD = DateTimeFormatter.ofPattern("yyyyMMdd");

  private final ObjectMapper objectMapper;
  private final SavingsPlanInfoMapper savingsPlanInfoMapper;
  private final RecurringPlanInfoMapper recurringPlanInfoMapper;
  private final PlanExecLogMapper planExecLogMapper;
  private final BillInfoMapper billInfoMapper;
  private final BillChangeLogMapper billChangeLogMapper;
  private final BillTagRelMapper billTagRelMapper;
  private final AccountInfoMapper accountInfoMapper;
  private final BookMapper bookMapper;

  public AutoPlanExecutionJob(
      ObjectMapper objectMapper,
      SavingsPlanInfoMapper savingsPlanInfoMapper,
      RecurringPlanInfoMapper recurringPlanInfoMapper,
      PlanExecLogMapper planExecLogMapper,
      BillInfoMapper billInfoMapper,
      BillChangeLogMapper billChangeLogMapper,
      BillTagRelMapper billTagRelMapper,
      AccountInfoMapper accountInfoMapper,
      BookMapper bookMapper) {
    this.objectMapper = objectMapper;
    this.savingsPlanInfoMapper = savingsPlanInfoMapper;
    this.recurringPlanInfoMapper = recurringPlanInfoMapper;
    this.planExecLogMapper = planExecLogMapper;
    this.billInfoMapper = billInfoMapper;
    this.billChangeLogMapper = billChangeLogMapper;
    this.billTagRelMapper = billTagRelMapper;
    this.accountInfoMapper = accountInfoMapper;
    this.bookMapper = bookMapper;
  }

  @Scheduled(cron = "0 */5 * * * ?")
  public void run() {
    try {
      runOnce();
    } catch (Exception e) {
      log.error("AutoPlanExecutionJob failed", e);
    }
  }

  @Transactional
  public void runOnce() {
    final LocalDate today = LocalDate.now();
    int savingsExecuted = 0;
    int recurringExecuted = 0;

    final List<SavingsPlanInfo> savings = savingsPlanInfoMapper.findAllActive();
    for (SavingsPlanInfo row : savings) {
      try {
        savingsExecuted += executeSavingsPlanRow(row, today);
      } catch (Exception e) {
        log.warn("execute savings plan failed book={} user={} plan={} err={}",
            row.getBookId(), row.getUserId(), row.getPlanId(), e.toString());
      }
    }

    final List<RecurringPlanInfo> recurring = recurringPlanInfoMapper.findAllActive();
    for (RecurringPlanInfo row : recurring) {
      try {
        recurringExecuted += executeRecurringPlanRow(row, today);
      } catch (Exception e) {
        log.warn("execute recurring plan failed book={} user={} plan={} err={}",
            row.getBookId(), row.getUserId(), row.getPlanId(), e.toString());
      }
    }

    if (savingsExecuted > 0 || recurringExecuted > 0) {
      log.info("AutoPlanExecutionJob executed savings={} recurring={}", savingsExecuted, recurringExecuted);
    }
  }

  private int executeSavingsPlanRow(SavingsPlanInfo row, LocalDate today) throws Exception {
    if (row == null || row.getIsDelete() != null && row.getIsDelete() == 1) return 0;
    final Map<String, Object> payload = parsePayload(row.getPayloadJson());
    final String type = asString(payload.get("type"));
    if (!"monthly_fixed".equalsIgnoreCase(type) && !"weekly_fixed".equalsIgnoreCase(type)) {
      return 0;
    }
    final Boolean archived = asBool(payload.get("archived"), false);
    if (archived) return 0;

    final LocalDate start = dateOnly(parseClientDate(payload.get("startDate"), payload.get("createdAt")));
    final LocalDate until = dateOnly(parseClientDate(payload.get("endDate"), null));
    final LocalDate end = (until != null && until.isBefore(today)) ? until : today;
    if (start == null) return 0;
    if (end.isBefore(start)) return 0;

    final String planId = row.getPlanId();
    final String bookId = row.getBookId();
    final Long userId = row.getUserId();

    final String planAccountId = asString(payload.get("accountId"));
    if (planAccountId == null || planAccountId.trim().isEmpty()) return 0;

    final double fixedAmount =
        "monthly_fixed".equalsIgnoreCase(type) ? asDouble(payload.get("monthlyAmount"), 0) : asDouble(payload.get("weeklyAmount"), 0);
    if (fixedAmount <= 0) return 0;

    // Resolve debit account
    String fromAccountId = asString(payload.get("defaultFromAccountId"));
    fromAccountId = resolveFromAccountId(fromAccountId, userId, bookId, planAccountId);
    if (fromAccountId == null) return 0;

    int executed = 0;
    double added = 0;
    LocalDateTime lastExecutedAt = null;

    final LocalDateTime lastExecutedAtPayload = parseClientDate(payload.get("lastExecutedAt"), null);
    LocalDate scanStart = start;
    if (lastExecutedAtPayload != null) {
      LocalDate d = lastExecutedAtPayload.toLocalDate();
      if (d.isAfter(scanStart)) {
        scanStart = d;
      }
    }

    if ("monthly_fixed".equalsIgnoreCase(type)) {
      final int day = asInt(payload.get("monthlyDay"), 1);
      LocalDate cursor = LocalDate.of(scanStart.getYear(), scanStart.getMonth(), 1);
      while (!cursor.isAfter(end)) {
        final LocalDate due = monthlyDueDate(cursor.getYear(), cursor.getMonthValue(), day);
        if (!due.isBefore(start) && !due.isAfter(end)) {
          final String periodKey = "m_" + cursor.format(YYYYMM);
          final String pairId = "sp_" + planId + "_" + periodKey;
          final int created =
              executeSavingsTransferIfNeeded(
                  row, payload, due, fixedAmount, fromAccountId, planAccountId, pairId, periodKey);
          if (created > 0) {
            executed += created;
            added += fixedAmount;
            lastExecutedAt = LocalDateTime.of(due, LocalTime.NOON);
          }
        }
        cursor = cursor.plusMonths(1);
      }
    } else {
      final int weekday = asInt(payload.get("weeklyWeekday"), LocalDate.now().getDayOfWeek().getValue()); // 1..7 Mon..Sun
      LocalDate first = scanStart;
      while (first.getDayOfWeek().getValue() != weekday) {
        first = first.plusDays(1);
        if (first.isAfter(end)) break;
      }
      LocalDate due = first;
      while (!due.isAfter(end)) {
        final LocalDate wkStart = weekStartMonday(due);
        final String periodKey = "w_" + wkStart.format(YYYYMMDD);
        final String pairId = "sp_" + planId + "_" + periodKey;
        final int created =
            executeSavingsTransferIfNeeded(
                row, payload, due, fixedAmount, fromAccountId, planAccountId, pairId, periodKey);
        if (created > 0) {
          executed += created;
          added += fixedAmount;
          lastExecutedAt = LocalDateTime.of(due, LocalTime.NOON);
        }
        due = due.plusDays(7);
      }
    }

    if (executed <= 0) return 0;

    final double savedAmount = asDouble(payload.get("savedAmount"), 0);
    payload.put("savedAmount", savedAmount + added);
    payload.put("executedCount", asInt(payload.get("executedCount"), 0) + executed);
    if (lastExecutedAt != null) payload.put("lastExecutedAt", lastExecutedAt.toString());
    payload.put("defaultFromAccountId", fromAccountId);
    payload.put("updatedAt", LocalDateTime.now().toString());

    savingsPlanInfoMapper.updatePayloadAndBumpVersion(userId, bookId, planId, objectMapper.writeValueAsString(payload));
    return executed;
  }

  private int executeSavingsTransferIfNeeded(
      SavingsPlanInfo row,
      Map<String, Object> payload,
      LocalDate dueDate,
      double amount,
      String fromAccountId,
      String toAccountId,
      String pairId,
      String periodKey) {
    if (pairId == null) return 0;
    final String bookId = row.getBookId();
    final Long userId = row.getUserId();
    final String planId = row.getPlanId();

    // Migration safety: if pairId already exists, skip.
    final int existing = billInfoMapper.countByBookIdAndPairId(bookId, pairId);
    if (existing >= 2) return 0;

    final int inserted = planExecLogMapper.insertIgnore("savings", userId, bookId, planId, periodKey);
    if (inserted <= 0) return 0;

    final String name = asString(payload.get("name"));
    final String remark = (name == null || name.trim().isEmpty()) ? "存钱" : name.trim();
    final LocalDateTime dueAt = LocalDateTime.of(dueDate, LocalTime.NOON);

    final boolean sharedBook = isSharedBook(bookId);
    final Long scopeUserId = sharedBook ? 0L : userId;

    // out leg
    BillInfo out = new BillInfo();
    out.setUserId(userId);
    out.setBookId(bookId);
    out.setAccountId(fromAccountId);
    out.setCategoryKey("saving-out");
    out.setAmount(BigDecimal.valueOf(amount));
    out.setDirection(0);
    out.setRemark(remark);
    out.setBillDate(dueAt);
    out.setIncludeInStats(0);
    out.setPairId(pairId);
    out.setIsDelete(0);
    billInfoMapper.insert(out);

    // in leg
    BillInfo in = new BillInfo();
    in.setUserId(userId);
    in.setBookId(bookId);
    in.setAccountId(toAccountId);
    in.setCategoryKey("saving-in");
    in.setAmount(BigDecimal.valueOf(amount));
    in.setDirection(1);
    in.setRemark(remark);
    in.setBillDate(dueAt);
    in.setIncludeInStats(0);
    in.setPairId(pairId);
    in.setIsDelete(0);
    billInfoMapper.insert(in);

    final List<BillChangeLog> logs = new ArrayList<>();
    logs.add(new BillChangeLog(bookId, scopeUserId, out.getId(), 0, 1L, userId));
    logs.add(new BillChangeLog(bookId, scopeUserId, in.getId(), 0, 1L, userId));
    billChangeLogMapper.batchInsert(logs);
    return 1;
  }

  private int executeRecurringPlanRow(RecurringPlanInfo row, LocalDate today) throws Exception {
    if (row == null || row.getIsDelete() != null && row.getIsDelete() == 1) return 0;
    final Map<String, Object> payload = parsePayload(row.getPayloadJson());
    final Boolean enabled = asBool(payload.get("enabled"), true);
    if (!enabled) return 0;

    final String planId = row.getPlanId();
    final String bookId = row.getBookId();
    final Long userId = row.getUserId();

    final String categoryKey = asString(payload.get("categoryKey"));
    final String accountId = asString(payload.get("accountId"));
    if (categoryKey == null || accountId == null) return 0;
    final double amount = asDouble(payload.get("amount"), 0);
    if (amount <= 0) return 0;

    final String periodType = asString(payload.get("periodType")); // "week"|"month"
    LocalDate next = dateOnly(parseClientDate(payload.get("nextDate"), null));
    if (next == null) return 0;
    if (next.isAfter(today)) return 0;

    final int createdLimit = 366;
    int created = 0;

    final boolean sharedBook = isSharedBook(bookId);
    final Long scopeUserId = sharedBook ? 0L : userId;

    @SuppressWarnings("unchecked")
    final List<Object> rawTags = payload.get("tagIds") instanceof List ? (List<Object>) payload.get("tagIds") : Collections.emptyList();
    final List<String> tagIds = new ArrayList<>();
    for (Object o : rawTags) {
      if (o == null) continue;
      final String t = o.toString().trim();
      if (!t.isEmpty()) tagIds.add(t);
    }

    while (!next.isAfter(today) && created < createdLimit) {
      final String periodKey = next.format(YYYYMMDD);
      final int inserted = planExecLogMapper.insertIgnore("recurring", userId, bookId, planId, periodKey);
      if (inserted > 0) {
        final LocalDateTime dueAt = LocalDateTime.of(next, LocalTime.NOON);
        final String remark = asString(payload.get("remark"));
        final boolean includeInStats = asBool(payload.get("includeInStats"), true);
        final String direction = asString(payload.get("direction"));
        final int dir = "in".equalsIgnoreCase(direction) ? 1 : 0;

        BillInfo bill = new BillInfo();
        bill.setUserId(userId);
        bill.setBookId(bookId);
        bill.setAccountId(accountId);
        bill.setCategoryKey(categoryKey);
        bill.setAmount(BigDecimal.valueOf(amount));
        bill.setDirection(dir);
        bill.setRemark(remark == null ? "" : remark);
        bill.setBillDate(dueAt);
        bill.setIncludeInStats(includeInStats ? 1 : 0);
        bill.setPairId(null);
        bill.setIsDelete(0);
        billInfoMapper.insert(bill);

        billChangeLogMapper.insert(bookId, scopeUserId, userId, bill.getId(), 0, 1L);

        if (!tagIds.isEmpty()) {
          final List<BillTagRel> rels = new ArrayList<>();
          for (int i = 0; i < tagIds.size(); i++) {
            BillTagRel rel = new BillTagRel(bookId, scopeUserId, bill.getId(), tagIds.get(i));
            rel.setSortOrder(i);
            rels.add(rel);
          }
          billTagRelMapper.batchInsert(rels);
        }
        created += 1;
      }

      next = nextDate(next, payload);
    }

    if (created <= 0) return 0;
    payload.put("nextDate", LocalDateTime.of(next, LocalTime.MIDNIGHT).toString());
    payload.put("lastRunAt", LocalDateTime.now().toString());
    payload.put("updatedAt", LocalDateTime.now().toString());
    recurringPlanInfoMapper.updatePayloadAndBumpVersion(userId, bookId, planId, objectMapper.writeValueAsString(payload));
    return created;
  }

  private LocalDate nextDate(LocalDate from, Map<String, Object> planPayload) {
    final String periodType = asString(planPayload.get("periodType"));
    final LocalDate start = dateOnly(parseClientDate(planPayload.get("startDate"), planPayload.get("nextDate")));
    if ("week".equalsIgnoreCase(periodType)) {
      final Integer weekdayObj = asIntOrNull(planPayload.get("weekday"));
      final int weekday = weekdayObj != null ? weekdayObj : (start != null ? start.getDayOfWeek().getValue() : from.getDayOfWeek().getValue());
      int delta = (weekday - from.getDayOfWeek().getValue()) % 7;
      if (delta == 0) delta = 7;
      return from.plusDays(delta);
    }
    final Integer dayObj = asIntOrNull(planPayload.get("monthDay"));
    final int day = dayObj != null ? dayObj : (start != null ? start.getDayOfMonth() : from.getDayOfMonth());
    return addMonthsClamped(from, 1, day);
  }

  private boolean isSharedBook(String bookId) {
    if (bookId == null) return false;
    try {
      Long bid = Long.parseLong(bookId.trim());
      Book book = bookMapper.findById(bid);
      return book != null && Boolean.TRUE.equals(book.getIsMulti());
    } catch (Exception ignored) {
      return false;
    }
  }

  private String resolveFromAccountId(String preferred, Long userId, String bookId, String planAccountId) {
    try {
      final List<AccountInfo> accounts = accountInfoMapper.findAllByUserIdAndBookId(userId, bookId);
      if (accounts == null || accounts.isEmpty()) return null;
      if (preferred != null && !preferred.trim().isEmpty() && !preferred.trim().equals(planAccountId)) {
        for (AccountInfo a : accounts) {
          if (preferred.trim().equals(a.getAccountId())) return preferred.trim();
        }
      }
      for (AccountInfo a : accounts) {
        if (a == null) continue;
        if (a.getAccountId() == null) continue;
        if (a.getAccountId().equals(planAccountId)) continue;
        if ("asset".equalsIgnoreCase(a.getKind()) && (a.getIncludeInOverview() != null && a.getIncludeInOverview() == 1)) {
          return a.getAccountId();
        }
      }
      for (AccountInfo a : accounts) {
        if (a == null || a.getAccountId() == null) continue;
        if (!a.getAccountId().equals(planAccountId)) return a.getAccountId();
      }
      return null;
    } catch (Exception e) {
      return null;
    }
  }

  private Map<String, Object> parsePayload(String raw) throws Exception {
    if (raw == null || raw.trim().isEmpty()) return Collections.emptyMap();
    return objectMapper.readValue(raw, new TypeReference<Map<String, Object>>() {});
  }

  private LocalDateTime parseClientDate(Object primary, Object fallback) {
    final String a = asString(primary);
    final String b = asString(fallback);
    final String raw = (a != null && !a.trim().isEmpty()) ? a : b;
    if (raw == null || raw.trim().isEmpty()) return null;
    final String s = raw.trim();
    try {
      return LocalDateTime.parse(s);
    } catch (Exception ignored) {
    }
    try {
      return OffsetDateTime.parse(s).toLocalDateTime();
    } catch (Exception ignored) {
    }
    try {
      return Instant.parse(s).atZone(ZoneOffset.UTC).toLocalDateTime();
    } catch (Exception ignored) {
    }
    return null;
  }

  private LocalDate dateOnly(LocalDateTime dt) {
    return dt == null ? null : dt.toLocalDate();
  }

  private LocalDate monthlyDueDate(int year, int month, int day) {
    int lastDay = LocalDate.of(year, month, 1).lengthOfMonth();
    int d = Math.max(1, Math.min(day, lastDay));
    return LocalDate.of(year, month, d);
  }

  private LocalDate weekStartMonday(LocalDate d) {
    int wd = d.getDayOfWeek().getValue();
    return d.minusDays(wd - 1L);
  }

  private LocalDate addMonthsClamped(LocalDate from, int monthsToAdd, int dayOfMonth) {
    LocalDate first = LocalDate.of(from.getYear(), from.getMonth(), 1).plusMonths(monthsToAdd);
    int lastDay = first.lengthOfMonth();
    int d = Math.max(1, Math.min(dayOfMonth, lastDay));
    return LocalDate.of(first.getYear(), first.getMonth(), d);
  }

  private String asString(Object v) {
    if (v == null) return null;
    return v.toString();
  }

  private boolean asBool(Object v, boolean def) {
    if (v == null) return def;
    if (v instanceof Boolean) return (Boolean) v;
    if (v instanceof Number) return ((Number) v).intValue() != 0;
    String s = v.toString().trim().toLowerCase();
    if (s.isEmpty()) return def;
    return "true".equals(s) || "1".equals(s) || "yes".equals(s);
  }

  private int asInt(Object v, int def) {
    if (v == null) return def;
    if (v instanceof Number) return ((Number) v).intValue();
    try {
      return Integer.parseInt(v.toString().trim());
    } catch (Exception ignored) {
      return def;
    }
  }

  private Integer asIntOrNull(Object v) {
    if (v == null) return null;
    if (v instanceof Number) return ((Number) v).intValue();
    try {
      return Integer.parseInt(v.toString().trim());
    } catch (Exception ignored) {
      return null;
    }
  }

  private double asDouble(Object v, double def) {
    if (v == null) return def;
    if (v instanceof Number) return ((Number) v).doubleValue();
    try {
      return Double.parseDouble(v.toString().trim());
    } catch (Exception ignored) {
      return def;
    }
  }
}
