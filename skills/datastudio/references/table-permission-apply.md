# 申请表权限（ApplyResourceAccessPermission）

给用户申请 **MaxCompute 表**（或其它资源）的访问权限，走 DataWorks 审批流。基于真实验证的完整方法。

## API

| API | 用途 | 必需参数 |
|-----|------|----------|
| `ApplyResourceAccessPermission` | 提交权限申请 | `ApplyContents` `Reason` |
| `GetProcessInstance` | 查审批单详情/状态 | `ProcessInstanceId` |
| `GetApplicationContents` | **查申请内容明细**（schema/表/权限） | `ProcessInstanceId` |
| `ListMyRelatedApprovals` | 查「我是审批人」的单子 | `DefSchema` `ResourceType` |
| `ListPendingApprovals` | 查待我审批的单子 | `DefSchema` `ResourceType` |
| `ApproveProcessInstance` | 审批/驳回 | `ProcessInstanceId` `ApprovalAction` |
| `StopProcessInstance` | **撤回/终止审批单**（申请人） | `ProcessInstanceId` |

## ApplyContents 结构（数组，每个条目 = 一张表）

```json
[{
  "AccessTypes": ["select","update","download","describe"],
  "ExpirationTime": 1785835708000,
  "Grantee": {
    "PrincipalId": "202950341597718306",
    "PrincipalType": "RamUser"
  },
  "Resource": {
    "DefSchema": "MaxCompute",
    "MetaData": {
      "workspace": "672230",
      "project": "bdprd",
      "schema": "ods_member_db",
      "table": "t_member_header"
    }
  }
}]
```

### 字段说明

| 字段 | 必填 | 说明 |
|------|------|------|
| `AccessTypes` | ✅ | 申请的权限数组（见下） |
| `ExpirationTime` | ✅ | 到期毫秒时间戳（**必须在未来**，否则报 `deadline cannot be in the past`）|
| `Grantee.PrincipalId` | ✅ | DataWorks UserId（RAM User 的 UID；RamRole 需 `ROLE_` 前缀）|
| `Grantee.PrincipalType` | ✅ | `RamUser` / `RamRole` / `DlfRole` |
| `Resource.DefSchema` | ✅ | 资源类型名，MaxCompute 用 **`MaxCompute`**（不是 maxcompute_table）|
| `Resource.MetaData` | ✅ | 资源全路径声明：workspace→project→schema→table（从 level0 到叶子）|
| `AuthMethod` | 否 | 授权方式，仅 SEVERLESS_STARROCKS 用 ranger |

## MaxCompute 表权限类型（AccessTypes）

`select`（读）、`update`（写）、`download`（下载）、`describe`（描述）、`alter`、`drop`

> 注意：MaxCompute 表**没有 `insert`**，写操作用 `update`。完整枚举以 ResourceSchema 为准。

## 批量申请多张表

`ApplyContents` 是数组，放多个条目即可一次提交多张表：

```bash
APPLY='[{"AccessTypes":["select","update","download","describe"],"ExpirationTime":<未来ms>,"Grantee":{"PrincipalId":"202950341597718306","PrincipalType":"RamUser"},"Resource":{"DefSchema":"MaxCompute","MetaData":{"workspace":"672230","project":"bdprd","schema":"ods_member_db","table":"t_member_header"}}},{"..."}]'
aliyun dataworks-public ApplyResourceAccessPermission --Reason "申请xxx" --ApplyContents "$APPLY"
```

## 完整流程

### 1. 提交申请
```bash
aliyun dataworks-public ApplyResourceAccessPermission \
  --Reason "申请 ods_member_db.t_member_header 读写权限" \
  --ApplyContents '<JSON数组>'
```
> 成功返回 `Data: ["<申请单ID>"]`。

### 2. 查审批单状态
```bash
aliyun dataworks-public GetProcessInstance --ProcessInstanceId <申请单ID>
```
返回 `ProcessInstance`：`Status`（Running/Approved/Rejected/Aborted）、`ApprovalTasks[]`（各环节状态）、`ApplicatorName`、`Reason`。
> 注意：此处 `Reason`/`Title` 只是文字描述，**不含资源明细**。

### 2.5 查申请内容明细（核对 schema/表/权限）
```bash
aliyun dataworks-public GetApplicationContents --ProcessInstanceId <申请单ID>
```
> 返回 `Data.Contents[]`，每项含 `Resource.MetaData`（JSON 字符串，含 workspace/project/**schema**/table/tenant）和 `AccessTypes`。**这是核对申请到底提了什么（含 schema）的正确方式**。

### 3. 审批（审批人操作）
```bash
aliyun dataworks-public ApproveProcessInstance --ProcessInstanceId <ID> --ApprovalAction Approve|Reject --ApprovalComment "..."
```
> 注意 `ApprovalAction` 合法值为 `Agree`（同意）/ `Deny`（拒绝），无"撤回"选项。

### 4. 撤回申请（申请人操作）
```bash
aliyun dataworks-public StopProcessInstance --ProcessInstanceId <ID>
```
> 撤回后 `GetProcessInstance` 状态变为 **`Aborted`**。

## 踩坑要点

1. `Resource.DefSchema` 是 **`MaxCompute`**，用错名会报资源类型不合法。
2. `Grantee.PrincipalId` 是 **DataWorks UserId**，非 RAM 账号名。
3. **必须给 `ExpirationTime`**（未来时间戳），否则 500 `deadline cannot be in the past`。
4. `MetaData` 需**全路径**（workspace→project→schema→table），缺层级会解析失败。
5. 默认审批流：**提交申请(Applicator) → 表/项目管理员(TableOrProjectAdministrator)**，两级。
6. 审批通过后权限才生效；审批人可在 DataWorks 控制台审批中心处理。
7. **撤回**：用 `StopProcessInstance`（非 Approve），撤回后状态 `Aborted`；`ApproveProcessInstance` 的 `ApprovalAction` 只有 `Agree`/`Deny`。
