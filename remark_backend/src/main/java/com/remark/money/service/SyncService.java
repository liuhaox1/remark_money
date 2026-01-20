package com.remark.money.service;

import com.remark.money.common.ErrorCode;
import com.remark.money.entity.AccountInfo;
import com.remark.money.entity.BudgetInfo;
import com.remark.money.entity.CategoryInfo;
import com.remark.money.entity.Book;
import com.remark.money.entity.BookMember;
import com.remark.money.entity.RecurringPlanInfo;
import com.remark.money.entity.SavingsPlanInfo;
import com.remark.money.entity.TagInfo;
import com.remark.money.entity.User;
import com.remark.money.mapper.AccountInfoMapper;
import com.remark.money.mapper.BudgetInfoMapper;
import com.remark.money.mapper.CategoryInfoMapper;
import com.remark.money.mapper.BookMapper;
import com.remark.money.mapper.BookMemberMapper;
import com.remark.money.mapper.RecurringPlanInfoMapper;
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
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class SyncService {

  private static final Logger log = LoggerFactory.getLogger(SyncService.class);

  private static final String DEFAULT_WALLET_ACCOUNT_ID = "default_wallet";
  private static final String DEFAULT_WALLET_NAME = "默认钱包";
  private static final String DEFAULT_BOOK_ID = "default-book";

	  private String requireBookId(String bookIdRaw) {
	    if (bookIdRaw == null) throw new IllegalArgumentException("missing bookId");
	    String s = bookIdRaw.trim();
	    if (s.isEmpty()) throw new IllegalArgumentException("missing bookId");
	    return s;
	  }

	  private static class ServerBookAccess {
	    final boolean isServerBook;
	    final boolean ok;
	    final String error;
	    final Book book;

	    ServerBookAccess(boolean isServerBook, boolean ok, String error, Book book) {
	      this.isServerBook = isServerBook;
	      this.ok = ok;
	      this.error = error;
	      this.book = book;
	    }
	  }

	  /**
	   * If bookId is numeric and exists in {@code book} table, require active membership.
	   * Non-numeric bookIds are treated as local/personal scopes (no server membership to check).
	   */
	  private ServerBookAccess checkServerBookAccess(Long userId, String bookIdRaw) {
	    final String bookId = requireBookId(bookIdRaw);
	    final Long bid;
	    try {
	      bid = Long.parseLong(bookId);
	    } catch (NumberFormatException e) {
	      return new ServerBookAccess(false, true, null, null);
	    }
	    Book book = bookMapper.findById(bid);
	    if (book == null) {
	      return new ServerBookAccess(true, false, "book not found", null);
	    }
	    BookMember member = bookMemberMapper.find(bid, userId);
	    if (member == null || member.getStatus() == null || member.getStatus() != 1) {
	      return new ServerBookAccess(true, false, "no permission", book);
	    }
	    return new ServerBookAccess(true, true, null, book);
	  }

	  private String defaultWalletAccountIdForBook(String bookIdRaw) {
	    String bookId = requireBookId(bookIdRaw);
	    if (DEFAULT_BOOK_ID.equals(bookId)) return DEFAULT_WALLET_ACCOUNT_ID;
	    return DEFAULT_WALLET_ACCOUNT_ID + "_" + bookId;
	  }

  private static class EffectiveBookScope {
    final Long effectiveUserId;
    final String bookId;
    final boolean isMulti;
    EffectiveBookScope(Long effectiveUserId, String bookId, boolean isMulti) {
      this.effectiveUserId = effectiveUserId;
      this.bookId = bookId;
      this.isMulti = isMulti;
    }
  }

  private EffectiveBookScope resolveEffectiveBookScopeForAccounts(
      Long userId, String bookIdRaw, boolean requireOwnerForWrite) {
    String bookId = requireBookId(bookIdRaw);
    // Non-server book ids (e.g. default-book or local UUID) are treated as personal scope.
    Long effectiveUserId = userId;
    boolean isMulti = false;
    try {
      Long bid = Long.parseLong(bookId);
      Book book = bookMapper.findById(bid);
      if (book == null) {
        log.warn("resolveEffectiveBookScopeForAccounts missing book userId={} bookId={}", userId, bookId);
        return null;
      }
      BookMember member = bookMemberMapper.find(bid, userId);
      if (member == null) {
        log.warn("resolveEffectiveBookScopeForAccounts no member userId={} bookId={}", userId, bookId);
        return null;
      }
      isMulti = Boolean.TRUE.equals(book.getIsMulti());
      if (isMulti) {
        effectiveUserId = book.getOwnerId();
        if (requireOwnerForWrite && !Objects.equals(userId, effectiveUserId)) {
          log.warn("resolveEffectiveBookScopeForAccounts not owner userId={} ownerId={} bookId={}", userId, effectiveUserId, bookId);
          return null;
        }
      }
    } catch (NumberFormatException ignored) {
      // not a server book id
    }
    return new EffectiveBookScope(effectiveUserId, bookId, isMulti);
  }

  private final UserMapper userMapper;
  private final AccountInfoMapper accountInfoMapper;
  private final BudgetInfoMapper budgetInfoMapper;
  private final CategoryInfoMapper categoryInfoMapper;
  private final TagInfoMapper tagInfoMapper;
  private final SavingsPlanInfoMapper savingsPlanInfoMapper;
  private final RecurringPlanInfoMapper recurringPlanInfoMapper;
  private final BookMapper bookMapper;
  private final BookMemberMapper bookMemberMapper;

  public SyncService(UserMapper userMapper,
                     AccountInfoMapper accountInfoMapper,
                     BudgetInfoMapper budgetInfoMapper,
                     CategoryInfoMapper categoryInfoMapper,
                     TagInfoMapper tagInfoMapper,
                     SavingsPlanInfoMapper savingsPlanInfoMapper,
                     RecurringPlanInfoMapper recurringPlanInfoMapper,
                     BookMapper bookMapper,
                     BookMemberMapper bookMemberMapper) {
    this.userMapper = userMapper;
    this.accountInfoMapper = accountInfoMapper;
    this.budgetInfoMapper = budgetInfoMapper;
    this.categoryInfoMapper = categoryInfoMapper;
    this.tagInfoMapper = tagInfoMapper;
    this.savingsPlanInfoMapper = savingsPlanInfoMapper;
    this.recurringPlanInfoMapper = recurringPlanInfoMapper;
    this.bookMapper = bookMapper;
    this.bookMemberMapper = bookMemberMapper;
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

  private boolean isDefaultWallet(AccountInfo a) {
    if (a == null) return false;
    String aid = a.getAccountId();
    if (aid != null) {
      String s = aid.trim();
      if (DEFAULT_WALLET_ACCOUNT_ID.equals(s)) return true;
      if (s.startsWith(DEFAULT_WALLET_ACCOUNT_ID + "_")) return true;
    }
    if (DEFAULT_WALLET_ACCOUNT_ID.equals(a.getBrandKey())) return true;
    String name = a.getName();
    return name != null && DEFAULT_WALLET_NAME.equals(name.trim());
  }

  private AccountInfo buildDefaultWallet(Long userId, String bookId) {
    AccountInfo a = new AccountInfo();
    a.setUserId(userId);
    a.setBookId(bookId);
    a.setAccountId(defaultWalletAccountIdForBook(bookId));
    a.setName(DEFAULT_WALLET_NAME);
    a.setKind("asset");
    a.setSubtype("cash");
    a.setType("cash");
    a.setIcon("wallet");
    a.setIncludeInTotal(1);
    a.setIncludeInOverview(1);
    a.setCurrency("CNY");
    a.setSortOrder(-100);
    a.setInitialBalance(BigDecimal.ZERO);
    a.setCurrentBalance(BigDecimal.ZERO);
    a.setBrandKey(DEFAULT_WALLET_ACCOUNT_ID);
    a.setIsDelete(0);
    return a;
  }

  private void ensureDefaultWalletExists(Long userId, String bookId, List<AccountInfo> allAccounts) {
    if (allAccounts != null) {
      for (AccountInfo a : allAccounts) {
        if (a != null && defaultWalletAccountIdForBook(bookId).equals(a.getAccountId())) {
          if (a.getIsDelete() != null && a.getIsDelete() == 1) {
            restoreDefaultWallet(a);
          }
          return;
        }
      }
    }

    AccountInfo created = buildDefaultWallet(userId, bookId);
    accountInfoMapper.insert(created);
    if (allAccounts != null) {
      allAccounts.add(created);
    }
  }

  private void restoreDefaultWallet(AccountInfo existing) {
    existing.setIsDelete(0);
    if (existing.getName() == null || existing.getName().trim().isEmpty()) {
      existing.setName(DEFAULT_WALLET_NAME);
    }
    if (existing.getKind() == null || existing.getKind().trim().isEmpty()) {
      existing.setKind("asset");
    }
    if (existing.getSubtype() == null || existing.getSubtype().trim().isEmpty()) {
      existing.setSubtype("cash");
    }
    if (existing.getType() == null || existing.getType().trim().isEmpty()) {
      existing.setType("cash");
    }
    if (existing.getIcon() == null || existing.getIcon().trim().isEmpty()) {
      existing.setIcon("wallet");
    }
    if (existing.getIncludeInTotal() == null) existing.setIncludeInTotal(1);
    if (existing.getIncludeInOverview() == null) existing.setIncludeInOverview(1);
    if (existing.getCurrency() == null || existing.getCurrency().trim().isEmpty()) {
      existing.setCurrency("CNY");
    }
    if (existing.getSortOrder() == null) existing.setSortOrder(-100);
    if (existing.getInitialBalance() == null) existing.setInitialBalance(BigDecimal.ZERO);
    if (existing.getCurrentBalance() == null) existing.setCurrentBalance(BigDecimal.ZERO);
    if (existing.getBrandKey() == null || existing.getBrandKey().trim().isEmpty()) {
      existing.setBrandKey(DEFAULT_WALLET_ACCOUNT_ID);
    }
    accountInfoMapper.updateById(existing);
  }

  private List<AccountInfo> filterActiveAccounts(List<AccountInfo> allAccounts) {
    if (allAccounts == null) return new ArrayList<>();
    return allAccounts.stream()
        .filter(a -> a.getIsDelete() == null || a.getIsDelete() == 0)
        .collect(Collectors.toList());
  }

  /**
   * 上传账户数据（幂等：按 serverId 或 accountId 匹配）
   */
  @Transactional
  public AccountSyncResult uploadAccounts(Long userId, List<AccountInfo> accounts) {
    throw new IllegalArgumentException("missing bookId");
  }

  @Transactional
  public AccountSyncResult uploadAccounts(Long userId, String bookIdRaw, List<AccountInfo> accounts) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return AccountSyncResult.error(permissionError.getMessage());
    }

    EffectiveBookScope scope = resolveEffectiveBookScopeForAccounts(userId, bookIdRaw, true);
    if (scope == null) {
      return AccountSyncResult.error("no permission");
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
            : accountInfoMapper.findByUserIdAndIds(scope.effectiveUserId, incomingIds).stream()
                .collect(Collectors.toMap(AccountInfo::getId, a -> a));

    Set<String> incomingAccountIds =
        accounts.stream()
            .map(AccountInfo::getAccountId)
            .filter(id -> id != null && !id.trim().isEmpty())
            .collect(Collectors.toSet());
    Map<String, AccountInfo> existingByAccountId =
        incomingAccountIds.isEmpty()
            ? new HashMap<>()
            : accountInfoMapper
                .findByUserIdAndBookIdAndAccountIds(scope.effectiveUserId, scope.bookId, incomingAccountIds)
                .stream()
                .collect(Collectors.toMap(AccountInfo::getAccountId, a -> a));

    for (AccountInfo account : accounts) {
      account.setUserId(scope.effectiveUserId);
      account.setBookId(scope.bookId);
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

    List<AccountInfo> accountsFromDb =
        accountInfoMapper.findAllByUserIdAndBookIdIncludingDeleted(scope.effectiveUserId, scope.bookId);
    ensureDefaultWalletExists(scope.effectiveUserId, scope.bookId, accountsFromDb);
    return AccountSyncResult.success(filterActiveAccounts(accountsFromDb));
  }

  /**
   * 下载账户数据
   */
  public AccountSyncResult downloadAccounts(Long userId) {
    throw new IllegalArgumentException("missing bookId");
  }

  public AccountSyncResult downloadAccounts(Long userId, String bookIdRaw) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return AccountSyncResult.error(permissionError.getMessage());
    }

    EffectiveBookScope scope = resolveEffectiveBookScopeForAccounts(userId, bookIdRaw, false);
    if (scope == null) {
      return AccountSyncResult.success(Collections.emptyList());
    }
    List<AccountInfo> accounts =
        accountInfoMapper.findAllByUserIdAndBookIdIncludingDeleted(scope.effectiveUserId, scope.bookId);
    ensureDefaultWalletExists(scope.effectiveUserId, scope.bookId, accounts);
    return AccountSyncResult.success(filterActiveAccounts(accounts));
  }

  @Transactional
  public AccountSyncResult deleteAccounts(Long userId, List<Long> serverIds, List<String> accountIds) {
    throw new IllegalArgumentException("missing bookId");
  }

  @Transactional
  public AccountSyncResult deleteAccounts(
      Long userId, String bookIdRaw, List<Long> serverIds, List<String> accountIds) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return AccountSyncResult.error(permissionError.getMessage());
    }

    EffectiveBookScope scope = resolveEffectiveBookScopeForAccounts(userId, bookIdRaw, true);
    if (scope == null) {
      return AccountSyncResult.error("no permission");
    }

    int affected = 0;
    if (serverIds != null) {
      for (Long id : serverIds) {
        if (id == null || id <= 0) continue;
        affected += accountInfoMapper.softDeleteById(scope.effectiveUserId, scope.bookId, id);
      }
    }
    if (accountIds != null) {
      for (String aid : accountIds) {
        if (aid == null || aid.trim().isEmpty()) continue;
        affected += accountInfoMapper.softDeleteByAccountId(scope.effectiveUserId, scope.bookId, aid.trim());
      }
    }

    // return latest server view (non-deleted) for client reconciliation if needed
    List<AccountInfo> accounts =
        accountInfoMapper.findAllByUserIdAndBookIdIncludingDeleted(scope.effectiveUserId, scope.bookId);
    ensureDefaultWalletExists(scope.effectiveUserId, scope.bookId, accounts);
    return AccountSyncResult.success(filterActiveAccounts(accounts));
  }

  @Transactional
	  public BudgetSyncResult uploadBudget(Long userId, String bookId, BudgetInfo budget) {
	    ErrorCode permissionError = checkSyncPermission(userId);
	    if (permissionError.isError()) {
	      return BudgetSyncResult.error(permissionError.getMessage());
	    }
	    final String bid = (bookId == null) ? null : bookId.trim();
	    if (bid == null || bid.isEmpty()) return BudgetSyncResult.error("missing bookId");

	    final ServerBookAccess access = checkServerBookAccess(userId, bid);
	    if (!access.ok) return BudgetSyncResult.error(access.error);

	    // Shared (multi-member) server book budgets are book-scoped, not per-member.
	    final Long effectiveUserId =
	        access.book != null && Boolean.TRUE.equals(access.book.getIsMulti()) && access.book.getOwnerId() != null
	            ? access.book.getOwnerId()
	            : userId;
	    if (budget == null) {
	      return BudgetSyncResult.error("missing budget");
	    }
	    budget.setUserId(effectiveUserId);
	    budget.setBookId(bid);
	    if (budget.getTotal() == null) budget.setTotal(BigDecimal.ZERO);
	    if (budget.getAnnualTotal() == null) budget.setAnnualTotal(BigDecimal.ZERO);
	    if (budget.getPeriodStartDay() == null) budget.setPeriodStartDay(1);

	    BudgetInfo existing = budgetInfoMapper.findByUserIdAndBookId(effectiveUserId, bid);
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
	    final String bid = (bookId == null) ? null : bookId.trim();
	    if (bid == null || bid.isEmpty()) return BudgetSyncResult.error("missing bookId");

	    final ServerBookAccess access = checkServerBookAccess(userId, bid);
	    if (!access.ok) return BudgetSyncResult.error(access.error);

	    final Long effectiveUserId =
	        access.book != null && Boolean.TRUE.equals(access.book.getIsMulti()) && access.book.getOwnerId() != null
	            ? access.book.getOwnerId()
	            : userId;
	    BudgetInfo budget = budgetInfoMapper.findByUserIdAndBookId(effectiveUserId, bid);
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
	    final ServerBookAccess access = checkServerBookAccess(userId, bookId);
	    if (!access.ok) return SavingsPlanSyncResult.error(access.error);

	    if (deletedPlanIds != null) {
	      for (String pid : deletedPlanIds) {
	        if (pid == null || pid.trim().isEmpty()) continue;
        savingsPlanInfoMapper.softDeleteByPlanId(userId, bookId, pid.trim());
      }
    }

    Map<String, SavingsPlanInfo> existingByPlanId = new HashMap<>();
    if (plans != null && !plans.isEmpty()) {
      Set<String> planIds =
          plans.stream()
              .filter(Objects::nonNull)
              .map(SavingsPlanInfo::getPlanId)
              .filter(Objects::nonNull)
              .map(String::trim)
              .filter(s -> !s.isEmpty())
              .collect(Collectors.toSet());
      if (!planIds.isEmpty()) {
        existingByPlanId =
            savingsPlanInfoMapper.findByUserIdBookIdAndPlanIds(userId, bookId, planIds).stream()
                .filter(Objects::nonNull)
                .filter(p -> p.getPlanId() != null && !p.getPlanId().trim().isEmpty())
                .collect(
                    Collectors.toMap(
                        p -> p.getPlanId().trim(),
                        p -> p,
                        (a, b) -> a));
      }
    }

    if (plans != null) {
      for (SavingsPlanInfo p : plans) {
        if (p == null) continue;
        if (p.getPlanId() == null || p.getPlanId().trim().isEmpty()) {
          return SavingsPlanSyncResult.error("missing planId");
        }
        p.setPlanId(p.getPlanId().trim());
        p.setUserId(userId);
        p.setBookId(bookId);
        if (p.getIsDelete() == null) p.setIsDelete(0);
        if (p.getPayloadJson() == null) {
          return SavingsPlanSyncResult.error("missing payload");
        }

        SavingsPlanInfo existing = existingByPlanId.get(p.getPlanId());
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
	    final ServerBookAccess access = checkServerBookAccess(userId, bookId);
	    if (!access.ok) return SavingsPlanSyncResult.error(access.error);
	    return SavingsPlanSyncResult.success(
	        savingsPlanInfoMapper.findAllByUserIdAndBookId(userId, bookId));
	  }

  @Transactional
  public RecurringPlanSyncResult uploadRecurringPlans(
      Long userId, String bookId, List<RecurringPlanInfo> plans, List<String> deletedPlanIds) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return RecurringPlanSyncResult.error(permissionError.getMessage());
    }
    if (bookId == null || bookId.trim().isEmpty()) {
      return RecurringPlanSyncResult.error("missing bookId");
    }
    final ServerBookAccess access = checkServerBookAccess(userId, bookId);
    if (!access.ok) return RecurringPlanSyncResult.error(access.error);

    if (deletedPlanIds != null) {
      for (String pid : deletedPlanIds) {
        if (pid == null || pid.trim().isEmpty()) continue;
        recurringPlanInfoMapper.softDeleteByPlanId(userId, bookId, pid.trim());
      }
    }

    Map<String, RecurringPlanInfo> existingByPlanId = new HashMap<>();
    if (plans != null && !plans.isEmpty()) {
      Set<String> planIds =
          plans.stream()
              .filter(Objects::nonNull)
              .map(RecurringPlanInfo::getPlanId)
              .filter(Objects::nonNull)
              .map(String::trim)
              .filter(s -> !s.isEmpty())
              .collect(Collectors.toSet());
      if (!planIds.isEmpty()) {
        existingByPlanId =
            recurringPlanInfoMapper.findByUserIdBookIdAndPlanIds(userId, bookId, planIds).stream()
                .filter(Objects::nonNull)
                .filter(p -> p.getPlanId() != null && !p.getPlanId().trim().isEmpty())
                .collect(
                    Collectors.toMap(
                        p -> p.getPlanId().trim(),
                        p -> p,
                        (a, b) -> a));
      }
    }

    if (plans != null) {
      for (RecurringPlanInfo p : plans) {
        if (p == null) continue;
        if (p.getPlanId() == null || p.getPlanId().trim().isEmpty()) {
          return RecurringPlanSyncResult.error("missing planId");
        }
        p.setPlanId(p.getPlanId().trim());
        p.setUserId(userId);
        p.setBookId(bookId);
        if (p.getIsDelete() == null) p.setIsDelete(0);
        if (p.getPayloadJson() == null) {
          return RecurringPlanSyncResult.error("missing payload");
        }

        RecurringPlanInfo existing = existingByPlanId.get(p.getPlanId());
        if (existing == null) {
          recurringPlanInfoMapper.insertOne(p);
          continue;
        }

        if (existing.getSyncVersion() != null && p.getSyncVersion() == null) {
          return RecurringPlanSyncResult.error("missing syncVersion");
        }
        if (existing.getSyncVersion() != null) {
          if (!existing.getSyncVersion().equals(p.getSyncVersion())) {
            return RecurringPlanSyncResult.error("recurring_plan conflict");
          }
          int updated =
              recurringPlanInfoMapper.updateWithExpectedSyncVersion(p, p.getSyncVersion());
          if (updated <= 0) {
            return RecurringPlanSyncResult.error("recurring_plan conflict");
          }
        } else {
          return RecurringPlanSyncResult.error("server recurring_plan missing syncVersion");
        }
      }
    }

    return RecurringPlanSyncResult.success(
        recurringPlanInfoMapper.findAllByUserIdAndBookId(userId, bookId));
  }

  public RecurringPlanSyncResult downloadRecurringPlans(Long userId, String bookId) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return RecurringPlanSyncResult.error(permissionError.getMessage());
    }
    if (bookId == null || bookId.trim().isEmpty()) {
      return RecurringPlanSyncResult.error("missing bookId");
    }
    final ServerBookAccess access = checkServerBookAccess(userId, bookId);
    if (!access.ok) return RecurringPlanSyncResult.error(access.error);
    return RecurringPlanSyncResult.success(
        recurringPlanInfoMapper.findAllByUserIdAndBookId(userId, bookId));
  }

	  @Transactional
	  public CategorySyncResult uploadCategories(Long userId, List<CategoryInfo> categories, List<String> deletedKeys) {
	    throw new IllegalArgumentException("missing bookId");
	  }

	  @Transactional
	  public CategorySyncResult uploadCategories(
	      Long userId, String bookIdRaw, List<CategoryInfo> categories, List<String> deletedKeys) {
	    ErrorCode permissionError = checkSyncPermission(userId);
	    if (permissionError.isError()) {
	      return CategorySyncResult.error(permissionError.getMessage());
	    }
	    if (bookIdRaw == null || bookIdRaw.trim().isEmpty()) {
	      return CategorySyncResult.error("missing bookId");
	    }
	    final ServerBookAccess access = checkServerBookAccess(userId, bookIdRaw);
	    if (!access.ok) return CategorySyncResult.error(access.error);

	    Long effectiveUserId = userId;
    if (bookIdRaw != null && !bookIdRaw.trim().isEmpty()) {
      try {
        Long bookId = Long.parseLong(bookIdRaw.trim());
        Book book = bookMapper.findById(bookId);
        if (book != null && Boolean.TRUE.equals(book.getIsMulti())) {
          // Multi-book categories are owned by the creator and only editable by owner.
          if (book.getOwnerId() == null || !book.getOwnerId().equals(userId)) {
            return CategorySyncResult.error("permission denied");
          }
          effectiveUserId = book.getOwnerId();
        }
      } catch (Exception ignored) {
        // Non-numeric bookId or lookup failed: fall back to user-scoped categories.
      }
    }

    if (deletedKeys != null) {
      for (String k : deletedKeys) {
        if (k == null || k.trim().isEmpty()) continue;
        categoryInfoMapper.softDeleteByKey(effectiveUserId, k.trim());
      }
    }

    if (categories == null || categories.isEmpty()) {
      return CategorySyncResult.success(categoryInfoMapper.findAllByUserId(effectiveUserId));
    }

    boolean noDeleted = deletedKeys == null || deletedKeys.isEmpty();
    boolean allMissingSync =
        categories.stream()
            .filter(Objects::nonNull)
            .allMatch(c -> c.getSyncVersion() == null || c.getSyncVersion() <= 0);
    Integer existingCount = categoryInfoMapper.countByUserId(effectiveUserId);
    if (noDeleted && allMissingSync && (existingCount == null || existingCount <= 0)) {
      final Long insertUserId = effectiveUserId;
      List<CategoryInfo> toInsert =
          categories.stream()
              .filter(Objects::nonNull)
              .filter(c -> c.getCategoryKey() != null && !c.getCategoryKey().trim().isEmpty())
              .peek(c -> {
                c.setUserId(insertUserId);
                if (c.getIsDelete() == null) c.setIsDelete(0);
                if (c.getSyncVersion() == null || c.getSyncVersion() <= 0) {
                  c.setSyncVersion(1L);
                }
              })
              .collect(Collectors.toList());
      if (!toInsert.isEmpty()) {
        categoryInfoMapper.batchInsert(toInsert);
      }
      return CategorySyncResult.success(toInsert);
    }

    Set<String> keys =
        categories.stream()
            .map(CategoryInfo::getCategoryKey)
            .filter(k -> k != null && !k.trim().isEmpty())
            .collect(Collectors.toSet());
    Map<String, CategoryInfo> existingByKey =
        keys.isEmpty()
            ? new HashMap<>()
            : categoryInfoMapper.findByUserIdAndKeys(effectiveUserId, keys).stream()
                .collect(Collectors.toMap(CategoryInfo::getCategoryKey, c -> c));

    for (CategoryInfo c : categories) {
      if (c == null) continue;
      c.setUserId(effectiveUserId);
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

    final Long insertUserId = effectiveUserId;
    List<CategoryInfo> toInsert =
        categories.stream()
            .filter(Objects::nonNull)
            .filter(c -> c.getCategoryKey() != null && !c.getCategoryKey().trim().isEmpty())
            .filter(c -> !existingByKey.containsKey(c.getCategoryKey()))
            .peek(c -> {
              c.setUserId(insertUserId);
              if (c.getIsDelete() == null) c.setIsDelete(0);
            })
            .collect(Collectors.toList());
    if (!toInsert.isEmpty()) {
      categoryInfoMapper.batchInsert(toInsert);
    }

    return CategorySyncResult.success(categoryInfoMapper.findAllByUserId(effectiveUserId));
  }

	  public CategorySyncResult downloadCategories(Long userId) {
	    throw new IllegalArgumentException("missing bookId");
	  }

	  public CategorySyncResult downloadCategories(Long userId, String bookIdRaw) {
	    ErrorCode permissionError = checkSyncPermission(userId);
	    if (permissionError.isError()) {
	      return CategorySyncResult.error(permissionError.getMessage());
	    }
	    if (bookIdRaw == null || bookIdRaw.trim().isEmpty()) {
	      return CategorySyncResult.error("missing bookId");
	    }
	    final ServerBookAccess access = checkServerBookAccess(userId, bookIdRaw);
	    if (!access.ok) return CategorySyncResult.error(access.error);

	    Long effectiveUserId = userId;
	    if (access.book != null && Boolean.TRUE.equals(access.book.getIsMulti())) {
	      if (access.book.getOwnerId() != null) {
	        effectiveUserId = access.book.getOwnerId();
	      }
	    }
	    return CategorySyncResult.success(categoryInfoMapper.findAllByUserId(effectiveUserId));
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
	    final ServerBookAccess access = checkServerBookAccess(userId, bookId);
	    if (!access.ok) return TagSyncResult.error(access.error);

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
	    final ServerBookAccess access = checkServerBookAccess(userId, bookId);
	    if (!access.ok) return TagSyncResult.error(access.error);
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

  public static class RecurringPlanSyncResult {
    private boolean success;
    private String error;
    private List<RecurringPlanInfo> plans;

    public static RecurringPlanSyncResult error(String error) {
      RecurringPlanSyncResult result = new RecurringPlanSyncResult();
      result.success = false;
      result.error = error;
      return result;
    }

    public static RecurringPlanSyncResult success(List<RecurringPlanInfo> plans) {
      RecurringPlanSyncResult result = new RecurringPlanSyncResult();
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

    public List<RecurringPlanInfo> getPlans() {
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
