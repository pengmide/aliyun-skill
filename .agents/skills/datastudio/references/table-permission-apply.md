# 表权限申请与审批（ApplyResourceAccessPermission）

**MaxCompute 表**（或其它资源）访问权限的申请与审批，走 DataWorks 审批流。基于真实验证的完整方法。

分两个视角：**申请人**（提交/查/撤回）与**审批人**（查待审批/同意/驳回）。

## API

申请人侧：

| API | 用途 | 必需参数 |
|-----|------|----------|
| `ApplyResourceAccessPermission` | 提交权限申请 | `ApplyContents` `Reason` |
| `GetProcessInstance` | 查审批单详情/状态 | `ProcessInstanceId` |
| `GetApplicationContents` | **查申请内容明细**（schema/表/权限） | `ProcessInstanceId` |
| `StopProcessInstance` | **撤回/终止审批单** | `ProcessInstanceId` |

审批人侧（详见「审批人视角」）：

| API | 用途 | 必需参数 |
|-----|------|----------|
| `ListPendingApprovals` | 查**待我审批**的单子 | `DefSchema` `ResourceType` |
| `ListMyRelatedApprovals` | 查我作为审批人/相关方的**所有**单子（含已办） | `DefSchema` `ResourceType` |
| `ApproveProcessInstance` | 同意/驳回 | `ProcessInstanceId` `ApprovalAction` `ApprovalComment` |

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
返回 `ProcessInstance`：`Status`（待办 `Running` → 审批通过 `Completed`，实测）、`ApprovalTasks[]`（各环节状态，齐全）、`ApplicatorName`、`Reason`。
> 注意：此处 `Reason`/`Title` 只是文字描述，**不含资源明细**。

### 2.5 查申请内容明细（核对 schema/表/权限）
```bash
aliyun dataworks-public GetApplicationContents --ProcessInstanceId <申请单ID>
```
> 返回 `Data.Contents[]`，每项含 `Resource.MetaData`（JSON 字符串，含 workspace/project/**schema**/table/tenant）和 `AccessTypes`。**这是核对申请到底提了什么（含 schema）的正确方式**。

### 3. 审批（审批人操作）
```bash
aliyun dataworks-public ApproveProcessInstance --ProcessInstanceId <ID> --ApprovalAction Agree|Deny --ApprovalComment "..."
```
> `ApprovalAction` 合法值为 `Agree`（同意）/ `Deny`（拒绝），无"撤回"选项（撤回见 `StopProcessInstance`）。`ApprovalComment` 是**必填**。详细流程见「审批人视角」。

### 4. 撤回申请（申请人操作）
```bash
aliyun dataworks-public StopProcessInstance --ProcessInstanceId <ID>
```
> 撤回后 `GetProcessInstance` 状态变为 **`Aborted`**。

## 审批人视角（查待审批 → 核查 → 同意/驳回）

### 1. 查「待我审批」的表权限申请

```bash
aliyun dataworks-public ListPendingApprovals --DefSchema MaxCompute \
  --ResourceType '["table"]' --PageSize 50
```

要点：

- `--DefSchema MaxCompute`（资源类型名），`--ResourceType` 传 **JSON 数组字符串**如 `'["table"]'`，传裸值 `table` 报 `InvalidResourceType: JSON Array parsing error`。
- **`--PageSize` 上限 50**：传 100/200 报 `InvalidPageSize`（接口文档写最大 200，实测不成立）。
- `ResourceType` 其它合法值（实测返回空列表、不报错）：`Schema` / `Project` / `Function` / `Resource`。**先按 `table` 查**，确认无残留再抽查其它类型。
- 只关心表权限也**别漏翻页**：`HasMore=true` 时用响应里的 `NextToken` 传 `--NextToken`。

### 2. 读响应结构（**每个元素 = 一个审批单**，不是一张表）

```
Data.HasMore / Data.PageSize / (Data.NextToken)
Data.Data[]                      ← 审批单（ProcessInstanceId 在这一层）
  ├─ ProcessInstanceId, ApplicationTime, DefSchema, Status(=WaitApproval)
  └─ Contents[]                  ← 单内每一张表一条
       ├─ Id, AccessTypes[], FinalAccessTypes[], ExpirationTime
       ├─ Grantee{PrincipalId, PrincipalType}
       └─ Resource{DefSchema, DefVersion, MetaData{project, schema, table, tenant, workspace}}
```

- 顶层 `Status` 用 `WaitApproval`，而 `ListMyRelatedApprovals`/`GetProcessInstance` 里已办结的单子是 `AuthorizeSucceed` / `AuthorizeFailed` / `Canceled` / `Completed` —— **两套状态词表不通用**，别用一套去判断另一套。
- 列表里**没有申请人姓名和申请理由**，要 `GetProcessInstance --ProcessInstanceId <ID>` 取 `ApplicatorName` / `Reason`。

### 3. 审批前核查申请内容（按需裁剪 —— 例如"不允许申请 drop"）

`AccessTypes` 是申请项，`FinalAccessTypes` 是当前判定的生效项，**两者都要看**：

```bash
# 一眼扫出全批出现的权限类型 + 是否含 drop/alter（无输出即通过）
aliyun dataworks-public ListPendingApprovals --DefSchema MaxCompute \
  --ResourceType '["table"]' --PageSize 50 | python3 -c "
import sys,json
for pi in json.load(sys.stdin)['Data']['Data']:
    for c in pi['Contents']:
        for f in ('AccessTypes','FinalAccessTypes'):
            v=c.get(f,[])
            if any(x.lower() in ('drop','alter','truncate','delete') for x in v):
                print('命中:', pi['ProcessInstanceId'], c['Resource']['MetaData'], f, v)
"
```

MaxCompute 表权限枚举：`select` `describe` `update` `download` `alter` `drop`。注意：

- **删表看 `drop`**（`update` 不含删表能力）。
- 但 `update` = 写数据，可 `INSERT OVERWRITE` **覆盖/清空数据**；`download` = 数据导出。在意"删数据/带出数据"时这两项同样是敏感项，需单独确认。

### 4. 同意 / 驳回

```bash
aliyun dataworks-public ApproveProcessInstance --ProcessInstanceId <ID> \
  --ApprovalAction Agree --ApprovalComment "同意，未申请 drop 权限"
```

- 三参数均必填；成功只返回 `RequestId`，**无业务体**，需另行验证。
- 默认审批流**两级**（提交申请 → 表/项目管理员），审批人只会看到轮到自己那一环的单子；审批后 `GetProcessInstance` 的 `Status` → `Completed`，`ApprovalTasks[].Status` 各环节齐全。
- 多单批量：逐单循环调用即可，无批量接口。

### 5. 审批后验证

```bash
# a) 待办清零：ListPendingApprovals 的 Data.Data 应为 []
# b) 授权落地：
aliyun dataworks-public ListMyRelatedApprovals --DefSchema MaxCompute \
  --ResourceType '["table"]' --PageSize 50 \
  --cli-query 'Data.Data[].[ProcessInstanceId,Status]'
```

`Status` 变 `AuthorizeSucceed` 才算**权限真正生效**（`Completed` 只代表审批流走完）。

## 踩坑要点

1. `Resource.DefSchema` 是 **`MaxCompute`**，用错名会报资源类型不合法。
2. `Grantee.PrincipalId` 是 **DataWorks UserId**，非 RAM 账号名。
3. **必须给 `ExpirationTime`**（未来时间戳），否则 500 `deadline cannot be in the past`。
4. `MetaData` 需**全路径**（workspace→project→schema→table），缺层级会解析失败。
5. 默认审批流：**提交申请(Applicator) → 表/项目管理员(TableOrProjectAdministrator)**，两级。
6. 审批通过后权限才生效；审批人可在 DataWorks 控制台审批中心处理。
7. **撤回**：用 `StopProcessInstance`（非 Approve），撤回后状态 `Aborted`；`ApproveProcessInstance` 的 `ApprovalAction` 只有 `Agree`/`Deny`。
8. 审批侧：`--ResourceType` 必须是 **JSON 数组字符串**（`'["table"]'`）；`--PageSize` **实测上限 50**。
9. 翻页看响应 `HasMore`（`true` 时用响应里的 `NextToken` 传 `--NextToken`）；响应元素是**审批单**（含 `Contents[]` 多张表），别当单表处理。
10. 状态词表有两套：待办用 `WaitApproval`，办结用 `AuthorizeSucceed`/`AuthorizeFailed`/`Canceled`/`Completed`，不可混用。
11. `ApproveProcessInstance` 成功**不返回业务体**（仅 `RequestId`），必须回查 `GetProcessInstance`/`ListMyRelatedApprovals` 确认生效。
