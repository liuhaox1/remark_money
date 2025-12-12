package com.remark.money.service;

import com.remark.money.common.ErrorCode;
import com.remark.money.common.QuotaResult;
import com.remark.money.entity.AccountInfo;
import com.remark.money.entity.BillInfo;
import com.remark.money.entity.SyncRecord;
import com.remark.money.entity.User;
import com.remark.money.mapper.AccountInfoMapper;
import com.remark.money.mapper.BillInfoMapper;
import com.remark.money.mapper.BookMemberMapper;
import com.remark.money.mapper.SyncRecordMapper;
import com.remark.money.mapper.UserMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
public class SyncService {

  private static final Logger log = LoggerFactory.getLogger(SyncService.class);

  private final UserMapper userMapper;
  private final BillInfoMapper billInfoMapper;
  private final SyncRecordMapper syncRecordMapper;
  private final AccountInfoMapper accountInfoMapper;
  private final BookMemberMapper bookMemberMapper;

  public SyncService(UserMapper userMapper, BillInfoMapper billInfoMapper, SyncRecordMapper syncRecordMapper, AccountInfoMapper accountInfoMapper, BookMemberMapper bookMemberMapper) {
    this.userMapper = userMapper;
    this.billInfoMapper = billInfoMapper;
    this.syncRecordMapper = syncRecordMapper;
    this.accountInfoMapper = accountInfoMapper;
    this.bookMemberMapper = bookMemberMapper;
  }

  /**
   * 权限校验：检查用户是否有云端同步权限
   * @return null=有权限, 非null=错误码
   */
  public ErrorCode checkSyncPermission(Long userId) {
    // 当前阶段不区分付费/免费，同步默认开放
    if (isSyncAlwaysEnabled()) return null;
    User user = userMapper.findById(userId);
    if (user == null) {
      return ErrorCode.USER_NOT_FOUND;
    }

    // 免费用户
    if (user.getPayType() == null || user.getPayType() == 0) {
      return ErrorCode.NO_SYNC_PERMISSION;
    }

    // 付费过期
    if (user.getPayExpire() != null && user.getPayExpire().isBefore(LocalDateTime.now())) {
      return ErrorCode.PAYMENT_EXPIRED;
    }

    return null; // 有权限
  }

  /**
   * 检查数据量是否超限
   * @return QuotaResult，包含错误码和消息参数
   */
  public QuotaResult checkQuotaLimit(Long userId, String bookId, int currentCount) {
    if (isSyncAlwaysEnabled()) return QuotaResult.success();
    User user = userMapper.findById(userId);
    if (user == null || user.getPayType() == null) {
      return QuotaResult.error(ErrorCode.USER_INFO_ERROR);
    }

    int limit;
    switch (user.getPayType()) {
      case 1: // 3元档
        limit = 10000;
        break;
      case 2: // 5元档
        limit = 50000;
        break;
      case 3: // 10元档
        return QuotaResult.success(); // 不限
      default:
        return QuotaResult.error(ErrorCode.PLAN_TYPE_ERROR);
    }

    if (currentCount >= limit) {
      return QuotaResult.error(ErrorCode.QUOTA_EXCEEDED, limit);
    }

    // 80% 预警
    if (currentCount >= limit * 0.8) {
      log.warn("User {} quota warning: {}/{}", userId, currentCount, limit);
      return QuotaResult.warning(ErrorCode.QUOTA_WARNING);
    }

    return QuotaResult.success();
  }

  private boolean isSyncAlwaysEnabled() {
    return true;
  }

  private boolean isServerBook(String bookId) {
    if (bookId == null) return false;
    try {
      Long.parseLong(bookId);
      return true;
    } catch (NumberFormatException e) {
      return false;
    }
  }

  private void assertBookMember(Long userId, String bookId) {
    if (!isServerBook(bookId)) return;
    Long bid = Long.parseLong(bookId);
    if (bookMemberMapper.find(bid, userId) == null) {
      throw new IllegalArgumentException("无权限访问该多人账本");
    }
  }

  private int countBills(Long userId, String bookId) {
    return isServerBook(bookId)
        ? billInfoMapper.countByBookId(bookId)
        : billInfoMapper.countByUserIdAndBookId(userId, bookId);
  }

  private Long findMaxBillId(Long userId, String bookId) {
    return isServerBook(bookId)
        ? billInfoMapper.findMaxIdByBookId(bookId)
        : billInfoMapper.findMaxIdByUserIdAndBookId(userId, bookId);
  }

  /**
   * 全量上传：批量Upsert账单
   */
  @Transactional
  public SyncResult fullUpload(Long userId, String bookId, String deviceId, List<BillInfo> bills, int batchNum, int totalBatches) {
    assertBookMember(userId, bookId);
    // 权限校验
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError != null) {
      return SyncResult.error(permissionError.getMessage());
    }

    // 统计当前云端账单数
    int currentCount = countBills(userId, bookId);

    // 检查超限（3元/5元用户）
    QuotaResult quotaResult = checkQuotaLimit(userId, bookId, currentCount);
    if (quotaResult.isError()) {
      return SyncResult.error(quotaResult.getMessage());
    }

    // 过滤转账记录并设置基础字段
    List<BillInfo> validBills = new java.util.ArrayList<>();
    for (BillInfo bill : bills) {
      if (bill.getIncludeInStats() != null && bill.getIncludeInStats() == 0) {
        continue; // 跳过转账记录
      }
      bill.setUserId(userId);
      bill.setBookId(bookId);
      bill.setIsDelete(0);
      validBills.add(bill);
    }

    if (validBills.isEmpty()) {
      return SyncResult.success(0, bills.size() - validBills.size(), 
          getSyncRecord(userId, bookId, deviceId), new java.util.ArrayList<>());
    }

    // 批量查询：收集所有需要查询的id
    List<Long> idsToQuery = new java.util.ArrayList<>();
    for (BillInfo bill : validBills) {
      if (bill.getId() != null) {
        idsToQuery.add(bill.getId());
      }
    }

    // 批量查询现有记录
    java.util.Map<Long, BillInfo> existingMap = new java.util.HashMap<>();
    if (!idsToQuery.isEmpty()) {
      List<BillInfo> existingBills = billInfoMapper.findByIds(idsToQuery);
      for (BillInfo existing : existingBills) {
        existingMap.put(existing.getId(), existing);
      }
    }

    // 分类处理：更新列表和插入列表
    List<BillInfo> toUpdate = new java.util.ArrayList<>();
    List<BillInfo> toInsert = new java.util.ArrayList<>();
    int skipCount = bills.size() - validBills.size(); // 转账记录数量
    Long maxId = null;

    for (BillInfo bill : validBills) {
      BillInfo existing = bill.getId() != null ? existingMap.get(bill.getId()) : null;
      if (existing != null && existing.getBookId() != null && !existing.getBookId().equals(bookId)) {
        existing = null;
      }
      if (existing != null && existing.getBookId() != null && !existing.getBookId().equals(bookId)) {
        existing = null;
      }
      
      if (existing != null) {
        // 冲突处理：服务器端时间为准
        if (existing.getUpdateTime() != null && bill.getUpdateTime() != null
            && existing.getUpdateTime().isAfter(bill.getUpdateTime())) {
          skipCount++;
          if (maxId == null || existing.getId() > maxId) {
            maxId = existing.getId();
          }
          continue;
        }
        // 需要更新
        bill.setUserId(existing.getUserId());
        bill.setUserId(existing.getUserId());
        bill.setId(existing.getId());
        toUpdate.add(bill);
        if (maxId == null || bill.getId() > maxId) {
          maxId = bill.getId();
        }
      } else {
        // 检查超限（新增时）
        if (quotaResult.isSuccess() || quotaResult.isWarning()) {
          QuotaResult newQuotaResult = checkQuotaLimit(userId, bookId, currentCount + toInsert.size() + 1);
          if (newQuotaResult.isError()) {
            skipCount++;
            continue;
          }
        }
        // 需要插入
        toInsert.add(bill);
      }
    }

    // 批量更新
    if (!toUpdate.isEmpty()) {
      billInfoMapper.batchUpdate(toUpdate);
    }

    // 批量插入
    if (!toInsert.isEmpty()) {
      billInfoMapper.batchInsert(toInsert);
      currentCount += toInsert.size();
    }

    // 合并处理结果
    List<BillInfo> processed = new java.util.ArrayList<>();
    processed.addAll(toUpdate);
    processed.addAll(toInsert);
    int successCount = processed.size();

    // 更新同步记录（最后一批时）
    if (batchNum == totalBatches) {
      int finalCount = countBills(userId, bookId);
      updateSyncRecord(userId, bookId, deviceId, maxId, LocalDateTime.now(), finalCount);
    }

    return SyncResult.success(successCount, skipCount, getSyncRecord(userId, bookId, deviceId), processed);
  }

  /**
   * 全量拉取：分批返回所有有效账单
   */
  public SyncResult fullDownload(Long userId, String bookId, String deviceId, int offset, int limit) {
    assertBookMember(userId, bookId);
    List<BillInfo> bills = isServerBook(bookId)
        ? billInfoMapper.findAllByBookId(bookId, offset, limit)
        : billInfoMapper.findAllByUserIdAndBookId(userId, bookId, offset, limit);
    SyncRecord syncRecord = getSyncRecord(userId, bookId, deviceId);

    return SyncResult.success(bills, syncRecord);
  }

  /**
   * 增量上传
   */
  @Transactional
  public SyncResult incrementalUpload(Long userId, String bookId, String deviceId, List<BillInfo> bills) {
    assertBookMember(userId, bookId);
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError != null) {
      return SyncResult.error(permissionError.getMessage());
    }

    int currentCount = countBills(userId, bookId);
    QuotaResult quotaResult = checkQuotaLimit(userId, bookId, currentCount);
    if (quotaResult.isError()) {
      return SyncResult.error(quotaResult.getMessage());
    }

    // 过滤转账记录并设置基础字段
    List<BillInfo> validBills = new java.util.ArrayList<>();
    for (BillInfo bill : bills) {
      if (bill.getIncludeInStats() != null && bill.getIncludeInStats() == 0) {
        continue; // 跳过转账记录
      }
      bill.setUserId(userId);
      bill.setBookId(bookId);
      bill.setIsDelete(bill.getIsDelete() != null ? bill.getIsDelete() : 0);
      validBills.add(bill);
    }

    if (validBills.isEmpty()) {
      return SyncResult.success(0, bills.size(), 
          getSyncRecord(userId, bookId, deviceId), new java.util.ArrayList<>());
    }

    // 批量查询：收集所有需要查询的id
    List<Long> idsToQuery = new java.util.ArrayList<>();
    for (BillInfo bill : validBills) {
      if (bill.getId() != null) {
        idsToQuery.add(bill.getId());
      }
    }

    // 批量查询现有记录
    java.util.Map<Long, BillInfo> existingMap = new java.util.HashMap<>();
    if (!idsToQuery.isEmpty()) {
      List<BillInfo> existingBills = billInfoMapper.findByIds(idsToQuery);
      for (BillInfo existing : existingBills) {
        existingMap.put(existing.getId(), existing);
      }
    }

    // 分类处理：更新列表和插入列表
    List<BillInfo> toUpdate = new java.util.ArrayList<>();
    List<BillInfo> toInsert = new java.util.ArrayList<>();
    int skipCount = bills.size() - validBills.size(); // 转账记录数量
    Long maxId = null;

    for (BillInfo bill : validBills) {
      BillInfo existing = bill.getId() != null ? existingMap.get(bill.getId()) : null;
      
      if (existing != null) {
        // 冲突处理：服务器端时间为准
        if (existing.getUpdateTime() != null && bill.getUpdateTime() != null
            && existing.getUpdateTime().isAfter(bill.getUpdateTime())) {
          skipCount++;
          if (maxId == null || existing.getId() > maxId) {
            maxId = existing.getId();
          }
          continue;
        }
        // 需要更新
        bill.setId(existing.getId());
        toUpdate.add(bill);
        if (maxId == null || bill.getId() > maxId) {
          maxId = bill.getId();
        }
      } else {
        // 检查超限（新增时）
        if ((quotaResult.isSuccess() || quotaResult.isWarning()) && bill.getIsDelete() == 0) {
          QuotaResult newQuotaResult = checkQuotaLimit(userId, bookId, currentCount + toInsert.size() + 1);
          if (newQuotaResult.isError()) {
            skipCount++;
            continue;
          }
        }
        // 需要插入
        toInsert.add(bill);
      }
    }

    // 批量更新
    if (!toUpdate.isEmpty()) {
      billInfoMapper.batchUpdate(toUpdate);
    }

    // 批量插入
    if (!toInsert.isEmpty()) {
      billInfoMapper.batchInsert(toInsert);
      currentCount += toInsert.size();
    }

    // 合并处理结果
    List<BillInfo> processed = new java.util.ArrayList<>();
    processed.addAll(toUpdate);
    processed.addAll(toInsert);
    int successCount = processed.size();

    // 更新同步记录
    int finalCount = countBills(userId, bookId);
    updateSyncRecord(userId, bookId, deviceId, maxId, LocalDateTime.now(), finalCount);

    return SyncResult.success(successCount, skipCount, getSyncRecord(userId, bookId, deviceId), processed);
  }

  /**
   * 增量拉取
   */
  public SyncResult incrementalDownload(Long userId, String bookId, String deviceId,
                                       LocalDateTime lastSyncTime, Long lastSyncId,
                                       int offset, int limit) {
    assertBookMember(userId, bookId);
    List<BillInfo> bills = isServerBook(bookId)
        ? billInfoMapper.findIncrementalByBookId(bookId, lastSyncTime, lastSyncId, offset, limit)
        : billInfoMapper.findIncrementalByUserIdAndBookId(userId, bookId, lastSyncTime, lastSyncId, offset, limit);
    SyncRecord syncRecord = getSyncRecord(userId, bookId, deviceId);

    return SyncResult.success(bills, syncRecord);
  }

  /**
   * 查询同步状态
   */
  public SyncResult queryStatus(Long userId, String bookId, String deviceId) {
    assertBookMember(userId, bookId);
    SyncRecord syncRecord = getSyncRecord(userId, bookId, deviceId);
    // 当前阶段同步默认开放，不需要每次查询用户信息；避免高频接口重复查 user 表
    if (isSyncAlwaysEnabled()) {
      return SyncResult.success(syncRecord, null);
    }
    User user = userMapper.findById(userId);
    return SyncResult.success(syncRecord, user);
  }

  /**
   * 获取或创建同步记录
   */
  private SyncRecord getSyncRecord(Long userId, String bookId, String deviceId) {
    SyncRecord record = syncRecordMapper.findByUserBookDevice(userId, bookId, deviceId);
    if (record == null) {
      record = new SyncRecord();
      record.setUserId(userId);
      record.setBookId(bookId);
      record.setDeviceId(deviceId);
      record.setCloudBillCount(0);
      record.setDataVersion(1L); // 初始版本号为1
      syncRecordMapper.insert(record);
      return syncRecordMapper.findByUserBookDevice(userId, bookId, deviceId);
    }
    return record;
  }

  /**
   * 更新同步记录（包含版本号）
   */
  private void updateSyncRecord(Long userId, String bookId, String deviceId,
                                Long lastSyncId, LocalDateTime lastSyncTime, int cloudBillCount) {
    SyncRecord record = getSyncRecord(userId, bookId, deviceId);
    record.setLastSyncId(lastSyncId);
    record.setLastSyncTime(lastSyncTime);
    record.setCloudBillCount(cloudBillCount);
    record.setSyncDeviceId(deviceId);
    // 同步后版本号+1
    record.setDataVersion((record.getDataVersion() != null ? record.getDataVersion() : 1L) + 1);
    syncRecordMapper.upsert(record);
  }

  /**
   * 上传账户数据
   */
  @Transactional
  public AccountSyncResult uploadAccounts(Long userId, List<AccountInfo> accounts) {
    // 权限校验
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return AccountSyncResult.error(permissionError.getMessage());
    }

    List<AccountInfo> toInsert = new ArrayList<>();
    List<AccountInfo> toUpdate = new ArrayList<>();
    List<AccountInfo> processed = new ArrayList<>();

    for (AccountInfo account : accounts) {
      account.setUserId(userId);

      // 如果客户端提供了serverId，尝试查找现有记录
      AccountInfo existing = null;
      if (account.getId() != null) {
        existing = accountInfoMapper.findById(account.getId());
      }

      // 如果通过serverId找不到，尝试通过临时accountId查找（首次上传）
      if (existing == null && account.getAccountId() != null) {
        existing = accountInfoMapper.findByUserIdAndAccountId(userId, account.getAccountId());
      }

      if (existing != null) {
        // 冲突处理：服务器时间优先
        if (existing.getUpdateTime() != null && account.getUpdateTime() != null
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

    // 批量操作
    if (!toUpdate.isEmpty()) {
      accountInfoMapper.batchUpdate(toUpdate);
      processed.addAll(toUpdate);
    }
    if (!toInsert.isEmpty()) {
      accountInfoMapper.batchInsert(toInsert);
      processed.addAll(toInsert);
    }

    return AccountSyncResult.success(processed);
  }

  /**
   * 下载账户数据
   */
  public AccountSyncResult downloadAccounts(Long userId) {
    // 权限校验
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError.isError()) {
      return AccountSyncResult.error(permissionError.getMessage());
    }

    List<AccountInfo> accounts = accountInfoMapper.findAllByUserId(userId);
    return AccountSyncResult.success(accounts);
  }

  /**
   * 账户同步结果封装类
   */
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

    public boolean isSuccess() { return success; }
    public String getError() { return error; }
    public List<AccountInfo> getAccounts() { return accounts; }
  }

  /**
   * 同步结果封装类
   */
  public static class SyncResult {
    private boolean success;
    private String error;
    private List<BillInfo> bills;
    private SyncRecord syncRecord;
    private User user;
    private int successCount;
    private int skipCount;
    private String quotaWarning; // 80%预警信息

    public static SyncResult error(String error) {
      SyncResult result = new SyncResult();
      result.success = false;
      result.error = error;
      return result;
    }

    public static SyncResult success(List<BillInfo> bills, SyncRecord syncRecord) {
      SyncResult result = new SyncResult();
      result.success = true;
      result.bills = bills;
      result.syncRecord = syncRecord;
      return result;
    }

    public static SyncResult success(int successCount, int skipCount, SyncRecord syncRecord, List<BillInfo> bills) {
      SyncResult result = new SyncResult();
      result.success = true;
      result.successCount = successCount;
      result.skipCount = skipCount;
      result.syncRecord = syncRecord;
      result.bills = bills;
      return result;
    }

    public static SyncResult success(SyncRecord syncRecord, User user) {
      SyncResult result = new SyncResult();
      result.success = true;
      result.syncRecord = syncRecord;
      result.user = user;
      return result;
    }

    // Getters
    public boolean isSuccess() { return success; }
    public String getError() { return error; }
    public List<BillInfo> getBills() { return bills; }
    public SyncRecord getSyncRecord() { return syncRecord; }
    public User getUser() { return user; }
    public int getSuccessCount() { return successCount; }
    public int getSkipCount() { return skipCount; }
    public String getQuotaWarning() { return quotaWarning; }
    public void setQuotaWarning(String quotaWarning) { this.quotaWarning = quotaWarning; }
  }
}
