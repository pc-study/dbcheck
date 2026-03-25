# DBCheck2Word — 多数据库巡检脚本 & 报告生成平台

免费开源的数据库健康检查脚本集，支持 **Oracle / MySQL / PostgreSQL / SQL Server** 四大主流数据库。

**在线报告生成**: [https://dbcheck2word.com](https://dbcheck2word.com) — 上传巡检结果，一键生成专业 Word 巡检报告。

---

## 支持的数据库

| 数据库 | 版本要求 | 脚本 |
|--------|---------|------|
| Oracle | 10g ~ 23ai | `scripts/oracle/oscheck.sh` (自动检测版本) |
| MySQL | 5.7+ / 8.0+ | `scripts/mysql/dbcheck_mysql.sql` |
| PostgreSQL | 12+ | `scripts/postgres/dbcheck_pg.sql` |
| SQL Server | 2016+ | `scripts/sqlserver/dbcheck_mssql.sql` |

---

## 快速开始

### Oracle

```bash
# 下载并执行（oracle 用户）
wget https://raw.githubusercontent.com/pc-study/dbcheck/main/scripts/oracle/oscheck.sh
chmod +x oscheck.sh
su - oracle
./oscheck.sh

# 输出: dbcheck_*.tar.gz（含 HTML 报告 + OS 检查数据）
```

`oscheck.sh` 自动检测 Oracle 版本并选择对应的 SQL 脚本执行。

### MySQL

```bash
# 下载脚本
wget https://raw.githubusercontent.com/pc-study/dbcheck/main/scripts/mysql/dbcheck_mysql.sql

# 执行巡检（需要 root 或具备全局权限的用户）
mysql -u root -p < dbcheck_mysql.sql > dbcheck_mysql_result.html

# 输出: dbcheck_mysql_result.html
```

### PostgreSQL

```bash
# 下载脚本
wget https://raw.githubusercontent.com/pc-study/dbcheck/main/scripts/postgres/dbcheck_pg.sql

# 执行巡检（需要 superuser 权限）
psql -U postgres -f dbcheck_pg.sql

# 输出: /tmp/dbcheck_pg_result.html
```

### SQL Server

```bash
# 下载脚本
wget https://raw.githubusercontent.com/pc-study/dbcheck/main/scripts/sqlserver/dbcheck_mssql.sql

# 执行巡检（需要 sysadmin 权限）
sqlcmd -S localhost -i dbcheck_mssql.sql -o dbcheck_mssql_result.html
```

---

## 巡检覆盖项

### Oracle（20+ 项）

| 类别 | 检查项 | 异常判定 |
|------|--------|---------|
| **启动配置** | SPFILE 启动检查 | 未使用 SPFILE |
| **资源** | 数据库资源限制 | 资源参数设置不合理 |
| **存储** | 控制文件多路复用 | 控制文件少于 2 组 |
| **存储** | 在线重做日志 | 日志过小或 INACTIVE 不足 |
| **存储** | 重做日志切换频率 | 单小时切换超 100 次 |
| **存储** | 表空间使用率 | 可扩展使用率超 90% |
| **存储** | ASM 磁盘组使用率 | 使用率超 90% |
| **对象** | 回收站对象 | 数量超 1000 |
| **对象** | Top10 大表/大索引 | 超过 100G |
| **对象** | 外键缺失索引 | 外键列无索引 |
| **对象** | 无效对象 | 存在 INVALID 对象 |
| **安全** | 默认密码 / 密码过期 / 勒索病毒检测 | — |
| **备份** | RMAN 备份状态 | 近 10 天备份失败 |
| **高可用** | DataGuard 同步 | 同步延迟或 GAP |
| **性能** | AWR 负载 / Top SQL / 等待事件 / 统计信息 | — |
| **日志** | ALERT 日志 ORA 错误 | 存在 ORA- 错误 |

**季检附加项**（oscheck.sh 采集）: 磁盘/内存/Swap、THP 状态、CRS/OCR/Voting Disk、AWR 趋势图表

### MySQL（9 项）

| 类别 | 检查项 |
|------|--------|
| **连接** | 最大连接数、当前连接数 |
| **性能** | 慢查询统计 |
| **存储引擎** | InnoDB 缓冲池命中率 |
| **复制** | Binlog 状态、主从同步 |
| **对象** | 大表检测、索引使用率 |
| **安全** | 用户权限审计 |
| **备份** | 备份状态检查 |

### PostgreSQL（12 项）

| 类别 | 检查项 |
|------|--------|
| **存储** | 表空间使用率、数据库大小 |
| **连接** | 连接数统计 |
| **性能** | 慢查询、锁冲突、膨胀表检测 |
| **维护** | Vacuum 状态 |
| **复制** | 流复制状态、WAL 归档 |
| **对象** | 索引使用率、扩展列表 |
| **备份** | 备份状态检查 |

### SQL Server（10 项）

| 类别 | 检查项 |
|------|--------|
| **存储** | 文件组使用率、事务日志 |
| **连接** | 连接数统计 |
| **性能** | 慢查询、等待统计、索引碎片 |
| **高可用** | AlwaysOn 状态 |
| **运维** | 代理作业状态 |
| **安全** | 安全审计 |
| **备份** | 备份状态检查 |

---

## 生成 Word 巡检报告

巡检脚本生成 HTML 格式报告。配套的报告生成工具可以将其转换为**专业 Word 巡检报告**（含诊断建议、异常高亮、性能图表）。

### 在线版（免费）

访问 [https://dbcheck2word.com](https://dbcheck2word.com)，上传巡检文件，选择数据库类型和巡检深度，即时生成 Word 报告。

- 支持 Oracle / MySQL / PostgreSQL / SQL Server
- 周检 / 月检 / 季检三种模板
- 智能诊断引擎，异常项红色高亮
- 文件处理完即删除，保障数据安全

### 桌面版（专业版）

- 批量处理多个巡检文件
- 自定义公司 Logo 和巡检人员
- 数据不出内网，适合安全敏感环境
- Windows / macOS 双平台

联系获取专业版授权。

---

## Oracle 脚本说明

| 版本 | SQL 脚本 | 说明 |
|------|---------|------|
| 10g | `dbcheck10g.sql` | Oracle 10.x |
| 11g | `dbcheck11g.sql` | Oracle 11.x |
| 12c+ | `dbcheck12c.sql` | Oracle 12c / 18c / 19c / 21c / 23ai |

### Oracle 输出文件

```
dbcheck_{DBID}_{DBNAME}_{VERSION}_{DATE}.tar.gz
├── dbcheck_{DBID}_{DBNAME}_{VERSION}_{DATE}.html   # 数据库巡检报告
├── oscheck_{HOSTNAME}_{DATE}.txt                    # OS 级检查数据
├── awrrpt_{INSTANCE}_{SNAP}.html                    # AWR 报告
└── alert_{INSTANCE}.log                             # ALERT 日志摘要
```

---

## 常见问题

**Q: 脚本会修改数据库吗？**
A: 不会。所有脚本都是只读查询，不会对数据库做任何修改。

**Q: Oracle 脚本需要什么权限？**
A: 需要 `SYSDBA` 权限，通过 `sqlplus / as sysdba` 连接。

**Q: MySQL 脚本需要什么权限？**
A: 需要 `root` 或具备 `PROCESS`、`REPLICATION CLIENT` 等全局权限的用户。

**Q: PostgreSQL 脚本需要什么权限？**
A: 建议使用 `superuser`（如 postgres 用户）执行。

**Q: SQL Server 脚本需要什么权限？**
A: 需要 `sysadmin` 角色或等效的服务器级权限。

**Q: Oracle RAC 环境怎么用？**
A: 在任一节点执行 `oscheck.sh` 即可，脚本自动采集所有节点信息。

**Q: 支持 Oracle PDB/CDB 吗？**
A: 12c+ 脚本使用 `CDB_*` 视图，自动涵盖所有 PDB。

---

## License

巡检脚本（`scripts/` 目录）采用 MIT 许可证，可自由使用和修改。
