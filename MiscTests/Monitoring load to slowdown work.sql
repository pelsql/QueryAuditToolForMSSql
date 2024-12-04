
-- extra stuff for long term monitorign of short and long queries creating 
-- overload:  https://techcommunity.microsoft.com/blog/coreinfrastructureandsecurityblog/sql-high-cpu-scenario-troubleshooting-using-sys-dm-exec-query-stats-and-ring-buf/370314
-- https://bwunder.wordpress.com/2012/07/29/monitoring-and-troubleshooting-with-sys-dm_os_ring_buffers/
Drop table if Exists #TempCpu
Drop table if Exists #Threshold
Select SQLCPUThrehold_Percent=75 Into #Threshold

WHILE (1 = 1)
BEGIN
	 SELECT TOP 4
    runtime=CONVERT(VARCHAR(30), getdate(), 126) 
		 ,record_id=ORB.record.value('(Record/@id)[1]', 'int') 
		 ,system_idle_cpu=ORB.record.value('(Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') 
		 ,sql_cpu_utilization=ORB.record.value('(Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') 
   ,record
	 INTO #tempCPU
	 FROM 
    (
    SELECT TIMESTAMP, record=CONVERT(XML, record) 
    FROM sys.dm_os_ring_buffers
		  WHERE ring_buffer_type = 'RING_BUFFER_SCHEDULER_MONITOR'
    AND record LIKE '%%'
    ) as ORB
    CROSS JOIN sys.dm_os_sys_info inf
	 ORDER BY orb.record.value('(Record/@id)[1]', 'int') DESC

  -- Query return
  SELECT TOP 25 
    runtime=getdate()
	 , Executions=qs.Execution_count 
	 , totalCpu=qs.total_worker_time 
	 , PhysicalReads=qs.total_physical_reads 
	 , LogicalReads=qs.total_logical_reads 
	 , LogicalWrites=qs.total_logical_writes 
	 , Duration=qs.total_elapsed_time
	 , [Avg CPU Time]=qs.total_worker_time / qs.execution_count
	 , query_text=substring(qt.TEXT, qs.statement_start_offset / 2, (
			  CASE 
				  WHEN qs.statement_end_offset = - 1
					  THEN len(convert(NVARCHAR(max), qt.TEXT)) * 2
				  ELSE qs.statement_end_offset
				  END - qs.statement_start_offset
			  ) / 2) 
	 , DBID=qt.dbid
	 , OBJECT_ID=qt.objectid 
  Into #Tbl_troubleshootingPlans
  FROM 
    ( -- last 2 Ring buffer records had CPU > threshold so we capture the plans
    Select Collect=1
    From 
      #tempCPU 
      LEFT JOIN #Threshold as T
      On sql_cpu_utilization > T.SQLCPUThrehold_Percent
    having COUNT(*) = COUNT(T.SQLCPUThrehold_Percent)
    ) as Collect
    CROSS JOIN sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
  ORDER BY TotalCPU DESC

  DROP TABLE #tempCPU

	 WAITFOR DELAY '0:00:30' -- aux 30 secondes
END
GO

-- Initial snapshot
SELECT 
    database_id, file_id, num_of_reads, num_of_writes, 
    num_of_bytes_read, num_of_bytes_written, 
    io_stall_read_ms, io_stall_write_ms, io_stall 
INTO #io_baseline
FROM sys.dm_io_virtual_file_stats(NULL, NULL);

-- Wait for a period (e.g., 1 minute) and then take another snapshot
WAITFOR DELAY '00:01:00';

-- Second snapshot with differences calculated
SELECT 
    current.database_id,
    current.file_id,
    current.num_of_reads - baseline.num_of_reads AS reads_in_interval,
    current.num_of_writes - baseline.num_of_writes AS writes_in_interval,
    current.num_of_bytes_read - baseline.num_of_bytes_read AS bytes_read_in_interval,
    current.num_of_bytes_written - baseline.num_of_bytes_written AS bytes_written_in_interval,
    current.io_stall_read_ms - baseline.io_stall_read_ms AS read_stall_ms_in_interval,
    current.io_stall_write_ms - baseline.io_stall_write_ms AS write_stall_ms_in_interval,
    current.io_stall - baseline.io_stall AS total_stall_ms_in_interval
FROM 
    sys.dm_io_virtual_file_stats(NULL, NULL) AS current
JOIN 
    #io_baseline AS baseline
ON 
    current.database_id = baseline.database_id 
    AND current.file_id = baseline.file_id;

-- Drop the baseline table
DROP TABLE #io_baseline;
