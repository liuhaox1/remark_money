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
  INDEX idx_user_book_delete (user_id, book_id, is_delete),
  INDEX idx_user_update (user_id, update_time),
  INDEX idx_book (book_id),
  INDEX idx_book_delete (book_id, is_delete),
  INDEX idx_delete (is_delete),
  INDEX idx_delete_update (is_delete, update_time, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- bill_info: optimize pairId lookup (server auto plans / transfer healing)
SET @idx_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'bill_info'
    AND INDEX_NAME = 'idx_book_pair_delete'
);
SET @sql = IF(@idx_exists > 0,
  'SELECT 1',
  'CREATE INDEX idx_book_pair_delete ON bill_info(book_id, pair_id, is_delete)'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

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
  sync_version BIGINT NOT NULL DEFAULT 1 COMMENT 'server monotonic sync version',
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_book (user_id, book_id),
  INDEX idx_user_book (user_id, book_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- budget_info add sync_version if missing
SET @column_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'budget_info'
    AND COLUMN_NAME = 'sync_version'
);
SET @sql = IF(@column_exists > 0,
  'SELECT 1',
  'ALTER TABLE budget_info ADD COLUMN sync_version BIGINT NOT NULL DEFAULT 1 COMMENT ''server monotonic sync version'' AFTER annual_category_budgets'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- savings_plan_info (cloud sync, per user+book)
CREATE TABLE IF NOT EXISTS savings_plan_info (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  book_id VARCHAR(64) NOT NULL,
  plan_id VARCHAR(64) NOT NULL,
  payload_json MEDIUMTEXT NOT NULL COMMENT 'plan payload JSON',
  is_delete TINYINT NOT NULL DEFAULT 0,
  sync_version BIGINT NOT NULL DEFAULT 1 COMMENT 'server monotonic sync version',
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_book_plan (user_id, book_id, plan_id),
  INDEX idx_user_book (user_id, book_id),
  INDEX idx_user_book_update (user_id, book_id, update_time),
  INDEX idx_user_book_delete (user_id, book_id, is_delete)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- savings_plan_info: optimize list query (user_id + book_id + is_delete + ORDER BY update_time,id)
SET @idx_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'savings_plan_info'
    AND INDEX_NAME = 'idx_user_book_delete_update'
);
SET @sql = IF(@idx_exists > 0,
  'SELECT 1',
  'CREATE INDEX idx_user_book_delete_update ON savings_plan_info(user_id, book_id, is_delete, update_time, id)'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- recurring_plan_info (cloud sync, per user+book)
CREATE TABLE IF NOT EXISTS recurring_plan_info (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  book_id VARCHAR(64) NOT NULL,
  plan_id VARCHAR(64) NOT NULL,
  payload_json MEDIUMTEXT NOT NULL COMMENT 'plan payload JSON',
  is_delete TINYINT NOT NULL DEFAULT 0,
  sync_version BIGINT NOT NULL DEFAULT 1 COMMENT 'server monotonic sync version',
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_book_plan (user_id, book_id, plan_id),
  INDEX idx_user_book (user_id, book_id),
  INDEX idx_user_book_update (user_id, book_id, update_time),
  INDEX idx_user_book_delete (user_id, book_id, is_delete)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- recurring_plan_info: optimize list query (user_id + book_id + is_delete + ORDER BY update_time,id)
SET @idx_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'recurring_plan_info'
    AND INDEX_NAME = 'idx_user_book_delete_update'
);
SET @sql = IF(@idx_exists > 0,
  'SELECT 1',
  'CREATE INDEX idx_user_book_delete_update ON recurring_plan_info(user_id, book_id, is_delete, update_time, id)'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- auto execution dedup log (server-scheduled plans)
CREATE TABLE IF NOT EXISTS plan_exec_log (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  kind VARCHAR(16) NOT NULL COMMENT 'savings|recurring',
  user_id BIGINT NOT NULL,
  book_id VARCHAR(64) NOT NULL,
  plan_id VARCHAR(64) NOT NULL,
  period_key VARCHAR(64) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_kind_user_book_plan_period (kind, user_id, book_id, plan_id, period_key),
  INDEX idx_created_at (created_at),
  INDEX idx_user_book (user_id, book_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 分类表（云端同步，按用户）
CREATE TABLE IF NOT EXISTS category_info (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  category_key VARCHAR(128) NOT NULL,
  name VARCHAR(128) NOT NULL,
  icon_code_point INT NOT NULL,
  icon_font_family VARCHAR(128) DEFAULT NULL,
  icon_font_package VARCHAR(128) DEFAULT NULL,
  is_expense TINYINT NOT NULL DEFAULT 1,
  parent_key VARCHAR(128) DEFAULT NULL,
  is_delete TINYINT NOT NULL DEFAULT 0,
  sync_version BIGINT NOT NULL DEFAULT 1 COMMENT 'server monotonic sync version',
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_key (user_id, category_key),
  INDEX idx_user_update (user_id, update_time),
  INDEX idx_user_delete (user_id, is_delete)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- category_info: optimize common list query (user_id + is_delete + ORDER BY update_time,id)
SET @idx_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'category_info'
    AND INDEX_NAME = 'idx_user_delete_update'
);
SET @sql = IF(@idx_exists > 0,
  'SELECT 1',
  'CREATE INDEX idx_user_delete_update ON category_info(user_id, is_delete, update_time, id)'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- category_info add sync_version if missing
SET @column_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'category_info'
    AND COLUMN_NAME = 'sync_version'
);
SET @sql = IF(@column_exists > 0,
  'SELECT 1',
  'ALTER TABLE category_info ADD COLUMN sync_version BIGINT NOT NULL DEFAULT 1 COMMENT ''server monotonic sync version'' AFTER is_delete'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 标签表（云端同步，按用户+账本）
CREATE TABLE IF NOT EXISTS tag_info (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  book_id VARCHAR(64) NOT NULL,
  tag_id VARCHAR(64) NOT NULL,
  name VARCHAR(128) NOT NULL,
  color INT DEFAULT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_delete TINYINT NOT NULL DEFAULT 0,
  sync_version BIGINT NOT NULL DEFAULT 1 COMMENT 'server monotonic sync version',
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_book_tag (user_id, book_id, tag_id),
  INDEX idx_user_book_sort (user_id, book_id, sort_order, created_at),
  INDEX idx_user_book_delete (user_id, book_id, is_delete)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- tag_info: optimize list query (user_id + book_id + is_delete + ORDER BY sort_order, created_at)
SET @idx_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'tag_info'
    AND INDEX_NAME = 'idx_user_book_delete_sort'
);
SET @sql = IF(@idx_exists > 0,
  'SELECT 1',
  'CREATE INDEX idx_user_book_delete_sort ON tag_info(user_id, book_id, is_delete, sort_order, created_at)'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- tag_info add sync_version if missing
SET @column_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'tag_info'
    AND COLUMN_NAME = 'sync_version'
);
SET @sql = IF(@column_exists > 0,
  'SELECT 1',
  'ALTER TABLE tag_info ADD COLUMN sync_version BIGINT NOT NULL DEFAULT 1 COMMENT ''server monotonic sync version'' AFTER is_delete'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 账单-标签关系表（v2，按用户维度存储“个人标签”）
CREATE TABLE IF NOT EXISTS bill_tag_rel_user (
  book_id VARCHAR(64) NOT NULL,
  scope_user_id BIGINT NOT NULL COMMENT '标签归属用户（个人标签）',
  bill_id BIGINT NOT NULL,
  tag_id VARCHAR(64) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (book_id, scope_user_id, bill_id, tag_id),
  INDEX idx_bill_tag_user_bill (book_id, scope_user_id, bill_id),
  INDEX idx_bill_tag_user_tag (book_id, scope_user_id, tag_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 账单删除墓碑（用于 bill_info 物理删除后仍能同步“删除”给长期离线设备）
CREATE TABLE IF NOT EXISTS bill_delete_tombstone (
  book_id VARCHAR(64) NOT NULL,
  scope_user_id BIGINT NOT NULL COMMENT '0=shared book, otherwise user_id for personal books',
  bill_id BIGINT NOT NULL,
  bill_version BIGINT NOT NULL DEFAULT 1,
  deleted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (book_id, scope_user_id, bill_id),
  INDEX idx_tombstone_deleted (deleted_at),
  INDEX idx_tombstone_scope (book_id, scope_user_id, deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 账户表（云端同步）
CREATE TABLE IF NOT EXISTS account_info (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '服务器自增ID',
  user_id BIGINT NOT NULL,
  book_id VARCHAR(64) NOT NULL DEFAULT 'default-book' COMMENT '账本ID（多人账本按 bookId 共享）',
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
  is_delete TINYINT NOT NULL DEFAULT 0 COMMENT '0=active,1=deleted',
  sync_version BIGINT NOT NULL DEFAULT 1 COMMENT 'server monotonic sync version',
  update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_book_account (user_id, book_id, account_id),
  INDEX idx_user_book_delete (user_id, book_id, is_delete),
  INDEX idx_user_book (user_id, book_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- account_info: optimize list query (user_id + book_id + is_delete + ORDER BY sort_order,id)
SET @idx_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'account_info'
    AND INDEX_NAME = 'idx_user_book_delete_sort'
);
SET @sql = IF(@idx_exists > 0,
  'SELECT 1',
  'CREATE INDEX idx_user_book_delete_sort ON account_info(user_id, book_id, is_delete, sort_order, id)'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- account_info add book_id if missing
SET @column_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'account_info'
    AND COLUMN_NAME = 'book_id'
);
SET @sql = IF(@column_exists > 0,
  'SELECT 1',
  'ALTER TABLE account_info ADD COLUMN book_id VARCHAR(64) NOT NULL DEFAULT ''default-book'' COMMENT ''账本ID'' AFTER user_id'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- account_info ensure indexes for book scope
SET @idx_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'account_info'
    AND INDEX_NAME = 'idx_user_book'
);
SET @sql = IF(@idx_exists > 0,
  'SELECT 1',
  'CREATE INDEX idx_user_book ON account_info(user_id, book_id)'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'account_info'
    AND INDEX_NAME = 'idx_user_book_delete'
);
SET @sql = IF(@idx_exists > 0,
  'SELECT 1',
  'CREATE INDEX idx_user_book_delete ON account_info(user_id, book_id, is_delete)'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- account_info add sync_version if missing
SET @column_exists = (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'account_info'
    AND COLUMN_NAME = 'sync_version'
);
SET @sql = IF(@column_exists > 0,
  'SELECT 1',
  'ALTER TABLE account_info ADD COLUMN sync_version BIGINT NOT NULL DEFAULT 1 COMMENT ''server monotonic sync version'' AFTER is_delete'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- è´¦å•å˜æ›´æµï¼ˆv2 åŒæ­¥ç”¨ï¼‰
CREATE TABLE IF NOT EXISTS bill_change_log (
  change_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  book_id VARCHAR(64) NOT NULL,
  scope_user_id BIGINT NOT NULL COMMENT '0=shared book, otherwise user_id for personal books',
  actor_user_id BIGINT NOT NULL DEFAULT 0 COMMENT 'last writer user_id; 0=unknown/bootstrap',
  bill_id BIGINT NOT NULL,
  op TINYINT NOT NULL COMMENT '0=upsert,1=delete',
  bill_version BIGINT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_book_scope_change (book_id, scope_user_id, change_id),
  INDEX idx_book_scope_bill (book_id, scope_user_id, bill_id),
  INDEX idx_bill_change_created (created_at),
  INDEX idx_bill_change_created_id (created_at, change_id),
  INDEX idx_bill (bill_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- åŒæ­¥æ“ä½œåŽ»é‡?ï¼ˆä¿è¯? push å¹‚ç­‰ï¼‰
CREATE TABLE IF NOT EXISTS sync_op_dedup (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  book_id VARCHAR(64) NOT NULL,
  op_id VARCHAR(64) NOT NULL,
  request_id VARCHAR(64) DEFAULT NULL,
  device_id VARCHAR(64) DEFAULT NULL,
  sync_reason VARCHAR(64) DEFAULT NULL,
  status TINYINT NOT NULL DEFAULT 0 COMMENT '0=applied,1=conflict,2=error',
  bill_id BIGINT DEFAULT NULL,
  bill_version BIGINT DEFAULT NULL,
  error VARCHAR(255) DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_book_op (user_id, book_id, op_id),
  INDEX idx_user_book (user_id, book_id),
  INDEX idx_created_at (created_at),
  INDEX idx_dedup_created_id (created_at, id)
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
-- v2: auto-increment id allocator (client-side id reservation for true batch insert)
-- ============================================================================
CREATE TABLE IF NOT EXISTS id_sequence (
  name VARCHAR(32) PRIMARY KEY,
  next_id BIGINT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 意见反馈（MVP：文字+联系方式）
CREATE TABLE IF NOT EXISTS feedback (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT DEFAULT NULL,
  content TEXT NOT NULL,
  contact VARCHAR(128) DEFAULT NULL,
  ip VARCHAR(64) DEFAULT NULL,
  user_agent VARCHAR(255) DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_feedback_user (user_id),
  INDEX idx_feedback_created (created_at)
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

-- 9.1 bill_change_log add idx_book_scope_bill (fast bootstrap NOT EXISTS)
SET @index_exists = (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'bill_change_log'
      AND INDEX_NAME = 'idx_book_scope_bill'
);
SET @sql = IF(@index_exists = 0,
    'CREATE INDEX idx_book_scope_bill ON bill_change_log(book_id, scope_user_id, bill_id)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- bill_change_log: add created_at index for retention cleanup
SET @index_exists = (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'bill_change_log'
      AND INDEX_NAME = 'idx_bill_change_created'
);
SET @sql = IF(@index_exists = 0,
    'CREATE INDEX idx_bill_change_created ON bill_change_log(created_at)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- bill_change_log: add composite index (created_at, change_id) for batched retention cleanup
SET @index_exists = (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'bill_change_log'
      AND INDEX_NAME = 'idx_bill_change_created_id'
);
SET @sql = IF(@index_exists = 0,
    'CREATE INDEX idx_bill_change_created_id ON bill_change_log(created_at, change_id)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- sync_op_dedup: add composite index (created_at, id) for batched retention cleanup
SET @index_exists = (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'sync_op_dedup'
      AND INDEX_NAME = 'idx_dedup_created_id'
);
SET @sql = IF(@index_exists = 0,
    'CREATE INDEX idx_dedup_created_id ON sync_op_dedup(created_at, id)',
    'SELECT 1');
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

-- 10. bill_change_log add actor_user_id (who wrote this change)
SET @column_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'bill_change_log'
      AND COLUMN_NAME = 'actor_user_id'
);
SET @sql = IF(@column_exists = 0,
    'ALTER TABLE bill_change_log ADD COLUMN actor_user_id BIGINT NOT NULL DEFAULT 0 COMMENT ''last writer user_id; 0=unknown/bootstrap'' AFTER scope_user_id',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

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

-- bill_info add idx_book for shared-book queries
SET @index_exists = (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'bill_info'
      AND INDEX_NAME = 'idx_book'
);
SET @sql = IF(@index_exists = 0,
    'CREATE INDEX idx_book ON bill_info(book_id)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- bill_info add idx_book_delete for summary/pull queries
SET @index_exists = (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'bill_info'
      AND INDEX_NAME = 'idx_book_delete'
);
SET @sql = IF(@index_exists = 0,
    'CREATE INDEX idx_book_delete ON bill_info(book_id, is_delete)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- bill_info add idx_user_book_delete for per-user book summary queries
SET @index_exists = (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'bill_info'
      AND INDEX_NAME = 'idx_user_book_delete'
);
SET @sql = IF(@index_exists = 0,
    'CREATE INDEX idx_user_book_delete ON bill_info(user_id, book_id, is_delete)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- bill_info add idx_delete_update for purge/backfill scanning
SET @index_exists = (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'bill_info'
      AND INDEX_NAME = 'idx_delete_update'
);
SET @sql = IF(@index_exists = 0,
    'CREATE INDEX idx_delete_update ON bill_info(is_delete, update_time, id)',
    'SELECT 1');
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

-- bill_info: drop legacy tag_ids column (tag relations are stored in bill_tag_rel_user)
SET @column_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'bill_info'
      AND COLUMN_NAME = 'tag_ids'
);
SET @sql = IF(@column_exists > 0, 'ALTER TABLE bill_info DROP COLUMN tag_ids', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- account_info: add is_delete column + index (soft delete to avoid accidental data loss)
SET @column_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'account_info'
      AND COLUMN_NAME = 'is_delete'
);
SET @sql = IF(@column_exists = 0,
    'ALTER TABLE account_info ADD COLUMN is_delete TINYINT NOT NULL DEFAULT 0 COMMENT ''0=active,1=deleted'' AFTER brand_key',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @index_exists = (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'account_info'
      AND INDEX_NAME = 'idx_user_delete'
);
SET @sql = IF(@index_exists = 0,
    'CREATE INDEX idx_user_delete ON account_info(user_id, is_delete)',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- sync_op_dedup: add request_id/device_id/sync_reason for observability
SET @column_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'sync_op_dedup'
      AND COLUMN_NAME = 'request_id'
);
SET @sql = IF(@column_exists = 0,
    'ALTER TABLE sync_op_dedup ADD COLUMN request_id VARCHAR(64) DEFAULT NULL AFTER op_id',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'sync_op_dedup'
      AND COLUMN_NAME = 'device_id'
);
SET @sql = IF(@column_exists = 0,
    'ALTER TABLE sync_op_dedup ADD COLUMN device_id VARCHAR(64) DEFAULT NULL AFTER request_id',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @column_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = @db_name
      AND TABLE_NAME = 'sync_op_dedup'
      AND COLUMN_NAME = 'sync_reason'
);
SET @sql = IF(@column_exists = 0,
    'ALTER TABLE sync_op_dedup ADD COLUMN sync_reason VARCHAR(64) DEFAULT NULL AFTER device_id',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
