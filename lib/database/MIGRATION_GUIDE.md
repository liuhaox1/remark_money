# 数据库迁移指南

## 概述

本项目已完成从 SharedPreferences 到加密 SQLite 数据库的迁移架构。数据库使用 `sqflite_sqlcipher` 提供加密支持。

## 已完成的工作

### 1. 数据库基础设施
- ✅ `lib/database/database_helper.dart` - 数据库管理类
  - 加密数据库支持（使用 SQLCipher）
  - 自动迁移脚本（从 SharedPreferences 迁移）
  - 回退路径支持
  - 索引优化
  - 分页查询支持

### 2. 数据库表结构
已创建以下表：
- `records` - 记账记录
- `categories` - 分类
- `accounts` - 账户
- `books` - 账本
- `budgets` - 预算
- `record_templates` - 记录模板
- `recurring_records` - 循环记账
- `app_settings` - 应用设置
- `migration_log` - 迁移日志

### 3. 索引优化
为以下字段创建了索引以提升查询性能：
- `records`: book_id, date, category_key, account_id, (book_id, date), (is_expense, date)
- `categories`: parent_key, is_expense
- `accounts`: type
- `record_templates`: last_used_at

### 4. Repository 实现
- ✅ `lib/repository/record_repository_db.dart` - 记录仓库（数据库版本）
  - 支持分页查询
  - 支持增量写入（批量插入）
  - 支持复杂查询（日期范围、分类、账户等）

### 5. 迁移和回退
- ✅ 自动迁移脚本（从 SharedPreferences 读取并写入数据库）
- ✅ 迁移日志记录
- ✅ 回退路径（`rollbackToSharedPreferences()` 方法）

## 待完成的工作

### 1. 其他 Repository 的数据库实现
需要创建以下数据库版本的 Repository：
- [ ] `CategoryRepositoryDb`
- [ ] `AccountRepositoryDb`
- [ ] `BookRepositoryDb`
- [ ] `BudgetRepositoryDb`
- [ ] `RecordTemplateRepositoryDb`
- [ ] `RecurringRecordRepositoryDb`
- [ ] `ReminderRepositoryDb`

### 2. Repository Factory 更新
更新 `lib/repository/repository_factory.dart` 以支持所有新的数据库 Repository。

### 3. Provider 更新
更新所有 Provider 以使用新的 Repository Factory。

### 4. 测试
- [ ] 单元测试
- [ ] 集成测试
- [ ] 迁移测试
- [ ] 回退测试

## 使用方法

### 初始化数据库
在应用启动时调用：
```dart
await RepositoryFactory.initialize();
```

### 使用 Repository
```dart
final recordRepo = RepositoryFactory.createRecordRepository();
final records = await recordRepo.loadRecords();
```

### 回退到 SharedPreferences
如果遇到问题，可以回退：
```dart
final dbHelper = DatabaseHelper();
await dbHelper.rollbackToSharedPreferences();
```

## 数据库密码

当前使用固定密码 `remark_money_encrypted_key_v1`。**在生产环境中，应该：**
1. 使用设备密钥派生密码
2. 或使用用户设置的密码
3. 或使用安全的密钥存储（如 Keychain/Keystore）

## 性能优化

1. **索引**：已为常用查询字段创建索引
2. **分页**：支持分页查询，避免一次性加载大量数据
3. **批量操作**：支持批量插入/更新
4. **事务**：迁移过程使用事务确保数据一致性

## 注意事项

1. 数据库文件位置：`应用文档目录/remark_money.db`
2. 迁移是一次性的，迁移完成后会标记完成
3. 回退会清除迁移标记，下次启动会重新迁移
4. 数据库版本升级需要在 `_onUpgrade` 中处理

