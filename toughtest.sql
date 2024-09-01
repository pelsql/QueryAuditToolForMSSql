waitfor delay '00:00:05'
EXEC msdb.dbo.sp_stop_job @job_name = 'AuditReq';
waitfor delay '00:00:05'
select COUNT(*) from dbo.findMissingSeq(0) 
EXEC msdb.dbo.sp_start_job @job_name = 'AuditReq';
waitfor delay '00:00:05'
EXEC msdb.dbo.sp_stop_job @job_name = 'AuditReq';
waitfor delay '00:00:05'
select COUNT(*) from dbo.findMissingSeq(0) 
EXEC msdb.dbo.sp_start_job @job_name = 'AuditReq';
waitfor delay '00:00:05'
EXEC msdb.dbo.sp_stop_job @job_name = 'AuditReq';
select COUNT(*) from dbo.findMissingSeq(0) 
waitfor delay '00:00:05'
EXEC msdb.dbo.sp_start_job @job_name = 'AuditReq';
waitfor delay '00:00:05'
EXEC msdb.dbo.sp_stop_job @job_name = 'AuditReq';
select COUNT(*) from dbo.findMissingSeq(0) 
waitfor delay '00:00:05'
EXEC msdb.dbo.sp_start_job @job_name = 'AuditReq';
waitfor delay '00:00:05'
EXEC msdb.dbo.sp_stop_job @job_name = 'AuditReq';
select COUNT(*) from dbo.findMissingSeq(0) 
waitfor delay '00:00:05'
EXEC msdb.dbo.sp_start_job @job_name = 'AuditReq';
select * from dbo.findMissingSeq(1)-- where statement like '%n=3999%' 
order by f,s