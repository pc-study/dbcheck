#!/usr/bin/env bash
#==============================================================#
# File       :   OS Health Check
# Ctime      :   2024-08-20 10:00:00
# Mtime      :   2024-08-20 13:09:21
# Desc       :   MySQL Database OS Health Check script
# Version    :   1.0.0
# Author     :   Lucifer(pc1107750981@163.com)
# Copyright (C) 2021-2100 Pengcheng Liu
#==============================================================#
# 脚本描述：
#     1. 收集当前运行主机 OS 的信息。
#     2. 收集当前运行 MySQL 数据库的配置和状态信息。
#
# 用法：
#     ./oscheck.sh
#     举例:
#     1. 巡检当前实例（默认 root 用户）：sh oscheck.sh
#     2. 指定 MySQL 用户和密码：sh oscheck.sh -u root -p 'password'
#     3. 指定 socket 路径：sh oscheck.sh -u root -p 'password' -S /tmp/mysql.sock
#     4. 指定端口：sh oscheck.sh -u root -p 'password' -P 3306
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
# MySQL 连接参数（默认值）
mysql_user="root"
mysql_password=""
mysql_socket=""
mysql_port=""
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
        "-u MySQL 用户名，默认 root，示例: -u root"
        "-p MySQL 密码，示例: -p 'password'"
        "-S MySQL socket 路径，示例: -S /tmp/mysql.sock"
        "-P MySQL 端口号，示例: -P 3306"
    )
    print_options "${options[@]}"
}
#==============================================================#
#                       构建 MySQL 连接命令                      #
#==============================================================#
function build_mysql_cmd() {
    # 构建 mysql 命令行连接参数
    local cmd="mysql -u ${mysql_user}"
    if [[ -n "$mysql_password" ]]; then
        cmd="$cmd -p${mysql_password}"
    fi
    if [[ -n "$mysql_socket" ]]; then
        cmd="$cmd -S ${mysql_socket}"
    fi
    if [[ -n "$mysql_port" ]]; then
        cmd="$cmd -P ${mysql_port}"
    fi
    echo "$cmd"
}
#==============================================================#
#                       执行 OS 系统检查命令                      #
#==============================================================#
function oscmd() {
    echo "** $hostname:"
    $1 2>/dev/null
}
#==============================================================#
#                     自动检测 MySQL 环境                        #
#==============================================================#
function detect_mysql() {
    # 查找 mysqld 进程
    local mysqld_pid
    mysqld_pid=$(pgrep -x mysqld | head -n 1)
    if [[ -z "$mysqld_pid" ]]; then
        mysqld_pid=$(pgrep -f "mysqld " | head -n 1)
    fi
    if [[ -z "$mysqld_pid" ]]; then
        color_printf red "未检测到运行中的 MySQL 进程，请确认 MySQL 已启动！"
    fi
    # 获取 MySQL 运行用户
    mysql_os_user=$(ps -o user= -p "$mysqld_pid" 2>/dev/null | tr -d '[:space:]')
    # 获取 datadir（从进程参数中提取）
    mysql_datadir=$(ps -o args= -p "$mysqld_pid" 2>/dev/null | grep -oP '(?<=--datadir=)\S+' | head -n 1)
    if [[ -z "$mysql_datadir" ]]; then
        # 尝试从 mysql 命令获取 datadir
        mysql_datadir=$($(build_mysql_cmd) -N -B -e "SELECT @@datadir;" 2>/dev/null | tr -d '[:space:]')
    fi
    # 获取 my.cnf 配置文件路径
    mysql_cnf=""
    # 按优先级查找配置文件
    for cnf in /etc/my.cnf /etc/mysql/my.cnf /usr/local/mysql/etc/my.cnf ~/.my.cnf; do
        if [[ -f "$cnf" ]]; then
            mysql_cnf="$cnf"
            break
        fi
    done
    # 如果没有找到，尝试从进程参数中获取
    if [[ -z "$mysql_cnf" ]]; then
        mysql_cnf=$(ps -o args= -p "$mysqld_pid" 2>/dev/null | grep -oP '(?<=--defaults-file=)\S+' | head -n 1)
    fi
    # 获取 MySQL error log 路径
    mysql_error_log=$($(build_mysql_cmd) -N -B -e "SELECT @@log_error;" 2>/dev/null | tr -d '[:space:]')
    if [[ -z "$mysql_error_log" || "$mysql_error_log" == "stderr" ]]; then
        # 尝试从配置文件获取
        if [[ -n "$mysql_cnf" ]]; then
            mysql_error_log=$(grep -E "^log[_-]error" "$mysql_cnf" 2>/dev/null | head -n 1 | awk -F'=' '{print $2}' | tr -d '[:space:]')
        fi
    fi
    # 如果 error log 是相对路径，补全为 datadir 下的绝对路径
    if [[ -n "$mysql_error_log" && "$mysql_error_log" != /* ]]; then
        mysql_error_log="${mysql_datadir}/${mysql_error_log}"
    fi
}
#==============================================================#
#                          OS 系统检查                          #
#==============================================================#
function get_os_info() {
    # 定义命令名称数组
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
        "swapusage") free -m | awk '/Swap:/ {if ($2>0) print $3/$2*100; else print 0}' ;;
        "loadaverage") w | grep "load average" | awk -F ": " '{print $2}' ;;
        "upday") w | head -n 1 | awk -F ", " '{print $1}' | cut -c 11- ;;
        "time") date +"%Y-%m-%d %H:%M:%S" ;;
        "hosts") sed '1,2d' /etc/hosts | grep -v '^$' ;;
        "sysctl") grep -E "vm.swappiness|vm.overcommit_memory|vm.dirty_ratio|vm.dirty_background_ratio|net.core.somaxconn|net.ipv4.tcp_max_syn_backlog|fs.file-max|net.ipv4.ip_local_port_range" /etc/sysctl.conf ;;
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
#                      获取 MySQL 信息                          #
#==============================================================#
function get_mysql_info() {
    local mysql_cmd
    mysql_cmd=$(build_mysql_cmd)

    # MySQL 版本
    echo "mysql_version"
    $mysql_cmd -N -B -e "SELECT VERSION();" 2>/dev/null
    echo

    # MySQL 数据目录及大小
    echo "mysql_datadir"
    if [[ -n "$mysql_datadir" && -d "$mysql_datadir" ]]; then
        echo "datadir: ${mysql_datadir}"
        du -sh "$mysql_datadir" 2>/dev/null | awk '{print "size: "$1}'
    else
        echo "datadir: unknown"
    fi
    echo

    # MySQL 错误日志（最后 50 行）
    echo "mysql_error_log"
    if [[ -n "$mysql_error_log" ]] && check_file "$mysql_error_log"; then
        tail -n 50 "$mysql_error_log" 2>/dev/null
    else
        echo "error log 未找到或路径未知"
    fi
    echo

    # MySQL 关键配置参数
    echo "mysql_conf"
    $mysql_cmd -N -B -e "
SELECT CONCAT(variable_name, ' = ', variable_value)
FROM performance_schema.global_variables
WHERE variable_name IN (
    'innodb_buffer_pool_size',
    'innodb_buffer_pool_instances',
    'innodb_log_file_size',
    'innodb_log_buffer_size',
    'innodb_flush_log_at_trx_commit',
    'innodb_flush_method',
    'innodb_file_per_table',
    'innodb_io_capacity',
    'innodb_io_capacity_max',
    'innodb_read_io_threads',
    'innodb_write_io_threads',
    'max_connections',
    'max_connect_errors',
    'table_open_cache',
    'thread_cache_size',
    'sort_buffer_size',
    'join_buffer_size',
    'read_buffer_size',
    'read_rnd_buffer_size',
    'tmp_table_size',
    'max_heap_table_size',
    'key_buffer_size',
    'query_cache_size',
    'query_cache_type',
    'slow_query_log',
    'slow_query_log_file',
    'long_query_time',
    'log_bin',
    'binlog_format',
    'sync_binlog',
    'server_id',
    'gtid_mode',
    'enforce_gtid_consistency',
    'character_set_server',
    'collation_server',
    'lower_case_table_names',
    'explicit_defaults_for_timestamp',
    'default_storage_engine',
    'log_error',
    'general_log',
    'general_log_file',
    'expire_logs_days',
    'binlog_expire_logs_seconds',
    'max_allowed_packet',
    'interactive_timeout',
    'wait_timeout',
    'lock_wait_timeout',
    'innodb_lock_wait_timeout'
)
ORDER BY variable_name;
" 2>/dev/null
    echo
}
#==============================================================#
#                      执行 MySQL 巡检 SQL                      #
#==============================================================#
function run_mysql_sql() {
    local mysql_cmd sql_script html_output
    mysql_cmd=$(build_mysql_cmd)
    sql_script="${scripts_dir}/dbcheck_mysql.sql"
    html_output="${scripts_dir}/dbcheck_mysql.html"

    if check_file "$sql_script"; then
        color_printf blue "执行 MySQL 巡检 SQL 脚本 ..."
        $mysql_cmd -N -B --raw <"$sql_script" >"$html_output" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            color_printf green "警告: MySQL 巡检 SQL 执行失败，请检查连接参数！"
        fi
    else
        color_printf green "警告: MySQL 巡检 SQL 脚本 $sql_script 未找到！"
    fi
}
#==============================================================#
#                          tar logfile                         #
#==============================================================#
function tar_logfile() {
    # 切换目录到 $result_dir，并在切换失败时退出函数
    cd "$result_dir" || return
    # 移动 MySQL 巡检 HTML 报告到结果目录
    if ls ../dbcheck_*html 1>/dev/null 2>&1; then
        if ! mv ../dbcheck_*html .; then
            echo
            color_printf green "警告: 移动数据库检查报告失败！"
        fi
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

  __  __        ____   ___  _       _   _            _ _   _      ____ _               _
 |  \/  |_   _ / ___| / _ \| |     | | | | ___  __ _| | |_| |__  / ___| |__   ___  ___| | __
 | |\/| | | | |\___ \| | | | |     | |_| |/ _ \/ _` | | __| '_ \| |   | '_ \ / _ \/ __| |/ /
 | |  | | |_| | ___) | |_| | |___  |  _  |  __/ (_| | | |_| | | | |___| | | |  __/ (__|   <
 |_|  |_|\__, ||____/ \__\_\_____| |_| |_|\___|\__,_|_|\__|_| |_|\____|_| |_|\___|\___|_|\_\
         |___/

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
        -u)
            checkpara_NULL "$1" "$2"
            mysql_user=$2
            shift 2
            ;;
        -p)
            checkpara_NULL "$1" "$2"
            mysql_password=$2
            shift 2
            ;;
        -S)
            checkpara_NULL "$1" "$2"
            mysql_socket=$2
            shift 2
            ;;
        -P)
            checkpara_NULL "$1" "$2"
            mysql_port=$2
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
#                           前置准备                            #
#==============================================================#
function pre_todo() {
    # 检测 mysql 客户端是否存在
    if ! command -v mysql &>/dev/null; then
        color_printf red "未找到 mysql 客户端命令，请确认 MySQL 客户端已安装并在 PATH 中！"
    fi
    # 检测 MySQL 连接是否正常
    local mysql_cmd
    mysql_cmd=$(build_mysql_cmd)
    if ! $mysql_cmd -N -B -e "SELECT 1;" &>/dev/null; then
        color_printf red "无法连接到 MySQL，请检查用户名、密码、socket 或端口参数！"
    fi
    # 如果目录已存在则删除重建
    [[ -e $result_dir ]] && rm -rf "$result_dir"
    mkdir -p "$result_dir"
    # 设置语言环境变量
    export LANG="en_US.UTF-8"
    # 自动检测 MySQL 环境
    detect_mysql
}
#==============================================================#
#                            主函数                             #
#==============================================================#
function main() {
    logo_print
    accept_para "$@"
    pre_todo
    log_print "MySQL 数据库主机检查"
    color_printf blue "收集主机 OS 层信息 ..."
    get_os_info >"$filename"
    color_printf blue "收集 MySQL 数据库信息 ..."
    get_mysql_info >>"$filename"
    color_printf blue "执行 MySQL 巡检 SQL ..."
    run_mysql_sql
    tar_logfile
}
main "$@"
