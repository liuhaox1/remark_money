package com.remark.money.service;

import com.remark.money.common.ErrorCode;
import com.remark.money.common.QuotaResult;
import com.remark.money.entity.BillInfo;
import com.remark.money.entity.SyncRecord;
import com.remark.money.entity.User;
import com.remark.money.mapper.BillInfoMapper;
import com.remark.money.mapper.SyncRecordMapper;
import com.remark.money.mapper.UserMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class SyncService {

  private static final Logger log = LoggerFactory.getLogger(SyncService.class);

  private final UserMapper userMapper;
  private final BillInfoMapper billInfoMapper;
  private final SyncRecordMapper syncRecordMapper;

  public SyncService(UserMapper userMapper, BillInfoMapper billInfoMapper, SyncRecordMapper syncRecordMapper) {
    this.userMapper = userMapper;
    this.billInfoMapper = billInfoMapper;
    this.syncRecordMapper = syncRecordMapper;
  }

  /**
   * 权限校验：检查用户是否有云端同步权限
   * @return null=有权限, 非null=错误码
   */
  public ErrorCode checkSyncPermission(Long userId) {
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

  /**
   * 全量上传：批量Upsert账单
   */
  @Transactional
  public SyncResult fullUpload(Long userId, String bookId, String deviceId, List<BillInfo> bills, int batchNum, int totalBatches) {
    // 权限校验
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError != null) {
      return SyncResult.error(permissionError.getMessage());
    }

    // 统计当前云端账单数
    int currentCount = billInfoMapper.countByUserIdAndBookId(userId, bookId);

    // 检查超限（3元/5元用户）
    QuotaResult quotaResult = checkQuotaLimit(userId, bookId, currentCount);
    if (quotaResult.isError()) {
      return SyncResult.error(quotaResult.getMessage());
    }

    // 批量Upsert
    int successCount = 0;
    int skipCount = 0;
    String maxBillId = null;
    List<BillInfo> processed = new java.util.ArrayList<>();

    for (BillInfo bill : bills) {
      // 过滤转账记录：includeInStats == 0 的记录不参与同步
      if (bill.getIncludeInStats() != null && bill.getIncludeInStats() == 0) {
        skipCount++;
        continue;
      }
      
      bill.setUserId(userId);
      bill.setBookId(bookId);
      bill.setIsDelete(0); // 确保有效

      try {
        BillInfo existing = null;
        if (bill.getId() != null) {
          existing = billInfoMapper.findById(bill.getId());
        }
        if (existing == null) {
          existing = billInfoMapper.findByBillId(bill.getBillId());
        }
        if (existing != null) {
          bill.setId(existing.getId()); // 统一使用服务器ID
          // 冲突处理：服务器端时间为准
          if (existing.getUpdateTime() != null && bill.getUpdateTime() != null
              && existing.getUpdateTime().isAfter(bill.getUpdateTime())) {
            // 服务器端更新，跳过客户端数据
            skipCount++;
            if (maxBillId == null || bill.getBillId().compareTo(maxBillId) > 0) {
              maxBillId = bill.getBillId();
            }
            continue;
          }
          // 更新
          if (bill.getId() != null) {
            billInfoMapper.updateById(bill);
          } else {
            billInfoMapper.update(bill);
          }
        } else {
          // 检查超限（新增时）
          if (quotaResult.isSuccess() || quotaResult.isWarning()) {
            QuotaResult newQuotaResult = checkQuotaLimit(userId, bookId, currentCount + 1);
            if (newQuotaResult.isError()) {
              skipCount++;
              continue;
            }
          }
          // 插入
          billInfoMapper.insert(bill);
          currentCount++;
        }
        processed.add(bill);
        successCount++;
        if (maxBillId == null || bill.getBillId().compareTo(maxBillId) > 0) {
          maxBillId = bill.getBillId();
        }
      } catch (DuplicateKeyException e) {
        // 账单ID重复，跳过
        log.warn("Duplicate bill_id: {}", bill.getBillId());
        skipCount++;
      }
    }

    // 更新同步记录（最后一批时）
    if (batchNum == totalBatches) {
      int finalCount = billInfoMapper.countByUserIdAndBookId(userId, bookId);
      updateSyncRecord(userId, bookId, deviceId, maxBillId, LocalDateTime.now(), finalCount);
    }

    return SyncResult.success(successCount, skipCount, getSyncRecord(userId, bookId, deviceId), processed);
  }

  /**
   * 全量拉取：分批返回所有有效账单
   */
  public SyncResult fullDownload(Long userId, String bookId, String deviceId, int offset, int limit) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError != null) {
      return SyncResult.error(permissionError.getMessage());
    }

    List<BillInfo> bills = billInfoMapper.findAllByUserIdAndBookId(userId, bookId, offset, limit);
    SyncRecord syncRecord = getSyncRecord(userId, bookId, deviceId);

    return SyncResult.success(bills, syncRecord);
  }

  /**
   * 增量上传
   */
  @Transactional
  public SyncResult incrementalUpload(Long userId, String bookId, String deviceId, List<BillInfo> bills) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError != null) {
      return SyncResult.error(permissionError.getMessage());
    }

    int currentCount = billInfoMapper.countByUserIdAndBookId(userId, bookId);
    QuotaResult quotaResult = checkQuotaLimit(userId, bookId, currentCount);
    if (quotaResult.isError()) {
      return SyncResult.error(quotaResult.getMessage());
    }

    int successCount = 0;
    int skipCount = 0;
    String maxBillId = null;
    List<BillInfo> processed = new java.util.ArrayList<>();

    for (BillInfo bill : bills) {
      // 过滤转账记录：includeInStats == 0 的记录不参与同步
      if (bill.getIncludeInStats() != null && bill.getIncludeInStats() == 0) {
        skipCount++;
        continue;
      }
      
      bill.setUserId(userId);
      bill.setBookId(bookId);
      bill.setIsDelete(bill.getIsDelete() != null ? bill.getIsDelete() : 0);

      try {
        BillInfo existing = null;
        if (bill.getId() != null) {
          existing = billInfoMapper.findById(bill.getId());
        }
        if (existing == null) {
          existing = billInfoMapper.findByBillId(bill.getBillId());
        }
        if (existing != null) {
          bill.setId(existing.getId()); // 统一使用服务器ID
          // 冲突处理
          if (existing.getUpdateTime() != null && bill.getUpdateTime() != null
              && existing.getUpdateTime().isAfter(bill.getUpdateTime())) {
            skipCount++;
            continue;
          }
          if (bill.getId() != null) {
            billInfoMapper.updateById(bill);
          } else {
            billInfoMapper.update(bill);
          }
        } else {
          // 新增时检查超限
          if ((quotaResult.isSuccess() || quotaResult.isWarning()) && bill.getIsDelete() == 0) {
            QuotaResult newQuotaResult = checkQuotaLimit(userId, bookId, currentCount + 1);
            if (newQuotaResult.isError()) {
              skipCount++;
              continue;
            }
          }
          billInfoMapper.insert(bill);
          if (bill.getIsDelete() == 0) {
            currentCount++;
          }
        }
        processed.add(bill);
        successCount++;
        if (maxBillId == null || bill.getBillId().compareTo(maxBillId) > 0) {
          maxBillId = bill.getBillId();
        }
      } catch (DuplicateKeyException e) {
        log.warn("Duplicate bill_id: {}", bill.getBillId());
        skipCount++;
      }
    }

    // 更新同步记录
    int finalCount = billInfoMapper.countByUserIdAndBookId(userId, bookId);
    updateSyncRecord(userId, bookId, deviceId, maxBillId, LocalDateTime.now(), finalCount);

    return SyncResult.success(successCount, skipCount, getSyncRecord(userId, bookId, deviceId), processed);
  }

  /**
   * 增量拉取
   */
  public SyncResult incrementalDownload(Long userId, String bookId, String deviceId,
                                       LocalDateTime lastSyncTime, String lastSyncBillId,
                                       int offset, int limit) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError != null) {
      return SyncResult.error(permissionError.getMessage());
    }

    List<BillInfo> bills = billInfoMapper.findIncrementalByUserIdAndBookId(
        userId, bookId, lastSyncTime, lastSyncBillId, offset, limit);
    SyncRecord syncRecord = getSyncRecord(userId, bookId, deviceId);

    return SyncResult.success(bills, syncRecord);
  }

  /**
   * 查询同步状态
   */
  public SyncResult queryStatus(Long userId, String bookId, String deviceId) {
    ErrorCode permissionError = checkSyncPermission(userId);
    if (permissionError != null) {
      return SyncResult.error(permissionError.getMessage());
    }

    SyncRecord syncRecord = getSyncRecord(userId, bookId, deviceId);
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
                                String lastSyncBillId, LocalDateTime lastSyncTime, int cloudBillCount) {
    SyncRecord record = getSyncRecord(userId, bookId, deviceId);
    record.setLastSyncBillId(lastSyncBillId);
    record.setLastSyncTime(lastSyncTime);
    record.setCloudBillCount(cloudBillCount);
    record.setSyncDeviceId(deviceId);
    // 同步后版本号+1
    record.setDataVersion((record.getDataVersion() != null ? record.getDataVersion() : 1L) + 1);
    syncRecordMapper.upsert(record);
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

