# 数据同步深度分析（收入/支出为核心）

本文是对当前项目“记账数据（收入/支出/转账）同步”的端到端梳理：客户端 → 网络协议 → 服务端 → SQL 表结构 → 性能/数据量 → 容错与潜在漏同步点。  
目标是回答三类问题：

1) **同步链路是否会漏拉/漏推/丢字段/重复应用**（尤其是收入、支出、转账配对）。  
2) **哪些地方容易出 BUG**（游标、幂等、冲突、异常回滚、数据模型不一致）。  
3) **SQL 结构是否合理、哪些字段/表是否多余、数据量上来后的策略**（索引、保留期、清理任务）。

> 说明：本文基于代码静态分析 + 本地测试（`flutter test`/`mvn test`）推断行为；仍建议结合线上慢查询、错误日志、真实业务量做二次校验。

---

## 1. 当前同步“覆盖范围”与核心实体

### 1.1 已同步的数据类型（按频率/重要性）

1) **账单（收入/支出/转账）**：v2 协议  
   - 客户端：`lib/services/sync_engine.dart` 负责 push/pull  
   - 服务端：`remark_backend/src/main/java/com/remark/money/service/SyncV2Service.java`
   - 服务器表：`bill_info` + `bill_change_log` + `sync_op_dedup` + `sync_scope_state`

2) **预算（低频元数据）**：v1 协议（独立 upload/download）  
   - 客户端：`lib/services/sync_service.dart` `budgetUpload/budgetDownload`  
   - 服务端：`remark_backend/src/main/java/com/remark/money/controller/SyncController.java`
   - 服务器表：`budget_info`

3) **账户（低频元数据）**：v1 协议（独立 upload/download，已引入 tombstone）  
   - 客户端：`lib/services/sync_service.dart` `accountUpload/accountDownload`  
   - 服务端：`remark_backend/src/main/java/com/remark/money/controller/SyncController.java`
   - 服务器表：`account_info`

### 1.2 元数据（分类/标签）跨设备一致

你确认“分类/标签必须跨设备同步”后，已补齐两条链路：

- **分类（categories）**：新增服务端表 `category_info` + `/api/sync/category/upload|download`；客户端用 `CategoryDeleteQueue` 上报删除 tombstone，并在 meta sync 中下载覆盖本地分类列表。
- **标签（tags）**：新增服务端表 `tag_info` + `/api/sync/tag/upload|download`；客户端用 `TagDeleteQueue` 上报删除 tombstone，并在 meta sync 中下载覆盖本地标签列表。
- **标签关系（record_tags）**：不直接同步本地 `record_id` 映射；随账单 v2 同步，通过 `tagIds` 传输；服务端用关系表 `bill_tag_rel_user` 存储（替代 `bill_info.tag_ids` JSON），客户端落本地 `record_tags`。

仍未覆盖（若将来需要跨设备一致）：模板、循环记账、提醒、设置等。

---

## 2. 客户端同步链路（收入/支出/转账）

客户端同步由 `SyncEngine` 驱动，分为两个层次：  
**账单（高频）**走 v2（outbox + push/pull）；**元数据（低频）**走 v1（预算/账户）。

### 2.1 本地数据模型与存储形态

#### 2.1.1 账单本地模型（Record）

`lib/models/record.dart`

- `amount`：绝对值；方向由 `direction` 决定（`out`=支出，`income`=收入）  
- `includeInStats`：是否纳入统计  
- `pairId`：转账配对 ID（两条账单共享一个 `pairId`）

#### 2.1.2 两套本地持久化（必须区分）

项目存在 **SharedPreferences 版** 与 **SQLite DB 版** 两套仓库实现；同步逻辑在两套模式下要一致，否则会出现“同一字段在某一模式丢失”。

- DB 模式：`lib/database/database_helper.dart` + `lib/repository/record_repository_db.dart`
- SP 模式：通常是 `RecordRepository`（根据 `RepositoryFactory` 决定）

**关键风险（已修复）**：DB 模式 `records` 表原本没有 `pair_id` 列，导致转账配对信息在 DB 模式下会丢失（跨设备/重装后无法复原转账关联）。  
修复内容：

- `lib/database/database_helper.dart`：DB 版本升级到 9，新增 `pair_id` 列与迁移  
- `lib/repository/record_repository_db.dart`：写入/读取/云端 apply 都保留 `pair_id`

### 2.2 v2 同步的核心设计：Outbox + 幂等 opId + 乐观锁

#### 2.2.1 Outbox（本地变更队列）

`lib/services/sync_outbox_service.dart`

本地任何“新增/修改/删除账单”先写入 outbox（透明后台同步），outbox item 的核心字段：

- `book_id`
- `op`（upsert/delete）
- `payload`（包含 `opId`、`expectedVersion`、`bill`…）

这里的 `opId` 是**幂等键**：同一操作重复 push 必须得到相同结果（防止弱网重试导致重复插入）。

#### 2.2.2 v2Push（把 outbox 推到服务端）

`lib/services/sync_engine.dart:_uploadOutboxV2`

主要步骤：

1) `loadPending(bookId, limit: 1000)` 聚合同账本 outbox，尽量一次 push 降低 RTT
2) 对 “create 且需要 serverId” 的记录，先调用 `/api/sync/v2/ids/allocate` 分配 ID（避免服务端逐条插入取自增导致并发冲突/回填复杂）
3) 调 `/api/sync/v2/push` 发送 ops
4) 按服务端逐条结果处理：
   - `applied`：删除 outbox；回填本地 `serverId/serverVersion`
   - `conflict`：写入 `SyncV2ConflictStore`，从 outbox 移除，等待用户/策略处理
   - `error`：
     - `retryable=false`：直接隔离到冲突/错误存储，避免无限重试
     - `retryable=true/缺省`：有限次数重试；超过次数进入隔离（避免卡死）

**已加固点（防 BUG/卡死）**：

- 响应缺失 opId：不会直接丢；会重试并带 retry 次数，避免“服务器返回不完整导致本地丢数据”
- 连续循环无进展：检测“本轮 push 没有删除/更新 outbox”就退出，避免死循环占用 CPU

#### 2.2.3 v2Pull（从服务端拉增量）

`lib/services/sync_engine.dart:_pullV2`

主要步骤：

1) 从 `SyncV2CursorStore` 读出 `lastChangeId`（按 bookId 保存）
2) 调 `/api/sync/v2/pull?cursor=...&limit=...` 拉取变更列表 `changes`
3) 应用到本地（DB 模式会走 `RecordRepositoryDb.applyCloudBillsV2`）
4) 写回新的 cursor（防止重复拉）

**已加固点**：

- 防止 cursor 不推进导致无限拉同一页（服务端 bug / 客户端逻辑 bug 都会触发）：若 `hasMore=true` 但 `nextCursor` 没变，直接 stop
- 最大分页上限：防止异常数据量/协议问题导致一次 sync 过久
- `cursorExpired` 处理：当服务端因保留期清理导致 cursor 落在“已被清理的 change_log”之前，客户端会重置 cursor 并触发重新拉取（见 4.3）

### 2.3 元数据同步（账户/预算）与账单同步的关系

`SyncEngine.syncMeta` 单独负责预算与账户：  
原因是这类数据变更低频，不适合每次 outbox 变化都 pull；账单高频才需要 outbox。

账户同步特别点：

- 已引入 **tombstone（软删除）**：客户端 `AccountDeleteQueue` 记录被删账户，上传到服务端，避免“下载列表缺失就硬删”的危险行为（会导致误删）。

---

## 3. 服务端 v2 同步链路（账单）

### 3.1 表结构与职责划分

#### 3.1.1 `bill_info`（账单主表）

职责：存储账单最终态。关键字段：

- `id`：账单 serverId（可由 allocate 分配）
- `user_id` / `book_id`：归属
- `amount` + `direction`：金额与方向（0=支出，1=收入）
- `bill_date`：账单时间
- `include_in_stats`
- `pair_id`：转账配对
- `is_delete`：软删除
- `version`：乐观锁版本（服务端自增）
- `update_time`：最后更新时间（用于列表/统计/同步策略）

#### 3.1.2 `bill_change_log`（变更日志）

职责：为 pull 提供“增量变更序列”。关键字段：

- `change_id`：全局递增游标（pull 的 cursor）
- `book_id` + `scope_user_id`：变更可见范围（共享账本用 `0`）
- `bill_id` + `bill_version`：变更指向的账单与版本
- `op`：0=upsert，1=delete
- `created_at`

#### 3.1.3 `sync_op_dedup`（opId 幂等去重）

职责：保证 push 的“同一 opId 只应用一次”。关键字段：

- `user_id` + `book_id` + `op_id` 唯一约束：同用户同账本同 opId 幂等
- `status/bill_id/bill_version/error`：返回给客户端的结果缓存
- `request_id/device_id/sync_reason/created_at`：观测与追踪

> 这张表看似“多余”，但它承担的是 **push 幂等**，`bill_change_log` 不含 opId，无法替代。  
若想移除，需要把 opId 持久化到变更日志或账单表并构建等价幂等机制（代价更大，且仍需保留一定历史）。

#### 3.1.4 `sync_scope_state`（pull 引导/重建状态）

职责：记录某 book/scope 是否“已完成初始化引导（bootstrap）”。  
当 change_log 被清理或新设备首次同步时，需要知道是否应执行一次“全量引导”。

### 3.2 Push：事务内处理 + 按 opId 幂等

`remark_backend/.../SyncV2Service.java:push`

核心原则：

- 一个 push 请求整体在事务内：**如果出现非预期异常会回滚整个批次**，避免部分写入导致“本地以为成功但服务端部分失败”的不一致。
- 每个 op 都先查 `sync_op_dedup`：存在则直接复用历史结果（实现幂等）。
- 对 upsert/delete 基于 `expectedVersion` 做乐观锁冲突判断：
  - `expectedVersion` 与服务端 `version` 不一致 → `conflict`，返回 `serverBill`
  - 一致 → 应用，版本递增，写 change_log

已做的健壮性：

- 参数缺失、非法 billDate 等视为 `IllegalArgumentException`：返回 `retryable=false` 并写入 dedup，避免客户端无限重试。

### 3.3 Pull：limit+1 与 hasMore 正确性

`remark_backend/.../SyncV2Service.java:pull`

关键点：

- 采用 **limit+1** 查询：取 `limit+1` 条用于判断是否还有更多（避免“刚好等于 limit”无法知道是否结束）。
- `nextChangeId` 作为 cursor 返回，客户端保存为下一次起点。

### 3.4 共享账本（bookId 数字）与 scope_user_id

服务端会根据 bookId 是否为数字判断“共享账本”：

- 共享账本：`scope_user_id=0`（所有成员可见同一变更序列）
- 个人账本：`scope_user_id=userId`（每人一份变更序列）

这直接影响 `bill_change_log` 的数据量与查询索引设计（共享账本更集中，更需要索引/保留期控制）。

---

## 4. 保留期、清理任务与“cursorExpired”协议

### 4.1 为什么需要保留期

`bill_change_log` 与 `sync_op_dedup` 都是增长型表：

- 每一次账单变更都会产生一条 change_log（高频）
- 每一次客户端操作都会产生一条 dedup（高频）

如果不清理，数据量上来后：

- change_log 范围扫描成本上升
- 索引膨胀、缓存命中下降、主从同步/备份成本上升

### 4.2 当前策略：保留 30 天 + 每天凌晨 2 点清理

`remark_backend/src/main/java/com/remark/money/job/SyncRetentionJob.java`

- cron：`0 0 2 * * *`（每天 02:00）
- cutoff：`now - 30 days`
- 批量删除（每批 2000）+ 每批 `sleep 1s`（削峰，避免大事务/锁冲击）
- 不设“轮次上限”：符合“有多少删多少”的要求
- 全局遍历删除（不按用户分批），并用锁避免重入

为此补齐索引（避免全表扫描/大范围回表）：

- `bill_change_log(created_at, change_id)`
- `sync_op_dedup(created_at, id)`

### 4.3 清理后如何避免“漏拉取”

核心问题：客户端保存的 cursor 可能落在“已被清理的 change_id”之前。  
如果继续按旧 cursor 拉取，服务端已经找不到那段日志，会导致客户端永远追不上（漏拉）。

解决：

1) 服务端在 pull 检测 cursor 是否已过期（落在最小保留 change_id 之前）  
2) 返回 `cursorExpired=true` + `nextChangeId=0`  
3) 客户端收到后：
   - 重置本地 cursor 到 0
   - 触发重新 pull（会走 bootstrap 逻辑，重新构建当前账单全量态）

客户端实现：`lib/services/sync_engine.dart`  
服务端实现：`remark_backend/.../SyncV2Service.java:pull`（并会 reset `sync_scope_state.initialized` 以触发 bootstrap）

> 这套机制的关键在于：清理不会“丢最终态”，只丢“增量日志”；当增量追不上时，允许回退到一次“全量引导”。

---

## 5. 是否会漏拉取数据？逐条列出可能性与现状

下面按“最容易漏”的路径列举：

### 5.1 cursor 不推进导致无限重复同一页（已加固）

风险来源：

- 服务端返回 `nextChangeId` 不正确
- 客户端写 cursor 逻辑 bug

现状：客户端检测到 `hasMore=true` 但 cursor 未变会 stop（防死循环），并保留现有 cursor，等待下一次触发（不会把 cursor 写成错误值）。

### 5.2 change_log 被清理导致 cursor 断层（已加固）

风险来源：保留期清理。  
现状：有 `cursorExpired` 协议 + bootstrap，可补齐最终态，不漏。

### 5.3 push 部分失败 / 网络超时导致“本地以为没成功其实成功了”

风险来源：

- 请求超时（客户端没收到结果）但服务端事务已提交

现状：依赖 `opId` + `sync_op_dedup` 幂等。  
客户端重试同 opId，服务端直接返回历史结果，不会重复插入，也不会丢。

### 5.4 push 响应缺失某些 op 的结果（已加固）

风险来源：

- 服务端 bug
- 代理/网关截断

现状：客户端对“missing result for opId”会保留 outbox 并进入 retry 预算；超过预算会隔离（避免永远卡死且不提示）。

### 5.5 本地字段丢失导致“同步本身成功但信息不全”（已修复一项，仍有潜在）

典型：`pairId` 在 DB 模式丢失 → 转账关联丢。  
现状：已补齐 `pair_id` 列并在 DB 读写/迁移/云端 apply 全链路保留。

仍需关注：

- 分类/标签等是否需要同步（见 1.2）

### 5.6 时区/日期格式差异导致 billDate 解析失败（已加固）

风险来源：客户端若发送 `...Z` 或 `+08:00` 的 ISO 日期字符串，服务端 `LocalDateTime.parse` 会失败。  
现状：服务端增加了多格式解析（`LocalDateTime`/`OffsetDateTime`/`Instant`），解析失败会返回 `invalid billDate` 且 `retryable=false`（避免无意义重试）。

---

## 6. SQL 字段/表的“合理性”与可优化点

### 6.1 `sync_op_dedup` 能不能删？能不能用 `bill_change_log` 替代？

结论：**不能直接删**，除非你引入等价幂等机制。

原因：

- `bill_change_log` 不记录 `op_id`，无法判断“同一客户端操作是否已处理”
- 幂等需求是 push 端的“一次性”语义：网络重试、重复提交、客户端崩溃恢复都必须安全

如果一定要合并：

- 方案 A：把 `op_id` 持久化到 `bill_change_log`（每次变更写入），并加唯一约束 `(user_id, book_id, op_id)`  
  问题：change_log 语义变了（混合幂等与增量），仍需保留期；同时 delete/upsert 都要记录 op_id，复杂度上升。

- 方案 B：把 `last_applied_op_id`/幂等窗口存到别的 KV 存储  
  问题：多表/跨存储一致性与事务更复杂。

当前更稳妥的做法是：**保留 `sync_op_dedup`，但做保留期清理**（已实现 30 天）。

### 6.2 字段是否多余/不合理（以数据量角度）

建议从“查询路径”反推字段/索引：

- `bill_info`
  - `update_time`：必要（列表、统计、同步策略）
  - `created_at`：可用于审计/排序；必要性一般
  - `version`：必要（乐观锁）
  - `attachment_url`：若未来要多附件/结构化附件，单字段会受限；但当前够用

- `bill_change_log`
  - `created_at`：对保留期清理必要；并建议 `(created_at, change_id)` 复合索引（已加）
  - `bill_version`：必要（客户端应用时可做版本比较，避免旧变更覆盖新状态）

- `sync_op_dedup`
  - `request_id/device_id/sync_reason`：对排障很有价值；可按需保留（当前保留 30 天后自然收敛）
  - `error`：建议长度与规范化（例如 error_code + message），便于统计

### 6.3 数据量上来后的进一步建议

1) **按 book_id 分区/按时间分区**（MySQL 分区表）  
   - `bill_change_log` 非常适合按 `created_at` 分区，清理变成 drop partition

2) **减少 change_log 写入量**  
   - 高频字段变更可合并（例如同一 bill 在短时间多次修改只保留最终一次），但会影响实时性与回放一致性，需要谨慎

3) **压缩 payload/减少返回字段**  
   - pull 返回的 bill map 若包含大字段（备注、附件）会放大带宽；可做字段裁剪或 gzip

4) **服务器端“按 update_time 增量”替代“change_id 增量”**  
   - 优点：不需要 change_log（减少写入）  
   - 缺点：并发下 update_time 不严格单调、需要更复杂的去重与一致性保障  
   - 综合：当前 change_id 模式更稳、更适合“万无一失”。

---

## 7. 下一步（只聚焦“数据同步”的优化顺序）

在当前已完成的“幂等/冲突/保留期/cursorExpired/pairId”的基础上，若要继续提高“万无一失”，建议顺序：

1) 明确产品是否要求 **分类/标签/模板/循环记账/提醒** 跨设备一致  
   - 若需要：补充对应云端表与 v2 同步（或单独元数据同步）  
   - 若不需要：在客户端明确“分类/标签为本地配置”并给出缺失兜底 UI（但你现在说 UI 不管，可先只做数据层兜底）

2) 为 v2 协议加入 **一致性自检**（可选、低频）
   - 客户端定期（例如每日一次）拉取服务端账本摘要（总数/更新时间范围/hash），与本地对比，发现不一致触发一次 bootstrap

3) 线上观测：埋点/日志
   - push/pull 每次记录：bookId、cursor、changesCount、hasMore、cursorExpired、耗时、错误码
   - 结合 `request_id/device_id/sync_reason` 快速定位“一次同步链路”的全栈日志
