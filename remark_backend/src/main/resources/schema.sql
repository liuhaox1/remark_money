-- Example schema for user table, adjust as needed.

CREATE TABLE IF NOT EXISTS user (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(64) UNIQUE,
  password VARCHAR(255) NOT NULL,
  phone VARCHAR(20) UNIQUE,
  nickname VARCHAR(64) DEFAULT NULL,
  wechat_open_id VARCHAR(64) UNIQUE,
  pay_type TINYINT NOT NULL DEFAULT 0 COMMENT '0=free,1=3元档,2=5元档,3=10元档',
  pay_expire DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sms_code (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  phone VARCHAR(20) NOT NULL,
  code VARCHAR(10) NOT NULL,
  expires_at DATETIME NOT NULL,
  used TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_sms_phone (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 礼包码表：唯一索引保障并发核销，无需 FOR UPDATE
CREATE TABLE IF NOT EXISTS gift_code (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  code CHAR(8) NOT NULL COMMENT '礼包码，8位数字',
  status TINYINT NOT NULL DEFAULT 0 COMMENT '0=unused未使用,1=used已使用,2=expired已过期',
  used_by BIGINT DEFAULT NULL COMMENT '使用用户ID',
  used_at DATETIME DEFAULT NULL COMMENT '使用时间',
  expire_at DATETIME DEFAULT NULL COMMENT '礼包码过期时间',
  plan_type TINYINT NOT NULL DEFAULT 1 COMMENT '套餐类型：1=3元档,2=5元档,3=10元档',
  duration_months INT NOT NULL DEFAULT 12 COMMENT '有效期（月）',
  version INT NOT NULL DEFAULT 0 COMMENT '版本号，用于乐观锁',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  UNIQUE KEY uk_gift_code (code),
  INDEX idx_gift_status (status),
  INDEX idx_gift_code_status (code, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='礼包码表';

-- 账本表（支持多人账本与邀请码）
CREATE TABLE IF NOT EXISTS book (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  owner_id BIGINT NOT NULL,
  name VARCHAR(128) NOT NULL,
  invite_code CHAR(8) DEFAULT NULL,
  is_multi TINYINT NOT NULL DEFAULT 0,
  status TINYINT NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_book_invite (invite_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 账本成员
CREATE TABLE IF NOT EXISTS book_member (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  book_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  role VARCHAR(16) NOT NULL DEFAULT 'editor',
  status TINYINT NOT NULL DEFAULT 1,
  joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_book_member (book_id, user_id),
  INDEX idx_member_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 账单表（云端同步）
CREATE TABLE IF NOT EXISTS bill_info (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  book_id VARCHAR(64) NOT NULL,
  account_id VARCHAR(64) NOT NULL,
  category_key VARCHAR(64) NOT NULL,
  amount DECIMAL(15,2) NOT NULL,
  direction TINYINT NOT NULL COMMENT '0=out支出,1=income收入',
  remark VARCHAR(512) DEFAULT NULL,
  attachment_url VARCHAR(500) DEFAULT NULL COMMENT '附件URL（未来OSS）',
  bill_date DATETIME NOT NULL COMMENT '账单日期',
  include_in_stats TINYINT NOT NULL DEFAULT 1,
  pair_id VARCHAR(64) DEFAULT NULL COMMENT '转账配对ID',
  is_delete TINYINT NOT NULL DEFAULT 0 COMMENT '0=有效,1=已删除',
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_book (user_id, book_id),
  INDEX idx_user_update (user_id, update_time),
  INDEX idx_delete (is_delete)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 预算表（云端同步）
CREATE TABLE IF NOT EXISTS budget_info (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  book_id VARCHAR(64) NOT NULL,
  total DECIMAL(15,2) NOT NULL DEFAULT 0 COMMENT '总预算',
  category_budgets TEXT DEFAULT NULL COMMENT '分类预算JSON',
  period_start_day TINYINT NOT NULL DEFAULT 1 COMMENT '预算周期起始日1-28',
  annual_total DECIMAL(15,2) NOT NULL DEFAULT 0 COMMENT '年度总预算',
  annual_category_budgets TEXT DEFAULT NULL COMMENT '年度分类预算JSON',
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_book (user_id, book_id),
  INDEX idx_user_book (user_id, book_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 账户表（云端同步）
CREATE TABLE IF NOT EXISTS account_info (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '服务器自增ID',
  user_id BIGINT NOT NULL,
  account_id VARCHAR(64) NULL COMMENT '客户端生成的临时ID（仅用于首次上传匹配）',
  name VARCHAR(128) NOT NULL COMMENT '账户名称',
  kind VARCHAR(16) NOT NULL COMMENT '账户类型: asset, liability, lend',
  subtype VARCHAR(32) DEFAULT 'cash' COMMENT '账户子类型',
  type VARCHAR(32) DEFAULT 'cash' COMMENT '账户类型: cash, bankCard, eWallet, etc.',
  icon VARCHAR(32) DEFAULT 'wallet' COMMENT '图标',
  include_in_total TINYINT NOT NULL DEFAULT 1 COMMENT '是否计入总额',
  include_in_overview TINYINT NOT NULL DEFAULT 1 COMMENT '是否在概览中显示',
  currency VARCHAR(8) DEFAULT 'CNY' COMMENT '货币',
  sort_order INT NOT NULL DEFAULT 0 COMMENT '排序',
  initial_balance DECIMAL(15,2) NOT NULL DEFAULT 0 COMMENT '初始余额',
  current_balance DECIMAL(15,2) NOT NULL DEFAULT 0 COMMENT '当前余额',
  counterparty VARCHAR(128) DEFAULT NULL COMMENT '对方名称',
  interest_rate DECIMAL(10,4) DEFAULT NULL COMMENT '利率',
  due_date DATETIME DEFAULT NULL COMMENT '到期日期',
  note VARCHAR(512) DEFAULT NULL COMMENT '备注',
  brand_key VARCHAR(64) DEFAULT NULL COMMENT '品牌标识',
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_account_id (user_id, account_id),
  INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 同步记录表
CREATE TABLE IF NOT EXISTS sync_record (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  book_id VARCHAR(64) NOT NULL,
  device_id VARCHAR(64) NOT NULL COMMENT '设备唯一标识',
  last_sync_id BIGINT DEFAULT NULL COMMENT '上次同步的最大id',
  last_sync_time DATETIME DEFAULT NULL COMMENT '上次同步时间',
  cloud_bill_count INT NOT NULL DEFAULT 0 COMMENT '云端账单数量（is_delete=0）',
  sync_device_id VARCHAR(64) DEFAULT NULL COMMENT '最后同步的设备ID',
  data_version BIGINT NOT NULL DEFAULT 1 COMMENT '数据版本号，同步后统一',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_book_device (user_id, book_id, device_id),
  INDEX idx_user_book (user_id, book_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 数据库迁移脚本（从旧版本升级到新版本）
-- ============================================================================
-- 执行时间：2025-12-11
-- 说明：移除 bill_id 字段，改为只使用自增 id
-- 注意：以下迁移脚本仅用于从旧版本数据库升级，新数据库直接使用上面的 CREATE TABLE 即可

-- 检查并删除 bill_id 相关索引和字段
SET @db_name = DATABASE();

-- 1. 删除 bill_id 的唯一索引（如果存在）
SET @index_exists = (
    SELECT COUNT(*) FROM information_schema.STATISTICS 
    WHERE TABLE_SCHEMA = @db_name 
      AND TABLE_NAME = 'bill_info' 
      AND INDEX_NAME = 'uk_bill_id'
);
SET @sql = IF(@index_exists > 0, 'ALTER TABLE bill_info DROP INDEX uk_bill_id', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @index_exists = (
    SELECT COUNT(*) FROM information_schema.STATISTICS 
    WHERE TABLE_SCHEMA = @db_name 
      AND TABLE_NAME = 'bill_info' 
      AND INDEX_NAME = 'idx_user_bill_id'
);
SET @sql = IF(@index_exists > 0, 'ALTER TABLE bill_info DROP INDEX idx_user_bill_id', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 2. 删除 bill_info 表的 bill_id 字段（如果存在）
SET @column_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS 
    WHERE TABLE_SCHEMA = @db_name 
      AND TABLE_NAME = 'bill_info' 
      AND COLUMN_NAME = 'bill_id'
);
SET @sql = IF(@column_exists > 0, 'ALTER TABLE bill_info DROP COLUMN bill_id', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 3. 修改 sync_record 表：添加 last_sync_id 字段（如果不存在）
SET @column_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS 
    WHERE TABLE_SCHEMA = @db_name 
      AND TABLE_NAME = 'sync_record' 
      AND COLUMN_NAME = 'last_sync_id'
);
SET @sql = IF(@column_exists = 0, 
    'ALTER TABLE sync_record ADD COLUMN last_sync_id BIGINT NULL COMMENT ''上次同步的最大id'' AFTER device_id', 
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 4. 迁移现有数据：将 last_sync_bill_id 转换为 last_sync_id（如果有对应的记录）
SET @column_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS 
    WHERE TABLE_SCHEMA = @db_name 
      AND TABLE_NAME = 'sync_record' 
      AND COLUMN_NAME = 'last_sync_bill_id'
);
SET @sql = IF(@column_exists > 0,
    'UPDATE sync_record sr SET sr.last_sync_id = (SELECT MAX(bi.id) FROM bill_info bi WHERE bi.user_id = sr.user_id AND bi.book_id = sr.book_id AND bi.is_delete = 0 AND bi.include_in_stats = 1) WHERE sr.last_sync_bill_id IS NOT NULL',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 5. 删除旧的 last_sync_bill_id 字段（如果存在）
SET @column_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS 
    WHERE TABLE_SCHEMA = @db_name 
      AND TABLE_NAME = 'sync_record' 
      AND COLUMN_NAME = 'last_sync_bill_id'
);
SET @sql = IF(@column_exists > 0, 'ALTER TABLE sync_record DROP COLUMN last_sync_bill_id', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

