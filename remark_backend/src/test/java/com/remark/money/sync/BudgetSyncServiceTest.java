package com.remark.money.sync;

import com.remark.money.entity.BudgetInfo;
import com.remark.money.service.SyncService;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.context.junit4.SpringRunner;

import java.math.BigDecimal;

import static org.junit.Assert.*;

@RunWith(SpringRunner.class)
@SpringBootTest
@ActiveProfiles("test")
@Sql(scripts = "classpath:schema-test.sql")
public class BudgetSyncServiceTest {

  @Autowired
  private SyncService syncService;

  @Test
  public void uploadThenDownloadBudget_roundTrip() {
    Long userId = 400L;
    String bookId = "local-book";

    BudgetInfo b = new BudgetInfo();
    b.setTotal(new BigDecimal("123.45"));
    b.setAnnualTotal(new BigDecimal("999.00"));
    b.setPeriodStartDay(5);
    b.setCategoryBudgets("{\"food\":100}");
    b.setAnnualCategoryBudgets("{\"food\":900}");

    SyncService.BudgetSyncResult up = syncService.uploadBudget(userId, bookId, b);
    assertTrue(up.isSuccess());

    SyncService.BudgetSyncResult down = syncService.downloadBudget(userId, bookId);
    assertTrue(down.isSuccess());
    BudgetInfo got = down.getBudget();
    assertNotNull(got);
    assertEquals(0, new BigDecimal("123.45").compareTo(got.getTotal()));
    assertEquals(0, new BigDecimal("999.00").compareTo(got.getAnnualTotal()));
    assertEquals(Integer.valueOf(5), got.getPeriodStartDay());
    assertEquals("{\"food\":100}", got.getCategoryBudgets());
    assertEquals("{\"food\":900}", got.getAnnualCategoryBudgets());
    assertEquals(Long.valueOf(1L), got.getSyncVersion());
  }

  @Test
  public void uploadBudget_conflictsOnStaleSyncVersion() {
    Long userId = 401L;
    String bookId = "local-book";

    BudgetInfo initial = new BudgetInfo();
    initial.setTotal(new BigDecimal("10"));
    initial.setAnnualTotal(new BigDecimal("20"));
    initial.setPeriodStartDay(2);
    initial.setCategoryBudgets("{\"a\":1}");
    initial.setAnnualCategoryBudgets("{\"a\":2}");
    assertTrue(syncService.uploadBudget(userId, bookId, initial).isSuccess());

    BudgetInfo got = syncService.downloadBudget(userId, bookId).getBudget();
    assertNotNull(got);
    assertEquals(0, new BigDecimal("10").compareTo(got.getTotal()));
    assertEquals(Integer.valueOf(2), got.getPeriodStartDay());
    assertEquals("{\"a\":1}", got.getCategoryBudgets());
    assertEquals(Long.valueOf(1L), got.getSyncVersion());

    BudgetInfo updateOk = new BudgetInfo();
    updateOk.setSyncVersion(got.getSyncVersion());
    updateOk.setTotal(new BigDecimal("11"));
    updateOk.setAnnualTotal(new BigDecimal("21"));
    updateOk.setPeriodStartDay(3);
    updateOk.setCategoryBudgets("{\"a\":2}");
    updateOk.setAnnualCategoryBudgets("{\"a\":3}");
    assertTrue(syncService.uploadBudget(userId, bookId, updateOk).isSuccess());

    BudgetInfo after = syncService.downloadBudget(userId, bookId).getBudget();
    assertNotNull(after);
    assertEquals(0, new BigDecimal("11").compareTo(after.getTotal()));
    assertEquals(Long.valueOf(2L), after.getSyncVersion());

    BudgetInfo stale = new BudgetInfo();
    stale.setSyncVersion(1L);
    stale.setTotal(new BigDecimal("999"));
    stale.setAnnualTotal(new BigDecimal("999"));
    stale.setPeriodStartDay(10);
    stale.setCategoryBudgets("{\"b\":9}");
    stale.setAnnualCategoryBudgets("{\"b\":9}");
    assertFalse(syncService.uploadBudget(userId, bookId, stale).isSuccess());

    BudgetInfo unchanged = syncService.downloadBudget(userId, bookId).getBudget();
    assertNotNull(unchanged);
    assertEquals(0, new BigDecimal("11").compareTo(unchanged.getTotal()));
    assertEquals(Long.valueOf(2L), unchanged.getSyncVersion());
  }
}
