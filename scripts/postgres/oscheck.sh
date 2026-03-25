#!/usr/bin/env bash
#==============================================================#
# File       :   OS Health Check (PostgreSQL)
# Ctime      :   2026-03-25 00:00:00
# Desc       :   PostgreSQL Database OS Health Check script
# Version    :   1.0.0
# Author     :   DBCheck2Word
# Copyright (C) 2024 DBCheck2Word
#==============================================================#
# 脚本描述：
#     1. 收集当前运行主机 OS 的信息。
#     2. 收集当前运行 PostgreSQL 数据库的配置和日志信息。
#     3. 收集当前运行 PostgreSQL 数据库的巡检数据。
#
# 用法：
#     ./oscheck.sh [选项]
#     举例:
#     1. 巡检默认实例：sh oscheck.sh
#     2. 指定用户和数据库：sh oscheck.sh -U postgres -d mydb -p 5432
#==============================================================#
# 导出 PS4 变量，以便 set -x 调试时输出行号和函数参数
export PS4='+${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]}: '
#==============================================================#
#                           全局变量                            #
#==============================================================#
# 获取安装软件以及脚本目录（当前目录）
scripts_dir=$(dirname "$(readlink -f "$0")")
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
# PostgreSQL 连接参数默认值
PG_USER="postgres"
PG_DB="postgres"
PG_PORT="5432"
PG_HOST="/tmp"
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
    color_printf blue "用法: oscheck.sh [选项]"
    color_printf blue "选项: "
    options=(
        "-U PostgreSQL 数据库用户名称，默认 postgres，示例: -U postgres"
        "-d PostgreSQL 数据库名称，默认 postgres，示例: -d mydb"
        "-p PostgreSQL 数据库端口号，默认 5432，示例: -p 5432"
        "-H PostgreSQL 数据库主机地址，默认 /tmp（Unix Socket），示例: -H 127.0.0.1"
        "-h 显示帮助信息"
    )
    print_options "${options[@]}"
}
#==============================================================#
#                       执行 OS 系统检查命令                      #
#==============================================================#
function oscmd() {
    # 本地执行命令，输出主机名前缀
    echo "** $hostname:"
    $1 2>/dev/null
}
#==============================================================#
#                    自动检测 PostgreSQL 环境                     #
#==============================================================#
function detect_pg_env() {
    # 自动检测 postgres 进程获取用户和数据目录
    local pg_pid
    pg_pid=$(pgrep -x postgres | head -n 1)
    if [[ -z "$pg_pid" ]]; then
        # 尝试 postmaster 进程名
        pg_pid=$(pgrep -x postmaster | head -n 1)
    fi
    if [[ -n "$pg_pid" ]]; then
        # 获取 postgres 系统用户
        PG_OS_USER=$(ps -o user= -p "$pg_pid" | tr -d ' ')
        # 获取数据目录：从进程的 /proc/pid/environ 或命令行参数中解析
        PGDATA=$(ps -p "$pg_pid" -o args= | grep -oP '(?<=-D )\S+')
        if [[ -z "$PGDATA" ]]; then
            # 尝试从 /proc 环境变量中获取
            PGDATA=$(tr '\0' '\n' < /proc/"$pg_pid"/environ 2>/dev/null | grep '^PGDATA=' | cut -d= -f2)
        fi
        if [[ -z "$PGDATA" ]]; then
            # 通过 psql 查询
            PGDATA=$(su - "$PG_OS_USER" -c "psql -U $PG_USER -h $PG_HOST -p $PG_PORT -d $PG_DB -tAc \"SHOW data_directory;\"" 2>/dev/null | tr -d ' ')
        fi
    fi
    # 如果仍然为空，使用默认值
    : "${PG_OS_USER:=postgres}"
    : "${PGDATA:=/var/lib/pgsql/data}"
}
#==============================================================#
#                    构建 psql 命令                              #
#==============================================================#
function run_psql() {
    # 以 PostgreSQL 系统用户执行 psql 命令
    su - "$PG_OS_USER" -c "psql -U $PG_USER -h $PG_HOST -p $PG_PORT -d $PG_DB -tAc \"$1\"" 2>/dev/null
}
#==============================================================#
#                          OS 系统检查                          #
#==============================================================#
function get_os_info() {
    # 定义命令名称数组（与 parse_txt_file 解析器要求的 tag_id 一致）
    commands=(
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
    # 循环遍历数组，使用 case 语句匹配并执行命令
    for command in "${commands[@]}"; do
        echo "$command"
        case "$command" in
        "osversion") cat /etc/*release 2>/dev/null | head -n 1 ;;
        "kernel") uname -r ;;
        "cpu") awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo ;;
        "cpuasge") vmstat 1 2 | awk 'NR==4 {print 100 - $15}' ;;
        "memtotal") free -m | awk '/Mem:/ {print $2/1024}' ;;
        "memusage") free -m | awk '/Mem:/ {print $3/$2*100}' ;;
        "swap") free -m | awk '/Swap:/ {print $2/1024}' ;;
        "swapusage") free -m | awk '/Swap:/ {if($2>0) print $3/$2*100; else print 0}' ;;
        "loadaverage") w | grep "load average" | awk -F ": " '{print $2}' ;;
        "upday") w | head -n 1 | awk -F ", " '{print $1}' | cut -c 11- ;;
        "time") date +"%Y-%m-%d %H:%M:%S" ;;
        "hosts") sed '1,2d' /etc/hosts | grep -v '^$' ;;
        "sysctl")
            # PostgreSQL 相关内核参数
            grep -E "kernel.shmmax|kernel.shmall|kernel.sem|vm.swappiness|vm.overcommit_memory|vm.overcommit_ratio|vm.dirty_ratio|vm.dirty_background_ratio|vm.nr_hugepages|net.core.somaxconn|fs.file-max|net.ipv4.ip_local_port_range" /etc/sysctl.conf
            ;;
        "limits") grep -v "^\s*\(#\|$\)" /etc/security/limits.conf ;;
        "diskusage") oscmd "df -PTh" ;;
        "inode") oscmd "df -PTi" ;;
        "meminfo") awk -F": " '/MemTotal|MemFree|MemAvailable|Cached|SwapTotal|SwapFree|AnonHugePages|HugePages_Total|HugePages_Free/ {print $1":"$2}' /proc/meminfo ;;
        "freemem") free -k ;;
        "thp") [[ -e /sys/kernel/mm/transparent_hugepage/enabled ]] && cat /sys/kernel/mm/transparent_hugepage/enabled ;;
        "crontab") crontab -l ;;
        *) echo "Unknown command: $command" ;;
        esac
        echo
    done
}
#==============================================================#
#                    PostgreSQL 专项检查                         #
#==============================================================#
function get_pg_info() {
    # pg_version: PostgreSQL 服务器版本
    echo "pg_version"
    run_psql "SELECT version();"
    echo

    # pg_datadir: 数据目录路径及大小
    echo "pg_datadir"
    echo "PGDATA: $PGDATA"
    if [[ -d "$PGDATA" ]]; then
        echo "Size: $(du -sh "$PGDATA" 2>/dev/null | awk '{print $1}')"
    fi
    echo

    # pg_log: PostgreSQL 最近50行日志
    echo "pg_log"
    local log_dir log_file
    # 尝试从配置中获取日志目录
    log_dir=$(run_psql "SHOW log_directory;" | tr -d ' ')
    local log_filename_pattern
    log_filename_pattern=$(run_psql "SHOW log_filename;" | tr -d ' ')
    # 如果日志目录是相对路径，补全为绝对路径
    if [[ "$log_dir" != /* ]]; then
        log_dir="${PGDATA}/${log_dir}"
    fi
    # 获取最新的日志文件
    if [[ -d "$log_dir" ]]; then
        log_file=$(ls -t "$log_dir"/*.log "$log_dir"/*.csv 2>/dev/null | head -n 1)
        if [[ -n "$log_file" ]]; then
            tail -n 50 "$log_file" 2>/dev/null
        else
            echo "未找到日志文件"
        fi
    else
        echo "日志目录不存在: $log_dir"
    fi
    echo

    # pg_conf: PostgreSQL 关键配置参数
    echo "pg_conf"
    local pg_settings=(
        "shared_buffers"
        "max_connections"
        "work_mem"
        "maintenance_work_mem"
        "effective_cache_size"
        "wal_buffers"
        "checkpoint_completion_target"
        "max_wal_size"
        "min_wal_size"
        "random_page_cost"
        "effective_io_concurrency"
        "max_worker_processes"
        "max_parallel_workers_per_gather"
        "max_parallel_workers"
        "max_parallel_maintenance_workers"
        "log_destination"
        "logging_collector"
        "log_directory"
        "log_filename"
        "log_min_duration_statement"
        "log_statement"
        "log_line_prefix"
        "archive_mode"
        "archive_command"
        "wal_level"
        "max_replication_slots"
        "max_wal_senders"
        "listen_addresses"
        "port"
        "shared_preload_libraries"
        "huge_pages"
        "temp_buffers"
        "autovacuum"
        "autovacuum_max_workers"
        "autovacuum_naptime"
    )
    # 构建 SQL 查询获取所有关键配置
    local settings_list
    settings_list=$(printf "'%s'," "${pg_settings[@]}")
    settings_list="${settings_list%,}"
    run_psql "SELECT name || ' = ' || setting FROM pg_settings WHERE name IN (${settings_list}) ORDER BY name;"
    echo

    # pg_hba: pg_hba.conf 内容（用于安全审计）
    echo "pg_hba"
    local hba_file
    hba_file=$(run_psql "SHOW hba_file;" | tr -d ' ')
    if [[ -n "$hba_file" ]] && [[ -f "$hba_file" ]]; then
        grep -v "^\s*\(#\|$\)" "$hba_file"
    elif [[ -f "${PGDATA}/pg_hba.conf" ]]; then
        grep -v "^\s*\(#\|$\)" "${PGDATA}/pg_hba.conf"
    else
        echo "未找到 pg_hba.conf 文件"
    fi
    echo
}
#==============================================================#
#                     执行数据库巡检 SQL                         #
#==============================================================#
function get_db_report() {
    log_print "收集 PostgreSQL 数据库巡检报告"
    local sql_script="${scripts_dir}/dbcheck_pg.sql"
    if check_file "$sql_script"; then
        color_printf blue "执行数据库巡检 SQL ..."
        su - "$PG_OS_USER" -c "psql -U $PG_USER -h $PG_HOST -p $PG_PORT -d $PG_DB -f \"$sql_script\"" >/dev/null 2>&1
        # dbcheck_pg.sql 默认输出到 /tmp/dbcheck_pg_result.html
        if [[ -f /tmp/dbcheck_pg_result.html ]]; then
            mv /tmp/dbcheck_pg_result.html "$result_dir/"
        fi
    else
        color_printf blue "数据库巡检脚本 dbcheck_pg.sql 未找到，跳过数据库层巡检。"
    fi
}
#==============================================================#
#                          tar logfile                         #
#==============================================================#
function tar_logfile() {
    # 切换目录到 $result_dir，并在切换失败时退出函数
    cd "$result_dir" || return
    # 移动可能存在的 dbcheck HTML 报告
    mv ../dbcheck_*html . 2>/dev/null
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
    cat <<-'EOF'

  ____           _    ____  ___  _       _   _            _ _   _      ____ _               _
 |  _ \ ___  ___| |_ / ___|/ _ \| |     | | | | ___  __ _| | |_| |__  / ___| |__   ___  ___| | __
 | |_) / _ \/ __| __| |  _| |_| | |     | |_| |/ _ \/ _` | | __| '_ \| |   | '_ \ / _ \/ __| |/ /
 |  __/ (_) \__ \ |_| |_| |  _  | |___  |  _  |  __/ (_| | | |_| | | | |___| | | |  __/ (__|   <
 |_|   \___/|___/\__|\____|_| |_|_____| |_| |_|\___|\__,_|_|\__|_| |_|\____|_| |_|\___|\___|_|\_\

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
        -U)
            checkpara_NULL "$1" "$2"
            PG_USER=$2
            shift 2
            ;;
        -d)
            checkpara_NULL "$1" "$2"
            PG_DB=$2
            shift 2
            ;;
        -p)
            checkpara_NULL "$1" "$2"
            PG_PORT=$2
            shift 2
            ;;
        -H)
            checkpara_NULL "$1" "$2"
            PG_HOST=$2
            shift 2
            ;;
        -h | --help)
            help
            exit 0
            ;;
        *)
            echo
            color_printf red "脚本传参错误，请检查参数 [ $1 ], 执行 sh oscheck.sh -h 可以获得更多帮助！"
            echo
            exit 1
            ;;
        esac
    done
}
#==============================================================#
#                          前置检查                             #
#==============================================================#
function pre_todo() {
    # 自动检测 PostgreSQL 环境
    detect_pg_env
    # 检查 psql 是否可用
    if ! command -v psql &>/dev/null; then
        color_printf red "未找到 psql 命令，请确认 PostgreSQL 客户端已安装并在 PATH 中！"
    fi
    # 检查 PostgreSQL 进程是否运行
    if ! pgrep -x postgres &>/dev/null && ! pgrep -x postmaster &>/dev/null; then
        color_printf red "PostgreSQL 数据库未运行，请先启动数据库！"
    fi
    # 如果目录已存在则删除重建
    [[ -e $result_dir ]] && rm -rf "$result_dir"
    mkdir -p "$result_dir"
    # 设置语言环境变量
    export LANG="en_US.UTF-8"
}
#==============================================================#
#                            主函数                             #
#==============================================================#
function main() {
    logo_print
    accept_para "$@"
    pre_todo
    log_print "PostgreSQL 数据库主机检查"
    color_printf blue "收集主机 OS 层信息 ..."
    get_os_info >"$filename"
    color_printf blue "收集 PostgreSQL 数据库配置信息 ..."
    get_pg_info >>"$filename"
    get_db_report
    tar_logfile
}
main "$@"
