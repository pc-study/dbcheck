#!/usr/bin/env bash
#==============================================================#
# File       :   OS Health Check
# Ctime      :   2022-08-28 23:32:09
# Mtime      :   2024-08-20 13:09:21
# Desc       :   Oracle Database OS Health Check script
# Version    :   2.0.0
# Author     :   Lucifer(pc1107750981@163.com)
# Copyright (C) 2021-2100 Pengcheng Liu
#==============================================================#
# 脚本描述：
#     1. 收集当前运行主机 OS 的信息。
#     2. 收集当前运行数据库的补丁信息。
#     3. 收集当前运行数据库的数据信息。
#
# 用法：
#     ./oscheck.sh
#     举例:
#     1. 巡检当前实例：sh oscheck.sh
#     2. 巡检多个实例 orcl、luciferdb：sh oscheck.sh -o orcl,luciferdb
#==============================================================#
# 导出 PS4 变量，以便 set -x 调试时输出行号和函数参数
export PS4='+${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]}: '
#==============================================================#
#                           全局变量                            #
#==============================================================#
# 获取安装软件以及脚本目录（当前目录）
scripts_dir=$(dirname "$(readlink -f "$0")")
# 获取 oracle 数据库用户名称
dbusers=$(pgrep -f "ora_pmon_" | xargs -n 1 ps -o user= -p | sort -u)
# 获取当前主机名
hostname=$(hostname)
# 获取当前时间
date=$(date +%Y%m%d)
# 巡检文件夹名称
result_dir="$scripts_dir/dbcheck_${hostname}_${date}"
# os 系统文件名称
filename="${result_dir}/oscheck_${hostname}_${date}.txt"
# 巡检文件压缩包名称
tarname="${scripts_dir}/dbcheck_${hostname}_${date}.tar.gz"
# 获取 RAC 环境变量
GI_HOME=$(pgrep -f ohasd.bin | xargs -I {} ps -p {} -o args= | xargs -I {} dirname {} | awk -F'/bin' '{print $1}' | head -n 1)
# alert 日志收集天数，默认 7 天
dbalertdays=7
#==============================================================#
#                           颜色打印                            #
#==============================================================#
function color_printf() {
    local res='\E[0m' default_color='\E[1;32m'
    # 根据颜色参数设置颜色变量
    case "$1" in
    "red")
        color='\E[1;31m'
        ;;
    "green")
        color='\E[1;32m'
        ;;
    "blue")
        color='\E[1;34m'
        ;;
    "light_blue")
        color='\E[1;94m'
        ;;
    "purple")
        color='\033[35m'
        ;;
    *)
        color=${default_color}
        ;;
    esac
    case "$1" in
    "red")
        # 打印红色文本并退出
        printf "\n${color}%-20s %-30s %-50s\n${res}\n" "$2" "$3" "$4"
        exit 1
        ;;
    "green" | "light_blue")
        # 打印绿色或浅蓝色文本
        printf "${color}%-20s %-30s %-50s\n${res}" "$2" "$3" "$4"
        ;;
    "purple")
        # 打印紫色文本并等待用户输入
        printf "${color}%-s${res}" "$2" "$3"
        read -r con_flag
        # 如果用户未输入，默认为继续
        if [[ -z $con_flag ]]; then
            con_flag=Y
        fi
        if [[ $con_flag != "Y" ]]; then
            echo
            exit 1
        fi
        ;;
    *)
        # 打印其他颜色文本
        printf "${color}%-20s %-30s %-50s\n${res}\n" "$2" "$3" "$4"
        ;;
    esac
}
#==============================================================#
#                          日志打印                             #
#==============================================================#
function log_print() {
    echo
    color_printf green "#==============================================================#"
    color_printf green "$1"
    color_printf green "#==============================================================#"
    echo
}
function check_file() {
    # 检查文件是否存在
    if [[ -e "$1" ]]; then
        return 0
    else
        return 1
    fi
}
#==============================================================#
#                             Usage                            #
#==============================================================#
function help() {
    # 打印参数
    print_options() {
        local options=("$@")
        for option in "${options[@]}"; do
            color_printf green "${option%% *}" "${option#* }"
        done
    }
    echo
    color_printf blue "用法: oscheck.sh [选项] 对象 { 命令 | help }"
    color_printf blue "选项: "
    options=(
        "-o Oracle数据库实例名称，用于一次巡检多个实例，示例: -o orcl,luciferdb"
        "-a Oracle数据库实例 alert 日志收集天数，默认 7 天，示例: -a 30"
    )
    print_options "${options[@]}"
}
#==============================================================#
#                       执行 OS 系统检查命令                      #
#==============================================================#
function oscmd() {
    if [[ "$israc" = "YES" ]]; then
        echo "** $hostname:"
        $1 2>/dev/null
        for h in $remotehost; do
            echo "** $(ssh -o StrictHostKeyChecking=no "$h" hostname):"
            ssh -o StrictHostKeyChecking=no "$h" "$1" 2>/dev/null
        done
    else
        echo "** $hostname:"
        $1 2>/dev/null
    fi
}
#==============================================================#
#                          获取数据库补丁信息                     #
#==============================================================#
function get_patch_info() {
    if [[ "$dbver" != "10.2" ]]; then
        echo "dbpatch"
        "$ORACLE_HOME"/OPatch/opatch lspatches 2>/dev/null | sed '$d;/^$/d'
        echo
        if [[ -n "$GI_HOME" ]]; then
            echo "gipatch"
            "$GI_HOME"/OPatch/opatch lspatches 2>/dev/null | sed '$d;/^$/d'
            echo
        fi
    fi
}
#==============================================================#
#                           获取监听信息                         #
#==============================================================#
function get_lsnr_info() {
    # 定义一个变量，保存执行 lsnrctl 命令的路径
    local lsnrctl_path=$ORACLE_HOME/bin/lsnrctl
    echo "lsnrctl"
    # 如果是 RAC 环境，并且数据库版本不是 10.2 或 11.1
    if [[ "$israc" == "YES" ]] && ! [[ "$dbver" == "10.2" || "$dbver" == "11.1" ]]; then
        lsnrctl_path=$GI_HOME/bin/lsnrctl
        local srvctl_path=$GI_HOME/bin/srvctl
        # 获取 listener 的状态信息（去掉以井号 "#" 开头的注释行）
        $srvctl_path status listener 2>/dev/null | grep -v "^\s*\(#\|$\)"
    fi
    # 执行 lsnrctl 命令获取 listener 状态信息
    $lsnrctl_path status listener 2>/dev/null | grep -v "^\s*\(#\|$\)"
    echo
    # 输出 sqlnet.ora 文件内容
    echo "sqlnet"
    # 如果文件存在，则输出其内容（去掉以井号 "#" 开头的注释行）
    if [ -f "$ORACLE_HOME/network/admin/sqlnet.ora" ]; then
        grep -v "^\s*\(#\|$\)" "$ORACLE_HOME/network/admin/sqlnet.ora"
    fi
    echo
}
#==============================================================#
#                          OS 系统检查                          #
#==============================================================#
function get_os_info() {
    # 定义命令名称数组
    commands=(
        "rac"
        "osversion"
        "kernel"
        "cpu"
        "cpuasge"
        "memtotal"
        "memusage"
        "swap"
        "swapusage"
        "loadaverage"
        "upday"
        "time"
        "hosts"
        "sysctl"
        "limits"
        "diskusage"
        "inode"
        "meminfo"
        "freemem"
        "thp"
        "crontab"
    )
    # RAC 检查
    if [[ "$israc" == "YES" ]]; then
        commands+=("ocrcheck" "votedisk" "ocrbackup" "oifcfg")
        # 添加基于 dbver 的 RAC 特定命令
        commands+=("crsstat" "olsnode")
        [[ "$dbver" != "10.2" && "$dbver" != "11.1" ]] && commands+=("crsinit")
    fi
    # 循环遍历数组，使用 case 语句匹配并执行命令
    for command in "${commands[@]}"; do
        echo "$command"
        case "$command" in
        "rac") echo "$israc" ;;
        "osversion") cat /etc/*release 2>/dev/null | head -n 1 ;;
        "kernel") uname -r ;;
        "cpu") awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo ;;
        "cpuasge") vmstat 1 2 | awk 'NR==4 {print 100 - $15}' ;;
        "memtotal") free -m | awk '/Mem:/ {print $2/1024}' ;;
        "memusage") free -m | awk '/Mem:/ {print $3/$2*100}' ;;
        "swap") free -m | awk '/Swap:/ {print $2/1024}' ;;
        "swapusage") free -m | awk '/Swap:/ {print $3/$2*100}' ;;
        "loadaverage") w | grep "load average" | awk -F ": " '{print $2}' ;;
        "upday") w | head -n 1 | awk -F ", " '{print $1}' | cut -c 11- ;;
        "time") date +"%Y-%m-%d %H:%M:%S" ;;
        "hosts") sed '1,2d' /etc/hosts | grep -v '^$' ;;
        "sysctl") grep -E "kernel.shmall|kernel.shmmax|kernel.sem|kernel.shmmni|fs.aio-max-nr|fs.file-max|net.ipv4.ip_local_port_range|net.core.rmem_default|net.core.rmem_max|net.core.wmem_default|net.core.wmem_max|vm.swappiness|vm.nr_hugepages|vm.min_free_kbytes" /etc/sysctl.conf ;;
        "limits") grep -v "^\s*\(#\|$\)" /etc/security/limits.conf ;;
        "diskusage") oscmd "df -PTh" ;;
        "inode") oscmd "df -PTi" ;;
        "meminfo") awk -F": " '/MemTotal|MemFree|MemAvailable|Cached|SwapTotal|SwapFree|AnonHugePages|HugePages_Total|HugePages_Free/ {print $1":"$2}' /proc/meminfo ;;
        "freemem") free -k ;;
        "thp") [[ -e /sys/kernel/mm/transparent_hugepage/enabled ]] && cat /sys/kernel/mm/transparent_hugepage/enabled ;;
        "crontab") crontab -l ;;
        "ocrcheck") "$GI_HOME"/bin/ocrcheck | grep -v '^$' ;;
        "votedisk") "$GI_HOME"/bin/crsctl query css votedisk ;;
        "ocrbackup") "$GI_HOME"/bin/ocrconfig -showbackup | grep -v '^$' ;;
        "oifcfg") "$GI_HOME"/bin/oifcfg getif -global ;;
        "crsstat")
            if [[ "$dbver" == "10.2" || "$dbver" == "11.1" ]]; then
                "$GI_HOME/bin/crs_stat" -t
            else
                "$GI_HOME/bin/crsctl" stat res -t
            fi
            ;;
        "olsnode")
            if [[ "$dbver" != "10.2" && "$dbver" != "11.1" ]]; then
                "$GI_HOME/bin/olsnodes" -n -i -s
            else
                "$GI_HOME/bin/olsnodes" -n -p -i
            fi
            ;;
        "crsinit") "$GI_HOME"/bin/crsctl stat res -t -init ;;
        *) echo "Unknown command: $command" ;;
        esac
        echo
    done
}
#==============================================================#
#                    获取 oracle alert 日志                     #
#==============================================================#
function get_alert() {
    local db_alert_name alertname
    ((N = dbalertdays + 1))
    # 获取alert日志路径
    db_alert_name="$(sqlplus -S / as sysdba <<<"set heading off echo off termout off feed off time off timing off"$'\n'"select value || '/alert_' || instance_name || '.log' from gv\$instance a,gv\$diag_info b where a.inst_id = b.inst_id and upper(a.host_name) like upper('${hostname}%') and b.name = 'Diag Trace';" | tr -d '[:space:]')"
    # alert 日志名称
    alertname="${result_dir}/$(sqlplus -S / as sysdba <<<"set heading off echo off termout off feed off time off timing off"$'\n'"select 'alert_' || instance_name || '.log' from gv\$instance a where upper(a.host_name) like upper('${hostname}%');" | tr -d '[:space:]')"
    if check_file "$db_alert_name"; then
        # 获取 timeline，alert log 中最近的 N 行中可能包含的日期列表
        if [[ "$dbver" == "11.2" || "$dbver" == "12.1" ]]; then
            timeline=$(grep -E '^[A-Za-z]{3} [A-Za-z]{3} [0-9]{1,2} [0-9:]{8} [0-9]{4}' "$db_alert_name" | awk '{print $2, $3, $5}' | uniq | tail -n "$N")
        else
            timeline=$(awk '/^[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}T/ {print substr($1, 1, 10)}' "$db_alert_name" | uniq | tail -n "$N")
        fi
        # 遍历 timeline 中的每一行
        if [[ $timeline ]]; then
            echo "$timeline" | while read -r line; do
                # 查找本地数据库警报文件中匹配的行，并保存行号到 local_dbalert_linenum 变量中
                if [[ "$dbver" == "11.2" || "$dbver" == "12.1" ]]; then
                    db_alert_startday="$(echo "$line" | awk '{print $1, $2, $3}')"
                    local_dbalert_linenum=$(grep -En "^\w{3} ${db_alert_startday// /.* }$" "$db_alert_name" | awk -F: 'NR==1{print $1}')
                else
                    local_dbalert_linenum=$(grep -n "^${line}T" "$db_alert_name" | awk 'BEGIN{FS=":"}NR==1{print $1}')
                fi
                # 如果该行存在，则将从该行开始的后续日志写入新文件中
                if [[ "$local_dbalert_linenum" ]]; then
                    sed -n "${local_dbalert_linenum},\$p" "$db_alert_name" >"$alertname"
                else
                    color_printf green "从 $db_alert_startday 以来 alert 日志没有更新过!" >"$alertname"
                fi
                break
            done
        fi
    fi
    if [[ $remotehost ]]; then
        for host in $remotehost; do
            db_alert_name="$(sqlplus -S / as sysdba <<<"set heading off echo off termout off feed off time off timing off"$'\n'"select value || '/alert_' || instance_name || '.log' from gv\$instance a,gv\$diag_info b where a.inst_id = b.inst_id and upper(a.host_name) like upper('${host}%') and b.name = 'Diag Trace';" | tr -d '[:space:]')"
            alertname="${result_dir}/$(sqlplus -S / as sysdba <<<"set heading off echo off termout off feed off time off timing off"$'\n'"select 'alert_' || instance_name || '.log' from gv\$instance a where upper(a.host_name) like upper('${host}%');" | tr -d '[:space:]')"
            if [[ "$db_alert_name" ]]; then
                if [[ "$dbver" = "11.2" || "$dbver" = "12.1" ]]; then
                    timeline=$(ssh "$host" 'grep -E "^[A-Za-z]{3} [A-Za-z]{3} [0-9]{1,2} [0-9:]{8} [0-9]{4}" '"$db_alert_name"' | awk "{print \$2, \$3, \$5}" | uniq | tail -n '"$N")
                else
                    timeline=$(ssh "$host" 'awk '\''/^[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}T/ {print substr($1, 1, 10)}'\'' "'"$db_alert_name"'" | uniq | tail -n '"$N")
                fi
                if [[ $timeline ]]; then
                    echo "$timeline" | while read -r line; do
                        if [[ "$dbver" == "11.2" || "$dbver" == "12.1" ]]; then
                            db_alert_startday="$(echo "$line" | awk '{print $1, $2, $3}')"
                            local_dbalert_linenum=$(ssh -n "$host" "egrep -n \"^\w{3} ${db_alert_startday// /.* }$\" $db_alert_name | awk -F: 'NR==1{print \$1}'")
                        else
                            local_dbalert_linenum=$(ssh -n "$host" "grep -n \"^${line}T\" $db_alert_name | awk 'BEGIN{FS=\":\"}NR==1{print \$1}'")
                        fi
                        if [[ "$local_dbalert_linenum" ]]; then
                            ssh -n "$host" "sed -n '${local_dbalert_linenum},\$p' $db_alert_name" >"$alertname"
                        else
                            color_printf green "从 $db_alert_startday 以来 alert 日志没有更新过!" >"$alertname"
                        fi
                        break
                    done
                fi
            fi
        done
    fi
}
#==============================================================#
#                         获取 awr 报告                         #
#==============================================================#
function get_awr() {
    # 获取最近7天的 awr 报告
    local inst_num
    for ((i = 0; i <= ${#allhost[@]}; i++)); do
        ((inst_num = i + 1))
        sqlplus -S / as sysdba <<-EOF >/dev/null 2>&1
COLUMN dbid NEW_VALUE _dbid NOPRINT;
SELECT TRIM(dbid) dbid 
FROM v\$database d;
COLUMN snap_beg NEW_VALUE _snap_beg NOPRINT;
COLUMN snap_end NEW_VALUE _snap_end NOPRINT;
SELECT MIN(snap_id) snap_beg 
FROM dba_hist_snapshot b
WHERE b.begin_interval_time >= TRUNC(sysdate) - $dbalertdays
  AND b.dbid = &_dbid
  AND b.startup_time >= (SELECT MAX(startup_time) 
                         FROM gv\$instance);
SELECT snap_end
FROM (
    SELECT LEAD(d.snap_id) OVER (PARTITION BY d.startup_time ORDER BY snap_id) snap_end
    FROM dba_hist_snapshot d,
         v\$instance nd
    WHERE d.instance_number = nd.instance_number
      AND d.dbid = &_dbid
    ORDER BY d.snap_id DESC
) t
WHERE snap_end IS NOT NULL
  AND ROWNUM = 1;
COLUMN awrtitle NEW_VALUE _awrtitle NOPRINT;
SELECT TRIM('$result_dir/awrrpt_' || instance_name || '_' || &_snap_beg || '_' || &_snap_end || '.html') awrtitle
FROM gv\$instance d 
WHERE inst_id = $inst_num;
DEFINE report_type = 'html';
DEFINE dbid = &_dbid;
DEFINE inst_num = $inst_num;
DEFINE num_days = $dbalertdays;
DEFINE begin_snap = &_snap_beg;
DEFINE end_snap = &_snap_end;
DEFINE report_name = &_awrtitle;
@?/rdbms/admin/awrrpti.sql
EOF
    done
}

#==============================================================#
#                          tar logfile                         #
#==============================================================#
function get_db_report() {
    for SID in ${ORACLE_SIDS//,/ }; do
        export ORACLE_SID="$SID"
        log_print "检查数据库实例：$SID"
        color_printf blue "收集数据库 ALERT 日志 ..."
        get_alert
        color_printf blue "收集数据库 AWR 报告 ..."
        get_awr
        # Extract major version number for comparison
        major_ver=$(echo "$dbver" | cut -d. -f1)
        if [ "$major_ver" -ge 12 ]; then
            sql_script="dbcheck12c.sql"
        elif [ "$major_ver" -ge 11 ]; then
            sql_script="dbcheck11g.sql"
        else
            sql_script="dbcheck10g.sql"
        fi
        if check_file "$scripts_dir"/"$sql_script"; then
            sqlplus -S / as sysdba @"${sql_script%.sql}"
        else
            color_printf red "数据库巡检脚本 $sql_script 未找到，请上传至 $scripts_dir 目录下!"
        fi
    done
}
#==============================================================#
#                          tar logfile                         #
#==============================================================#
function tar_logfile() {
    # 切换目录到 $result_dir，并在切换失败时退出函数
    cd "$result_dir" || return
    # 移动日志文件并检查是否成功，如果失败则打印错误消息并返回错误状态
    if ! mv ../dbcheck_*html .; then
        echo
        color_printf red "移动数据库检查报告失败！"
        return 1
    fi
    # 创建压缩包并检查是否成功，如果失败则打印错误消息并返回错误状态
    if tar -zcf "$tarname" -C "$result_dir" .; then
        echo
        color_printf blue "压缩包位置: $tarname"
    else
        color_printf red "创建压缩包失败！"
        return 1
    fi
}
#==============================================================#
#                          Logo 打印                            #
#==============================================================#
function logo_print() {
    cat <<-EOF

   ███████                             ██         ██      ██                    ██   ██   ██        ██████  ██                      ██    
  ██░░░░░██                           ░██        ░██     ░██                   ░██  ░██  ░██       ██░░░░██░██                     ░██    
 ██     ░░██ ██████  ██████    █████  ░██  █████ ░██     ░██  █████   ██████   ░██ ██████░██      ██    ░░ ░██       █████   █████ ░██  ██
░██      ░██░░██░░█ ░░░░░░██  ██░░░██ ░██ ██░░░██░██████████ ██░░░██ ░░░░░░██  ░██░░░██░ ░██████ ░██       ░██████  ██░░░██ ██░░░██░██ ██ 
░██      ░██ ░██ ░   ███████ ░██  ░░  ░██░███████░██░░░░░░██░███████  ███████  ░██  ░██  ░██░░░██░██       ░██░░░██░███████░██  ░░ ░████  
░░██     ██  ░██    ██░░░░██ ░██   ██ ░██░██░░░░ ░██     ░██░██░░░░  ██░░░░██  ░██  ░██  ░██  ░██░░██    ██░██  ░██░██░░░░ ░██   ██░██░██ 
 ░░███████  ░███   ░░████████░░█████  ███░░██████░██     ░██░░██████░░████████ ███  ░░██ ░██  ░██ ░░██████ ░██  ░██░░██████░░█████ ░██░░██
  ░░░░░░░   ░░░     ░░░░░░░░  ░░░░░  ░░░  ░░░░░░ ░░      ░░  ░░░░░░  ░░░░░░░░ ░░░    ░░  ░░   ░░   ░░░░░░  ░░   ░░  ░░░░░░  ░░░░░  ░░  ░░ 

EOF
}
function checkpara_NULL() {
    # 检查参数是否为空
    if [[ -z $2 || $2 == -* ]]; then
        color_printf red "参数 [ $1 ] 的值为空，请检查！"
    fi
}
#==============================================================#
#                           校验传参                            #
#==============================================================#
function accept_para() {
    while [[ $1 ]]; do
        case $1 in
        -o)
            checkpara_NULL "$1" "$2"
            ORACLE_SIDS=$2
            shift 2
            ;;
        -a | --dbalertdays)
            if [[ $2 ]]; then
                dbalertdays=$2
            fi
            shift 2
            ;;
        -h | --help)
            help
            exit 1
            ;;
        *)
            echo
            color_printf red "脚本传参错误，请检查参数 [ $1 ], 执行 sh oscheck -h 可以获得更多帮助！"
            echo
            exit 1
            ;;
        esac
    done
}
function pre_todo() {
    # 检查当前用户是否为数据库用户，使用双方括号 [[ ... ]] 进行条件判断
    if [[ ! $dbusers =~ $USER ]]; then
        color_printf red "当前用户 $USER 不是 Oracle 数据库软件用户，请使用以下用户之一运行此脚本：$dbusers"
    fi
    if [[ $ORACLE_SIDS ]]; then
        # 循环处理 ORACLE_SIDS 中的每个 sid
        for SID in ${ORACLE_SIDS//,/ }; do
            # 检查数据库是否已经启动
            if ! pgrep -f "smon_${SID}" >/dev/null; then
                color_printf red "巡检数据库 [ $SID ] 未启动，请先启动数据库实例或者检查 [ -o ] 参数值 $ORACLE_SIDS 是否正确!"
            fi
        done
    else
        # 设置默认 ORACLE_SID 并检查数据库实例状态
        : "${ORACLE_SIDS:=$ORACLE_SID}"
        if ! pgrep -f "smon_${ORACLE_SIDS}" >/dev/null; then
            color_printf red "巡检数据库 [ $ORACLE_SIDS ] 未启动，请先启动数据库实例或者检查环境变量 $ORACLE_SID 是否设置正确!"
        fi
    fi
    # 避免 glogin.sql 中的 sql 查询，先屏蔽 glogin.sql
    if check_file "$ORACLE_HOME"/sqlplus/admin/glogin.sql; then
        /bin/cp -f "$ORACLE_HOME"/sqlplus/admin/glogin.sql "$ORACLE_HOME"/sqlplus/admin/glogin.sql.oraginal
        > "$ORACLE_HOME"/sqlplus/admin/glogin.sql
    fi
    trap 'end_todo' EXIT
    # 如果目录已存在则删除重建
    [[ -e $result_dir ]] && rm -rf "$result_dir"
    mkdir -p "$result_dir"
    # 获取数据版本
    dbver=$(sqlplus -v | awk '/SQL/{print substr($3,1,4)}')
    # 设置语言环境变量
    export LANG="en_US.UTF-8"
    NLS_LANG=$(sqlplus -S / as sysdba <<<"set heading off echo off termout off feed off time off timing off"$'\n'"select 'AMERICAN_AMERICA.'||property_value from database_properties where property_name = 'NLS_CHARACTERSET';")
    export NLS_LANG
    # 判断是否为 RAC 环境并处理节点间互信
    if pgrep crsd.bin >/dev/null; then
        israc=YES
        all_connections_ok="true"
        allhost=$("$GI_HOME"/bin/olsnodes)
        localhost=$("$GI_HOME"/bin/olsnodes -l)
        remotehost=(${allhost//$localhost/})
        # 循环遍历主机 IP 地址列表
        for ip in "${remotehost[@]}"; do
            # 使用 su 切换到指定用户，执行 ssh 命令检查连接
            if ssh -q -o ConnectTimeout=5 -o ConnectionAttempts=1 -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no "$ip" date >/dev/null 2>&1; then
                all_connections_ok="true"
            else
                # 如果某个连接失败，则标识 all_connections_ok 置为 false，并跳出循环
                all_connections_ok="false"
                break
            fi
        done
        if [[ $all_connections_ok == "false" ]]; then
            color_printf red "RAC 节点互信失败，请检查互信！"
            exit 1
        fi
    else
        israc=NO
        allhost=$hostname
    fi
}
function end_todo() {
    # 恢复 glogin.sql
    if check_file "$ORACLE_HOME"/sqlplus/admin/glogin.sql.oraginal; then
        /bin/mv -f "$ORACLE_HOME"/sqlplus/admin/glogin.sql.oraginal "$ORACLE_HOME"/sqlplus/admin/glogin.sql
    fi
}
#==============================================================#
#                            主函数                             #
#==============================================================#
function main() {
    logo_print
    accept_para "$@"
    pre_todo
    log_print "Oracle数据库主机检查"
    color_printf blue "收集主机 OS 层信息 ..."
    get_os_info >"$filename"
    color_printf blue "收集数据库补丁信息 ..."
    get_patch_info >>"$filename"
    color_printf blue "收集数据库监听信息 ..."
    get_lsnr_info >>"$filename"
    get_db_report
    tar_logfile
    end_todo
}
main "$@"
