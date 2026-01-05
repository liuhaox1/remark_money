# Remark Money 全功能回溯测试计划（按代码扫描）

> 目标：不漏任何入口/功能点，按“主链路 + 分支链路 + 异常/边界 + 数据一致性 + 同步/冲突 + 非功能”全面覆盖。
>
> 说明：本计划基于仓库内页面/Provider/Service/Repository 的静态扫描整理（不是拍脑袋的“通用记账App”模板）。

---

## 0. 范围与口径

### 0.1 测试范围（模块清单）

**入口路由（`lib/main.dart`）**
- 首页壳：`RootShell`（底部导航：Home / Analysis / Assets / Profile）
- 独立页面路由：`/stats`、`/bill`、`/budget`、`/category-manager`、`/finger-accounting`、`/login`、`/ui-lab`
- 生成路由：`/add`（`AddRecordPage`）

**主要页面（`lib/pages/*`）**
- Home：`lib/pages/home_page.dart`、`lib/pages/home_page_date_panel.dart`
- Bill：`lib/pages/bill_page.dart`
- Analysis：`lib/pages/analysis_page.dart`
- ReportDetail：`lib/pages/report_detail_page.dart`（含图表/成就/分享导出图片）
- AddRecord：`lib/pages/add_record_page.dart`（含模板 RecordTemplate、语音入口、数字键盘等）
- FingerAccounting：`lib/pages/finger_accounting_page.dart`
- Assets：在 `lib/pages/root_shell.dart` 内（账户列表/分组/新增账户流）
- Account：`account_detail_page.dart`、`account_records_page.dart`、`account_form_page.dart`、`add_account_type_page.dart`
- Category：`lib/pages/category_manager_page.dart`
- Budget：`lib/pages/budget_page.dart`
- Recurring：`recurring_records_page.dart`、`recurring_record_form_page.dart`
- SavingsPlan：`savings_plans_page.dart`、`savings_plan_create_page.dart`、`savings_plan_detail_page.dart`
- ExportData：`lib/pages/export_data_page.dart`
- Profile：`lib/pages/profile_page.dart`（礼品码/主题/数据安全/强制修复同步/反馈/条款隐私/VIP入口等）
- Feedback：`lib/pages/feedback_page.dart`
- TermsPrivacy：`lib/pages/terms_privacy_page.dart`
- SyncConflicts：`lib/pages/sync_conflicts_page.dart`
- Login：`lib/pages/login_landing_page.dart`、`lib/pages/login_page.dart`、`lib/pages/register_page.dart`、`lib/pages/account_login_page.dart`
- VIP：`lib/pages/vip_purchase_page.dart`
- VoiceRecord：`lib/pages/voice_record_page.dart`
- UI Lab：`lib/pages/ui_lab_page.dart`

**核心业务层**
- Providers：`lib/providers/*`（Book/Record/Category/Budget/Account/Tag/Recurring/Theme）
- 数据库与迁移：`lib/database/database_helper.dart`（SQLite/加密/迁移/索引/分页）
- Repositories：`lib/repository/*`（DB 与 SharedPreferences 双实现）
- 同步系统：`lib/services/sync_engine.dart`、`lib/services/sync_service.dart`、`lib/services/sync_outbox_service.dart`、`lib/services/sync_v2_*`
- 语音识别：`lib/services/speech_service.dart`、`lib/services/voice_record_parser.dart`、`lib/services/voice_category_alias_service.dart`
- 导入导出：`lib/services/records_export_service.dart`、`lib/utils/data_export_import.dart`、`lib/utils/csv_utils.dart`
- 用户统计：`lib/services/user_stats_service.dart`、`lib/widgets/user_stats_card.dart`

### 0.2 口径（必须全程一致）
- **金额口径**：`Record.amount` 为绝对值；收支方向由 `Record.direction` 决定（`TransactionDirection.out` / `income`）。
- **统计口径**：`Record.includeInStats` 为 false 的记录不应计入统计/报表/预算（除非产品设计另有说明）。
- **时间口径**：日/周/月/年范围边界（含 23:59:59.999）必须统一；跨时区/夏令时需明确策略。
- **一致性口径**：同一范围下：账单列表汇总 = 顶部汇总 = 报表分类汇总 = 导出汇总 = 同步后数据。

---

## 1. 端到端主链路（P0，必须跑通）

### 1.1 “新用户从0到可用”（离线可用）
1) 首次启动 → 数据库初始化/迁移完成  
2) 账本存在（默认账本）  
3) 默认账户存在（`AccountProvider.ensureDefaultWallet`）  
4) 新增一笔支出 → Home/账单/统计/资产余额均正确  
5) 新增一笔收入 → 同上验证  
6) 编辑/删除记录 → 余额与统计回滚正确  

### 1.2 “账单→筛选→报表→导出”
1) 账单页（周/月/年/日）切换 → 范围正确  
2) 搜索关键字 → 命中字段与展示正确  
3) 多条件筛选组合（分类多选/账户多选/金额区间/日期区间/收支类型）→ 结果正确  
4) 进入报表详情 → 分类/趋势/成就数据与账单一致  
5) 导出（Excel/PDF/CSV）→ 文件生成/字段/编码/金额精度/时间正确  
6) 分享导出文件/图片 → 授权/失败提示/重试路径正确  

### 1.3 “同步主链路”（登录态）
1) 未登录离线记账 → outbox（如有）与本地数据正常  
2) 登录后补推 outbox → 云端一致  
3) 多设备同时修改 → 冲突可见、可处理、最终一致  
4) 强制修复同步（Profile 入口）→ 能自愈并给出明确反馈  

---

## 2. 功能脑图（全量覆盖，不漏入口）

> 你可以把每个叶子节点当成“至少 3 条用例：正常/异常/边界”。

### 2.1 启动与基础
- 冷启动/热启动/前后台切换/系统杀进程恢复
- 数据库初始化、迁移（升级前后数据不丢）
- 主题与外观（暗色/风格持久化）

### 2.2 账本（Book）
- 新建/重命名/切换/删除（删除含数据时策略）
- 多账本隔离（记录/标签/预算/存钱计划/定时记账等不串）
- 本地账本升级为服务端账本（`upgradeLocalBookToServer`）

### 2.3 账户/资产（Account/Assets）
- 默认钱包兜底创建（无账户也能记账）
- 新增账户（现金/储蓄卡/信用卡/虚拟/投资/贷款/自定义资产等）
- 账户分组展示、排序、是否计入总资产/概览
- 账户详情/账户流水一致性
- 删除账户：有流水时限制/迁移策略；与同步队列（AccountDeleteQueue）一致
- 余额重建：从记录汇总重算余额（数据库与 SP 两套实现一致）

### 2.4 分类（Category）
- 默认分类初始化（含“未分类”兜底 `top_uncategorized`）
- 新增/编辑/删除分类（隐藏分类 key 不应出现在“记一笔”选择器）
- 分类迁移逻辑（旧 key/旧名称兼容）

### 2.5 标签（Tag）
- 标签增删改查、去重规则（同名返回已有）
- 记录-标签关联（record_tags）：设置/删除/批量加载缓存一致
- 标签删除队列（TagDeleteQueue）与同步一致

### 2.6 记账（AddRecord）
- 支出/收入切换
- 金额校验（最小 0.01；最多 2 位小数；最大值；非法输入）
- 备注长度、必填校验
- 日期选择与边界（跨月/跨年/闰日/未来日期限制）
- 账户/分类选择校验
- 模板（RecordTemplate）：创建/套用/覆盖规则
- 语音记账入口联动（跳转 VoiceRecord）

### 2.7 指尖记账（FingerAccounting）
- 快速输入、撤销/修改（如有）
- 与 AddRecord/账单/统计一致

### 2.8 账单页（Bill）
- 周/月/年/日模式；自动跳周逻辑（若存在）
- 搜索：历史记录、建议列表、清空
- 筛选：分类多选、收支类型、金额区间、账户多选、日期区间
- 筛选摘要展示、清空筛选
- 列表分页/性能（大量记录）
- 进入报表详情、导出、分享路径

### 2.9 统计分析（Analysis）& 报表详情（ReportDetail）
- 分类饼图/趋势折线（数据源、范围、精度）
- 成就展示（计算规则、边界：0 记录/跨月/跨年）
- 从报表跳转到账单/新增记录（回跳参数正确）

### 2.10 预算（Budget）
- 设置/修改/删除预算
- 预算范围与账单范围一致；`includeInStats=false` 不纳入预算
- 同步/冲突备份（BudgetConflictBackupStore 等）

### 2.11 定时记账（Recurring）
- 创建/编辑/禁用/删除
- weekly/monthly 触发策略、补跑策略、重复触发防重
- Runner 前台补齐（`RecurringRecordRunner`）与后台同步（如有）一致

### 2.12 存钱计划（SavingsPlan）
- 创建/编辑/删除、进度/明细
- 同步/冲突备份与删除队列一致

### 2.13 导入导出（Export/Import）
- 导出 Excel/PDF/CSV：字段、编码、金额精度、时间范围、无数据提示
- 导入容错：缺字段/格式错误/重复数据处理
- 分享：文件权限、取消分享、失败提示

### 2.14 登录/VIP/礼品码/反馈/条款
- 登录/注册/短信登录（如存在）、token 清理与本地同步状态清理
- VIP购买页、错误提示与降级体验
- 礼品码兑换（成功/失败/已兑换/网络异常）
- 反馈提交（失败重试、附件如有）
- 条款与隐私页面可达性

### 2.15 同步/冲突（Sync v2）
- pull/push、cursor、summary、retry
- outbox：离线产生、登录后补推、失败重试策略
- 冲突：冲突存储、冲突页展示、解决后数据一致性

---

## 3. 详细用例模板（每个功能必须至少覆盖这些维度）

对每个功能点，至少补齐以下维度（建议写成用例表）：
- **正常流**：最常用路径
- **异常流**：权限拒绝/网络失败/服务端返回失败/本地存储失败
- **边界**：时间边界（跨日/跨月/跨年/闰日/23:59:59.999）、金额边界（0.01/最大值/小数位）、空数据/大数据
- **一致性**：列表↔统计↔报表↔导出↔同步后
- **回归点**：改动最容易影响的联动区域（余额、统计缓存、同步 outbox、删除队列、迁移）

---

## 4. 数据准备（强烈建议：固定“基准数据集”用于回归）

建议准备 2 套数据集：
- **基准集（P0 回归集）**：200~500 笔记录，覆盖所有分类/账户/标签/跨月跨年/不计入统计
- **压力集（性能集）**：1万~5万笔记录，验证账单列表/筛选/统计聚合性能

推荐用“业务层 API/Provider”造数，避免直接写库绕过校验导致假阳性/假阴性。

---

## 5. 已发现的高风险点（优先在冒烟阶段验证）

> 这些不是“肯定有 bug”，而是从代码结构推断的高风险区，建议优先跑用例。

- **登录态/未登录态分支**：本产品支持游客模式，但“登录后能力（同步/VIP/礼品码等）”的入口与提示要清晰，避免用户误以为已登录或误以为数据会自动上云。
- **统计缓存与数据库聚合口径**：`RecordProvider` 同时存在缓存/DB聚合两条路径，易出现“某些页面不刷新/口径不一致”。
- **删除队列 + 同步**：Account/Category/Tag/SavingsPlan 的删除队列与 outbox 的交互，容易产生“删了又回来”或“云端残留”。
- **时间范围边界**：账单周/月/年范围与报表范围必须完全一致，否则用户感知极强。

---

## 6. 回归与自动化建议（不影响现有交付）

### 6.1 建议最先自动化的 P0 冒烟
- 启动后能进入主界面（无崩溃）
- 一键造数成功（`/ui-lab` → QA 工具）
- 新增一笔支出/收入成功（金额校验、保存、回跳刷新）
- 账单页周/月切换成功（范围展示 + 列表不空）
- 导出 CSV 成功（文件生成 + 分享入口可达）

### 6.2 自动化形态建议
- 单测（`test/`）：校验解析/序列化/同步 outbox/时间范围计算/金额校验
- Widget 测试：核心页面空态/错误态渲染、筛选摘要展示
- 集成测试（`integration_test/`）：端到端主链路（造数→记账→账单→统计→导出）
