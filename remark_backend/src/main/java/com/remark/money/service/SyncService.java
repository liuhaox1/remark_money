package com.remark.money.service;

import com.remark.money.common.ErrorCode;
import com.remark.money.entity.AccountInfo;
import com.remark.money.entity.BudgetInfo;
import com.remark.money.entity.User;
import com.remark.money.mapper.AccountInfoMapper;
import com.remark.money.mapper.BudgetInfoMapper;
import com.remark.money.mapper.UserMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class SyncService {

  private static final Logger log = LoggerFactory.getLogger(SyncService.class);

  private final UserMapper userMapper;
  private final AccountInfoMapper accountInfoMapper;
  private final BudgetInfoMapper budgetInfoMapper;

  public SyncService(UserMapper userMapper, AccountInfoMapper accountInfoMapper, BudgetInfoMapper budgetInfoMapper) {
    this.userMapper = userMapper;
    this.accountInfoMapper = accountInfoMapper;
    this.budgetInfoMapper = budgetInfoMapper;
  }

  /**
   * 权限校验：检查用户是否有云端同步权限
   *
   * <p>当前阶段不区分付费/免费，同步默认开启。
   */
  public ErrorCode checkSyncPermission(Long userId) {
    if (isSyncAlwaysEnabled()) return ErrorCode.SUCCESS;
    User user = userMapper.findById(userId);
    if (user == null) {
      return ErrorCode.USER_NOT_FOUND;
    }

    if (user.getPayType() == null || user.getPayType() == 0) {
      return ErrorCode.NO_SYNC_PERMISSION;
    }

    if (user.getPayExpire() != null && user.getPayExpire().isBefore(LocalDateTime.now())) {
      return ErrorCode.PAYMENT_EXPIRED;
    }

    return ErrorCode.SUCCESS;
  }

  private boolean isSyncAlwaysEnabled() {
    return true;
  }

  /**
   * 上传账户数据（幂等：按 serverId 或 accountId 匹配）
   */
  @Transactional
  public AccountSyncResult uploadAccounts(Long userId, List<AccountInfo> accounts) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return AccountSyncResult.error(permissionError.getMessage());
    }

    List<AccountInfo> toInsert = new ArrayList<>();
    List<AccountInfo> toUpdate = new ArrayList<>();
    List<AccountInfo> processed = new ArrayList<>();

    Set<Long> incomingIds =
        accounts.stream()
            .map(AccountInfo::getId)
            .filter(id -> id != null && id > 0)
            .collect(Collectors.toSet());
    Map<Long, AccountInfo> existingById =
        incomingIds.isEmpty()
            ? new HashMap<>()
            : accountInfoMapper.findByUserIdAndIds(userId, incomingIds).stream()
                .collect(Collectors.toMap(AccountInfo::getId, a -> a));

    Set<String> incomingAccountIds =
        accounts.stream()
            .map(AccountInfo::getAccountId)
            .filter(id -> id != null && !id.trim().isEmpty())
            .collect(Collectors.toSet());
    Map<String, AccountInfo> existingByAccountId =
        incomingAccountIds.isEmpty()
            ? new HashMap<>()
            : accountInfoMapper.findByUserIdAndAccountIds(userId, incomingAccountIds).stream()
                .collect(Collectors.toMap(AccountInfo::getAccountId, a -> a));

    for (AccountInfo account : accounts) {
      account.setUserId(userId);

      AccountInfo existing = null;
      if (account.getId() != null) {
        existing = existingById.get(account.getId());
      }
      if (existing == null && account.getAccountId() != null) {
        existing = existingByAccountId.get(account.getAccountId());
      }

      if (existing != null) {
        // 冲突处理：服务端 update_time 更新的优先
        if (existing.getUpdateTime() != null
            && account.getUpdateTime() != null
            && existing.getUpdateTime().isAfter(account.getUpdateTime())) {
          processed.add(existing);
          continue;
        }
        account.setId(existing.getId());
        toUpdate.add(account);
      } else {
        toInsert.add(account);
      }
    }

    if (!toUpdate.isEmpty()) {
      accountInfoMapper.batchUpdate(toUpdate);
      processed.addAll(toUpdate);
    }
    if (!toInsert.isEmpty()) {
      accountInfoMapper.batchInsert(toInsert);
      processed.addAll(toInsert);
    }

    // 账户同步约定：客户端在 accounts_changed 时上传全量账户列表。
    // 服务端应删除（硬删）不在本次全量列表中的旧账户，避免“删完又回来”。
    if (!incomingAccountIds.isEmpty()) {
      accountInfoMapper.deleteByUserIdAndAccountIdsNotIn(userId, incomingAccountIds);
    }

    return AccountSyncResult.success(processed);
  }

  /**
   * 下载账户数据
   */
  public AccountSyncResult downloadAccounts(Long userId) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return AccountSyncResult.error(permissionError.getMessage());
    }

    List<AccountInfo> accounts = accountInfoMapper.findAllByUserId(userId);
    return AccountSyncResult.success(accounts);
  }

  @Transactional
  public BudgetSyncResult uploadBudget(Long userId, String bookId, BudgetInfo budget) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return BudgetSyncResult.error(permissionError.getMessage());
    }
    if (bookId == null || bookId.trim().isEmpty()) {
      return BudgetSyncResult.error("missing bookId");
    }
    if (budget == null) {
      return BudgetSyncResult.error("missing budget");
    }
    budget.setUserId(userId);
    budget.setBookId(bookId);
    if (budget.getTotal() == null) budget.setTotal(BigDecimal.ZERO);
    if (budget.getAnnualTotal() == null) budget.setAnnualTotal(BigDecimal.ZERO);
    if (budget.getPeriodStartDay() == null) budget.setPeriodStartDay(1);
    budgetInfoMapper.upsert(budget);
    return BudgetSyncResult.success();
  }

  public BudgetSyncResult downloadBudget(Long userId, String bookId) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return BudgetSyncResult.error(permissionError.getMessage());
    }
    if (bookId == null || bookId.trim().isEmpty()) {
      return BudgetSyncResult.error("missing bookId");
    }
    BudgetInfo budget = budgetInfoMapper.findByUserIdAndBookId(userId, bookId);
    return BudgetSyncResult.success(budget);
  }

  public static class AccountSyncResult {
    private boolean success;
    private String error;
    private List<AccountInfo> accounts;

    public static AccountSyncResult error(String error) {
      AccountSyncResult result = new AccountSyncResult();
      result.success = false;
      result.error = error;
      return result;
    }

    public static AccountSyncResult success(List<AccountInfo> accounts) {
      AccountSyncResult result = new AccountSyncResult();
      result.success = true;
      result.accounts = accounts;
      return result;
    }

    public boolean isSuccess() {
      return success;
    }

    public String getError() {
      return error;
    }

    public List<AccountInfo> getAccounts() {
      return accounts;
    }
  }

  public static class BudgetSyncResult {
    private boolean success;
    private String error;
    private BudgetInfo budget;

    public static BudgetSyncResult error(String error) {
      BudgetSyncResult result = new BudgetSyncResult();
      result.success = false;
      result.error = error;
      return result;
    }

    public static BudgetSyncResult success() {
      BudgetSyncResult result = new BudgetSyncResult();
      result.success = true;
      return result;
    }

    public static BudgetSyncResult success(BudgetInfo budget) {
      BudgetSyncResult result = new BudgetSyncResult();
      result.success = true;
      result.budget = budget;
      return result;
    }

    public boolean isSuccess() {
      return success;
    }

    public String getError() {
      return error;
    }

    public BudgetInfo getBudget() {
      return budget;
    }
  }
}
