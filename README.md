# OraCheck - Oracle 数据库巡检脚本

免费开源的 Oracle 数据库健康检查脚本集，覆盖 Oracle 10g ~ 23ai 全版本。

**在线报告生成工具**: [https://pc-study.github.io/oracheck](https://pc-study.github.io/oracheck) — 上传巡检文件，一键生成专业 Word 巡检报告。

## 快速开始

```bash
# 1. 下载脚本到数据库服务器
wget https://raw.githubusercontent.com/pc-study/oracheck/main/scripts/oscheck.sh

# 2. 赋予执行权限
chmod +x oscheck.sh

# 3. 以 oracle 用户执行
su - oracle
./oscheck.sh

# 4. 输出文件: dbcheck_*.tar.gz（包含 HTML 报告 + OS 检查数据）
```

脚本会自动检测 Oracle 版本并选择对应的 SQL 脚本执行。

## 巡检覆盖项（20+ 项）

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
| **安全** | 默认密码检查 | 使用初始密码 |
| **安全** | 密码过期检查 | 30天内过期 |
| **安全** | 比特币勒索病毒 | 检测到特征 |
| **安全** | 序列接近 MAXVALUE | 使用率超 80% |
| **备份** | RMAN 备份状态 | 近 10 天备份失败 |
| **高可用** | DataGuard 同步 | 同步延迟或 GAP |
| **性能** | AWR 负载概况 | CPU > 80% |
| **性能** | Top10 等待事件 | 异常等待占比高 |
| **性能** | Top10 SQL | 单次执行 > 1 分钟 |
| **性能** | 统计信息检查 | 大表统计信息过期 |
| **日志** | ALERT 日志 ORA 错误 | 存在 ORA- 错误 |

### 季检附加项（oscheck.sh 采集）

| 类别 | 检查项 |
|------|--------|
| OS | 磁盘空间使用率、内存使用、Swap |
| OS | 透明大页 (THP) 状态 |
| 集群 | CRS 资源状态、OCR/Voting Disk |
| 性能 | AWR 趋势图表 (CPU/连接数/提交数/等待事件) |

## 支持的 Oracle 版本

| 版本 | SQL 脚本 | 说明 |
|------|---------|------|
| 10g | `dbcheck10g.sql` | Oracle 10.x |
| 11g | `dbcheck11g.sql` | Oracle 11.x |
| 12c+ | `dbcheck12c.sql` | Oracle 12c / 18c / 19c / 21c / 23ai |

`oscheck.sh` 会自动根据 `$ORACLE_HOME` 检测版本，选择正确的脚本。

## 输出文件

```
dbcheck_{DBID}_{DBNAME}_{VERSION}_{DATE}.tar.gz
├── dbcheck_{DBID}_{DBNAME}_{VERSION}_{DATE}.html   # 数据库巡检报告
├── oscheck_{HOSTNAME}_{DATE}.txt                    # OS 级检查数据
├── awrrpt_{INSTANCE}_{SNAP}.html                    # AWR 报告
└── alert_{INSTANCE}.log                             # ALERT 日志摘要
```

## 生成 Word 巡检报告

巡检脚本生成的是 HTML 格式报告。如果你需要生成**专业的 Word 巡检报告**（带诊断建议、异常高亮、公司 Logo），可以使用配套的报告生成工具：

### 在线版（免费体验）

访问 [https://pc-study.github.io/oracheck](https://pc-study.github.io/oracheck)，上传巡检文件，即时生成 Word 报告。

### 桌面版（专业版）

- 支持批量处理多个巡检文件
- 自定义公司 Logo 和巡检人员
- 周检/月检/季检三种报告模板
- 含 AWR 性能趋势图表（季检）
- Windows / macOS 双平台

联系获取专业版授权。

## 常见问题

**Q: 脚本会修改数据库吗？**
A: 不会。所有 SQL 都是只读查询（SELECT），不会对数据库做任何修改。唯一的写操作是 sqlplus 的 errorlogging 表（用于记录脚本执行错误），脚本结束后会自动清理。

**Q: 需要什么权限？**
A: 需要 `SYSDBA` 权限。脚本通过 `sqlplus / as sysdba` 连接。

**Q: RAC 环境怎么用？**
A: 在任一节点执行 `oscheck.sh` 即可，脚本会自动采集所有节点的信息。

**Q: 支持 PDB/CDB 吗？**
A: 12c+ 脚本使用 `CDB_*` 视图，自动涵盖所有 PDB（排除 CDB$ROOT 和 PDB$SEED）。

## License

巡检脚本（`scripts/` 目录）采用 MIT 许可证，可自由使用和修改。
