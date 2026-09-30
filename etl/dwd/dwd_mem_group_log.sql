----####################################################################

----# 任务功能说明：企微群成员明细表开发

----# 库表命名：ODPS 三段式 project.schema.table

----# project = bdprd，schema：源表 ods_wechat_app_db / 目标表 dwd

----# 作者：yanjh

----# 修改记录

----# 版本     修改人                修改日期                修改说明

----# v001     yanjh                2025-11-11             v0

----# v002     yanjh                2026-09-30             Hive SQL 改为 ODPS(MaxCompute) SQL

----####################################################################



set odps.namespace.schema=true;--开启 schema 三层模型，表名按 project.schema.table 书写

set odps.task.name=dwd_mem_group_log_da;--设置job名

set odps.task.wlm.quota=root.etl;--设置跑数队列（Quota组）

-- 以下 Hive 参数在 ODPS 上无对应或不需要：动态分区默认支持，
-- 输入目录递归属于表语义，执行引擎不可切换，
-- 小表 mapjoin 由优化器自动决定（需强制时用 /*+ mapjoin(t) */ 提示）。







insert overwrite table dwd.dwd_mem_group_log_da partition(dt='${bizdate}')

select

    group_info.chat_id

    , group_info.chat_name

    -- , group_log.group_chat_id

    , group_info.leader_id

    --企微用户标识

    , group_log.user_id

    --中台用户标识（外部用户没有登录小程序会为null）

    , ext_user.member_id

    , group_log.user_del

    , group_info.group_chat_status

    , group_info.group_del

    , scope.store_id

    -- , store.sp_store_name

    , group_log.join_time

    , group_log.updated_at

    , row_number() over (partition by group_info.chat_id, group_log.user_id order by group_log.join_time desc) join_desc_rn

from

    --群信息

    --分区全量表

    (

        select

            --群id

            chat_id

            , chat_name

            --群主id

            , corp_user_id as leader_id

            , group_chat_status

            , deleted as group_del

        from

            bdprd.ods_wechat_app_db.t_corp_group_chat

        where

            dt = '${bizdate}'

    ) group_info

left join

    --群成员信息（进群退群日志表）

    --分区全量表

    (

        select

            group_chat_id

            --群成员id

            , user_id

            , user_type

            , join_time

            , updated_at

            , deleted as user_del

        from

            bdprd.ods_wechat_app_db.t_corp_group_chat_user

        where

            dt = '${bizdate}'

			--针对历史重跑过滤数据

			and substr(cast(join_time as string), 1, 10) <= '${bizdate}'

    ) group_log

on

    group_info.chat_id = group_log.group_chat_id

left join

    --群主和门店关系表

    --分区全量表

    (

        select

            --门店

            scope_id AS store_id

            --群主id

            , corp_user_id as leader_id

        from

            bdprd.ods_wechat_app_db.t_corp_user_power_scope

        where

            dt = '${bizdate}'

            and scope_type = 2

    ) scope

on

    group_info.leader_id = scope.leader_id

left join

    --分区全量

    (

        select

            --映射内部会员id（根据union_id）

            member_id

            --外部联系人在微信开放平台的唯一身份标识（微信unionid）

            , union_id

            --外部联系人的类型，1表示该外部联系人是微信用户，2表示该外部联系人是企业微信用户

            , user_type

            -- 外部联系人的userid

            , corp_external_user_id

        from

            bdprd.ods_wechat_app_db.t_corp_external_user

        where

            dt = '${bizdate}'

    ) ext_user

on

    group_log.user_id = ext_user.corp_external_user_id

;
