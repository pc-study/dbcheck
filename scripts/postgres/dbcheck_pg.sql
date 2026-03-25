-- +------------------------------------------------------------------------------------+
-- |               Copyright (c) 2024 DBCheck2Word. All rights reserved.              |
-- +------------------------------------------------------------------------------------+
-- | DATABASE : PostgreSQL                                                             |
-- | FILE     : dbcheck_pg.sql                                                         |
-- | CLASS    : Database Administration                                                |
-- | PURPOSE  : Generate an HTML health check report for PostgreSQL databases.         |
-- | VERSION  : PostgreSQL 12+                                                         |
-- | USAGE    : psql -U postgres -d <dbname> -f dbcheck_pg.sql                         |
-- +------------------------------------------------------------------------------------+

-- Script settings: clean unaligned output, no headers, no footer
\pset format unaligned
\pset tuples_only on
\pset footer off
\pset fieldsep ''

-- Output to file
\o /tmp/dbcheck_pg_result.html

-- ============================================================================
-- HTML Header
-- ============================================================================
SELECT '<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>PostgreSQL DBCheck Report</title>
<style type="text/css">
  body          { font: 12px Consolas, monospace; color: black; background: white; }
  table         { font: 11px Consolas, monospace; color: black; background: #FFFFCC;
                  border-collapse: collapse; margin: 10px 0; }
  td, th        { border: 1px solid #999; padding: 4px 8px; }
  tr:nth-child(odd)  { background: white; }
  tr:hover      { background-color: #ffffaa; }
  th            { font-weight: bold; color: white; background: #0066cc; white-space: nowrap; }
  .section      { font-size: 14px; color: #336699; font-weight: bold; margin: 20px 0 5px 0; }
  .warn         { color: red; font-weight: bold; }
</style>
</head>
<body>';

-- ============================================================================
-- Report Title
-- ============================================================================
SELECT '<center><font size="+3" color="darkgreen"><b>'
    || current_database()
    || ' PostgreSQL DBCheck Report</b></font></center><hr>';

-- ============================================================================
-- Scalar Values (span tags) - Original 8
-- ============================================================================

-- dbversion
SELECT '<span id="dbversion">' || version() || '</span>';

-- hostname
SELECT '<span id="hostname">' || COALESCE(
    inet_server_addr()::text,
    (SELECT setting FROM pg_settings WHERE name = 'listen_addresses'),
    'localhost'
) || '</span>';

-- dbname
SELECT '<span id="dbname">' || current_database() || '</span>';

-- checkdate
SELECT '<span id="checkdate">' || to_char(now(), 'YYYY-MM-DD') || '</span>';

-- uptime
SELECT '<span id="uptime">'
    || COALESCE(
        (SELECT
            EXTRACT(day FROM (now() - pg_postmaster_start_time()))::int || ' days '
            || EXTRACT(hour FROM (now() - pg_postmaster_start_time()))::int || ' hours '
            || EXTRACT(minute FROM (now() - pg_postmaster_start_time()))::int || ' min'
        ),
        'N/A'
    )
    || '</span>';

-- port
SELECT '<span id="port">'
    || COALESCE(
        inet_server_port()::text,
        (SELECT setting FROM pg_settings WHERE name = 'port'),
        '5432'
    )
    || '</span>';

-- datadir
SELECT '<span id="datadir">' || (SELECT setting FROM pg_settings WHERE name = 'data_directory') || '</span>';

-- max_connections_setting
SELECT '<span id="max_connections_setting">'
    || (SELECT setting FROM pg_settings WHERE name = 'max_connections')
    || '</span>';

-- ============================================================================
-- Scalar Values (span tags) - New 5
-- ============================================================================

-- cluster_name
SELECT '<span id="cluster_name">'
    || COALESCE(
        NULLIF((SELECT setting FROM pg_settings WHERE name = 'cluster_name'), ''),
        'not set'
    )
    || '</span>';

-- pg_config_file
SELECT '<span id="pg_config_file">'
    || (SELECT setting FROM pg_settings WHERE name = 'config_file')
    || '</span>';

-- shared_buffers
SELECT '<span id="shared_buffers">'
    || (SELECT setting || ' ' || unit FROM pg_settings WHERE name = 'shared_buffers')
    || '</span>';

-- work_mem
SELECT '<span id="work_mem">'
    || (SELECT setting || ' ' || unit FROM pg_settings WHERE name = 'work_mem')
    || '</span>';

-- effective_cache_size
SELECT '<span id="effective_cache_size">'
    || (SELECT setting || ' ' || unit FROM pg_settings WHERE name = 'effective_cache_size')
    || '</span>';

-- ============================================================================
-- Table: instance_info
-- Instance configuration parameters
-- ============================================================================
SELECT '<p class="section">Instance Configuration</p>';
SELECT '<table id="instance_info">'
    || '<tr><th>Parameter</th><th>Value</th></tr>';

SELECT '<tr>'
    || '<td>' || name || '</td>'
    || '<td>' || setting || CASE WHEN unit IS NOT NULL AND unit <> '' THEN ' ' || unit ELSE '' END || '</td>'
    || '</tr>'
FROM pg_settings
WHERE name IN (
    'shared_buffers',
    'work_mem',
    'maintenance_work_mem',
    'effective_cache_size',
    'wal_buffers',
    'max_wal_size',
    'min_wal_size',
    'checkpoint_timeout',
    'checkpoint_completion_target',
    'random_page_cost',
    'effective_io_concurrency',
    'max_parallel_workers',
    'max_parallel_workers_per_gather',
    'autovacuum'
)
ORDER BY name;

SELECT '</table>';

-- ============================================================================
-- Table: database_detail
-- Detailed database information
-- ============================================================================
SELECT '<p class="section">Database Detail</p>';
SELECT '<table id="database_detail">'
    || '<tr><th>Database</th><th>Owner</th><th>Encoding</th><th>Collation</th><th>Tablespace</th><th>Size</th><th>Connections</th><th>Age</th></tr>';

SELECT '<tr>'
    || '<td>' || d.datname || '</td>'
    || '<td>' || r.rolname || '</td>'
    || '<td>' || pg_encoding_to_char(d.encoding) || '</td>'
    || '<td>' || d.datcollate || '</td>'
    || '<td>' || t.spcname || '</td>'
    || '<td>' || pg_size_pretty(pg_database_size(d.datname)) || '</td>'
    || '<td>' || (SELECT count(*) FROM pg_stat_activity WHERE datname = d.datname) || '</td>'
    || '<td>'
    || CASE
        WHEN age(d.datfrozenxid) > 1000000000
            THEN '<font color="red"><b>' || age(d.datfrozenxid)::text || '</b></font>'
        ELSE age(d.datfrozenxid)::text
       END
    || '</td>'
    || '</tr>'
FROM pg_database d
JOIN pg_roles r ON d.datdba = r.oid
JOIN pg_tablespace t ON d.dattablespace = t.oid
WHERE d.datistemplate = false
ORDER BY pg_database_size(d.datname) DESC;

SELECT '</table>';

-- ============================================================================
-- Table: object_count
-- Object counts per schema
-- ============================================================================
SELECT '<p class="section">Object Count per Schema</p>';
SELECT '<table id="object_count">'
    || '<tr><th>Schema</th><th>Tables</th><th>Indexes</th><th>Sequences</th><th>Views</th><th>Functions</th></tr>';

SELECT '<tr>'
    || '<td>' || n.nspname || '</td>'
    || '<td>' || (SELECT count(*) FROM pg_class c WHERE c.relnamespace = n.oid AND c.relkind = 'r') || '</td>'
    || '<td>' || (SELECT count(*) FROM pg_class c WHERE c.relnamespace = n.oid AND c.relkind = 'i') || '</td>'
    || '<td>' || (SELECT count(*) FROM pg_class c WHERE c.relnamespace = n.oid AND c.relkind = 'S') || '</td>'
    || '<td>' || (SELECT count(*) FROM pg_class c WHERE c.relnamespace = n.oid AND c.relkind = 'v') || '</td>'
    || '<td>' || (SELECT count(*) FROM pg_proc p WHERE p.pronamespace = n.oid) || '</td>'
    || '</tr>'
FROM pg_namespace n
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
  AND n.nspname NOT LIKE 'pg_temp_%'
  AND n.nspname NOT LIKE 'pg_toast_temp_%'
  AND (
      EXISTS (SELECT 1 FROM pg_class c WHERE c.relnamespace = n.oid AND c.relkind IN ('r','i','S','v'))
      OR EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = n.oid)
  )
ORDER BY n.nspname;

SELECT '</table>';

-- ============================================================================
-- Table: table_age
-- Tables approaching TXID wraparound
-- ============================================================================
SELECT '<p class="section">Table Age (TXID Wraparound Risk)</p>';
SELECT '<table id="table_age">'
    || '<tr><th>Schema</th><th>Table</th><th>Age</th><th>Size</th></tr>';

SELECT '<tr>'
    || '<td>' || n.nspname || '</td>'
    || '<td>' || c.relname || '</td>'
    || '<td>'
    || CASE
        WHEN age(c.relfrozenxid) > 500000000
            THEN '<font color="red"><b>' || age(c.relfrozenxid)::text || '</b></font>'
        ELSE age(c.relfrozenxid)::text
       END
    || '</td>'
    || '<td>' || pg_size_pretty(pg_total_relation_size(c.oid)) || '</td>'
    || '</tr>'
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
ORDER BY age(c.relfrozenxid) DESC
LIMIT 30;

SELECT '</table>';

-- ============================================================================
-- Table: top_tables_by_size
-- Top 20 largest tables
-- ============================================================================
SELECT '<p class="section">Top 20 Tables by Size</p>';
SELECT '<table id="top_tables_by_size">'
    || '<tr><th>Schema</th><th>Table</th><th>Total_Size</th><th>Table_Size</th><th>Index_Size</th><th>Rows</th></tr>';

SELECT '<tr>'
    || '<td>' || n.nspname || '</td>'
    || '<td>' || c.relname || '</td>'
    || '<td>'
    || CASE
        WHEN pg_total_relation_size(c.oid) > 10737418240
            THEN '<font color="red"><b>' || pg_size_pretty(pg_total_relation_size(c.oid)) || '</b></font>'
        ELSE pg_size_pretty(pg_total_relation_size(c.oid))
       END
    || '</td>'
    || '<td>' || pg_size_pretty(pg_relation_size(c.oid)) || '</td>'
    || '<td>' || pg_size_pretty(pg_indexes_size(c.oid)) || '</td>'
    || '<td>' || c.reltuples::bigint || '</td>'
    || '</tr>'
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
ORDER BY pg_total_relation_size(c.oid) DESC
LIMIT 20;

SELECT '</table>';

-- ============================================================================
-- Table: tablespace_usage
-- ============================================================================
SELECT '<p class="section">Tablespace Usage</p>';
SELECT '<table id="tablespace_usage">'
    || '<tr><th>Name</th><th>Location</th><th>Size</th><th>Owner</th></tr>';

SELECT '<tr>'
    || '<td>' || spcname || '</td>'
    || '<td>' || COALESCE(pg_tablespace_location(oid), 'default (' || (SELECT setting FROM pg_settings WHERE name = 'data_directory') || ')') || '</td>'
    || '<td>' || COALESCE(pg_size_pretty(pg_tablespace_size(oid)), 'N/A') || '</td>'
    || '<td>' || (SELECT rolname FROM pg_roles WHERE oid = spcowner) || '</td>'
    || '</tr>'
FROM pg_tablespace
ORDER BY pg_tablespace_size(oid) DESC NULLS LAST;

SELECT '</table>';

-- ============================================================================
-- Table: connection_count
-- ============================================================================
SELECT '<p class="section">Connection Count</p>';
SELECT '<table id="connection_count">'
    || '<tr><th>State</th><th>Count</th><th>Database</th></tr>';

SELECT '<tr>'
    || '<td>' || COALESCE(state, 'total') || '</td>'
    || '<td>' || count(*) || '</td>'
    || '<td>' || COALESCE(datname, 'all') || '</td>'
    || '</tr>'
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
GROUP BY GROUPING SETS ((state, datname), ())
ORDER BY count(*) DESC;

SELECT '</table>';

-- ============================================================================
-- Table: slow_query
-- ============================================================================
SELECT '<p class="section">Slow Queries (> 1 min)</p>';
SELECT '<table id="slow_query">'
    || '<tr><th>PID</th><th>Duration</th><th>State</th><th>Query</th></tr>';

SELECT '<tr>'
    || '<td>' || pid || '</td>'
    || '<td>'
    || CASE
        WHEN now() - query_start > interval '5 minutes'
            THEN '<font color="red"><b>' || (now() - query_start)::text || '</b></font>'
        ELSE (now() - query_start)::text
       END
    || '</td>'
    || '<td>' || COALESCE(state, '') || '</td>'
    || '<td>' || COALESCE(left(replace(replace(query, '<', '&lt;'), '>', '&gt;'), 200), '') || '</td>'
    || '</tr>'
FROM pg_stat_activity
WHERE state = 'active'
  AND pid <> pg_backend_pid()
  AND now() - query_start > interval '1 minute'
ORDER BY query_start ASC
LIMIT 50;

SELECT '</table>';

-- ============================================================================
-- Table: vacuum_status
-- ============================================================================
SELECT '<p class="section">Vacuum Status</p>';
SELECT '<table id="vacuum_status">'
    || '<tr><th>Schema</th><th>Table</th><th>Last_Vacuum</th><th>Last_Autovacuum</th><th>Dead_Tuples</th><th>Live_Tuples</th></tr>';

SELECT '<tr>'
    || '<td>' || schemaname || '</td>'
    || '<td>' || relname || '</td>'
    || '<td>' || COALESCE(to_char(last_vacuum, 'YYYY-MM-DD HH24:MI:SS'), 'never') || '</td>'
    || '<td>' || COALESCE(to_char(last_autovacuum, 'YYYY-MM-DD HH24:MI:SS'), 'never') || '</td>'
    || '<td>'
    || CASE
        WHEN n_dead_tup > 10000
             AND COALESCE(last_autovacuum, last_vacuum, '1970-01-01'::timestamptz) < now() - interval '7 days'
            THEN '<font color="red"><b>' || n_dead_tup || '</b></font>'
        ELSE n_dead_tup::text
       END
    || '</td>'
    || '<td>' || n_live_tup || '</td>'
    || '</tr>'
FROM pg_stat_user_tables
WHERE n_dead_tup > 0
ORDER BY n_dead_tup DESC
LIMIT 50;

SELECT '</table>';

-- ============================================================================
-- Table: replication
-- ============================================================================
SELECT '<p class="section">Replication Status</p>';
SELECT '<table id="replication">'
    || '<tr><th>Client</th><th>State</th><th>Sent_LSN</th><th>Write_LSN</th><th>Flush_LSN</th><th>Replay_LSN</th><th>Lag_Bytes</th></tr>';

SELECT '<tr>'
    || '<td>' || COALESCE(client_addr::text, 'local') || '</td>'
    || '<td>' || COALESCE(state, '') || '</td>'
    || '<td>' || COALESCE(sent_lsn::text, '') || '</td>'
    || '<td>' || COALESCE(write_lsn::text, '') || '</td>'
    || '<td>' || COALESCE(flush_lsn::text, '') || '</td>'
    || '<td>' || COALESCE(replay_lsn::text, '') || '</td>'
    || '<td>'
    || CASE
        WHEN sent_lsn IS NOT NULL AND replay_lsn IS NOT NULL
             AND (pg_wal_lsn_diff(sent_lsn, replay_lsn)) > 10485760
            THEN '<font color="red"><b>' || pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)::bigint) || '</b></font>'
        WHEN sent_lsn IS NOT NULL AND replay_lsn IS NOT NULL
            THEN pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)::bigint)
        ELSE 'N/A'
       END
    || '</td>'
    || '</tr>'
FROM pg_stat_replication;

SELECT '</table>';

-- ============================================================================
-- Table: wal_archive
-- ============================================================================
SELECT '<p class="section">WAL Archive Status</p>';
SELECT '<table id="wal_archive">'
    || '<tr><th>Variable</th><th>Value</th></tr>';

SELECT '<tr><td>archive_mode</td><td>' || (SELECT setting FROM pg_settings WHERE name = 'archive_mode') || '</td></tr>';
SELECT '<tr><td>archive_command</td><td>' || COALESCE((SELECT setting FROM pg_settings WHERE name = 'archive_command'), 'not set') || '</td></tr>';
SELECT '<tr><td>archived_count</td><td>' || archived_count || '</td></tr>'
    || '<tr><td>last_archived_wal</td><td>' || COALESCE(last_archived_wal, 'none') || '</td></tr>'
    || '<tr><td>last_archived_time</td><td>' || COALESCE(to_char(last_archived_time, 'YYYY-MM-DD HH24:MI:SS'), 'never') || '</td></tr>'
    || '<tr><td>failed_count</td><td>'
    || CASE
        WHEN failed_count > 0
            THEN '<font color="red"><b>' || failed_count || '</b></font>'
        ELSE '0'
       END
    || '</td></tr>'
    || '<tr><td>last_failed_wal</td><td>' || COALESCE(last_failed_wal, 'none') || '</td></tr>'
    || '<tr><td>last_failed_time</td><td>'
    || CASE
        WHEN last_failed_time IS NOT NULL AND last_failed_time > now() - interval '24 hours'
            THEN '<font color="red"><b>' || to_char(last_failed_time, 'YYYY-MM-DD HH24:MI:SS') || '</b></font>'
        ELSE COALESCE(to_char(last_failed_time, 'YYYY-MM-DD HH24:MI:SS'), 'never')
       END
    || '</td></tr>'
FROM pg_stat_archiver;

SELECT '</table>';

-- ============================================================================
-- Table: bloat_tables
-- ============================================================================
SELECT '<p class="section">Table Bloat Estimation</p>';
SELECT '<table id="bloat_tables">'
    || '<tr><th>Schema</th><th>Table</th><th>Size</th><th>Bloat_Size</th><th>Bloat_Ratio</th></tr>';

SELECT '<tr>'
    || '<td>' || schemaname || '</td>'
    || '<td>' || tblname || '</td>'
    || '<td>' || pg_size_pretty(real_size::bigint) || '</td>'
    || '<td>' || pg_size_pretty(bloat_size::bigint) || '</td>'
    || '<td>'
    || CASE
        WHEN bloat_ratio > 40
            THEN '<font color="red"><b>' || round(bloat_ratio::numeric, 1) || '%</b></font>'
        ELSE round(bloat_ratio::numeric, 1) || '%'
       END
    || '</td>'
    || '</tr>'
FROM (
    SELECT
        schemaname,
        tblname,
        (bs * tblpages) AS real_size,
        CASE WHEN tblpages - est_tblpages > 0
            THEN (bs * (tblpages - est_tblpages))::float8
            ELSE 0
        END AS bloat_size,
        CASE WHEN tblpages > 0
            THEN 100.0 * (tblpages - est_tblpages) / tblpages
            ELSE 0
        END AS bloat_ratio
    FROM (
        SELECT
            ceil(reltuples / ((bs - page_hdr) / (4 + nullhdr2 + ma - CASE WHEN nullhdr2 % ma = 0 THEN ma ELSE nullhdr2 % ma END))) + 1 AS est_tblpages,
            tblpages, bs, schemaname, tblname
        FROM (
            SELECT
                s.schemaname,
                s.relname AS tblname,
                c.relpages AS tblpages,
                current_setting('block_size')::int AS bs,
                23 AS page_hdr,
                CASE WHEN MAX(COALESCE(s2.null_frac, 0)) > 0
                    THEN (2 + MAX(COALESCE(s2.avg_width, 0))) / 8.0
                    ELSE 0
                END AS nullhdr2,
                8 AS ma,
                c.reltuples
            FROM pg_stat_user_tables s
            JOIN pg_class c ON s.relid = c.oid
            LEFT JOIN pg_stats s2 ON s2.schemaname = s.schemaname AND s2.tablename = s.relname
            WHERE c.relpages > 0
              AND c.reltuples > 0
            GROUP BY s.schemaname, s.relname, c.relpages, c.reltuples
        ) sub
    ) sub2
    WHERE tblpages > 8
) sub3
WHERE bloat_ratio > 10
ORDER BY bloat_size DESC
LIMIT 50;

SELECT '</table>';

-- ============================================================================
-- Table: index_usage
-- ============================================================================
SELECT '<p class="section">Index Usage Statistics</p>';
SELECT '<table id="index_usage">'
    || '<tr><th>Schema</th><th>Table</th><th>Index</th><th>Scans</th><th>Size</th><th>Usage</th></tr>';

SELECT '<tr>'
    || '<td>' || s.schemaname || '</td>'
    || '<td>' || s.relname || '</td>'
    || '<td>' || s.indexrelname || '</td>'
    || '<td>'
    || CASE
        WHEN s.idx_scan = 0
            THEN '<font color="red"><b>0</b></font>'
        ELSE s.idx_scan::text
       END
    || '</td>'
    || '<td>' || pg_size_pretty(pg_relation_size(s.indexrelid)) || '</td>'
    || '<td>'
    || CASE
        WHEN s.idx_scan = 0
            THEN '<font color="red"><b>unused</b></font>'
        ELSE 'active'
       END
    || '</td>'
    || '</tr>'
FROM pg_stat_user_indexes s
JOIN pg_index i ON s.indexrelid = i.indexrelid
WHERE NOT i.indisunique
  AND NOT i.indisprimary
  AND s.schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY s.idx_scan ASC, pg_relation_size(s.indexrelid) DESC
LIMIT 50;

SELECT '</table>';

-- ============================================================================
-- Table: lock_conflicts
-- ============================================================================
SELECT '<p class="section">Lock Conflicts</p>';
SELECT '<table id="lock_conflicts">'
    || '<tr><th>Blocked_PID</th><th>Blocked_Query</th><th>Blocking_PID</th><th>Blocking_Query</th></tr>';

SELECT '<tr>'
    || '<td><font color="red"><b>' || blocked_locks.pid || '</b></font></td>'
    || '<td>' || COALESCE(left(replace(replace(blocked_activity.query, '<', '&lt;'), '>', '&gt;'), 200), '') || '</td>'
    || '<td>' || blocking_locks.pid || '</td>'
    || '<td>' || COALESCE(left(replace(replace(blocking_activity.query, '<', '&lt;'), '>', '&gt;'), 200), '') || '</td>'
    || '</tr>'
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted
LIMIT 50;

SELECT '</table>';

-- ============================================================================
-- Table: backup_status (pg_stat_archiver)
-- ============================================================================
SELECT '<p class="section">Backup / Archiver Status</p>';
SELECT '<table id="backup_status">'
    || '<tr><th>Variable</th><th>Value</th></tr>';

SELECT '<tr><td>archived_count</td><td>' || archived_count || '</td></tr>'
    || '<tr><td>last_archived_wal</td><td>' || COALESCE(last_archived_wal, 'none') || '</td></tr>'
    || '<tr><td>last_archived_time</td><td>' || COALESCE(to_char(last_archived_time, 'YYYY-MM-DD HH24:MI:SS'), 'never') || '</td></tr>'
    || '<tr><td>failed_count</td><td>'
    || CASE
        WHEN failed_count > 0
            THEN '<font color="red"><b>' || failed_count || '</b></font>'
        ELSE '0'
       END
    || '</td></tr>'
    || '<tr><td>last_failed_wal</td><td>' || COALESCE(last_failed_wal, 'none') || '</td></tr>'
    || '<tr><td>last_failed_time</td><td>' || COALESCE(to_char(last_failed_time, 'YYYY-MM-DD HH24:MI:SS'), 'never') || '</td></tr>'
    || '<tr><td>stats_reset</td><td>' || COALESCE(to_char(stats_reset, 'YYYY-MM-DD HH24:MI:SS'), 'never') || '</td></tr>'
FROM pg_stat_archiver;

SELECT '</table>';

-- ============================================================================
-- Table: db_size
-- ============================================================================
SELECT '<p class="section">Database Sizes</p>';
SELECT '<table id="db_size">'
    || '<tr><th>Database</th><th>Size</th><th>Owner</th></tr>';

SELECT '<tr>'
    || '<td>' || d.datname || '</td>'
    || '<td>'
    || CASE
        WHEN pg_database_size(d.datname) > 107374182400
            THEN '<font color="red"><b>' || pg_size_pretty(pg_database_size(d.datname)) || '</b></font>'
        ELSE pg_size_pretty(pg_database_size(d.datname))
       END
    || '</td>'
    || '<td>' || r.rolname || '</td>'
    || '</tr>'
FROM pg_database d
JOIN pg_roles r ON d.datdba = r.oid
WHERE d.datistemplate = false
ORDER BY pg_database_size(d.datname) DESC;

SELECT '</table>';

-- ============================================================================
-- Table: extension_list
-- ============================================================================
SELECT '<p class="section">Installed Extensions</p>';
SELECT '<table id="extension_list">'
    || '<tr><th>Name</th><th>Version</th><th>Schema</th><th>Description</th></tr>';

SELECT '<tr>'
    || '<td>' || e.extname || '</td>'
    || '<td>' || e.extversion || '</td>'
    || '<td>' || n.nspname || '</td>'
    || '<td>' || COALESCE(replace(replace(c.description, '<', '&lt;'), '>', '&gt;'), '') || '</td>'
    || '</tr>'
FROM pg_extension e
JOIN pg_namespace n ON e.extnamespace = n.oid
LEFT JOIN pg_description c ON c.objoid = e.oid AND c.classoid = 'pg_extension'::regclass
ORDER BY e.extname;

SELECT '</table>';

-- ============================================================================
-- Table: cache_hit_ratio
-- Buffer cache hit ratios per database
-- ============================================================================
SELECT '<p class="section">Cache Hit Ratio</p>';
SELECT '<table id="cache_hit_ratio">'
    || '<tr><th>Database</th><th>Heap_Hit_Ratio</th><th>Index_Hit_Ratio</th></tr>';

SELECT '<tr>'
    || '<td>' || datname || '</td>'
    || '<td>'
    || CASE
        WHEN heap_hit_ratio < 95
            THEN '<font color="red"><b>' || heap_hit_ratio || '%</b></font>'
        ELSE heap_hit_ratio || '%'
       END
    || '</td>'
    || '<td>'
    || CASE
        WHEN idx_hit_ratio < 95
            THEN '<font color="red"><b>' || idx_hit_ratio || '%</b></font>'
        ELSE idx_hit_ratio || '%'
       END
    || '</td>'
    || '</tr>'
FROM (
    SELECT
        datname,
        round(
            CASE WHEN (blks_hit + blks_read) > 0
                THEN 100.0 * blks_hit / (blks_hit + blks_read)
                ELSE 100
            END, 2
        ) AS heap_hit_ratio,
        round(
            CASE WHEN (blks_hit + blks_read) > 0
                THEN 100.0 * blks_hit / (blks_hit + blks_read)
                ELSE 100
            END, 2
        ) AS idx_hit_ratio
    FROM pg_stat_database
    WHERE datname NOT LIKE 'template%'
      AND datname IS NOT NULL
) sub
ORDER BY datname;

SELECT '</table>';

-- ============================================================================
-- Table: bgwriter_stats
-- Background writer / checkpointer statistics
-- PG 17+ moved checkpoint stats to pg_stat_checkpointer; PG <= 16 uses pg_stat_bgwriter.
-- We detect the version and query the correct view.
-- ============================================================================
SELECT '<p class="section">Background Writer Statistics</p>';
SELECT '<table id="bgwriter_stats">'
    || '<tr><th>Metric</th><th>Value</th></tr>';

SELECT
    '<tr><td>checkpoints_timed</td><td>' || v.timed || '</td></tr>'
    || '<tr><td>checkpoints_req</td><td>'
    || CASE
        WHEN v.req > v.timed AND v.timed > 0
            THEN '<font color="red"><b>' || v.req || '</b></font>'
        ELSE v.req::text
       END
    || '</td></tr>'
FROM (
    SELECT num_timed AS timed, num_requested AS req
    FROM pg_stat_checkpointer
) v;

SELECT '<tr><td>buffers_clean</td><td>' || buffers_clean || '</td></tr>'
    || '<tr><td>maxwritten_clean</td><td>'
    || CASE
        WHEN maxwritten_clean > 0
            THEN '<font color="red"><b>' || maxwritten_clean || '</b></font>'
        ELSE '0'
       END
    || '</td></tr>'
    || '<tr><td>buffers_alloc</td><td>' || buffers_alloc || '</td></tr>'
    || '<tr><td>stats_reset</td><td>' || COALESCE(to_char(stats_reset, 'YYYY-MM-DD HH24:MI:SS'), 'never') || '</td></tr>'
FROM pg_stat_bgwriter;

SELECT '</table>';

-- ============================================================================
-- Table: user_roles
-- Database roles and users
-- ============================================================================
SELECT '<p class="section">Database Roles and Users</p>';
SELECT '<table id="user_roles">'
    || '<tr><th>Role</th><th>Super</th><th>CreateDB</th><th>CreateRole</th><th>Login</th><th>Replication</th><th>Connections</th><th>Expiry</th></tr>';

SELECT '<tr>'
    || '<td>' || rolname || '</td>'
    || '<td>'
    || CASE
        WHEN rolsuper AND rolname <> 'postgres'
            THEN '<font color="red"><b>YES</b></font>'
        WHEN rolsuper
            THEN 'YES'
        ELSE 'no'
       END
    || '</td>'
    || '<td>' || CASE WHEN rolcreatedb THEN 'YES' ELSE 'no' END || '</td>'
    || '<td>' || CASE WHEN rolcreaterole THEN 'YES' ELSE 'no' END || '</td>'
    || '<td>' || CASE WHEN rolcanlogin THEN 'YES' ELSE 'no' END || '</td>'
    || '<td>' || CASE WHEN rolreplication THEN 'YES' ELSE 'no' END || '</td>'
    || '<td>' || CASE WHEN rolconnlimit = -1 THEN 'unlimited' ELSE rolconnlimit::text END || '</td>'
    || '<td>'
    || CASE
        WHEN rolvaliduntil IS NOT NULL AND rolvaliduntil < now()
            THEN '<font color="red"><b>' || to_char(rolvaliduntil, 'YYYY-MM-DD HH24:MI:SS') || ' (EXPIRED)</b></font>'
        WHEN rolvaliduntil IS NOT NULL
            THEN to_char(rolvaliduntil, 'YYYY-MM-DD HH24:MI:SS')
        ELSE 'never'
       END
    || '</td>'
    || '</tr>'
FROM pg_roles
ORDER BY rolname;

SELECT '</table>';

-- ============================================================================
-- Table: pg_hba_rules
-- pg_hba.conf rules (PG 12+ has pg_hba_file_rules)
-- ============================================================================
SELECT '<p class="section">pg_hba.conf Rules</p>';
SELECT '<table id="pg_hba_rules">'
    || '<tr><th>Line</th><th>Type</th><th>Database</th><th>User</th><th>Address</th><th>Auth_Method</th></tr>';

SELECT '<tr>'
    || '<td>' || line_number || '</td>'
    || '<td>' || COALESCE(type, '') || '</td>'
    || '<td>' || COALESCE(array_to_string(database, ', '), '') || '</td>'
    || '<td>' || COALESCE(array_to_string(user_name, ', '), '') || '</td>'
    || '<td>' || COALESCE(address, '') || '</td>'
    || '<td>'
    || CASE
        WHEN auth_method = 'trust'
            THEN '<font color="red"><b>trust</b></font>'
        ELSE COALESCE(auth_method, '')
       END
    || '</td>'
    || '</tr>'
FROM pg_hba_file_rules
WHERE error IS NULL
ORDER BY line_number;

SELECT '</table>';

-- ============================================================================
-- Table: unused_indexes_detail
-- Detailed unused index analysis
-- ============================================================================
SELECT '<p class="section">Unused Indexes (Detailed)</p>';
SELECT '<table id="unused_indexes_detail">'
    || '<tr><th>Schema</th><th>Table</th><th>Index</th><th>Size</th><th>Scans</th><th>Last_Used</th></tr>';

SELECT '<tr>'
    || '<td>' || s.schemaname || '</td>'
    || '<td>' || s.relname || '</td>'
    || '<td>'
    || CASE
        WHEN pg_relation_size(s.indexrelid) > 1048576 AND s.idx_scan = 0
            THEN '<font color="red"><b>' || s.indexrelname || '</b></font>'
        ELSE s.indexrelname
       END
    || '</td>'
    || '<td>'
    || CASE
        WHEN pg_relation_size(s.indexrelid) > 1048576 AND s.idx_scan = 0
            THEN '<font color="red"><b>' || pg_size_pretty(pg_relation_size(s.indexrelid)) || '</b></font>'
        ELSE pg_size_pretty(pg_relation_size(s.indexrelid))
       END
    || '</td>'
    || '<td>'
    || CASE
        WHEN s.idx_scan = 0
            THEN '<font color="red"><b>0</b></font>'
        ELSE s.idx_scan::text
       END
    || '</td>'
    || '<td>' || COALESCE(to_char(s.last_idx_scan, 'YYYY-MM-DD HH24:MI:SS'), 'never') || '</td>'
    || '</tr>'
FROM pg_stat_user_indexes s
JOIN pg_index i ON s.indexrelid = i.indexrelid
WHERE NOT i.indisunique
  AND NOT i.indisprimary
  AND s.schemaname NOT IN ('pg_catalog', 'information_schema')
  AND s.idx_scan = 0
  AND pg_relation_size(s.indexrelid) > 0
ORDER BY pg_relation_size(s.indexrelid) DESC
LIMIT 50;

SELECT '</table>';

-- ============================================================================
-- Table: database_stats
-- pg_stat_database statistics
-- ============================================================================
SELECT '<p class="section">Database Statistics</p>';
SELECT '<table id="database_stats">'
    || '<tr><th>Database</th><th>Commits</th><th>Rollbacks</th><th>Blks_Read</th><th>Blks_Hit</th><th>Conflicts</th><th>Deadlocks</th></tr>';

SELECT '<tr>'
    || '<td>' || datname || '</td>'
    || '<td>' || xact_commit || '</td>'
    || '<td>' || xact_rollback || '</td>'
    || '<td>' || blks_read || '</td>'
    || '<td>' || blks_hit || '</td>'
    || '<td>' || conflicts || '</td>'
    || '<td>'
    || CASE
        WHEN deadlocks > 0
            THEN '<font color="red"><b>' || deadlocks || '</b></font>'
        ELSE '0'
       END
    || '</td>'
    || '</tr>'
FROM pg_stat_database
WHERE datname NOT LIKE 'template%'
  AND datname IS NOT NULL
ORDER BY datname;

SELECT '</table>';

-- ============================================================================
-- HTML Footer
-- ============================================================================
SELECT '<hr><p>Report generated: ' || to_char(now(), 'YYYY-MM-DD HH24:MI:SS TZ') || '</p>';
SELECT '</body></html>';

-- Close output file
\o
\pset tuples_only off
