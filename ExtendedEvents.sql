---- Créer une session Extended Events : target ring buffer
--CREATE EVENT SESSION [QueryTrackingSession] ON SERVER
--ADD EVENT sqlserver.sql_statement_completed(
--    ACTION(sqlserver.sql_text, sqlserver.client_hostname, sqlserver.database_name, sqlserver.username)
--)
--ADD TARGET package0.ring_buffer
--WITH (MAX_MEMORY=4096 KB, EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY=30 SECONDS, MAX_EVENT_SIZE=0 KB, MEMORY_PARTITION_MODE=NONE, TRACK_CAUSALITY=OFF, STARTUP_STATE=OFF);
--GO
-- Créer une session Extended Events : target fichier

https://www.sqlskills.com/blogs/jonathan/tracking-compiles-with-extended-events/


CREATE EVENT SESSION [QueryTrackingSession] ON SERVER
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.sql_text, sqlserver.client_hostname, sqlserver.client_app_name, sqlserver.database_name, sqlserver.username, sqlserver.session_id)
    WHERE [sqlserver].[is_system]=(0)

)
ADD TARGET package0.asynchronous_file_target(
    SET filename = N'D:\_tmp\scans\QueryTrackingSession.xel',
        metadatafile = N'D:\_tmp\scans\QueryTrackingSession.xem'
)
WITH (MAX_MEMORY=4096 KB, EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY=30 SECONDS, MAX_EVENT_SIZE=0 KB, MEMORY_PARTITION_MODE=NONE, TRACK_CAUSALITY=OFF, STARTUP_STATE=OFF);
GO
---- Créer une sessions Extended Events : Event Tracing for Windows (ETW)
---- L'intégration avec ETW permet de stocker les événements dans les journaux ETW pour une analyse ultérieure avec des outils comme le Windows Event Viewer. Cependant, l'utilisation d'ETW est plus avancée et nécessite des outils supplémentaires pour l'analyse.
--CREATE EVENT SESSION [QueryTrackingSession] ON SERVER
--ADD EVENT sqlserver.sql_statement_completed(
--    ACTION(sqlserver.sql_text, sqlserver.client_hostname, sqlserver.database_name, sqlserver.username)
--)
--ADD TARGET package0.event_tracing_for_windows(
--    SET session_name = N'QueryTrackingSession',
--        filename = N'C:\TraceFiles\QueryTrackingSession.etl'
--)
--WITH (MAX_MEMORY=4096 KB, EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY=30 SECONDS, MAX_EVENT_SIZE=0 KB, MEMORY_PARTITION_MODE=NONE, TRACK_CAUSALITY=OFF, STARTUP_STATE=OFF);
--GO
-- Démarrer la session :
ALTER EVENT SESSION [QueryTrackingSession] ON SERVER STATE = START;
GO
--Exemple de requête pour lire les données collectées
--Pour lire les données collectées dans la cible ring_buffer, vous pouvez utiliser la requête suivante :
-- notez la source de l'information : sys.dm_xe_sessions AS s
    --JOIN sys.dm_xe_session_targets AS t
    --ON s.address = t.event_session_address
    --WHERE s.name = 'QueryTrackingSession'
    --AND t.target_name = 'ring_buffer' 
--SELECT
--    event_data.value('(event/@name)[1]', 'varchar(50)') AS event_name,
--    event_data.value('(event/data[@name="duration"]/value)[1]', 'bigint') AS duration,
--    event_data.value('(event/data[@name="cpu_time"]/value)[1]', 'bigint') AS cpu_time,
--    event_data.value('(event/data[@name="logical_reads"]/value)[1]', 'bigint') AS logical_reads,
--    event_data.value('(event/data[@name="writes"]/value)[1]', 'bigint') AS writes,
--    event_data.value('(event/data[@name="row_count"]/value)[1]', 'bigint') AS row_count,
--    event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS sql_text,
--    event_data.value('(event/action[@name="client_hostname"]/value)[1]', 'varchar(50)') AS client_hostname,
--    event_data.value('(event/action[@name="database_name"]/value)[1]', 'varchar(50)') AS database_name,
--    event_data.value('(event/action[@name="username"]/value)[1]', 'varchar(50)') AS username,
--    event_data.value('(event/@timestamp)[1]', 'datetime2') AS event_time
--FROM (
--    SELECT CAST(target_data AS XML) AS event_data
--    FROM sys.dm_xe_sessions AS s
--    JOIN sys.dm_xe_session_targets AS t
--    ON s.address = t.event_session_address
--    WHERE s.name = 'QueryTrackingSession'
--    AND t.target_name = 'ring_buffer'
--) AS tab
--ORDER BY event_time DESC;
go
--Pour lire les données collectées dans le fichier de trace, vous pouvez utiliser la requête suivante :
--notez la source de l'information : sys.fn_xe_file_target_read_file
-- select * from S#.ColInfo('S#.RealRestoreFileListOnly',NULL)
Select *
From 
  (
  SELECT 
      xEvents.event_data.value('(event/@name)[1]', 'varchar(50)') AS event_name,
      xEvents.event_data.value('(event/data[@name="duration"]/value)[1]', 'bigint') AS duration,
      xEvents.event_data.value('(event/data[@name="cpu_time"]/value)[1]', 'bigint') AS cpu_time,
      xEvents.event_data.value('(event/data[@name="logical_reads"]/value)[1]', 'bigint') AS logical_reads,
      xEvents.event_data.value('(event/data[@name="writes"]/value)[1]', 'bigint') AS writes,
      xEvents.event_data.value('(event/data[@name="row_count"]/value)[1]', 'bigint') AS row_count,
      xEvents.event_data.value('(event/action[@name="session_id"]/value)[1]', 'int') AS [session_id],
      xEvents.event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS sql_text,
      xEvents.event_data.value('(event/action[@name="client_hostname"]/value)[1]', 'varchar(50)') AS client_hostname,
      xEvents.event_data.value('(event/action[@name="client_app_name"]/value)[1]', 'varchar(50)') AS client_app_name,
      xEvents.event_data.value('(event/action[@name="database_name"]/value)[1]', 'varchar(50)') AS database_name,
      xEvents.event_data.value('(event/action[@name="username"]/value)[1]', 'varchar(50)') AS username,
      xEvents.event_data.value('(event/@timestamp)[1]', 'datetime2') AS event_time
  FROM sys.fn_xe_file_target_read_file('D:\_tmp\scans\QueryTrackingSession*.xel', NULL, NULL, NULL) 
  CROSS APPLY (SELECT CAST(event_data AS XML) AS event_data) AS xEvents
  ) as ev
Where ev.event_name = 'sql_statement_completed' and session_id is not null
order by ev.event_time;
go
-- Arrêter la session
ALTER EVENT SESSION [QueryTrackingSession] ON SERVER STATE = STOP;
GO
-- Supprimer la session
DROP EVENT SESSION [QueryTrackingSession] ON SERVER;
GO

