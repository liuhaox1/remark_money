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
  code CHAR(6) NOT NULL,
  status TINYINT NOT NULL DEFAULT 0 COMMENT '0=unused,1=used,2=expired',
  used_by BIGINT DEFAULT NULL,
  used_at DATETIME DEFAULT NULL,
  expire_at DATETIME DEFAULT NULL,
  plan_type TINYINT NOT NULL DEFAULT 1 COMMENT '1=3元档',
  duration_months INT NOT NULL DEFAULT 12,
  version INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_gift_code (code),
  INDEX idx_gift_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
  bill_id VARCHAR(64) NOT NULL COMMENT '客户端生成的唯一ID',
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
  UNIQUE KEY uk_bill_id (bill_id),
  INDEX idx_user_book (user_id, book_id),
  INDEX idx_user_update (user_id, update_time),
  INDEX idx_user_bill_id (user_id, bill_id),
  INDEX idx_delete (is_delete)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 同步记录表
CREATE TABLE IF NOT EXISTS sync_record (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  book_id VARCHAR(64) NOT NULL,
  device_id VARCHAR(64) NOT NULL COMMENT '设备唯一标识',
  last_sync_bill_id VARCHAR(64) DEFAULT NULL COMMENT '上次同步的最大bill_id',
  last_sync_time DATETIME DEFAULT NULL COMMENT '上次同步时间',
  cloud_bill_count INT NOT NULL DEFAULT 0 COMMENT '云端账单数量（is_delete=0）',
  sync_device_id VARCHAR(64) DEFAULT NULL COMMENT '最后同步的设备ID',
  data_version BIGINT NOT NULL DEFAULT 1 COMMENT '数据版本号，同步后统一',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_book_device (user_id, book_id, device_id),
  INDEX idx_user_book (user_id, book_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

