package com.remark.money.service;

import com.remark.money.common.ErrorCode;
import com.remark.money.entity.AccountInfo;
import com.remark.money.entity.BudgetInfo;
import com.remark.money.entity.CategoryInfo;
import com.remark.money.entity.SavingsPlanInfo;
import com.remark.money.entity.TagInfo;
import com.remark.money.entity.User;
import com.remark.money.mapper.AccountInfoMapper;
import com.remark.money.mapper.BudgetInfoMapper;
import com.remark.money.mapper.CategoryInfoMapper;
import com.remark.money.mapper.SavingsPlanInfoMapper;
import com.remark.money.mapper.TagInfoMapper;
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
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class SyncService {

  private static final Logger log = LoggerFactory.getLogger(SyncService.class);

  private final UserMapper userMapper;
  private final AccountInfoMapper accountInfoMapper;
  private final BudgetInfoMapper budgetInfoMapper;
  private final CategoryInfoMapper categoryInfoMapper;
  private final TagInfoMapper tagInfoMapper;
  private final SavingsPlanInfoMapper savingsPlanInfoMapper;

  public SyncService(UserMapper userMapper,
                     AccountInfoMapper accountInfoMapper,
                     BudgetInfoMapper budgetInfoMapper,
                     CategoryInfoMapper categoryInfoMapper,
                     TagInfoMapper tagInfoMapper,
                     SavingsPlanInfoMapper savingsPlanInfoMapper) {
    this.userMapper = userMapper;
    this.accountInfoMapper = accountInfoMapper;
    this.budgetInfoMapper = budgetInfoMapper;
    this.categoryInfoMapper = categoryInfoMapper;
    this.tagInfoMapper = tagInfoMapper;
    this.savingsPlanInfoMapper = savingsPlanInfoMapper;
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
      if (account.getIsDelete() == null) {
        account.setIsDelete(0);
      }

      AccountInfo existing = null;
      if (account.getId() != null) {
        existing = existingById.get(account.getId());
      }
      if (existing == null && account.getAccountId() != null) {
        existing = existingByAccountId.get(account.getAccountId());
      }

      if (existing != null) {
        // Hard requirement: once server has sync_version, client must provide syncVersion to update.
        if (existing.getSyncVersion() != null && account.getSyncVersion() == null) {
          return AccountSyncResult.error("missing syncVersion");
        }

        // Prefer server monotonic sync_version when available (avoid client clock drift).
        if (account.getSyncVersion() != null && existing.getSyncVersion() != null) {
          if (!existing.getSyncVersion().equals(account.getSyncVersion())) {
            return AccountSyncResult.error("account conflict");
          }
          account.setId(existing.getId());
          int updated =
              accountInfoMapper.updateWithExpectedSyncVersion(account, account.getSyncVersion());
          if (updated <= 0) {
            return AccountSyncResult.error("account conflict");
          }
          continue;
        }
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
    // IMPORTANT: do NOT hard-delete "missing" accounts based on a potentially partial client list.
    // Deletions must be explicit (tombstone) to avoid irreversible data loss.

    return AccountSyncResult.success(accountInfoMapper.findAllByUserId(userId));
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
  public AccountSyncResult deleteAccounts(Long userId, List<Long> serverIds, List<String> accountIds) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return AccountSyncResult.error(permissionError.getMessage());
    }

    int affected = 0;
    if (serverIds != null) {
      for (Long id : serverIds) {
        if (id == null || id <= 0) continue;
        affected += accountInfoMapper.softDeleteById(userId, id);
      }
    }
    if (accountIds != null) {
      for (String aid : accountIds) {
        if (aid == null || aid.trim().isEmpty()) continue;
        affected += accountInfoMapper.softDeleteByAccountId(userId, aid);
      }
    }

    // return latest server view (non-deleted) for client reconciliation if needed
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

    BudgetInfo existing = budgetInfoMapper.findByUserIdAndBookId(userId, bookId);
    if (existing == null) {
      budgetInfoMapper.insertNew(budget);
      return BudgetSyncResult.success();
    }

    // Use server monotonic sync_version to avoid client clock drift (optimistic concurrency).
    if (budget.getSyncVersion() == null) {
      return BudgetSyncResult.error("missing syncVersion");
    }
    if (existing.getSyncVersion() == null) {
      log.warn("budget_info missing sync_version for userId={} bookId={}", userId, bookId);
      return BudgetSyncResult.error("server budget missing syncVersion");
    }
    if (!existing.getSyncVersion().equals(budget.getSyncVersion())) {
      return BudgetSyncResult.error("budget conflict");
    }

    int updated = budgetInfoMapper.updateWithExpectedSyncVersion(budget, budget.getSyncVersion());
    if (updated == 0) {
      return BudgetSyncResult.error("budget conflict");
    }
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

  @Transactional
  public SavingsPlanSyncResult uploadSavingsPlans(
      Long userId, String bookId, List<SavingsPlanInfo> plans, List<String> deletedPlanIds) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return SavingsPlanSyncResult.error(permissionError.getMessage());
    }
    if (bookId == null || bookId.trim().isEmpty()) {
      return SavingsPlanSyncResult.error("missing bookId");
    }

    if (deletedPlanIds != null) {
      for (String pid : deletedPlanIds) {
        if (pid == null || pid.trim().isEmpty()) continue;
        savingsPlanInfoMapper.softDeleteByPlanId(userId, bookId, pid.trim());
      }
    }

    if (plans != null) {
      for (SavingsPlanInfo p : plans) {
        if (p == null) continue;
        if (p.getPlanId() == null || p.getPlanId().trim().isEmpty()) {
          return SavingsPlanSyncResult.error("missing planId");
        }
        p.setUserId(userId);
        p.setBookId(bookId);
        if (p.getIsDelete() == null) p.setIsDelete(0);
        if (p.getPayloadJson() == null) {
          return SavingsPlanSyncResult.error("missing payload");
        }

        SavingsPlanInfo existing =
            savingsPlanInfoMapper.findByUserIdBookIdAndPlanId(userId, bookId, p.getPlanId());
        if (existing == null) {
          savingsPlanInfoMapper.insertOne(p);
          continue;
        }

        if (existing.getSyncVersion() != null && p.getSyncVersion() == null) {
          return SavingsPlanSyncResult.error("missing syncVersion");
        }
        if (existing.getSyncVersion() != null) {
          if (!existing.getSyncVersion().equals(p.getSyncVersion())) {
            return SavingsPlanSyncResult.error("savings_plan conflict");
          }
          int updated =
              savingsPlanInfoMapper.updateWithExpectedSyncVersion(p, p.getSyncVersion());
          if (updated <= 0) {
            return SavingsPlanSyncResult.error("savings_plan conflict");
          }
        } else {
          return SavingsPlanSyncResult.error("server savings_plan missing syncVersion");
        }
      }
    }

    return SavingsPlanSyncResult.success(
        savingsPlanInfoMapper.findAllByUserIdAndBookId(userId, bookId));
  }

  public SavingsPlanSyncResult downloadSavingsPlans(Long userId, String bookId) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return SavingsPlanSyncResult.error(permissionError.getMessage());
    }
    if (bookId == null || bookId.trim().isEmpty()) {
      return SavingsPlanSyncResult.error("missing bookId");
    }
    return SavingsPlanSyncResult.success(
        savingsPlanInfoMapper.findAllByUserIdAndBookId(userId, bookId));
  }

  @Transactional
  public CategorySyncResult uploadCategories(Long userId, List<CategoryInfo> categories, List<String> deletedKeys) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return CategorySyncResult.error(permissionError.getMessage());
    }

    if (deletedKeys != null) {
      for (String k : deletedKeys) {
        if (k == null || k.trim().isEmpty()) continue;
        categoryInfoMapper.softDeleteByKey(userId, k.trim());
      }
    }

    if (categories == null || categories.isEmpty()) {
      return CategorySyncResult.success(categoryInfoMapper.findAllByUserId(userId));
    }

    Set<String> keys =
        categories.stream()
            .map(CategoryInfo::getCategoryKey)
            .filter(k -> k != null && !k.trim().isEmpty())
            .collect(Collectors.toSet());
    Map<String, CategoryInfo> existingByKey =
        keys.isEmpty()
            ? new HashMap<>()
            : categoryInfoMapper.findByUserIdAndKeys(userId, keys).stream()
                .collect(Collectors.toMap(CategoryInfo::getCategoryKey, c -> c));

    for (CategoryInfo c : categories) {
      if (c == null) continue;
      c.setUserId(userId);
      if (c.getIsDelete() == null) c.setIsDelete(0);
      CategoryInfo existing = c.getCategoryKey() == null ? null : existingByKey.get(c.getCategoryKey());
      if (existing != null) {
        c.setId(existing.getId());
        if (existing.getSyncVersion() != null && c.getSyncVersion() == null) {
          return CategorySyncResult.error("missing syncVersion");
        }
        if (existing.getSyncVersion() != null) {
          // No-op optimization: avoid touching rows when nothing changed.
          boolean unchanged =
              Objects.equals(existing.getName(), c.getName())
                  && Objects.equals(existing.getIconCodePoint(), c.getIconCodePoint())
                  && Objects.equals(existing.getIconFontFamily(), c.getIconFontFamily())
                  && Objects.equals(existing.getIconFontPackage(), c.getIconFontPackage())
                  && Objects.equals(existing.getIsExpense(), c.getIsExpense())
                  && Objects.equals(existing.getParentKey(), c.getParentKey())
                  && Objects.equals(existing.getIsDelete(), c.getIsDelete());
          if (unchanged) {
            continue;
          }

          Long expected = existing.getSyncVersion();
          if (c.getSyncVersion() != null) {
            if (!existing.getSyncVersion().equals(c.getSyncVersion())) {
              return CategorySyncResult.error("category conflict");
            }
            expected = c.getSyncVersion();
          } else {
            // Backward-compat: fall back to update_time
            if (existing.getUpdateTime() != null && c.getUpdateTime() != null && existing.getUpdateTime().isAfter(c.getUpdateTime())) {
              continue;
            }
          }
          int updated = categoryInfoMapper.updateWithExpectedSyncVersion(c, expected);
          if (updated <= 0) {
            return CategorySyncResult.error("category conflict");
          }
        }
      } else {
        // Batch insert after the loop to reduce SQL chatter on first sync.
        // Keep logic in one transaction; final return will re-query to get authoritative list.
      }
    }

    List<CategoryInfo> toInsert =
        categories.stream()
            .filter(Objects::nonNull)
            .filter(c -> c.getCategoryKey() != null && !c.getCategoryKey().trim().isEmpty())
            .filter(c -> !existingByKey.containsKey(c.getCategoryKey()))
            .peek(c -> {
              c.setUserId(userId);
              if (c.getIsDelete() == null) c.setIsDelete(0);
            })
            .collect(Collectors.toList());
    if (!toInsert.isEmpty()) {
      categoryInfoMapper.batchInsert(toInsert);
    }

    return CategorySyncResult.success(categoryInfoMapper.findAllByUserId(userId));
  }

  public CategorySyncResult downloadCategories(Long userId) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return CategorySyncResult.error(permissionError.getMessage());
    }
    return CategorySyncResult.success(categoryInfoMapper.findAllByUserId(userId));
  }

  @Transactional
  public TagSyncResult uploadTags(Long userId, String bookId, List<TagInfo> tags, List<String> deletedTagIds) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return TagSyncResult.error(permissionError.getMessage());
    }
    if (bookId == null || bookId.trim().isEmpty()) {
      return TagSyncResult.error("missing bookId");
    }

    if (deletedTagIds != null) {
      for (String tid : deletedTagIds) {
        if (tid == null || tid.trim().isEmpty()) continue;
        tagInfoMapper.softDeleteByTagId(userId, bookId, tid.trim());
      }
    }

    if (tags == null || tags.isEmpty()) {
      return TagSyncResult.success(tagInfoMapper.findAllByUserIdAndBookId(userId, bookId));
    }

    Set<String> incomingIds =
        tags.stream()
            .map(TagInfo::getTagId)
            .filter(id -> id != null && !id.trim().isEmpty())
            .collect(Collectors.toSet());
    Map<String, TagInfo> existingByTagId =
        incomingIds.isEmpty()
            ? new HashMap<>()
            : tagInfoMapper.findByUserIdBookIdAndTagIds(userId, bookId, incomingIds).stream()
                .collect(Collectors.toMap(TagInfo::getTagId, t -> t));

    for (TagInfo t : tags) {
      if (t == null) continue;
      t.setUserId(userId);
      t.setBookId(bookId);
      if (t.getIsDelete() == null) t.setIsDelete(0);
      TagInfo existing = t.getTagId() == null ? null : existingByTagId.get(t.getTagId());
      if (existing != null) {
        t.setId(existing.getId());
        if (existing.getSyncVersion() != null && t.getSyncVersion() == null) {
          return TagSyncResult.error("missing syncVersion");
        }
        if (existing.getSyncVersion() != null) {
          // No-op optimization: avoid touching rows when nothing changed.
          boolean unchanged =
              Objects.equals(existing.getName(), t.getName())
                  && Objects.equals(existing.getColor(), t.getColor())
                  && Objects.equals(existing.getSortOrder(), t.getSortOrder())
                  && Objects.equals(existing.getIsDelete(), t.getIsDelete());
          if (unchanged) {
            continue;
          }

          Long expected = existing.getSyncVersion();
          if (t.getSyncVersion() != null) {
            if (!existing.getSyncVersion().equals(t.getSyncVersion())) {
              return TagSyncResult.error("tag conflict");
            }
            expected = t.getSyncVersion();
          } else {
            if (existing.getUpdateTime() != null && t.getUpdateTime() != null && existing.getUpdateTime().isAfter(t.getUpdateTime())) {
              continue;
            }
          }
          int updated = tagInfoMapper.updateWithExpectedSyncVersion(t, expected);
          if (updated <= 0) {
            return TagSyncResult.error("tag conflict");
          }
        }
      } else {
        // Batch insert after the loop to reduce SQL chatter on first sync.
      }
    }

    List<TagInfo> toInsert =
        tags.stream()
            .filter(Objects::nonNull)
            .filter(t -> t.getTagId() != null && !t.getTagId().trim().isEmpty())
            .filter(t -> !existingByTagId.containsKey(t.getTagId()))
            .peek(t -> {
              t.setUserId(userId);
              t.setBookId(bookId);
              if (t.getIsDelete() == null) t.setIsDelete(0);
            })
            .collect(Collectors.toList());
    if (!toInsert.isEmpty()) {
      tagInfoMapper.batchInsert(toInsert);
    }

    return TagSyncResult.success(tagInfoMapper.findAllByUserIdAndBookId(userId, bookId));
  }

  public TagSyncResult downloadTags(Long userId, String bookId) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return TagSyncResult.error(permissionError.getMessage());
    }
    if (bookId == null || bookId.trim().isEmpty()) {
      return TagSyncResult.error("missing bookId");
    }
    return TagSyncResult.success(tagInfoMapper.findAllByUserIdAndBookId(userId, bookId));
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

  public static class SavingsPlanSyncResult {
    private boolean success;
    private String error;
    private List<SavingsPlanInfo> plans;

    public static SavingsPlanSyncResult error(String error) {
      SavingsPlanSyncResult result = new SavingsPlanSyncResult();
      result.success = false;
      result.error = error;
      return result;
    }

    public static SavingsPlanSyncResult success(List<SavingsPlanInfo> plans) {
      SavingsPlanSyncResult result = new SavingsPlanSyncResult();
      result.success = true;
      result.plans = plans;
      return result;
    }

    public boolean isSuccess() {
      return success;
    }

    public String getError() {
      return error;
    }

    public List<SavingsPlanInfo> getPlans() {
      return plans;
    }
  }

  public static class CategorySyncResult {
    private boolean success;
    private String error;
    private List<CategoryInfo> categories;

    public static CategorySyncResult error(String error) {
      CategorySyncResult result = new CategorySyncResult();
      result.success = false;
      result.error = error;
      return result;
    }

    public static CategorySyncResult success(List<CategoryInfo> categories) {
      CategorySyncResult result = new CategorySyncResult();
      result.success = true;
      result.categories = categories;
      return result;
    }

    public boolean isSuccess() {
      return success;
    }

    public String getError() {
      return error;
    }

    public List<CategoryInfo> getCategories() {
      return categories;
    }
  }

  public static class TagSyncResult {
    private boolean success;
    private String error;
    private List<TagInfo> tags;

    public static TagSyncResult error(String error) {
      TagSyncResult result = new TagSyncResult();
      result.success = false;
      result.error = error;
      return result;
    }

    public static TagSyncResult success(List<TagInfo> tags) {
      TagSyncResult result = new TagSyncResult();
      result.success = true;
      result.tags = tags;
      return result;
    }

    public boolean isSuccess() {
      return success;
    }

    public String getError() {
      return error;
    }

    public List<TagInfo> getTags() {
      return tags;
    }
  }
}
