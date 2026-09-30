# DataWorks 模块 × API × 权限矩阵

产品：`dataworks-public`（2024-05-18）。**权限基于当前用户 `yanjianhao` 实测**。
「有权限」= 实测可达授权层/成功；「无权限」= 实测返回 `403030`。

## 权限总览

当前用户有：**项目空间、节点(Node)、任务/工作流/实例、函数、资源、参数、数据集成(DI)**
当前用户无：**文件(File)、目录(Folder)、业务流程(Business)、数据源(DataSource)、数据地图/元数据**

| 模块 | 权限状态 | 需要的 RAM 策略 |
|------|---------|----------------|
| 项目空间 | ✅ | DataWorks 基础 |
| 节点 Node | ✅ | dataworks 节点权限 |
| 文件/目录 | ❌ | 需 `AliyunDataWorksFullAccess` 或 dataworks:ListFiles/ListFolders |
| 业务流程 Business | ❌ | 需 dataworks:ListBusiness |
| 函数/资源/参数 | ✅ | dataworks 基础 |
| 数据源 DataSource | ❌ | 需 dataworks:ListDataSources |
| 数据地图/元数据 | ❌ | 需 `AliyunDataWorksFullAccess` + 数据地图权限 |
| 任务/工作流/实例 | ✅ | dataworks 运维权限 |
| 数据集成 DI | ✅ | dataworks:ListDIJobs 等 |

---

## 1. 项目空间

| API | 能力 | 权限 |
|-----|------|------|
| `ListProjects` | 查项目空间列表 | ✅ |
| `GetProject` | 查项目详情 | ✅ |
| `CreateProject` / `UpdateProject` / `DeleteProject` | 建/改/删项目 | ❓ 未测（高风险） |

## 2. 节点 Node（DataStudio 核心）

| API | 能力 | 权限 |
|-----|------|------|
| `ListNodes` | 查节点列表 | ✅ |
| `GetNode` | 查节点详情（FlowSpec） | ✅ |
| `CreateNode` | 创建节点 | ✅ |
| `UpdateNode` | 修改节点 | ✅ |
| `DeleteNode` | 删除节点 | ⚠️ **禁止执行**（需人工确认） |
| `ListNodeDependencies` | 查节点依赖 | ❓ 未测 |
| `RenameNode` / `MoveNode` | 重命名/移动 | ❓ 未测 |

## 3. 文件 / 目录（File / Folder）

| API | 能力 | 权限 |
|-----|------|------|
| `ListFiles` | 查文件列表 | ❌ |
| `GetFile` / `CreateFile` / `UpdateFile` / `DeleteFile` | 文件 CRUD | ❌（推测） |
| `ListFolders` | 查目录 | ❌ |
| `CreateFolder` / `UpdateFolder` / `DeleteFolder` | 目录 CRUD | ❌（推测） |
| `SubmitFile` / `DeployFile` | 提交/发布 | ❌（推测） |

> 文件体系需 `AliyunDataWorksFullAccess`。**当前走 node 体系**（见 datastudio）。

## 4. 业务流程 Business

| API | 能力 | 权限 |
|-----|------|------|
| `ListBusiness` | 查业务流程列表 | ❌ |
| `CreateBusiness` / `GetBusiness` / `UpdateBusiness` / `DeleteBusiness` | 业务流程 CRUD | ❌（推测） |

## 5. 函数 / 资源 / 参数

| API | 能力 | 权限 |
|-----|------|------|
| `ListFunctions` | 查 UDF 函数 | ✅ |
| `CreateFunction` / `UpdateFunction` / `GetFunction` | 函数 CRUD | ✅（推测） |
| `ListResources` | 查资源文件 | ✅ |
| `CreateResource` / `GetResource` / `UpdateResource` | 资源 CRUD | ✅（推测） |
| `ListParameters` | 查参数 | ✅ |
| `CreateParameter` / `GetParameter` / `UpdateParameter` | 参数 CRUD | ✅（推测） |

## 6. 数据源 DataSource

| API | 能力 | 权限 |
|-----|------|------|
| `ListDataSources` | 查数据源列表 | ❌ |
| `GetDataSource` / `CreateDataSource` / `UpdateDataSource` / `DeleteDataSource` | 数据源 CRUD | ❌（推测） |
| `TestDataSourceConnectivity` | 测试连通性 | ❌（推测） |

## 7. 任务 / 工作流 / 实例（运维）

| API | 能力 | 权限 |
|-----|------|------|
| `ListTasks` | 查任务列表 | ✅ |
| `GetTask` | 查任务详情 | ✅ |
| `ListWorkflowDefinitions` | 查工作流定义 | ✅ |
| `GetWorkflowDefinition` | 查工作流定义详情 | ✅ |
| `ListWorkflowInstances` | 查工作流实例 | ✅ |
| `ListTaskInstances` | 查任务实例（Bizdate 默认 `${workspace.lastday}`） | ✅ |
| `GetWorkflow` / `GetWorkflowInstance` | 查工作流/实例详情 | ✅ |
| `GetTaskInstance` | 查任务实例详情 | ✅ |
| 实例操作：`RerunTaskInstances` / `StopTaskInstances` / `SetSuccessTaskInstances` | 重跑/停止/置成功 | ⚠️ 需真实实例 ID 确认 |

## 8. 数据集成 DI

| API | 能力 | 权限 |
|-----|------|------|
| `ListDIJobs` | 查数据集成任务 | ✅ |
| `GetDIJob` | 查数据集成任务详情 | ✅ |
| `CreateDIJob` / `UpdateDIJob` / `DeleteDIJob` | DI 任务 CRUD | ❓ 未测 |
| `StartDIJob` / `StopDIJob` / `GetDIJobLog` | 启停/日志 | ❓ 未测 |

## 9. 数据地图 / 元数据（Data Map）

| API | 能力 | 权限 |
|-----|------|------|
| `ListMetaCollections` | 查数据地图集合 | ❌ |
| `ListDatabases` / `ListSchemas` / `ListTables` | 查库/模式/表 | ❌ |
| `GetTable` / `GetSchema` / `GetMetaEntity` | 表/元数据详情 | ❌ |
| `ListLineages` | 血缘 | ❌ |
| `ListDatasets` | 数据集 | ❌ |

> 数据地图 API 需 `AliyunDataWorksFullAccess` + 专门的数据地图权限。

---

## 常用 RAM 权限名

| 策略 | 覆盖 |
|------|------|
| `AliyunDataWorksFullAccess` | DataWorks 全部（文件/目录/数据源/数据地图等） |
| `AliyunDataWorksReadOnlyAccess` | 只读（含数据地图只读） |

## 备注

- 「❓未测」= 未实际验证，权限状态待确认（多数与同组 API 一致）。
- `Bizdate`（任务实例）参数为**时间戳毫秒**，非日期字符串。**默认值用 `${workspace.lastday}`（业务日期前一天）**，见下方「bizdate 默认 lastday」。
- 敏感操作（Delete*、Stop*、Rerun*）执行前需人工确认。

## bizdate 默认 lastday

查询任务/工作流实例时，`Bizdate` 默认用 **`${workspace.lastday}`**（DataWorks 调度参数 = 业务日期前一天，即昨天）。

CLI 手动调用时，把 `${workspace.lastday}` 换算为**昨天 00:00 的毫秒时间戳**传给 `--Bizdate`：

```bash
# lastday = 昨天（macOS/Linux）
LAST_DAY=$(date -j -v-1d "+%Y-%m-%d" 2>/dev/null || date -d "yesterday" "+%Y-%m-%d")
BIZDATE_MS=$(($(date -j -f "%Y-%m-%d" "$LAST_DAY" "+%s" 2>/dev/null || date -d "$LAST_DAY" "+%s")*1000))

# 查 lastday（昨天）的任务实例
# 默认查 lastday，如需指定其它业务日期自行替换 BIZDATE_MS
aliyun dataworks-public ListTaskInstances --ProjectId 672230 --Bizdate $BIZDATE_MS --PageNumber 1 --PageSize 10
```

> 说明：`${workspace.lastday}` 是调度系统内置参数，在节点运行时自动求值；CLI 手动查询时需自行换算成毫秒时间戳。默认即查昨天的实例。
