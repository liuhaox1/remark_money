package com.remark.money.sync;

import com.remark.money.entity.AccountInfo;
import com.remark.money.service.SyncService;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.context.junit4.SpringRunner;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import static org.junit.Assert.*;

@RunWith(SpringRunner.class)
@SpringBootTest
@ActiveProfiles("test")
@Sql(scripts = "classpath:schema-test.sql")
public class AccountSyncServiceTest {

  @Autowired
  private SyncService syncService;

  private AccountInfo account(String accountId, String name) {
    AccountInfo a = new AccountInfo();
    a.setAccountId(accountId);
    a.setName(name);
    a.setKind("asset");
    a.setSubtype("cash");
    a.setType("cash");
    a.setIcon("wallet");
    a.setCurrency("CNY");
    a.setSortOrder(0);
    a.setIncludeInTotal(1);
    a.setIncludeInOverview(1);
    a.setInitialBalance(new BigDecimal("0.00"));
    a.setCurrentBalance(new BigDecimal("0.00"));
    a.setIsDelete(0);
    a.setUpdateTime(LocalDateTime.now());
    return a;
  }

  @Test
  public void uploadDoesNotHardDeleteMissingAccounts() {
    Long userId = 500L;

    AccountInfo a1 = account("a1", "A1");
    AccountInfo a2 = account("a2", "A2");

    SyncService.AccountSyncResult up1 =
        syncService.uploadAccounts(userId, Arrays.asList(a1, a2));
    assertTrue(up1.isSuccess());

    // Uploading a partial list must NOT delete server-side accounts that are missing from the list.
    SyncService.AccountSyncResult up2 =
        syncService.uploadAccounts(userId, Collections.singletonList(a1));
    assertTrue(up2.isSuccess());

    SyncService.AccountSyncResult down = syncService.downloadAccounts(userId);
    assertTrue(down.isSuccess());
    List<AccountInfo> got = down.getAccounts();
    assertNotNull(got);
    assertEquals(2, got.size());
  }

  @Test
  public void explicitDeleteRemovesFromDownloadView() {
    Long userId = 501L;

    AccountInfo a1 = account("b1", "B1");
    AccountInfo a2 = account("b2", "B2");

    SyncService.AccountSyncResult up =
        syncService.uploadAccounts(userId, Arrays.asList(a1, a2));
    assertTrue(up.isSuccess());

    SyncService.AccountSyncResult del =
        syncService.deleteAccounts(userId, null, Collections.singletonList("b2"));
    assertTrue(del.isSuccess());

    SyncService.AccountSyncResult down = syncService.downloadAccounts(userId);
    assertTrue(down.isSuccess());
    List<AccountInfo> got = down.getAccounts();
    assertNotNull(got);
    assertEquals(1, got.size());
    assertEquals("b1", got.get(0).getAccountId());
  }
}

