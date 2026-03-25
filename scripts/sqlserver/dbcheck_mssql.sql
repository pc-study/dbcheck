-- +------------------------------------------------------------------------------------+
-- |               Copyright (c) 2015-2100 lucifer. All rights reserved.               |
-- +------------------------------------------------------------------------------------+
-- | DATABASE : SQL Server                                                              |
-- | FILE     : dbcheck_mssql.sql                                                       |
-- | CLASS    : Database Administration                                                 |
-- | PURPOSE  : This T-SQL script provides a detailed report (in HTML format) on        |
-- |            all database metrics including storage, performance, security,           |
-- |            backup status, and availability group health.                            |
-- | VERSION  : This script was designed for SQL Server 2016+.                          |
-- | USAGE    :                                                                         |
-- |   sqlcmd -S <server> -d master -i dbcheck_mssql.sql -o dbcheck_mssql.html          |
-- |                                                                                    |
-- | NOTE     : Run with sysadmin or equivalent privileges.                             |
-- +------------------------------------------------------------------------------------+

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

-- ============================================================================
-- Helper: We build the entire HTML document in @html and print at the end.
-- Using NVARCHAR(MAX) throughout to avoid truncation.
-- ============================================================================

DECLARE @html NVARCHAR(MAX) = N'';
DECLARE @section NVARCHAR(MAX) = N'';
DECLARE @crlf NVARCHAR(2) = CHAR(13) + CHAR(10);

-- ============================================================================
-- Collect scalar values
-- ============================================================================
DECLARE @dbversion NVARCHAR(512);
DECLARE @hostname NVARCHAR(256);
DECLARE @dbname NVARCHAR(256);
DECLARE @checkdate NVARCHAR(20);
DECLARE @uptime NVARCHAR(128);
DECLARE @port NVARCHAR(20);
DECLARE @edition NVARCHAR(256);
DECLARE @collation NVARCHAR(256);

SET @dbversion = @@VERSION;
SET @hostname = CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(256));
SET @dbname = CAST(SERVERPROPERTY('InstanceName') AS NVARCHAR(256));
IF @dbname IS NULL SET @dbname = N'MSSQLSERVER';
SET @checkdate = CONVERT(NVARCHAR(20), GETDATE(), 23); -- YYYY-MM-DD
SET @edition = CAST(SERVERPROPERTY('Edition') AS NVARCHAR(256));
SET @collation = CAST(SERVERPROPERTY('Collation') AS NVARCHAR(256));

-- Uptime
BEGIN TRY
    DECLARE @start_time DATETIME;
    SELECT @start_time = sqlserver_start_time FROM sys.dm_os_sys_info;
    SET @uptime = CONVERT(NVARCHAR(20), @start_time, 120)
        + N' (up '
        + CAST(DATEDIFF(DAY, @start_time, GETDATE()) AS NVARCHAR(10))
        + N' days)';
END TRY
BEGIN CATCH
    SET @uptime = N'N/A';
END CATCH

-- TCP Port
BEGIN TRY
    SELECT @port = CAST(local_tcp_port AS NVARCHAR(20))
    FROM sys.dm_exec_connections
    WHERE session_id = @@SPID;
    IF @port IS NULL SET @port = N'N/A';
END TRY
BEGIN CATCH
    SET @port = N'N/A';
END CATCH

-- ============================================================================
-- HTML Header + Scalar Spans
-- ============================================================================
SET @html = @html
    + N'<html><head><meta charset="utf-8"><title>SQL Server DBCheck Report</title></head><body>' + @crlf
    + N'<center><font size="+3" color="darkgreen"><b>' + @dbname + N' DBCheck Report</b></font></center>' + @crlf
    + N'<hr>' + @crlf
    + N'<span id="dbversion">' + REPLACE(@dbversion, CHAR(10), ' ') + N'</span>' + @crlf
    + N'<span id="hostname">' + @hostname + N'</span>' + @crlf
    + N'<span id="dbname">' + @dbname + N'</span>' + @crlf
    + N'<span id="checkdate">' + @checkdate + N'</span>' + @crlf
    + N'<span id="uptime">' + @uptime + N'</span>' + @crlf
    + N'<span id="port">' + @port + N'</span>' + @crlf
    + N'<span id="edition">' + @edition + N'</span>' + @crlf
    + N'<span id="collation">' + @collation + N'</span>' + @crlf
    + N'<hr>' + @crlf;

-- ============================================================================
-- 1. filegroup_usage - Database file/filegroup usage
-- Columns: Database, FileGroup, File, Size_MB, Used_MB, Free_MB, Usage%
-- ============================================================================
BEGIN TRY
    SET @section = N'';
    SELECT @section = @section
        + N'<tr>'
        + N'<td>' + d.name + N'</td>'
        + N'<td>' + ISNULL(fg.name, N'LOG') + N'</td>'
        + N'<td>' + mf.name + N'</td>'
        + N'<td>' + CAST(CAST(mf.size * 8.0 / 1024 AS DECIMAL(12,2)) AS NVARCHAR(30)) + N'</td>'
        + N'<td>' + CAST(CAST(FILEPROPERTY(mf.name, 'SpaceUsed') * 8.0 / 1024 AS DECIMAL(12,2)) AS NVARCHAR(30)) + N'</td>'
        + N'<td>' + CAST(CAST((mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(12,2)) AS NVARCHAR(30)) + N'</td>'
        + CASE
            WHEN mf.size > 0 AND CAST(FILEPROPERTY(mf.name, 'SpaceUsed') AS FLOAT) / CAST(mf.size AS FLOAT) * 100 >= 90
            THEN N'<td><font color="red"><b>' + CAST(CAST(FILEPROPERTY(mf.name, 'SpaceUsed') * 100.0 / mf.size AS DECIMAL(5,2)) AS NVARCHAR(10)) + N'</b></font></td>'
            ELSE N'<td>' + CAST(CAST(CASE WHEN mf.size > 0 THEN FILEPROPERTY(mf.name, 'SpaceUsed') * 100.0 / mf.size ELSE 0 END AS DECIMAL(5,2)) AS NVARCHAR(10)) + N'</td>'
          END
        + N'</tr>' + @crlf
    FROM sys.master_files mf
    JOIN sys.databases d ON mf.database_id = d.database_id
    LEFT JOIN sys.filegroups fg ON mf.data_space_id = fg.data_space_id AND mf.database_id = DB_ID()
    WHERE d.state_desc = N'ONLINE'
    ORDER BY d.name, mf.type, mf.file_id;

    IF LEN(@section) > 0
        SET @html = @html + N'<table id="filegroup_usage" border="1" width="90%" align="center">'
            + N'<tr><th>Database</th><th>FileGroup</th><th>File</th><th>Size_MB</th><th>Used_MB</th><th>Free_MB</th><th>Usage%</th></tr>'
            + @section + N'</table>' + @crlf;
    ELSE
        SET @html = @html + N'<table id="filegroup_usage" border="1" width="90%" align="center">'
            + N'<tr><th>Database</th><th>FileGroup</th><th>File</th><th>Size_MB</th><th>Used_MB</th><th>Free_MB</th><th>Usage%</th></tr>'
            + N'</table>' + @crlf;
END TRY
BEGIN CATCH
    SET @html = @html + N'<!-- filegroup_usage error: ' + ERROR_MESSAGE() + N' -->' + @crlf
        + N'<table id="filegroup_usage" border="1" width="90%" align="center">'
        + N'<tr><th>Database</th><th>FileGroup</th><th>File</th><th>Size_MB</th><th>Used_MB</th><th>Free_MB</th><th>Usage%</th></tr>'
        + N'</table>' + @crlf;
END CATCH

-- ============================================================================
-- 2. connection_count - Current connections by database
-- Columns: Database, Login, Count, Status
-- ============================================================================
BEGIN TRY
    SET @section = N'';
    SELECT @section = @section
        + N'<tr>'
        + N'<td>' + ISNULL(DB_NAME(s.database_id), N'N/A') + N'</td>'
        + N'<td>' + ISNULL(s.login_name, N'N/A') + N'</td>'
        + N'<td>' + CAST(cnt AS NVARCHAR(10)) + N'</td>'
        + N'<td>' + status + N'</td>'
        + N'</tr>' + @crlf
    FROM (
        SELECT database_id, login_name, status, COUNT(*) AS cnt
        FROM sys.dm_exec_sessions
        WHERE is_user_process = 1
        GROUP BY database_id, login_name, status
    ) s
    ORDER BY cnt DESC;

    SET @html = @html + N'<table id="connection_count" border="1" width="90%" align="center">'
        + N'<tr><th>Database</th><th>Login</th><th>Count</th><th>Status</th></tr>'
        + @section + N'</table>' + @crlf;
END TRY
BEGIN CATCH
    SET @html = @html + N'<!-- connection_count error: ' + ERROR_MESSAGE() + N' -->' + @crlf
        + N'<table id="connection_count" border="1" width="90%" align="center">'
        + N'<tr><th>Database</th><th>Login</th><th>Count</th><th>Status</th></tr>'
        + N'</table>' + @crlf;
END CATCH

-- ============================================================================
-- 3. slow_query - Long running queries (> 60 seconds)
-- Columns: Session_ID, Duration_Sec, Status, Command, Query
-- ============================================================================
BEGIN TRY
    SET @section = N'';
    SELECT @section = @section
        + N'<tr>'
        + N'<td>' + CAST(r.session_id AS NVARCHAR(10)) + N'</td>'
        + CASE
            WHEN DATEDIFF(SECOND, r.start_time, GETDATE()) > 300
            THEN N'<td><font color="red"><b>' + CAST(DATEDIFF(SECOND, r.start_time, GETDATE()) AS NVARCHAR(20)) + N'</b></font></td>'
            ELSE N'<td>' + CAST(DATEDIFF(SECOND, r.start_time, GETDATE()) AS NVARCHAR(20)) + N'</td>'
          END
        + N'<td>' + r.status + N'</td>'
        + N'<td>' + r.command + N'</td>'
        + N'<td>' + LEFT(ISNULL(CAST(t.text AS NVARCHAR(MAX)), N''), 200) + N'</td>'
        + N'</tr>' + @crlf
    FROM sys.dm_exec_requests r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
    WHERE r.session_id > 50
      AND DATEDIFF(SECOND, r.start_time, GETDATE()) > 60
    ORDER BY DATEDIFF(SECOND, r.start_time, GETDATE()) DESC;

    SET @html = @html + N'<table id="slow_query" border="1" width="90%" align="center">'
        + N'<tr><th>Session_ID</th><th>Duration_Sec</th><th>Status</th><th>Command</th><th>Query</th></tr>'
        + @section + N'</table>' + @crlf;
END TRY
BEGIN CATCH
    SET @html = @html + N'<!-- slow_query error: ' + ERROR_MESSAGE() + N' -->' + @crlf
        + N'<table id="slow_query" border="1" width="90%" align="center">'
        + N'<tr><th>Session_ID</th><th>Duration_Sec</th><th>Status</th><th>Command</th><th>Query</th></tr>'
        + N'</table>' + @crlf;
END CATCH

-- ============================================================================
-- 4. agent_jobs - SQL Agent job status
-- Columns: Job_Name, Enabled, Last_Run_Status, Last_Run_Date, Schedule
-- ============================================================================
BEGIN TRY
    SET @section = N'';
    SELECT @section = @section
        + N'<tr>'
        + N'<td>' + j.name + N'</td>'
        + N'<td>' + CASE j.enabled WHEN 1 THEN N'Yes' ELSE N'No' END + N'</td>'
        + CASE
            WHEN h.run_status = 0
            THEN N'<td><font color="red"><b>Failed</b></font></td>'
            WHEN h.run_status = 1 THEN N'<td>Succeeded</td>'
            WHEN h.run_status = 2 THEN N'<td>Retry</td>'
            WHEN h.run_status = 3 THEN N'<td>Canceled</td>'
            ELSE N'<td>N/A</td>'
          END
        + N'<td>' + ISNULL(
            STUFF(STUFF(CAST(h.run_date AS NVARCHAR(8)), 5, 0, '-'), 8, 0, '-')
            + ' '
            + STUFF(STUFF(RIGHT('000000' + CAST(h.run_time AS NVARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':'),
            N'Never')
          + N'</td>'
        + N'<td>' + ISNULL(sc.name, N'No Schedule') + N'</td>'
        + N'</tr>' + @crlf
    FROM msdb.dbo.sysjobs j
    OUTER APPLY (
        SELECT TOP 1 run_status, run_date, run_time
        FROM msdb.dbo.sysjobhistory
        WHERE job_id = j.job_id AND step_id = 0
        ORDER BY run_date DESC, run_time DESC
    ) h
    LEFT JOIN msdb.dbo.sysjobschedules js ON j.job_id = js.job_id
    LEFT JOIN msdb.dbo.sysschedules sc ON js.schedule_id = sc.schedule_id
    ORDER BY j.name;

    SET @html = @html + N'<table id="agent_jobs" border="1" width="90%" align="center">'
        + N'<tr><th>Job_Name</th><th>Enabled</th><th>Last_Run_Status</th><th>Last_Run_Date</th><th>Schedule</th></tr>'
        + @section + N'</table>' + @crlf;
END TRY
BEGIN CATCH
    SET @html = @html + N'<!-- agent_jobs error: ' + ERROR_MESSAGE() + N' -->' + @crlf
        + N'<table id="agent_jobs" border="1" width="90%" align="center">'
        + N'<tr><th>Job_Name</th><th>Enabled</th><th>Last_Run_Status</th><th>Last_Run_Date</th><th>Schedule</th></tr>'
        + N'</table>' + @crlf;
END CATCH

-- ============================================================================
-- 5. always_on - AlwaysOn AG status
-- Columns: AG_Name, Replica, Role, Sync_State, Health
-- ============================================================================
BEGIN TRY
    SET @section = N'';
    IF SERVERPROPERTY('IsHadrEnabled') = 1
    BEGIN
        SELECT @section = @section
            + N'<tr>'
            + N'<td>' + ag.name + N'</td>'
            + N'<td>' + ar.replica_server_name + N'</td>'
            + N'<td>' + ISNULL(ars.role_desc, N'UNKNOWN') + N'</td>'
            + CASE
                WHEN drs.synchronization_state_desc NOT IN (N'SYNCHRONIZING', N'SYNCHRONIZED')
                THEN N'<td><font color="red"><b>' + ISNULL(drs.synchronization_state_desc, N'N/A') + N'</b></font></td>'
                ELSE N'<td>' + ISNULL(drs.synchronization_state_desc, N'N/A') + N'</td>'
              END
            + CASE
                WHEN ISNULL(ars.synchronization_health_desc, N'') <> N'HEALTHY'
                THEN N'<td><font color="red"><b>' + ISNULL(ars.synchronization_health_desc, N'N/A') + N'</b></font></td>'
                ELSE N'<td>' + ISNULL(ars.synchronization_health_desc, N'N/A') + N'</td>'
              END
            + N'</tr>' + @crlf
        FROM sys.availability_groups ag
        JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
        LEFT JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id
        LEFT JOIN sys.dm_hadr_database_replica_states drs ON ar.replica_id = drs.replica_id
        ORDER BY ag.name, ar.replica_server_name;
    END

    SET @html = @html + N'<table id="always_on" border="1" width="90%" align="center">'
        + N'<tr><th>AG_Name</th><th>Replica</th><th>Role</th><th>Sync_State</th><th>Health</th></tr>'
        + @section + N'</table>' + @crlf;
END TRY
BEGIN CATCH
    SET @html = @html + N'<!-- always_on error: ' + ERROR_MESSAGE() + N' -->' + @crlf
        + N'<table id="always_on" border="1" width="90%" align="center">'
        + N'<tr><th>AG_Name</th><th>Replica</th><th>Role</th><th>Sync_State</th><th>Health</th></tr>'
        + N'</table>' + @crlf;
END CATCH

-- ============================================================================
-- 6. transaction_log - Transaction log usage
-- Columns: Database, Log_Size_MB, Used_MB, Usage%, Status
-- ============================================================================
BEGIN TRY
    SET @section = N'';

    DECLARE @log_space TABLE (
        database_name NVARCHAR(256),
        database_id INT,
        log_size_mb DECIMAL(18,2),
        used_mb DECIMAL(18,2),
        used_pct DECIMAL(5,2),
        log_status INT
    );

    INSERT INTO @log_space (database_name, database_id, log_size_mb, used_mb, used_pct, log_status)
    SELECT
        d.name,
        d.database_id,
        CAST(ls.total_log_size_in_bytes / 1048576.0 AS DECIMAL(18,2)),
        CAST(ls.used_log_space_in_bytes / 1048576.0 AS DECIMAL(18,2)),
        CAST(ls.used_log_space_in_percent AS DECIMAL(5,2)),
        0
    FROM sys.databases d
    CROSS APPLY sys.dm_db_log_space_usage ls
    WHERE d.database_id = DB_ID() AND d.state_desc = N'ONLINE';

    -- For other databases, use sys.master_files estimate
    INSERT INTO @log_space (database_name, database_id, log_size_mb, used_mb, used_pct, log_status)
    SELECT
        d.name,
        d.database_id,
        CAST(SUM(mf.size) * 8.0 / 1024 AS DECIMAL(18,2)),
        0,
        0,
        0
    FROM sys.databases d
    JOIN sys.master_files mf ON d.database_id = mf.database_id AND mf.type_desc = N'LOG'
    WHERE d.state_desc = N'ONLINE'
      AND d.database_id <> DB_ID()
    GROUP BY d.name, d.database_id;

    SELECT @section = @section
        + N'<tr>'
        + N'<td>' + ls.database_name + N'</td>'
        + N'<td>' + CAST(ls.log_size_mb AS NVARCHAR(30)) + N'</td>'
        + N'<td>' + CAST(ls.used_mb AS NVARCHAR(30)) + N'</td>'
        + CASE
            WHEN ls.used_pct >= 80
            THEN N'<td><font color="red"><b>' + CAST(ls.used_pct AS NVARCHAR(10)) + N'</b></font></td>'
            ELSE N'<td>' + CAST(ls.used_pct AS NVARCHAR(10)) + N'</td>'
          END
        + N'<td>' + CASE WHEN d.log_reuse_wait_desc IS NOT NULL THEN d.log_reuse_wait_desc ELSE N'N/A' END + N'</td>'
        + N'</tr>' + @crlf
    FROM @log_space ls
    JOIN sys.databases d ON ls.database_id = d.database_id
    ORDER BY ls.database_name;

    SET @html = @html + N'<table id="transaction_log" border="1" width="90%" align="center">'
        + N'<tr><th>Database</th><th>Log_Size_MB</th><th>Used_MB</th><th>Usage%</th><th>Status</th></tr>'
        + @section + N'</table>' + @crlf;
END TRY
BEGIN CATCH
    SET @html = @html + N'<!-- transaction_log error: ' + ERROR_MESSAGE() + N' -->' + @crlf
        + N'<table id="transaction_log" border="1" width="90%" align="center">'
        + N'<tr><th>Database</th><th>Log_Size_MB</th><th>Used_MB</th><th>Usage%</th><th>Status</th></tr>'
        + N'</table>' + @crlf;
END CATCH

-- ============================================================================
-- 7. index_fragmentation - Index fragmentation (current database, top 50)
-- Columns: Database, Schema, Table, Index, Fragmentation%, Pages, Recommendation
-- ============================================================================
BEGIN TRY
    SET @section = N'';
    SELECT TOP 50 @section = @section
        + N'<tr>'
        + N'<td>' + DB_NAME() + N'</td>'
        + N'<td>' + s.name + N'</td>'
        + N'<td>' + o.name + N'</td>'
        + N'<td>' + ISNULL(i.name, N'HEAP') + N'</td>'
        + CASE
            WHEN ips.avg_fragmentation_in_percent > 30 AND ips.page_count > 1000
            THEN N'<td><font color="red"><b>' + CAST(CAST(ips.avg_fragmentation_in_percent AS DECIMAL(5,2)) AS NVARCHAR(10)) + N'</b></font></td>'
            ELSE N'<td>' + CAST(CAST(ips.avg_fragmentation_in_percent AS DECIMAL(5,2)) AS NVARCHAR(10)) + N'</td>'
          END
        + N'<td>' + CAST(ips.page_count AS NVARCHAR(20)) + N'</td>'
        + N'<td>' + CASE
            WHEN ips.avg_fragmentation_in_percent > 30 AND ips.page_count > 1000 THEN N'REBUILD'
            WHEN ips.avg_fragmentation_in_percent > 10 AND ips.page_count > 1000 THEN N'REORGANIZE'
            ELSE N'OK'
          END + N'</td>'
        + N'</tr>' + @crlf
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, N'LIMITED') ips
    JOIN sys.objects o ON ips.object_id = o.object_id
    JOIN sys.schemas s ON o.schema_id = s.schema_id
    LEFT JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE ips.page_count > 100
      AND o.is_ms_shipped = 0
      AND ips.index_id > 0
    ORDER BY ips.avg_fragmentation_in_percent DESC;

    SET @html = @html + N'<table id="index_fragmentation" border="1" width="90%" align="center">'
        + N'<tr><th>Database</th><th>Schema</th><th>Table</th><th>Index</th><th>Fragmentation%</th><th>Pages</th><th>Recommendation</th></tr>'
        + @section + N'</table>' + @crlf;
END TRY
BEGIN CATCH
    SET @html = @html + N'<!-- index_fragmentation error: ' + ERROR_MESSAGE() + N' -->' + @crlf
        + N'<table id="index_fragmentation" border="1" width="90%" align="center">'
        + N'<tr><th>Database</th><th>Schema</th><th>Table</th><th>Index</th><th>Fragmentation%</th><th>Pages</th><th>Recommendation</th></tr>'
        + N'</table>' + @crlf;
END CATCH

-- ============================================================================
-- 8. wait_stats - Top wait statistics
-- Columns: Wait_Type, Wait_Time_Sec, Pct, Running_Pct
-- ============================================================================
BEGIN TRY
    SET @section = N'';

    ;WITH waits AS (
        SELECT
            wait_type,
            wait_time_ms / 1000.0 AS wait_time_sec,
            100.0 * wait_time_ms / NULLIF(SUM(wait_time_ms) OVER(), 0) AS pct,
            ROW_NUMBER() OVER(ORDER BY wait_time_ms DESC) AS rn
        FROM sys.dm_os_wait_stats
        WHERE wait_type NOT IN (
            N'SLEEP_TASK', N'BROKER_TASK_STOP', N'BROKER_IO_FLUSH',
            N'SQLTRACE_BUFFER_FLUSH', N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT',
            N'LAZYWRITER_SLEEP', N'CHECKPOINT_QUEUE', N'WAITFOR',
            N'XE_TIMER_EVENT', N'XE_DISPATCH_QUEUE', N'FT_IFTS_SCHEDULER_IDLE_WAIT',
            N'LOGMGR_QUEUE', N'DIRTY_PAGE_POLL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
            N'SP_SERVER_DIAGNOSTICS_SLEEP', N'BROKER_EVENTHANDLER',
            N'BROKER_RECEIVE_WAITFOR', N'BROKER_TRANSMITTER',
            N'REQUEST_FOR_DEADLOCK_SEARCH', N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
            N'ONDEMAND_TASK_QUEUE', N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
            N'QDS_ASYNC_QUEUE', N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
            N'PREEMPTIVE_OS_AUTHORIZATIONOPS', N'PREEMPTIVE_OS_GETPROCADDRESS'
        )
          AND wait_time_ms > 0
    )
    SELECT @section = @section
        + N'<tr>'
        + CASE
            WHEN w.wait_type IN (N'CXPACKET', N'CXCONSUMER', N'PAGEIOLATCH_SH', N'PAGEIOLATCH_EX',
                N'LCK_M_S', N'LCK_M_X', N'LCK_M_U', N'LCK_M_IX', N'LCK_M_IS',
                N'WRITELOG', N'IO_COMPLETION', N'ASYNC_NETWORK_IO')
            THEN N'<td><font color="red"><b>' + w.wait_type + N'</b></font></td>'
            ELSE N'<td>' + w.wait_type + N'</td>'
          END
        + N'<td>' + CAST(CAST(w.wait_time_sec AS DECIMAL(18,2)) AS NVARCHAR(30)) + N'</td>'
        + N'<td>' + CAST(CAST(w.pct AS DECIMAL(5,2)) AS NVARCHAR(10)) + N'</td>'
        + N'<td>' + CAST(CAST(SUM(w2.pct) AS DECIMAL(5,2)) AS NVARCHAR(10)) + N'</td>'
        + N'</tr>' + @crlf
    FROM waits w
    JOIN waits w2 ON w2.rn <= w.rn
    WHERE w.rn <= 20
    GROUP BY w.rn, w.wait_type, w.wait_time_sec, w.pct
    ORDER BY w.rn;

    SET @html = @html + N'<table id="wait_stats" border="1" width="90%" align="center">'
        + N'<tr><th>Wait_Type</th><th>Wait_Time_Sec</th><th>Pct</th><th>Running_Pct</th></tr>'
        + @section + N'</table>' + @crlf;
END TRY
BEGIN CATCH
    SET @html = @html + N'<!-- wait_stats error: ' + ERROR_MESSAGE() + N' -->' + @crlf
        + N'<table id="wait_stats" border="1" width="90%" align="center">'
        + N'<tr><th>Wait_Type</th><th>Wait_Time_Sec</th><th>Pct</th><th>Running_Pct</th></tr>'
        + N'</table>' + @crlf;
END CATCH

-- ============================================================================
-- 9. backup_status - Backup history (last 7 days)
-- Columns: Database, Type, Status, Start_Time, Duration_Sec, Size_MB
-- ============================================================================
BEGIN TRY
    SET @section = N'';
    SELECT @section = @section
        + N'<tr>'
        + N'<td>' + bs.database_name + N'</td>'
        + N'<td>' + CASE bs.type
            WHEN 'D' THEN N'Full'
            WHEN 'I' THEN N'Differential'
            WHEN 'L' THEN N'Log'
            ELSE bs.type
          END + N'</td>'
        + N'<td>' + CASE
            WHEN bmf.physical_device_name IS NOT NULL THEN N'Completed'
            ELSE N'<font color="red"><b>Unknown</b></font>'
          END + N'</td>'
        + N'<td>' + CONVERT(NVARCHAR(20), bs.backup_start_date, 120) + N'</td>'
        + N'<td>' + CAST(DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date) AS NVARCHAR(20)) + N'</td>'
        + N'<td>' + CAST(CAST(bs.backup_size / 1048576.0 AS DECIMAL(12,2)) AS NVARCHAR(30)) + N'</td>'
        + N'</tr>' + @crlf
    FROM msdb.dbo.backupset bs
    LEFT JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE bs.backup_start_date >= DATEADD(DAY, -7, GETDATE())
    ORDER BY bs.backup_start_date DESC;

    -- Check for databases without recent full backup
    DECLARE @no_backup_section NVARCHAR(MAX) = N'';
    SELECT @no_backup_section = @no_backup_section
        + N'<tr>'
        + N'<td>' + d.name + N'</td>'
        + N'<td>Full</td>'
        + N'<td><font color="red"><b>No Backup in 7 Days</b></font></td>'
        + N'<td>N/A</td>'
        + N'<td>N/A</td>'
        + N'<td>N/A</td>'
        + N'</tr>' + @crlf
    FROM sys.databases d
    WHERE d.database_id > 4  -- exclude system databases
      AND d.state_desc = N'ONLINE'
      AND NOT EXISTS (
          SELECT 1 FROM msdb.dbo.backupset bs
          WHERE bs.database_name = d.name
            AND bs.type = 'D'
            AND bs.backup_start_date >= DATEADD(DAY, -7, GETDATE())
      );

    SET @html = @html + N'<table id="backup_status" border="1" width="90%" align="center">'
        + N'<tr><th>Database</th><th>Type</th><th>Status</th><th>Start_Time</th><th>Duration_Sec</th><th>Size_MB</th></tr>'
        + @section + @no_backup_section + N'</table>' + @crlf;
END TRY
BEGIN CATCH
    SET @html = @html + N'<!-- backup_status error: ' + ERROR_MESSAGE() + N' -->' + @crlf
        + N'<table id="backup_status" border="1" width="90%" align="center">'
        + N'<tr><th>Database</th><th>Type</th><th>Status</th><th>Start_Time</th><th>Duration_Sec</th><th>Size_MB</th></tr>'
        + N'</table>' + @crlf;
END CATCH

-- ============================================================================
-- 10. security_audit - Security settings
-- Columns: Setting, Value, Recommendation
-- ============================================================================
BEGIN TRY
    SET @section = N'';

    -- Check sa account
    DECLARE @sa_enabled INT = 0;
    SELECT @sa_enabled = CASE WHEN is_disabled = 0 THEN 1 ELSE 0 END
    FROM sys.server_principals WHERE sid = 0x01;

    SET @section = @section + N'<tr>'
        + CASE WHEN @sa_enabled = 1
            THEN N'<td>sa Account</td><td><font color="red"><b>Enabled</b></font></td><td><font color="red"><b>Disable the sa account or rename it</b></font></td>'
            ELSE N'<td>sa Account</td><td>Disabled</td><td>OK</td>'
          END
        + N'</tr>' + @crlf;

    -- Check xp_cmdshell
    DECLARE @xp_cmdshell INT = 0;
    SELECT @xp_cmdshell = CAST(value_in_use AS INT)
    FROM sys.configurations WHERE name = N'xp_cmdshell';

    SET @section = @section + N'<tr>'
        + CASE WHEN @xp_cmdshell = 1
            THEN N'<td>xp_cmdshell</td><td><font color="red"><b>Enabled</b></font></td><td><font color="red"><b>Disable xp_cmdshell for security</b></font></td>'
            ELSE N'<td>xp_cmdshell</td><td>Disabled</td><td>OK</td>'
          END
        + N'</tr>' + @crlf;

    -- Check CLR
    DECLARE @clr_enabled INT = 0;
    SELECT @clr_enabled = CAST(value_in_use AS INT)
    FROM sys.configurations WHERE name = N'clr enabled';

    SET @section = @section + N'<tr>'
        + CASE WHEN @clr_enabled = 1
            THEN N'<td>CLR Enabled</td><td><font color="red"><b>Enabled</b></font></td><td><font color="red"><b>Disable CLR if not required</b></font></td>'
            ELSE N'<td>CLR Enabled</td><td>Disabled</td><td>OK</td>'
          END
        + N'</tr>' + @crlf;

    -- Check remote admin connections
    DECLARE @remote_dac INT = 0;
    SELECT @remote_dac = CAST(value_in_use AS INT)
    FROM sys.configurations WHERE name = N'remote admin connections';

    SET @section = @section + N'<tr>'
        + CASE WHEN @remote_dac = 1
            THEN N'<td>Remote DAC</td><td>Enabled</td><td>Review if remote DAC is necessary</td>'
            ELSE N'<td>Remote DAC</td><td>Disabled</td><td>OK</td>'
          END
        + N'</tr>' + @crlf;

    -- Check authentication mode
    DECLARE @auth_mode NVARCHAR(50);
    SELECT @auth_mode = CASE SERVERPROPERTY('IsIntegratedSecurityOnly')
        WHEN 1 THEN N'Windows Only'
        ELSE N'Mixed Mode'
    END;

    SET @section = @section + N'<tr>'
        + CASE WHEN @auth_mode = N'Mixed Mode'
            THEN N'<td>Authentication Mode</td><td><font color="red"><b>Mixed Mode</b></font></td><td>Consider Windows Authentication only</td>'
            ELSE N'<td>Authentication Mode</td><td>Windows Only</td><td>OK</td>'
          END
        + N'</tr>' + @crlf;

    -- Check cross db ownership chaining
    DECLARE @cross_db INT = 0;
    SELECT @cross_db = CAST(value_in_use AS INT)
    FROM sys.configurations WHERE name = N'cross db ownership chaining';

    SET @section = @section + N'<tr>'
        + CASE WHEN @cross_db = 1
            THEN N'<td>Cross DB Ownership Chaining</td><td><font color="red"><b>Enabled</b></font></td><td><font color="red"><b>Disable unless specifically required</b></font></td>'
            ELSE N'<td>Cross DB Ownership Chaining</td><td>Disabled</td><td>OK</td>'
          END
        + N'</tr>' + @crlf;

    SET @html = @html + N'<table id="security_audit" border="1" width="90%" align="center">'
        + N'<tr><th>Setting</th><th>Value</th><th>Recommendation</th></tr>'
        + @section + N'</table>' + @crlf;
END TRY
BEGIN CATCH
    SET @html = @html + N'<!-- security_audit error: ' + ERROR_MESSAGE() + N' -->' + @crlf
        + N'<table id="security_audit" border="1" width="90%" align="center">'
        + N'<tr><th>Setting</th><th>Value</th><th>Recommendation</th></tr>'
        + N'</table>' + @crlf;
END CATCH

-- ============================================================================
-- HTML Footer
-- ============================================================================
SET @html = @html + N'<hr><center><font size="-1">Generated by DBCheck SQL Server Script</font></center>' + @crlf
    + N'</body></html>';

-- ============================================================================
-- Output: Print HTML in chunks (PRINT has 8000 char limit for NVARCHAR)
-- ============================================================================
DECLARE @pos INT = 1;
DECLARE @len INT = LEN(@html);
DECLARE @chunk INT = 4000;

WHILE @pos <= @len
BEGIN
    PRINT SUBSTRING(@html, @pos, @chunk);
    SET @pos = @pos + @chunk;
END
GO
