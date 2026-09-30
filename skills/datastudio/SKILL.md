---
name: datastudio
description: DataWorks DataStudio 数据开发，以节点(Node)为核心：查询、创建、修改、调度、运行 ODPS_SQL 等节点。当需要用 aliyun-cli 开发/管理 DataWorks 数据开发节点（建节点、改节点、查节点、调度）时使用。
---

# datastudio

DataWorks 数据开发模块（DataStudio）。**核心对象是节点（Node）**，用 FlowSpec 定义，不用 file 体系。

## 产品信息

- 产品代码：`dataworks-public`，API 版本：`2024-05-18`
- 默认 region：`cn-hangzhou`
- **默认项目空间：`bdprd`（ProjectId=672230）**
- 凭证：全局 `aliyun`（已配置，见 install skill）

## 核心概念

- **节点（Node）**：数据开发的基本调度单元（ODPS_SQL、Shell、PyODPS 等），用 **FlowSpec** 描述（`GetNode` 返回）。
- **FlowSpec**：节点定义格式（`version:1.1.0, kind:CycleWorkflow`），含 script/trigger/runtimeResource/inputs/outputs。
- 节点有独立权限：`ListNodes`/`GetNode`/`UpdateNode`/`CreateNode` 可用。
- **禁止删除节点**：不对节点执行 `DeleteNode`（生产环境删除风险高，如有删除需求须人工确认）。

## Node 生命周期流程

### 1. 查项目空间
```bash
aliyun dataworks-public ListProjects --PageNumber 1 --PageSize 50
```

### 2. 查节点列表（按项目 + 名称过滤）
```bash
aliyun dataworks-public ListNodes --ProjectId 672230 --Name "cli_odps_demo" --PageNumber 1 --PageSize 50
```

### 3. 查节点详情（拿 FlowSpec）
```bash
aliyun dataworks-public GetNode --Id <节点ID>
```
> 节点 ID 从 ListNodes 输出的顶层 `Id` 字段拿。

### 4. 创建节点（默认 `Scene=DATAWORKS_PROJECT`）
```bash
aliyun dataworks-public CreateNode --ProjectId 672230 --Scene DATAWORKS_PROJECT --Spec '<FlowSpec JSON>'
```
> **`Scene` 默认 `DATAWORKS_PROJECT`**（数据开发目录，创建调度节点固定用此值）。仅手动工作流用 `DATAWORKS_MANUAL_WORKFLOW`（需 ContainerId）。

### 5. 修改节点（增量更新，FlowSpec）
```bash
aliyun dataworks-public UpdateNode --Id <节点ID> --ProjectId 672230 --Spec '<FlowSpec JSON>'
```

> **不提供删除步骤**：禁止 DeleteNode。

## FlowSpec 样例

见 [examples/cli_odps_demo_node.json](examples/cli_odps_demo_node.json) —— 一个真实的 `cli_odps_demo`（ODPS_SQL，Daily 调度）节点定义，可作为创建/修改节点的模板。

要点：
- `spec.nodes[].script.content`：节点脚本（SQL 等）
- `spec.nodes[].script.runtime.command`：命令类型（如 `ODPS_SQL`）
- `spec.nodes[].trigger`：调度 cron / cycleType
- `spec.nodes[].runtimeResource`：调度资源组
- `spec.nodes[].datasource`：数据源（如 `BDMaxCompute`/odps）

## 创建节点所需信息

`CreateNode` 需要 3 个必需参数 + FlowSpec：

| 必需参数 | 说明 | 示例 |
|----------|------|------|
| `ProjectId` | 项目空间 ID | `672230`（bdprd） |
| `Scene` | 创建场景（**默认 `DATAWORKS_PROJECT`**） | `DATAWORKS_PROJECT` |
| `Spec` | 节点 FlowSpec JSON | 见样例 |

FlowSpec 至少要提供：

| 字段 | 说明 | 示例 |
|------|------|------|
| `name` | 节点名（唯一） | `cli_odps_demo` |
| `script.path` | 脚本路径 | `个人开发目录/yanjianhao/xxx` |
| `script.content` | 脚本内容 | `select 1;` |
| `script.runtime.command` | 命令类型 | `ODPS_SQL` |
| `script.language` | 语言 | `odps-sql` |
| `datasource` | 数据源 | `BDMaxCompute`(odps) |
| `trigger` | 调度触发 | cron `00 30 00 * * ?` |
| `runtimeResource` | 调度资源组 | `BD_RG01`（创建前解析实际资源组 ID） |

## 创建节点默认配置

创建 DataStudio 节点时固定使用以下默认值；只有标记为“用户填写”的字段才向用户询问：

- 计算配置：使用项目默认 Quota，不设置节点级 Quota 覆盖。
- 调度资源组：`BD_RG01`。`runtimeResource.resourceGroup` 使用资源组标识，不能把显示名当作 ID；若无法查询 ID，先报权限或信息缺失，不臆填。
- 重跑属性：`rerunMode=Allowed`、`rerunTimes=2`、`rerunInterval=900000`（15 分钟，毫秒）。
- 描述：用户填写。
- 调度周期：用户指定 `cycleType` 和 `cron`，未指定前不创建调度节点。

创建前确认：项目、节点名、命令类型、脚本路径、脚本内容、描述、调度周期、数据源；资源组默认 `BD_RG01`，计算配置默认项目 Quota，重跑使用上述固定值。

## 常用节点查询

| 目的 | 命令 |
|------|------|
| 查全部节点 | `ListNodes --ProjectId 672230` |
| 按名查节点 | `ListNodes --ProjectId 672230 --Name <名>` |
| 查节点详情 | `GetNode --Id <节点ID>` |
| 查任务 | `ListTasks`（任务/实例相关见 operation-center）|

> **bizdate 默认值**：查询任务实例（`ListTaskInstances`）时 `Bizdate` 默认用 **`${workspace.lastday}`**（业务日期前一天）。CLI 手动查询需换算成毫秒时间戳，见 [dataworks-permissions.md](references/dataworks-permissions.md) 的「bizdate 默认 lastday」。

## 铁律

1. 动手前必跑 `aliyun dataworks-public <ApiName> help` 确认参数。
2. 创建/修改节点前先 `GetNode` 拿现有 FlowSpec 再改，别从零编。
3. **禁止删除节点**（`DeleteNode` 不执行，除非用户明确人工确认）。
4. 输出用 `--output json`。
5. 敏感信息不落盘、不进命令历史。

## 申请表权限

给用户申请 MaxCompute 表等资源的访问权限（走审批流），见 [references/table-permission-apply.md](references/table-permission-apply.md)。

支持：单表/多表批量申请、指定权限集（select/update/download/describe 等）、查审批单状态、**撤回审批单**（`StopProcessInstance`）。

## 权限要求

- node 相关 API（`ListNodes`/`GetNode` 等）**有权限**。
- file 相关 API（`ListFiles`/`ListFolders` 等）当前 **403030 无权限**，如用到需 `AliyunDataWorksFullAccess`。

**各模块 API + 权限完整矩阵见 [references/dataworks-permissions.md](references/dataworks-permissions.md)**。
