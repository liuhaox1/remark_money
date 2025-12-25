package com.remark.money.job;

import com.remark.money.entity.BillDeleteTombstone;
import com.remark.money.entity.BillInfo;
import com.remark.money.mapper.BillDeleteTombstoneMapper;
import com.remark.money.mapper.BillInfoMapper;
import com.remark.money.mapper.BillTagRelMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.stream.Collectors;

@Component
public class BillInfoPurgeJob {

  private static final Logger log = LoggerFactory.getLogger(BillInfoPurgeJob.class);

  // Hard-delete soft-deleted bills older than this.
  private static final int BILL_INFO_DELETE_DAYS = 90;
  // Keep tombstones longer so long-offline devices can still receive deletions via bootstrap.
  private static final int TOMBSTONE_RETENTION_DAYS = 365;
  private static final int BATCH_SIZE = 2000;
  private static final long SLEEP_MS_BETWEEN_BATCHES = 1000L;

  private static final AtomicBoolean RUNNING = new AtomicBoolean(false);

  private final BillInfoMapper billInfoMapper;
  private final BillTagRelMapper billTagRelMapper;
  private final BillDeleteTombstoneMapper billDeleteTombstoneMapper;

  public BillInfoPurgeJob(BillInfoMapper billInfoMapper,
                          BillTagRelMapper billTagRelMapper,
                          BillDeleteTombstoneMapper billDeleteTombstoneMapper) {
    this.billInfoMapper = billInfoMapper;
    this.billTagRelMapper = billTagRelMapper;
    this.billDeleteTombstoneMapper = billDeleteTombstoneMapper;
  }

  // Run daily at 02:10 server time (after sync retention at 02:00).
  @Scheduled(cron = "0 10 2 * * ?")
  public void purge() {
    if (!RUNNING.compareAndSet(false, true)) {
      log.warn("BillInfoPurgeJob skipped because previous run is still running");
      return;
    }

    LocalDateTime billCutoff = LocalDateTime.now().minusDays(BILL_INFO_DELETE_DAYS);
    LocalDateTime tombstoneCutoff = LocalDateTime.now().minusDays(TOMBSTONE_RETENTION_DAYS);
    try {
      int billsDeleted = purgeBillInfoInBatches(billCutoff);
      int tombstonesDeleted = purgeTombstonesInBatches(tombstoneCutoff);
      log.info(
          "BillInfoPurgeJob done billCutoff={} tombstoneCutoff={} deletedBills={} deletedTombstones={}",
          billCutoff,
          tombstoneCutoff,
          billsDeleted,
          tombstonesDeleted);
    } catch (Exception e) {
      log.error("BillInfoPurgeJob failed", e);
    } finally {
      RUNNING.set(false);
    }
  }

  private int purgeBillInfoInBatches(LocalDateTime cutoff) {
    int totalDeleted = 0;
    while (true) {
      List<BillInfo> bills = billInfoMapper.findDeletedBillsBefore(cutoff, BATCH_SIZE);
      if (bills == null || bills.isEmpty()) break;

      Map<String, List<Long>> byBook =
          bills.stream()
              .filter(b -> b.getBookId() != null && b.getId() != null)
              .collect(Collectors.groupingBy(BillInfo::getBookId, Collectors.mapping(BillInfo::getId, Collectors.toList())));
      for (Map.Entry<String, List<Long>> e : byBook.entrySet()) {
        String bookId = e.getKey();
        List<Long> ids = e.getValue();
        if (bookId == null || ids == null || ids.isEmpty()) continue;
        billTagRelMapper.deleteByBillIds(bookId, ids);
      }

      List<Long> ids = bills.stream().map(BillInfo::getId).collect(Collectors.toList());
      totalDeleted += billInfoMapper.deleteByIds(ids);

      if (bills.size() < BATCH_SIZE) break;
      sleepQuietly();
    }
    return totalDeleted;
  }

  private int purgeTombstonesInBatches(LocalDateTime cutoff) {
    int totalDeleted = 0;
    while (true) {
      List<BillDeleteTombstone> keys = billDeleteTombstoneMapper.findKeysBefore(cutoff, BATCH_SIZE);
      if (keys == null || keys.isEmpty()) break;
      totalDeleted += billDeleteTombstoneMapper.deleteByKeys(keys);
      if (keys.size() < BATCH_SIZE) break;
      sleepQuietly();
    }
    return totalDeleted;
  }

  private void sleepQuietly() {
    try {
      Thread.sleep(SLEEP_MS_BETWEEN_BATCHES);
    } catch (InterruptedException ie) {
      Thread.currentThread().interrupt();
    }
  }
}
