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
  }
}

