package com.remark.money.job;

import com.remark.money.entity.BillInfo;
import com.remark.money.entity.BillTagRel;
import com.remark.money.mapper.BillInfoMapper;
import com.remark.money.mapper.BillTagRelMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

@Component
public class BillTagRelBackfillJob {

  private static final Logger log = LoggerFactory.getLogger(BillTagRelBackfillJob.class);

  private static final int BATCH_SIZE = 500;
  private static final long SLEEP_MS_BETWEEN_BATCHES = 500L;
  private static final AtomicBoolean RUNNING = new AtomicBoolean(false);

  private final BillInfoMapper billInfoMapper;
  private final BillTagRelMapper billTagRelMapper;

  public BillTagRelBackfillJob(BillInfoMapper billInfoMapper, BillTagRelMapper billTagRelMapper) {
    this.billInfoMapper = billInfoMapper;
    this.billTagRelMapper = billTagRelMapper;
  }

  // Run daily at 02:20 server time (after purge job).
  @Scheduled(cron = "0 20 2 * * ?")
  public void backfill() {
    if (!RUNNING.compareAndSet(false, true)) {
      log.warn("BillTagRelBackfillJob skipped because previous run is still running");
      return;
    }

    int processed = 0;
    int relsInserted = 0;
    try {
      while (true) {
        List<BillInfo> bills = billInfoMapper.findBillsNeedingTagRelBackfill(BATCH_SIZE);
        if (bills == null || bills.isEmpty()) break;
        processed += bills.size();

        List<BillTagRel> rels = new ArrayList<>();
        for (BillInfo b : bills) {
          if (b == null || b.getId() == null || b.getBookId() == null) continue;
          List<String> tagIds = decodeTagIds(b.getTagIds());
          if (tagIds == null || tagIds.isEmpty()) continue;
          int idx = 0;
          for (String tid : tagIds) {
            if (tid == null || tid.trim().isEmpty()) continue;
            BillTagRel r = new BillTagRel(b.getBookId(), b.getId(), tid.trim());
            r.setSortOrder(idx++);
            rels.add(r);
          }
        }

        if (!rels.isEmpty()) {
          relsInserted += billTagRelMapper.batchInsert(rels);
        }
        if (bills.size() < BATCH_SIZE) break;
        sleepQuietly();
      }
      log.info("BillTagRelBackfillJob done processedBills={} insertedRels={}", processed, relsInserted);
    } catch (Exception e) {
      log.error("BillTagRelBackfillJob failed", e);
    } finally {
      RUNNING.set(false);
    }
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

  private void sleepQuietly() {
    try {
      Thread.sleep(SLEEP_MS_BETWEEN_BATCHES);
    } catch (InterruptedException ie) {
      Thread.currentThread().interrupt();
    }
  }
}
