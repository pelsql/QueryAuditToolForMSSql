waitfor delay '00:00:20'
EXEC msdb.dbo.sp_stop_job @job_name = 'AuditReq';
select COUNT(*) from dbo.findMissingSeq(0) 
waitfor delay '00:00:20'
-- un redemarrage se manifeste pas un drop table if exists #tmp dans la trace
EXEC msdb.dbo.sp_start_job @job_name = 'AuditReq';
select COUNT(*) from dbo.findMissingSeq(0) 
waitfor delay '00:00:20'
-- dernier rangée de chaque groupe
select * 
--, MAX(s) Over (partition by f) 
from dbo.findMissingSeq(0) where s = 3000
order by f,s
-- trous? aucune rangée s'il n'y en a pas
select * from dbo.findMissingSeq(1) 
order by f,s
