#!/usr/bin/env bash
#==============================================================#
# File       :   OS Health Check
# Ctime      :   2026-03-25 00:00:00
# Desc       :   SQL Server on Linux OS Health Check script
# Version    :   1.0.0
# Author     :   Lucifer(pc1107750981@163.com)
# Copyright (C) 2021-2100 Pengcheng Liu
#==============================================================#
# 脚本描述：
#     1. 收集当前运行主机 OS 的信息。
#     2. 收集 SQL Server 相关配置和日志信息。
#     3. 收集当前运行数据库的数据信息。
#
# 用法：
#     ./oscheck.sh
#     举例:
#     1. 使用 SA 用户巡检：sh oscheck.sh -P 'yourpassword'
#     2. 指定用户和端口：sh oscheck.sh -U sa -P 'pass' -S localhost,1433
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
# SQL Server 认证参数默认值
MSSQL_USER="SA"
MSSQL_PASSWORD=""
MSSQL_SERVER="localhost"
# SQL Server 错误日志路径
MSSQL_ERRORLOG="/var/opt/mssql/log/errorlog"
# SQL Server 配置文件路径
MSSQL_CONF="/var/opt/mssql/mssql.conf"
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
    color_printf blue "用法: oscheck.sh [选项] { 命令 | help }"
    color_printf blue "选项: "
    options=(
        "-U SQL Server 认证用户名，默认 SA，示例: -U sa"
        "-P SQL Server 认证密码，示例: -P 'YourPassword123'"
        "-S SQL Server 地址和端口，默认 localhost，示例: -S localhost,1433"
        "-h 显示帮助信息"
    )
    print_options "${options[@]}"
}
#==============================================================#
#                       执行 OS 系统检查命令                      #
#==============================================================#
function oscmd() {
    # 简化版 oscmd，仅本地执行，输出 ** hostname: 前缀
    echo "** $hostname:"
    $1 2>/dev/null
}
#==============================================================#
#                          OS 系统检查                          #
#==============================================================#
function get_os_info() {
    # 定义命令名称数组（与 Python 管道 parse_txt_file() 解析的 tag_id 保持一致）
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
            # 检查 MSSQL 相关的内核参数
            grep -E "vm.swappiness|vm.max_map_count|kernel.numa_balancing|net.core.somaxconn|fs.file-max|net.ipv4.ip_local_port_range|fs.aio-max-nr" /etc/sysctl.conf 2>/dev/null
            ;;
        "limits") grep -v "^\s*\(#\|$\)" /etc/security/limits.conf ;;
        "diskusage") oscmd "df -PTh" ;;
        "inode") oscmd "df -PTi" ;;
        "meminfo") awk -F": " '/MemTotal|MemFree|MemAvailable|Cached|SwapTotal|SwapFree|AnonHugePages|HugePages_Total|HugePages_Free/ {print $1":"$2}' /proc/meminfo ;;
        "freemem") free -k ;;
        "thp") [[ -e /sys/kernel/mm/transparent_hugepage/enabled ]] && cat /sys/kernel/mm/transparent_hugepage/enabled ;;
        "crontab") crontab -l 2>/dev/null ;;
        *) echo "Unknown command: $command" ;;
        esac
        echo
    done
}
#==============================================================#
#                    获取 SQL Server 版本信息                     #
#==============================================================#
function get_mssql_version() {
    echo "mssql_version"
    sqlcmd -S "$MSSQL_SERVER" -U "$MSSQL_USER" -P "$MSSQL_PASSWORD" -C -Q "SET NOCOUNT ON; SELECT @@VERSION;" -h -1 -W 2>/dev/null | head -n 2
    echo
}
#==============================================================#
#                    获取 SQL Server 数据目录                     #
#==============================================================#
function get_mssql_datadir() {
    echo "mssql_datadir"
    # 获取默认数据目录路径
    local datadir
    datadir=$(sqlcmd -S "$MSSQL_SERVER" -U "$MSSQL_USER" -P "$MSSQL_PASSWORD" -C -Q "SET NOCOUNT ON; SELECT SERVERPROPERTY('InstanceDefaultDataPath');" -h -1 -W 2>/dev/null | head -n 1)
    if [[ -n "$datadir" ]]; then
        echo "DefaultDataPath: $datadir"
        # 显示数据目录大小
        if [[ -d "$datadir" ]]; then
            du -sh "$datadir" 2>/dev/null
        fi
    fi
    # 获取默认日志目录路径
    local logdir
    logdir=$(sqlcmd -S "$MSSQL_SERVER" -U "$MSSQL_USER" -P "$MSSQL_PASSWORD" -C -Q "SET NOCOUNT ON; SELECT SERVERPROPERTY('InstanceDefaultLogPath');" -h -1 -W 2>/dev/null | head -n 1)
    if [[ -n "$logdir" ]]; then
        echo "DefaultLogPath: $logdir"
        if [[ -d "$logdir" ]]; then
            du -sh "$logdir" 2>/dev/null
        fi
    fi
    echo
}
#==============================================================#
#                  获取 SQL Server 错误日志                       #
#==============================================================#
function get_mssql_errorlog() {
    echo "mssql_errorlog"
    # 获取 SQL Server 错误日志最后 50 行
    if check_file "$MSSQL_ERRORLOG"; then
        tail -n 50 "$MSSQL_ERRORLOG" 2>/dev/null
    else
        echo "错误日志文件不存在: $MSSQL_ERRORLOG"
    fi
    echo
}
#==============================================================#
#                  获取 SQL Server 配置信息                       #
#==============================================================#
function get_mssql_conf() {
    echo "mssql_conf"
    # 获取 mssql.conf 关键配置
    if check_file "$MSSQL_CONF"; then
        grep -v "^\s*\(#\|$\|;\)" "$MSSQL_CONF" 2>/dev/null
    else
        echo "配置文件不存在: $MSSQL_CONF"
    fi
    echo
}
#==============================================================#
#                          tar logfile                         #
#==============================================================#
function tar_logfile() {
    # 切换目录到 $result_dir，并在切换失败时退出函数
    cd "$result_dir" || return
    # 移动数据库巡检 HTML 报告到结果目录
    if ls ../dbcheck_mssql*.html 1>/dev/null 2>&1; then
        mv ../dbcheck_mssql*.html .
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
    cat <<-'EOF'

  __  __ ____ ____   ___  _     _   _            _ _   _      ____ _               _
 |  \/  / ___/ ___| / _ \| |   | | | | ___  __ _| | |_| |__  / ___| |__   ___  ___| | __
 | |\/| \___ \___ \| | | | |   | |_| |/ _ \/ _` | | __| '_ \| |   | '_ \ / _ \/ __| |/ /
 | |  | |___) |__) | |_| | |___|  _  |  __/ (_| | | |_| | | | |___| | | |  __/ (__|   <
 |_|  |_|____/____/ \__\_\_____|_| |_|\___|\__,_|_|\__|_| |_|\____|_| |_|\___|\___|_|\_\

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
            MSSQL_USER=$2
            shift 2
            ;;
        -P)
            checkpara_NULL "$1" "$2"
            MSSQL_PASSWORD=$2
            shift 2
            ;;
        -S)
            checkpara_NULL "$1" "$2"
            MSSQL_SERVER=$2
            shift 2
            ;;
        -h | --help)
            help
            exit 1
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
#                          预处理检查                            #
#==============================================================#
function pre_todo() {
    # 检查密码是否已设置
    if [[ -z "$MSSQL_PASSWORD" ]]; then
        color_printf red "请使用 -P 参数指定 SQL Server 认证密码！"
    fi
    # 检测 SQL Server 进程是否在运行
    if ! pgrep -f "sqlservr" >/dev/null 2>&1; then
        color_printf red "SQL Server 进程未运行，请先启动 SQL Server！"
    fi
    # 获取 mssql 用户名（运行 sqlservr 进程的用户）
    mssql_user=$(pgrep -f "sqlservr" | head -n 1 | xargs -I {} ps -o user= -p {} 2>/dev/null)
    if [[ -n "$mssql_user" ]]; then
        color_printf green "检测到 SQL Server 运行用户: $mssql_user"
    fi
    # 检查 sqlcmd 是否可用
    if ! command -v sqlcmd >/dev/null 2>&1; then
        color_printf red "sqlcmd 命令不可用，请确认已安装 mssql-tools！"
    fi
    # 验证 SQL Server 连接
    if ! sqlcmd -S "$MSSQL_SERVER" -U "$MSSQL_USER" -P "$MSSQL_PASSWORD" -C -Q "SELECT 1;" >/dev/null 2>&1; then
        color_printf red "无法连接到 SQL Server ($MSSQL_SERVER)，请检查连接参数！"
    fi
    # 如果目录已存在则删除重建
    [[ -e $result_dir ]] && rm -rf "$result_dir"
    mkdir -p "$result_dir"
    # 设置语言环境变量
    export LANG="en_US.UTF-8"
}
#==============================================================#
#                     执行数据库巡检 SQL 脚本                     #
#==============================================================#
function get_db_report() {
    log_print "SQL Server 数据库巡检"
    local sql_script="$scripts_dir/dbcheck_mssql.sql"
    local html_output="$scripts_dir/dbcheck_mssql_${hostname}_${date}.html"
    if check_file "$sql_script"; then
        color_printf blue "执行数据库巡检 SQL 脚本 ..."
        sqlcmd -S "$MSSQL_SERVER" -U "$MSSQL_USER" -P "$MSSQL_PASSWORD" -C \
            -d master -i "$sql_script" -o "$html_output" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            color_printf green "数据库巡检报告已生成: $html_output"
        else
            color_printf green "数据库巡检 SQL 执行失败，请检查连接和权限！"
        fi
    else
        color_printf green "数据库巡检脚本 dbcheck_mssql.sql 未找到，请上传至 $scripts_dir 目录下！"
    fi
}
#==============================================================#
#                            主函数                             #
#==============================================================#
function main() {
    logo_print
    accept_para "$@"
    pre_todo
    log_print "SQL Server 数据库主机检查"
    color_printf blue "收集主机 OS 层信息 ..."
    get_os_info >"$filename"
    color_printf blue "收集 SQL Server 版本信息 ..."
    get_mssql_version >>"$filename"
    color_printf blue "收集 SQL Server 数据目录信息 ..."
    get_mssql_datadir >>"$filename"
    color_printf blue "收集 SQL Server 错误日志 ..."
    get_mssql_errorlog >>"$filename"
    color_printf blue "收集 SQL Server 配置信息 ..."
    get_mssql_conf >>"$filename"
    get_db_report
    tar_logfile
}
main "$@"
