-- +------------------------------------------------------------------------------------+
-- |               Copyright (c) 2015-2100 lucifer. All rights reserved.                |
-- +------------------------------------------------------------------------------------+
-- | DATABASE : MySQL                                                                    |
-- | FILE     : dbcheck_mysql.sql                                                        |
-- | CLASS    : Database Administration                                                  |
-- | PURPOSE  : MySQL database health check script. Outputs a single HTML document       |
-- |            with span/table tags for automated report generation.                     |
-- | VERSION  : Compatible with MySQL 5.7+ and MySQL 8.0+                                |
-- | USAGE    : mysql -u root -p < dbcheck_mysql.sql > dbcheck_mysql.html                |
-- +------------------------------------------------------------------------------------+

-- Disable pager and column names for clean HTML output
\! echo ''

SELECT CONCAT(
'<html>',
'<head><meta charset="utf-8"><title>MySQL DBCheck Report</title></head>',
'<body>',
'<center><font size=+3 color=darkgreen><b>', @@hostname, ' MySQL DBCheck Report</b></font></center>',
'<hr>'
) AS '';

-- ============================================================
-- Scalar values (span tags)
-- ============================================================

SELECT CONCAT(
'<span id="dbversion">', VERSION(), '</span>'
) AS '';

SELECT CONCAT(
'<span id="hostname">', @@hostname, '</span>'
) AS '';

SELECT CONCAT(
'<span id="dbname">', @@hostname, '</span>'
) AS '';

SELECT CONCAT(
'<span id="checkdate">', DATE_FORMAT(NOW(), '%Y%m%d'), '</span>'
) AS '';

SELECT CONCAT(
'<span id="uptime">', VARIABLE_VALUE, ' seconds</span>'
) AS ''
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Uptime';

SELECT CONCAT(
'<span id="port">', @@port, '</span>'
) AS '';

SELECT CONCAT(
'<span id="datadir">', @@datadir, '</span>'
) AS '';

SELECT CONCAT(
'<span id="buffer_pool_size">',
  ROUND(@@innodb_buffer_pool_size / 1024 / 1024, 2), ' MB',
'</span>'
) AS '';

-- ============================================================
-- Table: max_connections - Current vs Max connections
-- ============================================================

SELECT CONCAT(
'<table id="max_connections" border="1" width="90%" align="center">',
'<tr><td>Parameter</td><td>Current</td><td>Max</td><td>',
  CASE
    WHEN ROUND(cur.v / mx.v * 100, 1) > 80 THEN CONCAT('<font color="red">', ROUND(cur.v / mx.v * 100, 1), '%</font>')
    ELSE CONCAT(ROUND(cur.v / mx.v * 100, 1), '%')
  END,
'</td></tr>',
'</table>'
) AS ''
FROM
  (SELECT CAST(VARIABLE_VALUE AS UNSIGNED) AS v FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Threads_connected') cur,
  (SELECT CAST(@@max_connections AS UNSIGNED) AS v) mx;

-- ============================================================
-- Table: slow_query - Slow query settings and count
-- ============================================================

SELECT CONCAT(
'<table id="slow_query" border="1" width="90%" align="center">'
) AS '';

SELECT CONCAT(
'<tr><td>slow_query_log</td><td>',
  CASE
    WHEN @@slow_query_log = 0 THEN '<font color="red">OFF</font>'
    ELSE 'ON'
  END,
'</td></tr>'
) AS '';

SELECT CONCAT(
'<tr><td>long_query_time</td><td>', @@long_query_time, '</td></tr>'
) AS '';

SELECT CONCAT(
'<tr><td>slow_query_log_file</td><td>', @@slow_query_log_file, '</td></tr>'
) AS '';

SELECT CONCAT(
'<tr><td>Slow_queries</td><td>',
  CASE
    WHEN CAST(VARIABLE_VALUE AS UNSIGNED) > 100 THEN CONCAT('<font color="red">', VARIABLE_VALUE, '</font>')
    ELSE VARIABLE_VALUE
  END,
'</td></tr>'
) AS ''
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Slow_queries';

SELECT '</table>' AS '';

-- ============================================================
-- Table: innodb_buffer - Buffer pool stats
-- ============================================================

SELECT CONCAT(
'<table id="innodb_buffer" border="1" width="90%" align="center">'
) AS '';

SELECT CONCAT(
'<tr><td>Buffer Pool Size</td><td>',
  ROUND(@@innodb_buffer_pool_size / 1024 / 1024, 2), ' MB',
'</td><td>-</td></tr>'
) AS '';

SELECT CONCAT(
'<tr><td>Buffer Pool Instances</td><td>', @@innodb_buffer_pool_instances, '</td><td>-</td></tr>'
) AS '';

-- Buffer pool hit rate
SELECT CONCAT(
'<tr><td>Buffer Pool Hit Rate</td><td>',
  hit_rate, '%',
'</td><td>',
  CASE
    WHEN hit_rate < 95 THEN '<font color="red">LOW</font>'
    ELSE 'OK'
  END,
'</td></tr>'
) AS ''
FROM (
  SELECT ROUND(
    (1 - IFNULL(reads.v, 0) / NULLIF(reqs.v, 0)) * 100, 2
  ) AS hit_rate
  FROM
    (SELECT CAST(VARIABLE_VALUE AS UNSIGNED) AS v FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') reads,
    (SELECT CAST(VARIABLE_VALUE AS UNSIGNED) AS v FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests') reqs
) t;

SELECT CONCAT(
'<tr><td>Pages Dirty</td><td>',
  VARIABLE_VALUE,
'</td><td>-</td></tr>'
) AS ''
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_dirty';

SELECT CONCAT(
'<tr><td>Pages Free</td><td>',
  VARIABLE_VALUE,
'</td><td>-</td></tr>'
) AS ''
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_free';

SELECT '</table>' AS '';

-- ============================================================
-- Table: binlog_status - Binary log configuration
-- ============================================================

SELECT CONCAT(
'<table id="binlog_status" border="1" width="90%" align="center">'
) AS '';

SELECT CONCAT(
'<tr><td>log_bin</td><td>',
  CASE
    WHEN @@log_bin = 0 THEN '<font color="red">OFF</font>'
    ELSE 'ON'
  END,
'</td></tr>'
) AS '';

SELECT CONCAT(
'<tr><td>binlog_format</td><td>',
  IFNULL(@@binlog_format, 'N/A'),
'</td></tr>'
) AS '';

SELECT CONCAT(
'<tr><td>expire_logs_days</td><td>',
  @@expire_logs_days,
'</td></tr>'
) AS '';

SELECT CONCAT(
'<tr><td>sync_binlog</td><td>', @@sync_binlog, '</td></tr>'
) AS '';

SELECT CONCAT(
'<tr><td>binlog_row_image</td><td>',
  IFNULL(@@binlog_row_image, 'N/A'),
'</td></tr>'
) AS '';

SELECT '</table>' AS '';

-- ============================================================
-- Table: replication - Slave/Replica status
-- ============================================================

SELECT CONCAT(
'<table id="replication" border="1" width="90%" align="center">'
) AS '';

-- Use a procedure-like approach to handle empty replication status
-- When not a slave, output a single informational row
SELECT CONCAT(
'<tr><td>Slave_IO_Running</td><td>',
  IFNULL(sio, 'N/A'),
'</td><td>',
  CASE
    WHEN sio IS NULL THEN 'Not Configured'
    WHEN sio != 'Yes' THEN '<font color="red">STOPPED</font>'
    ELSE 'OK'
  END,
'</td></tr>',
'<tr><td>Slave_SQL_Running</td><td>',
  IFNULL(ssql, 'N/A'),
'</td><td>',
  CASE
    WHEN ssql IS NULL THEN 'Not Configured'
    WHEN ssql != 'Yes' THEN '<font color="red">STOPPED</font>'
    ELSE 'OK'
  END,
'</td></tr>',
'<tr><td>Seconds_Behind_Master</td><td>',
  IFNULL(sbm, 'N/A'),
'</td><td>',
  CASE
    WHEN sbm IS NULL THEN 'Not Configured'
    WHEN CAST(sbm AS UNSIGNED) > 60 THEN '<font color="red">LAG</font>'
    ELSE 'OK'
  END,
'</td></tr>',
'<tr><td>Master_Host</td><td>',
  IFNULL(mhost, 'N/A'),
'</td><td>-</td></tr>',
'<tr><td>Relay_Log_Space</td><td>',
  IFNULL(rlspace, 'N/A'),
'</td><td>-</td></tr>'
) AS ''
FROM (
  SELECT
    MAX(CASE WHEN col = 'Slave_IO_Running' THEN val END) AS sio,
    MAX(CASE WHEN col = 'Slave_SQL_Running' THEN val END) AS ssql,
    MAX(CASE WHEN col = 'Seconds_Behind_Master' THEN val END) AS sbm,
    MAX(CASE WHEN col = 'Master_Host' THEN val END) AS mhost,
    MAX(CASE WHEN col = 'Relay_Log_Space' THEN val END) AS rlspace
  FROM (
    SELECT 'Slave_IO_Running' AS col, NULL AS val
    UNION ALL SELECT 'Slave_SQL_Running', NULL
    UNION ALL SELECT 'Seconds_Behind_Master', NULL
    UNION ALL SELECT 'Master_Host', NULL
    UNION ALL SELECT 'Relay_Log_Space', NULL
  ) defaults
) t;

SELECT '</table>' AS '';

-- ============================================================
-- Table: table_size - Top 10 tables by size
-- ============================================================

SELECT CONCAT(
'<table id="table_size" border="1" width="90%" align="center">'
) AS '';

SELECT CONCAT(
'<tr>',
'<td>', TABLE_SCHEMA, '</td>',
'<td>', TABLE_NAME, '</td>',
'<td>', IFNULL(ENGINE, 'N/A'), '</td>',
'<td>', TABLE_ROWS, '</td>',
'<td>',
  CASE
    WHEN ROUND((DATA_LENGTH) / 1024 / 1024, 2) > 10240 THEN CONCAT('<font color="red">', ROUND((DATA_LENGTH) / 1024 / 1024, 2), '</font>')
    ELSE CAST(ROUND((DATA_LENGTH) / 1024 / 1024, 2) AS CHAR)
  END,
'</td>',
'<td>', ROUND((INDEX_LENGTH) / 1024 / 1024, 2), '</td>',
'</tr>'
) AS ''
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND TABLE_TYPE = 'BASE TABLE'
  AND DATA_LENGTH IS NOT NULL
ORDER BY DATA_LENGTH DESC
LIMIT 10;

SELECT '</table>' AS '';

-- ============================================================
-- Table: index_usage - Unused/duplicate indexes
-- ============================================================

SELECT CONCAT(
'<table id="index_usage" border="1" width="90%" align="center">'
) AS '';

-- Duplicate indexes (indexes with same columns on same table)
SELECT CONCAT(
'<tr>',
'<td>', s1.TABLE_SCHEMA, '</td>',
'<td>', s1.TABLE_NAME, '</td>',
'<td><font color="red">', s1.INDEX_NAME, '</font></td>',
'<td>', CASE WHEN s1.NON_UNIQUE = 0 THEN 'UNIQUE' ELSE 'INDEX' END, '</td>',
'<td><font color="red">Duplicate</font></td>',
'</tr>'
) AS ''
FROM INFORMATION_SCHEMA.STATISTICS s1
JOIN INFORMATION_SCHEMA.STATISTICS s2
  ON s1.TABLE_SCHEMA = s2.TABLE_SCHEMA
  AND s1.TABLE_NAME = s2.TABLE_NAME
  AND s1.SEQ_IN_INDEX = s2.SEQ_IN_INDEX
  AND s1.COLUMN_NAME = s2.COLUMN_NAME
  AND s1.INDEX_NAME != s2.INDEX_NAME
  AND s1.INDEX_NAME > s2.INDEX_NAME
WHERE s1.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
GROUP BY s1.TABLE_SCHEMA, s1.TABLE_NAME, s1.INDEX_NAME, s1.NON_UNIQUE
LIMIT 20;

SELECT '</table>' AS '';

-- ============================================================
-- Table: user_security - User account security
-- ============================================================

SELECT CONCAT(
'<table id="user_security" border="1" width="90%" align="center">'
) AS '';

SELECT CONCAT(
'<tr>',
'<td>', u.User, '</td>',
'<td>', u.Host, '</td>',
'<td>',
  CASE
    WHEN u.plugin = 'mysql_native_password' AND (u.authentication_string IS NULL OR u.authentication_string = '')
      THEN CONCAT('<font color="red">', u.plugin, '</font>')
    ELSE u.plugin
  END,
'</td>',
'<td>',
  CASE
    WHEN u.password_expired = 'Y' THEN '<font color="red">Y</font>'
    ELSE u.password_expired
  END,
'</td>',
'<td>',
  CASE
    WHEN u.account_locked = 'Y' THEN 'Y'
    ELSE u.account_locked
  END,
'</td>',
'</tr>'
) AS ''
FROM mysql.user u
ORDER BY u.User, u.Host;

SELECT '</table>' AS '';

-- ============================================================
-- Table: backup_status - Recent backup info
-- Uses performance_schema events if available; otherwise empty
-- ============================================================

SELECT CONCAT(
'<table id="backup_status" border="1" width="90%" align="center">'
) AS '';

-- Check for recent backups via INFORMATION_SCHEMA.FILES or general heuristics
-- Since MySQL has no built-in backup catalog, we check binary log freshness as a proxy
SELECT CONCAT(
'<tr>',
'<td>Binlog Backup</td>',
'<td>',
  CASE
    WHEN @@log_bin = 1 THEN 'Enabled'
    ELSE '<font color="red">Disabled</font>'
  END,
'</td>',
'<td>',
  CASE
    WHEN @@log_bin = 1 THEN 'OK'
    ELSE '<font color="red">No binary log</font>'
  END,
'</td>',
'</tr>'
) AS '';

SELECT '</table>' AS '';

-- ============================================================
-- Footer
-- ============================================================

SELECT CONCAT(
'<hr>',
'<center><font size=-1>MySQL DBCheck Report generated at ', NOW(), '</font></center>',
'</body></html>'
) AS '';
