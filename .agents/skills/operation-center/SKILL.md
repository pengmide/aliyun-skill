---
name: operation-center
description: DataWorks 运维中心：实例查询、补数据、重跑、监控告警等运维操作。
---

# operation-center

运维中心模块：运行（补数据/冒烟测试）、实例查询、重跑。

## 核心认知（务必先读）

1. **节点 ID ≠ 任务 ID**。DataWorks 中 DataStudio 节点（Node）创建后，只有**提交**才生成对应的调度**任务（Task）**。二者 ID 不同（`ListNodeDependencies` 里依赖节点可看到 Node.Id 与 TaskId 同时存在且不同）。
2. **运行/补数据/冒烟测试/实例查询都基于 Task ID**，不认节点 ID。
3. 未提交节点**没有 Task**，无法用 `CreateWorkflowInstances` 运行（报 `Non-existent TaskIDs: [<nodeId>]`）。
4. **临时/试运行 SQL 统一走 Adhoc 链路**（`ExecuteAdhocWorkflowInstance`），**不需要节点有 Task**，SQL 内联直接跑，不落节点、不进调度。见下方「临时跑 SQL（Adhoc）」一节。
5. 判断节点是否有 Task：`ListTasks --ProjectId 672230` 全量扫描 Name 是否命中。

## 运行节点（补数据 / 冒烟测试）

核心 API：`CreateWorkflowInstances`

### 冒烟测试（试运行，Type=SmokeTest）
```bash
aliyun dataworks-public CreateWorkflowInstances \
  --ProjectId 672230 \
  --Type SmokeTest \
  --WorkflowId 1 \
  --Name "<运行名>" \
  --Comment "<说明>" \
  --EnvType Prod \
  --Periods '{"BizDates":[{"StartBizDate":"2026-09-29 00:00:00","EndBizDate":"2026-09-29 00:00:00"}],"BizdateIntervals":[{"StartDate":"2026-09-29 00:00:00","EndDate":"2026-09-29 00:00:00"}]}' \
  --DefaultRunProperties '{"RootTaskIds":["<TaskID>"]}'
```
> `RootTaskIds` 传 **Task ID**（不是节点 ID）。`Periods` 需同时含 `BizDates`（元素为 `{StartBizDate,EndBizDate}`）和 `BizdateIntervals`（元素为 `{StartDate,EndDate}`），缺一个报 `BizdateIntervals not set`。

### 补数据（Type=SupplementData，正式跑历史/指定日期）
```bash
aliyun dataworks-public CreateWorkflowInstances \
  --ProjectId 672230 \
  --Type SupplementData \
  --WorkflowId 1 \
  --Name "<运行名>" \
  --Comment "<说明>" \
  --EnvType Prod \
  --Periods '<同上结构>' \
  --DefaultRunProperties '{"RootTaskIds":["<TaskID>"]}'
```

### 运行后查结果
- `GetCreateWorkflowInstancesResult`：查异步创建结果

## 临时跑 SQL（Adhoc，试运行推荐）

**试运行 / 验证一段 SQL 统一用这条链路**，不需要先建节点、不要求节点有 Task。

封装脚本：`scripts/run_sql_adhoc.sh`（提交 → 轮询找任务实例 → 拉日志，一次完成）

```bash
scripts/run_sql_adhoc.sh "<SQL 内容>" [任务名]
scripts/run_sql_adhoc.sh "create table if not exists bdprd.dwd.t (id string) partition (dt string);" dwd_t
```

链路（底层就是这 4 步，脚本已封装）：

| 步骤 | API | 作用 | 返回 |
|------|-----|------|------|
| 1 | `ExecuteAdhocWorkflowInstance` | 把 SQL 内联进临时工作流提交（非阻塞） | `WorkflowInstanceId` |
| 2 | `GetWorkflowInstance` | 轮询工作流状态到 Success + 拿归一化 `BizDate` | `Status`/`BizDate` |
| 3 | `ListTaskInstances --WorkflowInstanceId --ProjectEnv` | 从临时工作流找派生任务实例 | 任务实例 `Id` |
| 4 | `GetTaskInstanceLog --Id` | 拉任务日志看 `OK`/报错 | 执行日志 |

要点（**均为实测**）：
- **`Script` 内容字段必须用大写 `Content`**（`"Script":{"Content":"<SQL>"}`）。用 `content`（小写）会导致执行时报 `[600:NON_TRANSIENT]:download code failed`（代码未注册）。
- `Tasks` 元素必需字段：`ClientUniqueCode`、`Name`、`Type=ODPS_SQL`、`Owner`、`RuntimeResource.ResourceGroupId`（调度资源组标识，如 `group_212862176241921`）。`DataSource.Name=BDMaxCompute`，`Dependencies:[]`。
- `ExecuteAdhocWorkflowInstance` 只回 `WorkflowInstanceId`，**不阻塞、不回结果**，结果只在任务实例日志里，必须轮询 + 拉日志。
- **`BizDate` 用 `GetWorkflowInstance` 返回的归一化值**（当天 00:00 北京毫秒），别自己猜；`ListTaskInstances --ProjectEnv` 要和提交的 `--EnvType` 一致（Dev↔Dev / Prod↔Prod）。
- **节点内 SQL 用 `schema.table` 两段式，不加 project 前缀**（如 `ods_member_db.t_member_apple`）；写 `bdprd.ods_member_db...` 会报 `ODPS-0130161`（不支持全限定名）。脚本已自动前置 `set odps.namespace.schema=true;` 使 schema.table 可解析。
- **适合**：建表、DML 验证、临时查询等一次性/验证性执行；**不适合**：长期定时任务（应建调度节点落库）。
- 缺省参数（项目 672230 / Owner / Env=Dev / region / 资源组）脚本已内置，可用环境变量 `DW_PROJECT_ID`/`DW_OWNER`/`DW_ENV`/`DW_REGION`/`DW_RESOURCE_GROUP` 覆盖。生产建表把 `DW_ENV=Prod`。

## 实例查询

核心 API：`ListTaskInstances`（`Bizdate` 为必填毫秒时间戳）

```bash
# bizdate 毫秒换算
python3 -c "import datetime; print(int(datetime.datetime.strptime('2026-09-29','%Y-%m-%d').timestamp()*1000))"

aliyun dataworks-public ListTaskInstances \
  --ProjectId 672230 \
  --Bizdate <毫秒时间戳> \
  --TaskName "<节点名>" \
  --PageNumber 1 --PageSize 20
```
> `Bizdate` 是 int（毫秒），`--output json` 在本 CLI 版本不适用（报 bad flag format）。

## 常用辅助 API

| 目的 | API | 备注 |
|------|-----|------|
| 查节点 | `GetNode --Id <nodeId>` | 返回 FlowSpec |
| 列节点 | `ListNodes --ProjectId 672230` | PageSize≤100，返回节点 ID |
| 查任务 | `ListTasks --ProjectId 672230` | 判断节点是否有 Task |
| 节点依赖 | `ListNodeDependencies --Id <nodeId>` | 返回依赖节点的 Node.Id + TaskId |
| 重跑实例 | `RerunTaskInstances` | 需 Task 实例 ID |

## 铁律

1. 动手前跑 `aliyun dataworks-public <ApiName> help` 确认参数。
2. **运行节点前先确认节点已产生 Task**（`ListTasks` 能查到）；未提交节点无法用 CLI 运行。
3. **`RootTaskIds` 用 Task ID，不用节点 ID**。
4. **临时/试运行 SQL 用 Adhoc 链路**（`scripts/run_sql_adhoc.sh`），别用 `CreateWorkflowInstances` 跑未提交节点（会报 `Non-existent TaskIDs`）。
5. 节点 SQL 分区匹配问题：若源表是年月分区（如 `2026-09`）而脚本用 `dt='${bizdate}'`（日期格式），会查不到数据——用 MaxCompute 只读查询验证，必要时改脚本分区条件为 `substr('${bizdate}',1,7)`。
