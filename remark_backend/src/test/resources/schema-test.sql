DROP TABLE IF EXISTS sync_op_dedup;
DROP TABLE IF EXISTS sync_scope_state;
DROP TABLE IF EXISTS bill_change_log;
DROP TABLE IF EXISTS bill_info;
DROP TABLE IF EXISTS book_member;
DROP TABLE IF EXISTS budget_info;
DROP TABLE IF EXISTS account_info;

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

CREATE TABLE budget_info (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  book_id VARCHAR(64) NOT NULL,
  total DECIMAL(15,2) NOT NULL DEFAULT 0,
  category_budgets CLOB,
  period_start_day INT NOT NULL DEFAULT 1,
  annual_total DECIMAL(15,2) NOT NULL DEFAULT 0,
  annual_category_budgets CLOB,
  update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (user_id, book_id)
);

CREATE TABLE account_info (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  account_id VARCHAR(64),
  name VARCHAR(128) NOT NULL,
  kind VARCHAR(16) NOT NULL,
  subtype VARCHAR(32),
  type VARCHAR(32),
  icon VARCHAR(32),
  include_in_total INT NOT NULL DEFAULT 1,
  include_in_overview INT NOT NULL DEFAULT 1,
  currency VARCHAR(8),
  sort_order INT NOT NULL DEFAULT 0,
  initial_balance DECIMAL(15,2) NOT NULL DEFAULT 0,
  current_balance DECIMAL(15,2) NOT NULL DEFAULT 0,
  counterparty VARCHAR(128),
  interest_rate DECIMAL(10,4),
  due_date TIMESTAMP,
  note VARCHAR(512),
  brand_key VARCHAR(64),
  is_delete INT NOT NULL DEFAULT 0,
  update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_account_id ON account_info(user_id, account_id);
CREATE INDEX idx_user_delete ON account_info(user_id, is_delete);

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
CREATE INDEX idx_book_scope_bill ON bill_change_log(book_id, scope_user_id, bill_id);
CREATE INDEX idx_bill_change_created ON bill_change_log(created_at);
CREATE INDEX idx_bill_change_created_id ON bill_change_log(created_at, change_id);

CREATE TABLE sync_op_dedup (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  book_id VARCHAR(64) NOT NULL,
  op_id VARCHAR(64) NOT NULL,
  request_id VARCHAR(64),
  device_id VARCHAR(64),
  sync_reason VARCHAR(64),
  status INT NOT NULL,
  bill_id BIGINT,
  bill_version BIGINT,
  error VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX uk_user_book_op ON sync_op_dedup(user_id, book_id, op_id);
CREATE INDEX idx_dedup_created_id ON sync_op_dedup(created_at, id);

CREATE TABLE sync_scope_state (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  book_id VARCHAR(64) NOT NULL,
  scope_user_id BIGINT NOT NULL DEFAULT 0,
  initialized INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX uk_book_scope ON sync_scope_state(book_id, scope_user_id);

DROP TABLE IF EXISTS feedback;

CREATE TABLE feedback (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT DEFAULT NULL,
  content CLOB NOT NULL,
  contact VARCHAR(128) DEFAULT NULL,
  ip VARCHAR(64) DEFAULT NULL,
  user_agent VARCHAR(255) DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
