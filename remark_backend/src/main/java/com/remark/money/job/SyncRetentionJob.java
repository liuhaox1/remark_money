package com.remark.money.job;

import com.remark.money.mapper.BillChangeLogMapper;
import com.remark.money.mapper.SyncOpDedupMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

@Component
public class SyncRetentionJob {

  private static final Logger log = LoggerFactory.getLogger(SyncRetentionJob.class);

  private static final int RETENTION_DAYS = 30;
  private static final int BATCH_SIZE = 2000;
  private static final long SLEEP_MS_BETWEEN_BATCHES = 1000L;

  private final SyncOpDedupMapper syncOpDedupMapper;
  private final BillChangeLogMapper billChangeLogMapper;
  private static final java.util.concurrent.atomic.AtomicBoolean RUNNING =
      new java.util.concurrent.atomic.AtomicBoolean(false);

  public SyncRetentionJob(SyncOpDedupMapper syncOpDedupMapper, BillChangeLogMapper billChangeLogMapper) {
    this.syncOpDedupMapper = syncOpDedupMapper;
    this.billChangeLogMapper = billChangeLogMapper;
  }

  // Run daily at 02:00 server time.
  @Scheduled(cron = "0 0 2 * * ?")
  public void cleanup() {
    if (!RUNNING.compareAndSet(false, true)) {
      log.warn("SyncRetentionJob cleanup skipped because previous run is still running");
      return;
    }
    LocalDateTime cutoff = LocalDateTime.now().minusDays(RETENTION_DAYS);
    try {
      int dedupDeleted = deleteDedupInBatches(cutoff);
      int logDeleted = deleteBillChangeLogInBatches(cutoff);
      log.info(
          "SyncRetentionJob cleanup cutoff={} deleted sync_op_dedup={} bill_change_log={}",
          cutoff,
          dedupDeleted,
          logDeleted);
    } catch (Exception e) {
      log.error("SyncRetentionJob cleanup failed cutoff=" + cutoff, e);
    } finally {
      RUNNING.set(false);
    }
  }

  private int deleteDedupInBatches(LocalDateTime cutoff) {
    int total = 0;
    while (true) {
      java.util.List<Long> ids = syncOpDedupMapper.findIdsBefore(cutoff, BATCH_SIZE);
      if (ids == null || ids.isEmpty()) break;
      total += syncOpDedupMapper.deleteByIds(ids);
      if (ids.size() < BATCH_SIZE) break;
      sleepQuietly();
    }
    return total;
  }

  private int deleteBillChangeLogInBatches(LocalDateTime cutoff) {
    int total = 0;
    while (true) {
      java.util.List<Long> ids = billChangeLogMapper.findChangeIdsBefore(cutoff, BATCH_SIZE);
      if (ids == null || ids.isEmpty()) break;
      total += billChangeLogMapper.deleteByChangeIds(ids);
      if (ids.size() < BATCH_SIZE) break;
      sleepQuietly();
    }
    return total;
  }

  private void sleepQuietly() {
    try {
      Thread.sleep(SLEEP_MS_BETWEEN_BATCHES);
    } catch (InterruptedException ie) {
      Thread.currentThread().interrupt();
    }
  }
}
