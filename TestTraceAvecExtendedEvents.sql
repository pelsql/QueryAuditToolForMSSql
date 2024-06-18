CREATE EVENT SESSION [QueryTrackingSession] ON SERVER
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.sql_text, sqlserver.client_hostname, sqlserver.database_name, sqlserver.username)
)
ADD TARGET package0.ring_buffer
WITH (MAX_MEMORY=4096 KB, EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY=30 SECONDS, MAX_EVENT_SIZE=0 KB, MEMORY_PARTITION_MODE=NONE, TRACK_CAUSALITY=OFF, STARTUP_STATE=OFF);
GO
ALTER EVENT SESSION [QueryTrackingSession] ON SERVER STATE = START;
GO
SELECT
    s.name AS session_name,
    t.target_name,
    t.target_data
FROM sys.dm_xe_sessions AS s
JOIN sys.dm_xe_session_targets AS t
ON s.address = t.event_session_address
WHERE s.name = 'QueryTrackingSession'
AND t.target_name = 'ring_buffer';
SELECT
    event_data.value('(event/@name)[1]', 'varchar(50)') AS event_name,
    event_data.value('(event/data[@name="duration"]/value)[1]', 'bigint') AS duration,
    event_data.value('(event/data[@name="cpu_time"]/value)[1]', 'bigint') AS cpu_time,
    event_data.value('(event/data[@name="logical_reads"]/value)[1]', 'bigint') AS logical_reads,
    event_data.value('(event/data[@name="writes"]/value)[1]', 'bigint') AS writes,
    event_data.value('(event/data[@name="row_count"]/value)[1]', 'bigint') AS row_count,
    event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS sql_text,
    event_data.value('(event/action[@name="client_hostname"]/value)[1]', 'varchar(50)') AS client_hostname,
    event_data.value('(event/action[@name="database_name"]/value)[1]', 'varchar(50)') AS database_name,
    event_data.value('(event/action[@name="username"]/value)[1]', 'varchar(50)') AS username,
    event_data.value('(event/@timestamp)[1]', 'datetime2') AS event_time
FROM (
    SELECT CAST(target_data AS XML) AS event_data
    FROM sys.dm_xe_sessions AS s
    JOIN sys.dm_xe_session_targets AS t
    ON s.address = t.event_session_address
    WHERE s.name = 'QueryTrackingSession'
    AND t.target_name = 'ring_buffer'
) AS tab
ORDER BY event_time DESC;
go
-- Arrêter la session
ALTER EVENT SESSION [QueryTrackingSession] ON SERVER STATE = STOP;
GO
-- Supprimer la session
DROP EVENT SESSION [QueryTrackingSession] ON SERVER;
GO
