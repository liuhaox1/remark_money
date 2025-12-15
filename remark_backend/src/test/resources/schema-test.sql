DROP TABLE IF EXISTS sync_op_dedup;
DROP TABLE IF EXISTS sync_scope_state;
DROP TABLE IF EXISTS bill_change_log;
DROP TABLE IF EXISTS bill_info;
DROP TABLE IF EXISTS book_member;

CREATE TABLE book_member (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  book_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  role VARCHAR(32),
  status INT DEFAULT 1,
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bill_info (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  version BIGINT NOT NULL DEFAULT 1,
  user_id BIGINT NOT NULL,
  book_id VARCHAR(64) NOT NULL,
  account_id VARCHAR(64),
  category_key VARCHAR(128),
  amount DECIMAL(18,2),
  direction INT,
  remark VARCHAR(255),
  attachment_url VARCHAR(255),
  bill_date TIMESTAMP,
  include_in_stats INT NOT NULL DEFAULT 1,
  pair_id VARCHAR(128),
  is_delete INT NOT NULL DEFAULT 0,
  update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bill_change_log (
  change_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  book_id VARCHAR(64) NOT NULL,
  scope_user_id BIGINT NOT NULL DEFAULT 0,
  bill_id BIGINT NOT NULL,
  op INT NOT NULL DEFAULT 0,
  bill_version BIGINT NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_book_scope_change ON bill_change_log(book_id, scope_user_id, change_id);

CREATE TABLE sync_op_dedup (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  book_id VARCHAR(64) NOT NULL,
  op_id VARCHAR(64) NOT NULL,
  status INT NOT NULL,
  bill_id BIGINT,
  bill_version BIGINT,
  error VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX uk_user_book_op ON sync_op_dedup(user_id, book_id, op_id);

CREATE TABLE sync_scope_state (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  book_id VARCHAR(64) NOT NULL,
  scope_user_id BIGINT NOT NULL DEFAULT 0,
  initialized INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX uk_book_scope ON sync_scope_state(book_id, scope_user_id);
