#!/usr/bin/env bash
# run_sql_adhoc.sh — 用 DataStudio Adhoc 临时工作流跑一段 ODPS SQL 并回读结果
#
# 链路：ExecuteAdhocWorkflowInstance(提交) -> GetWorkflowInstance(轮询状态+拿BizDate)
#       -> ListTaskInstances(找任务实例) -> GetTaskInstanceLog(拉日志)
#
# 适用于：临时/试运行/验证性 SQL（建表、查询、DML 验证）。
# 不落节点、不进调度，跑完即弃。无直连 MaxCompute 时，这是 CLI 跑 SQL 的唯一入口。
#
# 用法：
#   ./run_sql_adhoc.sh "<SQL 内容>" [任务名]
#   ./run_sql_adhoc.sh "select 1 as a;" smoke_test
#
# 环境变量（有默认值，通常不用改）：
#   DW_PROJECT_ID=672230            项目空间 ID（bdprd）
#   DW_OWNER=1645446608222577       Owner 账号 ID
#   DW_ENV=Dev                      环境（试运行默认 Dev；生产建表用 Prod）
#   DW_REGION=cn-hangzhou
#   DW_RESOURCE_GROUP=group_212862176241921  调度资源组标识

set -euo pipefail

SQL="${1:?用法: run_sql_adhoc.sh \"<SQL 内容>\" [任务名]}"
TASK_NAME="${2:-adhoc_sql}"
# 开 schema 命名空间，使 schema.table（如 ods_member_db.t_member_apple）能正确解析；纯 SQL 不受影响
SQL=$(printf "set odps.namespace.schema=true;\n%s" "$SQL")
PROJECT_ID="${DW_PROJECT_ID:-672230}"
OWNER="${DW_OWNER:-1645446608222577}"
ENV="${DW_ENV:-Dev}"
REGION="${DW_REGION:-cn-hangzhou}"
RESOURCE_GROUP="${DW_RESOURCE_GROUP:-group_212862176241921}"

# 1) 提交 Adhoc 临时工作流（非阻塞，只回 WorkflowInstanceId）
#    注意 Script 内容字段必须用大写 Content，否则执行时报 download code failed
OUT=$(
  aliyun dataworks-public ExecuteAdhocWorkflowInstance \
    --region "$REGION" --ProjectId "$PROJECT_ID" --Owner "$OWNER" \
    --Name "adhoc_${TASK_NAME}_$(date +%s)" --EnvType "$ENV" \
    --Tasks "[{\"ClientUniqueCode\":\"Task_$(date +%s%N)\",\"Name\":\"$TASK_NAME\",\"Type\":\"ODPS_SQL\",\"Owner\":\"$OWNER\",\"Timeout\":3600,\"DataSource\":{\"Name\":\"BDMaxCompute\"},\"RuntimeResource\":{\"ResourceGroupId\":\"$RESOURCE_GROUP\"},\"Dependencies\":[],\"Inputs\":{},\"Outputs\":{},\"Script\":{\"Content\":$(python3 -c "import json,sys;print(json.dumps(sys.argv[1]))" "$SQL")}}]"
)
WF_ID=$(echo "$OUT" | python3 -c "import json,sys;print(json.load(sys.stdin).get('WorkflowInstanceId') or '')")
if [ -z "$WF_ID" ]; then
  echo "!! 提交失败: $OUT" >&2
  exit 1
fi
echo "== 提交 OK，WorkflowInstanceId = $WF_ID =="

# 2) 轮询工作流实例直到 Success/Failure，同时拿归一化 BizDate
BIZDATE=""
STATUS=""
echo "== 轮询工作流实例 =="
for i in $(seq 1 30); do
  sleep 5
  read -r STATUS BIZDATE < <(
    aliyun dataworks-public GetWorkflowInstance --Id "$WF_ID" 2>/dev/null \
      | python3 -c "import json,sys; w=json.load(sys.stdin)['WorkflowInstance']; print(w.get('Status',''), w.get('BizDate',''))"
  )
  echo "  $STATUS (bizdate=$BIZDATE)"
  [ "$STATUS" = "Success" ] && break
  [ "$STATUS" = "Failure" ] && { echo "!! 工作流执行失败" >&2; exit 1; }
done
if [ "$STATUS" != "Success" ]; then
  echo "!! 超时未完成" >&2
  exit 1
fi

# 3) 用 BizDate 找派生任务实例
INST_ID=""
for i in $(seq 1 10); do
  INST_ID=$(
    aliyun dataworks-public ListTaskInstances \
      --region "$REGION" --ProjectId "$PROJECT_ID" --Bizdate "$BIZDATE" \
      --WorkflowInstanceId "$WF_ID" --ProjectEnv "$ENV" --PageNumber 1 --PageSize 20 \
      --cli-query 'PagingInfo.TaskInstances[0].Id' 2>/dev/null \
      | python3 -c "import json,sys; s=sys.stdin.read().strip(); print(s.strip('\"'))"
  )
  [ -n "$INST_ID" ] && [ "$INST_ID" != "null" ] && break
  sleep 3
done
if [ -z "$INST_ID" ] || [ "$INST_ID" = "null" ]; then
  echo "!! 未找到任务实例 (WorkflowInstanceId=$WF_ID, Env=$ENV)" >&2
  exit 1
fi
echo "== 任务实例 ID = $INST_ID =="

# 4) 拉日志（最新一次运行）
echo "== 任务日志 =="
aliyun dataworks-public GetTaskInstanceLog --region "$REGION" --Id "$INST_ID"
