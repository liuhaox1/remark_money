# 服务器请求审计（客户端）

目标：把 `lib/` 里所有“会请求服务器”的方法一次性盘清楚：**谁在调、什么时候调、是否重复/不必要、可怎么改更稳更省**。

## 1) 客户端请求清单（按 Service）

### `AuthService`（`lib/services/auth_service.dart`）
- `POST /api/auth/send-sms-code`：短信登录发送验证码
- `POST /api/auth/login/sms`：短信验证码登录
- `POST /api/auth/login/wechat`：微信登录
- `POST /api/auth/register`：账号注册
- `POST /api/auth/login`：账号密码登录

风险/优化点
- 登录成功后只做“本地 token 存在性”校验（`isTokenValid`），如果服务端未来引入 token 过期/撤销，需要补 `401` 统一处理（清 token + 引导重登）。

### `BookService`（`lib/services/book_service.dart`）
- `POST /api/book/create-multi`：创建多人账本（服务端会同时插入创建者成员）
- `POST /api/book/refresh-invite`：刷新邀请码
- `POST /api/book/join`：通过邀请码加入账本
- `GET /api/book/list`：获取我的账本列表
- `GET /api/book/members?bookId=...`：获取账本成员列表

触发点（关键）
- 成员列表会被 **统计页/分类管理页/成员页** 使用：`lib/pages/analysis_page.dart`、`lib/pages/category_manager_page.dart`、`lib/pages/book_members_page.dart`

已做优化
- 成员列表 **2 分钟缓存 + in-flight 合并**，避免短时间内多页面重复请求；并在创建多人账本成功后预填“owner=自己”到缓存，减少“创建后立刻拉成员”的一次请求。

### `SyncService`（`lib/services/sync_service.dart`）—— 元数据 v1 + 账单 v2

#### 元数据（v1）
- `GET /api/sync/category/download?deviceId=...&bookId=...`：分类下载（多人账本带 `bookId` 时按 owner 口径）
- `POST /api/sync/category/upload`：分类上传（多人账本仅 owner 可上传）
- `GET /api/sync/tag/download?deviceId=...&bookId=...`：标签下载
- `POST /api/sync/tag/upload`：标签上传
- `GET /api/sync/budget/download?deviceId=...&bookId=...`：预算下载
- `POST /api/sync/budget/upload`：预算上传
- `GET /api/sync/account/download?deviceId=...`：账户下载（按用户维度）
- `POST /api/sync/account/upload`：账户上传
- `GET /api/sync/savingsPlan/download?deviceId=...&bookId=...`：存钱计划下载
- `POST /api/sync/savingsPlan/upload`：存钱计划上传

#### 账单/记录（v2）
- `POST /api/sync/v2/push`：批量推送 outbox
- `GET /api/sync/v2/pull?bookId=...&afterChangeId=...&limit=...`：增量拉取 change_log
- `GET /api/sync/v2/summary?bookId=...`：一致性摘要（仅每 6h 允许检查一次）
- `POST /api/sync/v2/ids/allocate`：预分配 serverId（批量新增）

触发点（关键）
- `pushAllOutboxAfterLogin`：登录成功后补推“未登录期间创建的 outbox”
- `BackgroundSyncManager`：统一调度 `syncBookV2`（push+pull）和 `syncMeta`（v1 元数据）

已做优化（你之前看到的 SQL 过多问题主要在这里）
- `syncMeta`：无本地改动时跳过 upload（分类/标签/存钱计划），减少同表“download+upload+findAll”的重复 SQL
- 登录后避免 `app_start` 同步与 `login` 同步叠加（客户端竞态已处理）
- v2 服务端侧：同一请求内不再重复 `book`/`book_member` 查询（减少你日志里的重复 `BookMapper.findById`）

### 其它
- `FeedbackService`：`POST /api/feedback/submit`
- `GiftCodeService`：`POST /api/gift/redeem`

## 2) 典型“重复/不合理请求”模式（以及怎么避免漏）

### A. 登录/启动竞态导致的“login + app_start”双同步
现象：登录后仍出现 `reason=app_start` 的 v2 pull/summary，导致重复 SQL。

原因：`BackgroundSyncManager.start(triggerInitialSync:true)` 内部有异步 `isTokenValid()`；如果用户在启动后很快登录，异步判断可能在 token 写入后才执行，从而误触发 `app_start` 同步。

处理：登录成功后标记跳过一次 app_start（已实现）。

### B. 多页面重复拉“成员列表”
现象：统计页/分类管理页/成员页都需要成员信息，短时间切换会重复 `GET /api/book/members`。

处理：客户端缓存 + 合并请求（已实现）。

### C. v2 服务端重复查 book / member
现象：同一个 pull/summary 请求里出现多次 `BookMapper.findById`。

原因：服务端 `isServerBook()` 每次都会查询 `book`，而 `assertBookMember()/scopeUserId/sharedBook` 都会调用它。

处理：把“是否 server book + 成员校验”做成一次性判断并复用（已实现）。

## 3) 仍然存在的风险点（建议上线前继续收）

### P0（上线前建议做）
- **401/权限失败的统一处理**：现在很多请求把服务端返回当作普通错误字符串显示，但不会统一清 token/回登录；如果服务端后续收紧权限或 token 过期，会出现“假登录态”。
- **HTTP Client 复用**：`AuthService/BookService/FeedbackService/GiftCodeService` 用的是 `http.get/post`（隐式 client），而 `SyncService` 用的是单例 `http.Client`；建议统一到一个共享 client，减少连接抖动、统一超时/headers/埋点。
- **请求取消/页面卸载**：部分页面 FutureBuilder 请求完成前退出页面，响应回来仍会触发 rebuild/异常提示（现在多数能靠 mounted 避免，但没全覆盖）。

### P1（强烈建议，但可分期）
- **元数据 batch 聚合接口**：登录时 `categories/tags/budget/accounts/savings` 仍是多次请求；提供 `GET /api/sync/meta/batch?bookId=...` 一次返回，能显著降 SQL/RTT。

### P2（中长期）
- **元数据增量同步**：v1 元数据目前是全量 download +（有改动才）upload；可以改成按 `sync_version` 拉 delta（包含 tombstone），进一步减少流量与 DB 压力。
- **多人账本实时性**：多设备一致性目前靠 periodic pull；实时可用 SSE/WebSocket 推 change_id。

## 4) 结论
目前客户端“会打服务器”的入口很集中：**Auth / Book / Sync(v1+v2) / Feedback / Gift**。最大的“上线后爆雷点”一般不是功能本身，而是：
- 启动/登录/前台恢复的触发时机叠加（重复请求 + 重复 SQL）
- 多页面重复拉同一份数据（成员/分类/标签等）
- 401/权限变化导致的登录态错乱

这份清单就是为了把“漏”变成“可核对项”。后续你再给我任何日志，我都能直接对照到具体端点与触发链路，不会靠猜。

