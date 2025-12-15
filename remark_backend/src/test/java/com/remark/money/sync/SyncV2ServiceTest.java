package com.remark.money.sync;

import com.remark.money.entity.BillInfo;
import com.remark.money.entity.BookMember;
import com.remark.money.mapper.BillChangeLogMapper;
import com.remark.money.mapper.BillInfoMapper;
import com.remark.money.mapper.BookMemberMapper;
import com.remark.money.mapper.SyncOpDedupMapper;
import com.remark.money.mapper.SyncScopeStateMapper;
import com.remark.money.service.SyncV2Service;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.junit4.SpringRunner;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.jdbc.Sql;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;

import static org.junit.Assert.*;

@RunWith(SpringRunner.class)
@SpringBootTest
@ActiveProfiles("test")
@Sql(scripts = "classpath:schema-test.sql")
public class SyncV2ServiceTest {

  @Autowired
  private SyncV2Service syncV2Service;

  @Autowired
  private BillInfoMapper billInfoMapper;

  @Autowired
  private BillChangeLogMapper billChangeLogMapper;

  @Autowired
  private SyncOpDedupMapper syncOpDedupMapper;

  @Autowired
  private SyncScopeStateMapper syncScopeStateMapper;

  @Autowired
  private BookMemberMapper bookMemberMapper;

  private Map<String, Object> buildUpsertOp(String opId, Long expectedVersion, Map<String, Object> bill) {
    Map<String, Object> op = new HashMap<>();
    op.put("opId", opId);
    op.put("type", "upsert");
    if (expectedVersion != null) op.put("expectedVersion", expectedVersion);
    op.put("bill", bill);
    return op;
  }

  private Map<String, Object> buildDeleteOp(String opId, Long serverId, Long expectedVersion) {
    Map<String, Object> op = new HashMap<>();
    op.put("opId", opId);
    op.put("type", "delete");
    op.put("serverId", serverId);
    if (expectedVersion != null) op.put("expectedVersion", expectedVersion);
    return op;
  }

  private Map<String, Object> newBillPayload(String bookId, String remark, BigDecimal amount) {
    Map<String, Object> bill = new HashMap<>();
    bill.put("bookId", bookId);
    bill.put("accountId", "acc-1");
    bill.put("categoryKey", "food");
    bill.put("amount", amount);
    bill.put("direction", 0);
    bill.put("remark", remark);
    bill.put("billDate", LocalDateTime.now().withNano(0).toString());
    bill.put("includeInStats", 1);
    bill.put("isDelete", 0);
    return bill;
  }

  @SuppressWarnings("unchecked")
  private List<Map<String, Object>> resultsOf(Map<String, Object> resp) {
    assertEquals(true, resp.get("success"));
    Object results = resp.get("results");
    assertTrue(results instanceof List);
    return (List<Map<String, Object>>) results;
  }

  @SuppressWarnings("unchecked")
  private List<Map<String, Object>> changesOf(Map<String, Object> resp) {
    assertEquals(true, resp.get("success"));
    Object changes = resp.get("changes");
    assertTrue(changes instanceof List);
    return (List<Map<String, Object>>) changes;
  }

  @Test
  public void personalBook_pushInsert_thenPull_returnsChange() {
    Long userId = 100L;
    String bookId = "local-book";

    Map<String, Object> bill = newBillPayload(bookId, "first", new BigDecimal("12.34"));
    Map<String, Object> resp = syncV2Service.push(userId, bookId, Collections.singletonList(
        buildUpsertOp("op-1", null, bill)
    ));

    List<Map<String, Object>> results = resultsOf(resp);
    assertEquals(1, results.size());
    assertEquals("applied", results.get(0).get("status"));
    assertNotNull(results.get(0).get("serverId"));
    assertEquals(1L, ((Number) results.get(0).get("version")).longValue());

    Map<String, Object> pull = syncV2Service.pull(userId, bookId, null, 200);
    List<Map<String, Object>> changes = changesOf(pull);
    assertEquals(1, changes.size());
    Map<String, Object> change = changes.get(0);
    assertEquals("upsert", change.get("op"));
    assertNotNull(change.get("changeId"));
    assertNotNull(change.get("bill"));
  }

  @Test
  public void push_isIdempotent_byOpId() {
    Long userId = 101L;
    String bookId = "local-book";

    Map<String, Object> bill = newBillPayload(bookId, "idempotent", new BigDecimal("10.00"));
    Map<String, Object> resp1 = syncV2Service.push(userId, bookId, Collections.singletonList(
        buildUpsertOp("op-dup", null, bill)
    ));
    List<Map<String, Object>> r1 = resultsOf(resp1);
    Long serverId = ((Number) r1.get(0).get("serverId")).longValue();

    int before = billChangeLogMapper.countForScope(bookId, userId);

    Map<String, Object> resp2 = syncV2Service.push(userId, bookId, Collections.singletonList(
        buildUpsertOp("op-dup", null, bill)
    ));
    List<Map<String, Object>> r2 = resultsOf(resp2);
    assertEquals("applied", r2.get(0).get("status"));
    assertEquals(serverId.longValue(), ((Number) r2.get(0).get("serverId")).longValue());
    assertEquals(1L, ((Number) r2.get(0).get("version")).longValue());

    int after = billChangeLogMapper.countForScope(bookId, userId);
    assertEquals(before, after);
    assertNotNull(syncOpDedupMapper.find(userId, bookId, "op-dup"));
  }

  @Test
  public void conflict_onStaleExpectedVersion_upsert() {
    Long userId = 102L;
    String bookId = "local-book";

    Map<String, Object> bill = newBillPayload(bookId, "base", new BigDecimal("1.00"));
    Map<String, Object> resp1 = syncV2Service.push(userId, bookId, Collections.singletonList(
        buildUpsertOp("op-a", null, bill)
    ));
    Long serverId = ((Number) resultsOf(resp1).get(0).get("serverId")).longValue();

    // update with correct expectedVersion=1 => applied, version becomes 2
    Map<String, Object> updateBill = newBillPayload(bookId, "updated", new BigDecimal("2.00"));
    updateBill.put("serverId", serverId);
    Map<String, Object> resp2 = syncV2Service.push(userId, bookId, Collections.singletonList(
        buildUpsertOp("op-b", 1L, updateBill)
    ));
    assertEquals("applied", resultsOf(resp2).get(0).get("status"));
    assertEquals(2L, ((Number) resultsOf(resp2).get(0).get("version")).longValue());

    // stale expectedVersion=1 => conflict with serverBill version=2
    Map<String, Object> resp3 = syncV2Service.push(userId, bookId, Collections.singletonList(
        buildUpsertOp("op-c", 1L, updateBill)
    ));
    Map<String, Object> r3 = resultsOf(resp3).get(0);
    assertEquals("conflict", r3.get("status"));
    assertEquals(2L, ((Number) r3.get("version")).longValue());
    assertNotNull(r3.get("serverBill"));
  }

  @Test
  public void conflict_onStaleExpectedVersion_delete() {
    Long userId = 103L;
    String bookId = "local-book";

    Map<String, Object> bill = newBillPayload(bookId, "base", new BigDecimal("3.00"));
    Map<String, Object> resp1 = syncV2Service.push(userId, bookId, Collections.singletonList(
        buildUpsertOp("op-ins", null, bill)
    ));
    Long serverId = ((Number) resultsOf(resp1).get(0).get("serverId")).longValue();

    // correct delete => applied, version becomes 2
    Map<String, Object> resp2 = syncV2Service.push(userId, bookId, Collections.singletonList(
        buildDeleteOp("op-del-ok", serverId, 1L)
    ));
    assertEquals("applied", resultsOf(resp2).get(0).get("status"));
    assertEquals(2L, ((Number) resultsOf(resp2).get(0).get("version")).longValue());

    // stale delete => conflict
    Map<String, Object> resp3 = syncV2Service.push(userId, bookId, Collections.singletonList(
        buildDeleteOp("op-del-stale", serverId, 1L)
    ));
    Map<String, Object> r3 = resultsOf(resp3).get(0);
    assertEquals("conflict", r3.get("status"));
    assertEquals(2L, ((Number) r3.get("version")).longValue());
    assertNotNull(r3.get("serverBill"));
  }

  @Test
  public void sharedBook_memberAccess_andVisibilityAcrossUsers() {
    Long userA = 201L;
    Long userB = 202L;
    String sharedBookId = "1"; // numeric => shared book

    BookMember ma = new BookMember();
    ma.setBookId(1L);
    ma.setUserId(userA);
    ma.setRole("owner");
    ma.setStatus(1);
    bookMemberMapper.insert(ma);

    BookMember mb = new BookMember();
    mb.setBookId(1L);
    mb.setUserId(userB);
    mb.setRole("member");
    mb.setStatus(1);
    bookMemberMapper.insert(mb);

    Map<String, Object> bill = newBillPayload(sharedBookId, "shared", new BigDecimal("9.99"));
    Map<String, Object> push = syncV2Service.push(userA, sharedBookId, Collections.singletonList(
        buildUpsertOp("op-shared", null, bill)
    ));
    Map<String, Object> r = resultsOf(push).get(0);
    assertEquals("applied", r.get("status"));

    // userB should be able to pull same change (scope_user_id = 0)
    Map<String, Object> pullB = syncV2Service.pull(userB, sharedBookId, null, 200);
    List<Map<String, Object>> changes = changesOf(pullB);
    assertEquals(1, changes.size());
    Map<String, Object> billMap = (Map<String, Object>) changes.get(0).get("bill");
    assertEquals(sharedBookId, billMap.get("bookId"));
  }

  @Test
  public void pull_bootstrapsExistingBills_noMissedData() {
    Long userId = 300L;
    String bookId = "local-book";

    // insert existing data without any change logs
    BillInfo bi = new BillInfo();
    bi.setUserId(userId);
    bi.setBookId(bookId);
    bi.setAccountId("acc-1");
    bi.setCategoryKey("food");
    bi.setAmount(new BigDecimal("5.00"));
    bi.setDirection(0);
    bi.setRemark("existing");
    bi.setBillDate(LocalDateTime.now().withNano(0));
    bi.setIncludeInStats(1);
    bi.setIsDelete(0);
    billInfoMapper.insert(bi);

    assertEquals(0, billChangeLogMapper.countForScope(bookId, userId));

    Map<String, Object> pull = syncV2Service.pull(userId, bookId, 0L, 200);
    List<Map<String, Object>> changes = changesOf(pull);
    assertEquals(1, changes.size());
    assertTrue(((Number) pull.get("nextChangeId")).longValue() > 0);
    assertEquals(1, billChangeLogMapper.countForScope(bookId, userId));

    // second pull with cursor==0 should NOT re-bootstrap (state initialized)
    Map<String, Object> pull2 = syncV2Service.pull(userId, bookId, 0L, 200);
    List<Map<String, Object>> changes2 = changesOf(pull2);
    assertEquals(1, changes2.size());
    assertNotNull(syncScopeStateMapper.find(bookId, userId));
  }
}
