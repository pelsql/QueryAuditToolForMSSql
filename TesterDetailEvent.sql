Create or alter view dbo.EquivExEventsVsTrace
as
Select top 99.9999 PERCENT *
From
  (
  SELECT DISTINCT
    tb.trace_event_id
  , EventClass = te.name            
  , Package=em.package_name
  , XEventName=em.xe_event_name
  , tb.trace_column_id
  , SQLTraceColumn = tc.name
  , ExtendedEventsaction = am.xe_action_name
  FROM
                sys.trace_events         te
      LEFT JOIN sys.trace_xe_event_map   em ON te.trace_event_id  = em.trace_event_id
      LEFT JOIN sys.trace_event_bindings tb ON em.trace_event_id  = tb.trace_event_id
      LEFT JOIN sys.trace_columns        tc ON tb.trace_column_id = tc.trace_column_id
      LEFT JOIN sys.trace_xe_action_map  am ON tc.trace_column_id = am.trace_column_id
  ) as eq
ORDER BY EventClass, SQLTraceColumn
go
Select * From dbo.EquivExEventsVsTrace where SQLTraceColumn like '%Sequence%'
go
CREATE EVENT SESSION [TrackEventSequence] 
ON SERVER
  ADD EVENT sqlserver.user_event
  (
    ACTION (package0.event_sequence)
  )
, ADD EVENT sqlserver.sql_statement_completed
  (
    ACTION
    (    
      sqlserver.server_principal_name
    , sqlserver.session_id
    , sqlserver.database_name
    , sqlserver.sql_text
    , package0.event_sequence
    )
    WHERE [sqlserver].[is_system]=(0)
  )
ADD TARGET package0.event_file
(
    SET filename = N'D:\_Tmp\AuditReq\TestUserEvent.xel'
)
WITH 
(
    MAX_MEMORY = 4096 KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 30 SECONDS,
    MAX_EVENT_SIZE = 0 KB,
    MEMORY_PARTITION_MODE = NONE,
    TRACK_CAUSALITY = OFF,
    STARTUP_STATE = ON
)

go
Declare @usrInf Nvarchar(4000)
Select @usrInf = (Select LoginName=ORIGINAL_LOGIN(), LoginTime=SYSDATETIME(), spid=232, client_net_address=HOST_NAME() For Json PATH)
select LEN (@usrInf)
SELECT 
  JSON_VALUE(value, '$.LoginName') AS LoginName,
  JSON_VALUE(value, '$.LoginTime') AS LoginTime,
  JSON_VALUE(value, '$.spid') AS spid,
  JSON_VALUE(value, '$.client_net_address') AS client_net_address
FROM 
  OPENJSON(@usrInf);

EXEC sp_trace_generateevent 
    @eventid = 82,           -- Event ID (range from 82 to 91 for user-defined)
    @userinfo = @UsrInf,  
    @userdata = 0x10;          -- Optional binary data
go

ALTER EVENT SESSION [TrackUserEvents] ON SERVER STATE = START;
GO
      Select event_data = xEvents.event_data, F.file_name, F.file_offset,
          xEvents.event_data.value('(event/data[@name="event_id"]/value)[1]', 'int') AS event_id,          
          UserDataBin, UserData, J.*
      FROM 
        sys.fn_xe_file_target_read_file('D:\_Tmp\AuditReq\TestUserEvent*.xel', NULL, NULL, NULL) as F 
        CROSS APPLY (SELECT CAST(event_data AS XML) AS event_data) AS xEvents
        CROSS APPLY (SELECT UserDataHexString=xEvents.event_data.value('(event/data[@name="user_data"]/value)[1]', 'nvarchar(max)')) AS UserDataHexString
        CROSS APPLY (SELECT UserDataBin = CONVERT(VARBINARY(MAX), '0x'+UserDataHexString, 1)) as UserDataBin
        CROSS APPLY (Select UserData=CAST(UserDataBin as NVARCHAR(4000))) as UserData
        Outer APPLY
        (
        SELECT 
          LoginName=JSON_VALUE(value, '$.LoginName') 
        , LoginTime=JSON_VALUE(value, '$.LoginTime')
        , spid=JSON_VALUE(value, '$.spid')
        , client_net_address=JSON_VALUE(value, '$.client_net_address')
        , program_name=JSON_VALUE(value, '$.program_name') 
        FROM OPENJSON(UserData)
        Where UserData like '_{%'
        ) as J

