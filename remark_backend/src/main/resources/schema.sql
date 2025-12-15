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
  version BIGINT NOT NULL DEFAULT 1 COMMENT 'optimistic lock version (server-managed)',
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

-- è´¦å•å˜æ›´æµï¼ˆv2 åŒæ­¥ç”¨ï¼‰
CREATE TABLE IF NOT EXISTS bill_change_log (
  change_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  book_id VARCHAR(64) NOT NULL,
  scope_user_id BIGINT NOT NULL COMMENT '0=shared book, otherwise user_id for personal books',
  bill_id BIGINT NOT NULL,
  op TINYINT NOT NULL COMMENT '0=upsert,1=delete',
  bill_version BIGINT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_book_scope_change (book_id, scope_user_id, change_id),
  INDEX idx_bill (bill_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- åŒæ­¥æ“ä½œåŽ»é‡?ï¼ˆä¿è¯? push å¹‚ç­‰ï¼‰
CREATE TABLE IF NOT EXISTS sync_op_dedup (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  book_id VARCHAR(64) NOT NULL,
  op_id VARCHAR(64) NOT NULL,
  status TINYINT NOT NULL DEFAULT 0 COMMENT '0=applied,1=conflict,2=error',
  bill_id BIGINT DEFAULT NULL,
  bill_version BIGINT DEFAULT NULL,
  error VARCHAR(255) DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_book_op (user_id, book_id, op_id),
  INDEX idx_user_book (user_id, book_id),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- v2: scope bootstrap state (avoid repeated COUNT+bootstrap)
CREATE TABLE IF NOT EXISTS sync_scope_state (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  book_id VARCHAR(64) NOT NULL,
  scope_user_id BIGINT NOT NULL DEFAULT 0 COMMENT '0=shared book, otherwise user_id for personal books',
  initialized TINYINT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_book_scope (book_id, scope_user_id),
  INDEX idx_scope_init (scope_user_id, initialized)
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

-- 8. bill_change_log æ·»åŠ  scope_user_id å­—æ®µï¼ˆå¦‚æžœä¸å­˜åœ¨ï¼‰
SET @column_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'bill_change_log'
      AND COLUMN_NAME = 'scope_user_id'
);
SET @sql = IF(@column_exists = 0,
    'ALTER TABLE bill_change_log ADD COLUMN scope_user_id BIGINT NOT NULL DEFAULT 0 COMMENT ''0=shared book, otherwise user_id for personal books'' AFTER book_id',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 9. bill_change_log ä¿®æ­£ç´¢å¼•ï¼ˆå¦‚æžœä¸å­˜åœ¨ï¼‰
SET @index_exists = (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'bill_change_log'
      AND INDEX_NAME = 'idx_book_scope_change'
);
SET @sql = IF(@index_exists = 0,
    'CREATE INDEX idx_book_scope_change ON bill_change_log(book_id, scope_user_id, change_id)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 6. bill_info æ·»åŠ  version å­—æ®µï¼ˆå¦‚æžœä¸å­˜åœ¨ï¼‰
SET @column_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'bill_info'
      AND COLUMN_NAME = 'version'
);
SET @sql = IF(@column_exists = 0,
    'ALTER TABLE bill_info ADD COLUMN version BIGINT NOT NULL DEFAULT 1 COMMENT ''optimistic lock version'' AFTER created_at',
    'SELECT 1');
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
