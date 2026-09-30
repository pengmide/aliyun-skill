# DataStudio（数据开发）Node API 参考

产品代码：`dataworks-public` · API 版本：`2024-05-18` · 默认 region：`cn-hangzhou` · 默认项目：`bdprd`(672230)

> 以**节点（Node）**为核心。动手前跑 `aliyun dataworks-public <ApiName> help` 确认参数。

## 节点 CRUD

| 操作 | API | 必需参数 |
|------|-----|----------|
| 建节点 | `CreateNode` | `ProjectId` `Scene` `Spec` |
| 查列表 | `ListNodes` | `ProjectId` |
| 查详情 | `GetNode` | `Id` |
| 改节点 | `UpdateNode` | `Id` `ProjectId` `Spec` |
| ~~删节点~~ | `DeleteNode` | **禁止执行**（需人工确认） |

## CreateNode

```
* ProjectId   项目空间 ID（如 672230）
* Scene       场景，**默认 `DATAWORKS_PROJECT`**（数据开发目录）。仅手动工作流用 `DATAWORKS_MANUAL_WORKFLOW`（需 ContainerId）
* Spec        FlowSpec JSON（节点完整定义）
   ContainerId
```

## ListNodes（过滤）

```
* ProjectId
   Name          按名称过滤
   ContainerId   按容器/目录过滤
   PageNumber / PageSize
   Scene         场景
   Recurrence    调度类型
   RerunMode     重跑模式
```
> 返回 `PagingInfo.Nodes[]`，节点 ID 在顶层 `Id` 字段。

## GetNode

```
* Id   节点 ID
```
> 返回 `Node.Spec`（FlowSpec），`Node.Name`。

## UpdateNode（增量）

```
* Id       节点 ID
* ProjectId
* Spec     FlowSpec（只改需要变更的字段）
```

## DeleteNode（禁止）

**不执行** `DeleteNode`。删除节点有生产风险，需用户明确人工确认。

## FlowSpec 结构（来自真实样例 cli_odps_demo）

```json
{
  "version": "1.1.0",
  "kind": "CycleWorkflow",
  "spec": {
    "nodes": [{
      "id": "<节点ID>",
      "recurrence": "Normal",
      "instanceMode": "T+1",
      "rerunMode": "Allowed",
      "datasource": { "name": "BDMaxCompute", "type": "odps" },
      "script": {
        "id": "<脚本ID>",
        "path": "个人开发目录/yanjianhao/cli_odps_demo",
        "language": "odps-sql",
        "runtime": { "command": "ODPS_SQL", "commandTypeId": 10, "cu": "0.25" },
        "content": "--MaxCompute SQL\nselect 1;\n"
      },
      "trigger": {
        "type": "Scheduler", "cron": "00 30 00 * * ?",
        "cycleType": "Daily", "timezone": "Asia/Shanghai"
      },
      "runtimeResource": { "resourceGroup": "group_212862176241921", "resourceGroupId": "23400772" },
      "name": "cli_odps_demo",
      "owner": "202950341597718306",
      "inputs":  { "nodeOutputs": [ { "data": "bdprd_root", "sourceType": "Manual" } ] },
      "outputs": { "nodeOutputs": [ { "data": "8839825464414464700", "refTableName": "cli_odps_demo" } ] }
    }],
    "flow": [ { "nodeId": "<节点ID>", "depends": [ { "type": "Normal", "output": "bdprd_root" } ] } ]
  }
}
```

完整样例见 [../examples/cli_odps_demo_node.json](../examples/cli_odps_demo_node.json)。

## 命令类型（runtime.command）

| command | 说明 |
|---------|------|
| `ODPS_SQL` | MaxCompute SQL |
| `SHELL` | Shell |
| `PYODPS` | PyODPS |
| `DATAWORKS_ALGORITHM` | 算法 |
> 以实际支持为准，创建前查 CreateNode help。

## 铁律

1. 动手前跑 `aliyun dataworks-public <ApiName> help` 确认参数。
2. 改节点前先 `GetNode` 拿现有 FlowSpec，再增量 `UpdateNode`。
3. 不确定 API 名 `aliyun dataworks-public --help-search <keyword>`。
4. 敏感信息不落盘、不进命令历史。

## 权限

- node API（ListNodes/GetNode 等）**有权限**。
- file API（ListFiles/ListFolders）**当前 403030**，如需用要 `AliyunDataWorksFullAccess`。
