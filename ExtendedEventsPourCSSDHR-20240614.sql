Use tempdb
go
If DB_ID('AuditReq') IS NULL -- Create Db if not there
Begin 
  CREATE DATABASE [AuditReq]
  alter DATABASE [AuditReq] Set recovery simple
  alter database  [AuditReq] modify file ( NAME = N'AuditReq', SIZE = 100MB, MAXSIZE = UNLIMITED, FILEGROWTH = 100MB )
  alter database  [AuditReq] modify file ( NAME = N'AuditReq_log', SIZE = 100MB , MAXSIZE = UNLIMITED , FILEGROWTH = 100MB )
End
go
USE AuditReq
go
Create Or Alter View Dbo.EnumsEtOpt
as
Select *
From 
  (
  Select 
    MsgPrefix='Fichier audit perdu: '
  , MatchFichTrc='AuditReq*.xel'
  , BaseFn='AuditReq.Xel'
  , RootAboveDir='D:\'
  , Dir='_TMP'
  ) as Base
  CROSS APPLY (Select RepFich=RootAboveDir+Dir) as RootAboveDir
  CROSS APPLY (Select RepFichTrc=RepFich+'\') as RepFichTrc
  CROSS APPLY (Select PathReadFileTargetPrm=RepFichTrc+MatchFichTrc) as PathReadFileTargetPrm
  CROSS APPLY (Select TargetFnCreateEvent=RepFichTrc+BaseFn) as TargetFnCreateEvent
GO
If Not Exists
   (
   Select * 
   FROM 
     Dbo.EnumsEtOpt as E 
     CROSS APPLY sys.dm_os_enumerate_filesystem(RootAboveDir, Dir) as F
   where is_directory=1
   ) 
Begin
  Declare @repFich sysname; Select @repFich = repfich from dbo.EnumsEtOpt
  Raiserror ('Le répertoire %s n''existe pas', 11, 1, @repfich)
End 
GO
if @@TRANCOUNT>0 Rollback -- quand on test d'ici la sp
GO
drop trigger if exists LogonAuditTrigger on all server
go
Drop table if exists dbo.connectionsRecentes
CREATE TABLE dbo.connectionsRecentes
(
	 LoginName nvarchar(256) NULL
, Session_id smallint NULL
, LoginTime datetime2  NULL
, Client_net_address nvarchar(48) NULL
, program_name sysname NULL
) 
go
create unique clustered index iconnectionsRecentes 
on dbo.connectionsRecentes (Session_id, LoginName, LoginTime Desc)
GO
-- simplifie les tests car quand on démarre, le logon trigger n'enregistre que les nouvelles
-- connexions mais il faut faire comme s'il avait enregistré les connexions déjà ouvertes
Set nocount on
Insert into dbo.connectionsRecentes
select S.login_name, S.session_id, S.login_time, C.client_net_address, S.program_name
from 
  (Select * From sys.dm_exec_sessions as S Where S.is_user_process=1) as S
  JOIN 
  sys.dm_exec_connections as C
  ON C.session_id = S.session_id
GO
CREATE or Alter TRIGGER LogonAuditTrigger
ON ALL SERVER
FOR LOGON
AS
BEGIN
  Insert into AuditReq.[dbo].[connectionsRecentes]
       ( LoginName    , Session_id, LoginTime,     client_net_address   , program_name)
  select S.Login_Name , Evi.Spid,   S.Login_Time,  C.client_net_address , S.program_name 
  From 
    (Select EventData=EVENTDATA()) as EvD
    CROSS APPLY (Select Spid=EventData.value('(/EVENT_INSTANCE/SPID)[1]', 'INT')) as Evi
    JOIN (select * from master.sys.dm_exec_sessions) as S
    ON S.session_id = Evi.Spid And S.is_user_process=1
    JOIN master.sys.dm_exec_connections as C
    ON C.session_id = S.session_id
END;
GO
If Exists(Select * From sys.dm_xe_sessions Where name = 'AuditReq')
  ALTER EVENT SESSION AuditReq ON SERVER STATE = STOP;
GO
-- Supprimer la session si elle existe et nettoyer ses fichiers de trace
IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'AuditReq')
Begin
  DROP EVENT SESSION AuditReq ON SERVER;
  Exec master.sys.xp_delete_files N'D:\_tmp\AuditReq*.xel'
End
go
declare @FullFn sysname;
Select @FullFn=E.TargetFnCreateEvent From Dbo.EnumsEtOpt as e;
Declare @Sql Nvarchar(max) =
'
CREATE EVENT SESSION AuditReq ON SERVER
  ADD EVENT sqlserver.sql_batch_completed
  (
    ACTION
    (    
      sqlserver.server_principal_name
    , sqlserver.session_id
    , sqlserver.database_name
    , sqlserver.sql_text
    )
    WHERE [sqlserver].[is_system]=(0)
  )
ADD TARGET package0.asynchronous_file_target(
SET 
  filename = ''#FullFn#''
, max_file_size = (10) -- fichier 50 meg file par défaut MB est le default
, max_rollover_files = (5) -- aussi le defaut
)
WITH 
  (
    MAX_MEMORY=4096 KB
  , EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS
  , MAX_DISPATCH_LATENCY=15 SECONDS -- adjust
  , MAX_EVENT_SIZE=0 KB
  , MEMORY_PARTITION_MODE=NONE
  , TRACK_CAUSALITY=OFF
  , STARTUP_STATE=ON -- I want the audit live by itself even after server restarts
  );
'
Set @Sql=replace(@Sql, '#FullFn#', @FullFn)
Exec (@Sql);
go
ALTER EVENT SESSION AuditReq ON SERVER STATE = START;
GO
Drop table if exists dbo.EvenementsTraites
Create table dbo.EvenementsTraites
(
  file_name nvarchar(260) NULL
,	last_Offset_done bigint NULL
)
GO
-- just a transaction table processed by an instead of trigger
-- the trigger processed data in Inserted but never make it to the table
Drop table if exists dbo.PipelineDeTraitementFinalDAudit
CREATE TABLE dbo.PipelineDeTraitementFinalDAudit
(
	 server_principal_name varchar(50) NULL
,	session_id int NULL
,	event_time datetimeoffset(7) NULL
, Database_name sysname NULL
,	sql_text nvarchar(max) NULL
,	file_name nvarchar(260) NOT NULL -- selon donc sys.fn_xe_file_target_read_file
,	file_Offset bigint NOT NULL -- selon donc sys.fn_xe_file_target_read_file
) 
go
-- final process data, put there by the trigger, that match 
-- events traced with RecentLiveConnection to get the client_net_address
-- because Sql Client allow host name change and we want
-- some reliable info from who is the real host
Drop table if Exists dbo.AuditComplet
CREATE TABLE dbo.AuditComplet
(
	 server_principal_name varchar(50) NULL
, event_time datetimeoffset(7) NULL
, Client_net_address nvarchar(48) NULL
,	session_id int NULL
, Program_name sysname
, database_name sysname
, sql_text nvarchar(max) NULL
) 
go
Drop table if Exists dbo.LogTraitementAudit
CREATE TABLE dbo.LogTraitementAudit
(
  MsgDate datetime2 default SYSDATETIME()
, Msg nvarchar(max) NULL
) 
go
--
-- Selon edition aller chercher meilleur option de compression
-- 
Set Nocount on
Declare @Sql nvarchar(max)=''
select @Sql=@Sql+Sql -- façon cheap de concatener toutes les requetes
From 
  (
  select 
    Edition=cast(SERVERPROPERTY('Edition') as sysname)
  , CompressTemplate='ALTER TABLE #Tab# REBUILD WITH (DATA_COMPRESSION = #Opt#); '
  , Dot='.'
  ) as Edition
  JOIN -- will discard any rows if edition do not support compression
  (Values 
     ('%Developer Edition%','PAGE')
  ,  ('%Enterprise Edition%', 'PAGE')
  ,  ('%Standard Edition%', 'ROW')
  ,  ('%Azure SQL%', 'PAGE')
  ) CompressOpt (LikeEdition, Opt)
  ON Edition Like CompressOpt.LikeEdition
  CROSS APPLY (select Tab=OBJECT_SCHEMA_NAME(object_id)+Dot+name from sys.tables) as Tab
  CROSS APPLY (Select Sql0=Replace(CompressTemplate, '#Tab#', Tab) ) as Sql0
  CROSS APPLY (Select Sql=Replace(sql0, '#Opt#', Opt) ) as Sql
Exec (@Sql)
GO
-- --------------------------------------------------------------------------------
-- This trigger is just a mean to implement a processing pipeline or events
-- the table is always left empty
-- It handle inserts and redirect processed output to different tables
-- and ignores Delete, Update
-- --------------------------------------------------------------------------------
Create or Alter Trigger trgPipelineDeTraitementFinalDAudit 
ON dbo.PipelineDeTraitementFinalDAudit
Instead of Insert, Update, Delete -- just handle insert, discard Delete, Update
AS -- just a mean to implement a pipeline, handle inserts and discard Delete, Update
Begin
  Set nocount on
  -- remember this table is always empty. It is just a pipeline
  -- In care there us non-sense attempts of deletes or update (since table is empty)
  -- there is nothing to do, since in both case inserted table is going to be empty.
  
  Insert into dbo.AuditComplet 
    (server_principal_name, event_time, Client_net_address, session_id, Program_name, database_name, sql_text)
  Select 
    I.server_principal_name, I.event_time, Hc.Client_net_address
  , I.session_id, Hc.Program_name, I.database_name, I.sql_text
  From 
    Inserted as I
    -- Un même login peut se connecter et se reconnecter avec un peu de chance de réobtenir le meme spid
    -- On va chercher la connexion qui précède de plus près le moment de la requête
    -- (la plus grande (en ordre décroissant) de LoginTime (temps connexion) < event_time (de la requête)
    -- pour le même numéro de session, loginName
    -- ici on a un outer apply pour le cas très improbable que la connextion ait été ôté de l'historique
    -- parce qu'elle y a été laissée très longtemps sans qu'on en traite les évènements
    -- mais on ne perdra pas le reste, le login, le moment, le numero de session, les requêtes
    OUTER APPLY 
    (
    Select TOP 1 Hc.Program_name, Hc.Client_net_address 
    From Auditreq.dbo.connectionsRecentes as Hc
    Where Hc.LoginName = I.server_principal_name 
      And Hc.session_id = I.session_id
      And Hc.LoginTime < I.event_time
    Order by Session_id, LoginName, LoginTime desc
    ) Hc

    -- record up to which file_offset was reached and processed from Inserted "frozen" image
    -- of events
    Insert into dbo.EvenementsTraites (file_name, last_Offset_done)
    Select Top 1 file_name, file_Offset
    From Inserted
    Order by file_name desc, file_offset Desc
End
GO
Create or Alter Proc dbo.CompleterInfoAudit
as
Begin
  Set nocount on

  -- complète les connexions manquantes, pour ne pas avoir des program_name NULL et des client_net_address NULL
  Insert into dbo.connectionsRecentes
  select S.login_name, S.session_id, S.login_time, C.client_net_address, S.program_name
  from 
    (Select * From sys.dm_exec_sessions as S Where S.is_user_process=1) as S
    JOIN 
    sys.dm_exec_connections as C
    ON C.session_id = S.session_id
  Except 
  select R.LoginName, R.Session_id, R.LoginTime, R.Client_net_address, R.program_name
  From Dbo.connectionsRecentes R

  Declare @eventsDone BigInt
  While (1=1) -- this procedure is intended to run forever, with waits if necessary
  Begin
    -- we want a consistent operation and only this proc operates on theses tables
    -- so there isn't a risk of deadlock and contention
    Begin Tran 

    Insert into Dbo.PipelineDeTraitementFinalDAudit
      (server_principal_name, session_id, event_time, Database_Name, sql_text, file_name, file_Offset)
    Select
      ev.server_principal_name
    , ev.session_id
    , ev.event_time
    , ev.database_name
    , ev.sql_text 
    , Ev.file_name
    , ev.file_Offset
    From 
      ( -- function sys.fn_xe_file_target_read_file needs file to read from and last_offset_done
        -- to skip events already done
      Select file_name, last_Offset_done From dbo.EvenementsTraites 
      UNION ALL
      -- La fonction sys.fn_xe_file_target_read_file a besoin de ces param au départ
      Select NULL, NULL Where Not Exists (Select * From dbo.EvenementsTraites)
      ) as StartP
      CROSS JOIN Dbo.EnumsEtOpt as E
      CROSS APPLY
      (
      SELECT 
        F.file_Name
      , F.file_Offset 
      , event_time = xEvents.event_data.value('(event/@timestamp)[1]', 'datetime2') AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time'
      , server_principal_name = xEvents.event_data.value('(event/action[@name="server_principal_name"]/value)[1]', 'varchar(50)')
      , session_id = xEvents.event_data.value('(event/action[@name="session_id"]/value)[1]', 'int')
      , database_name = xEvents.event_data.value('(event/action[@name="database_name"]/value)[1]', 'varchar(50)')
      , sql_text = xEvents.event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') 
      FROM sys.fn_xe_file_target_read_file(E.PathReadFileTargetPrm, NULL, StartP.file_name, StartP.last_Offset_done) as F 
      CROSS APPLY (SELECT CAST(event_data AS XML) AS event_data) AS xEvents
      ) as ev
    Set @eventsDone = @@ROWCOUNT 

    -- All but the last file is guaranteed to be completely processed, so memorize them
    Declare @filesToDel Table (file_Name nvarchar(260), last_Offset_done BigInt, SeqfileInDescOrder Int)
    Delete @filesToDel 
    Insert into @filesToDel
    Select File_Name, last_Offset_done, SeqfileInDescOrder
    From
      (
      Select file_name, last_Offset_done, SeqfileInDescOrder=Row_number() Over (Order By File_Name Desc)
      From dbo.EvenementsTraites -- recorded by the trigger
      ) as FileSeq
    Where SeqfileInDescOrder > 1 --to process all but the last one

    -- vérifier si j'ai un fichier à traiter que je ne retrouve plus sur disque pcq roll_over
    Insert into dbo.LogTraitementAudit (Msg)
    Select MsgPrefix+Diff.file_name
    From
      (Select MsgPrefix, RepFichTrc, MatchFichTrc From Dbo.EnumsEtOpt) as MsgPrefix
      CROSS APPLY
      (
      Select file_Name from @FilesToDel 
      Except
      Select RepFichTrc+file_or_directory_name FROM sys.dm_os_enumerate_filesystem(RepFichTrc, MatchFichTrc)
      ) as Diff
    If @@ROWCOUNT>0 
    Begin
      --Raiserror ('Fichier d''audit perdu, voir table dbo.LogTraitementAudit',11,1)
      Select MsgPrefix+Diff.file_name
      From
        (Select MsgPrefix, RepFichTrc,MatchFichTrc From Dbo.EnumsEtOpt) as MsgPrefix
        CROSS APPLY
        (
        Select file_Name from @FilesToDel 
        Except
        Select RepFichTrc+file_or_directory_name FROM sys.dm_os_enumerate_filesystem(RepFichTrc, MatchFichTrc)
        ) as Diff
      Rollback;
      Print 'Fichier(s) d''audit perdu, voir table dbo.LogTraitementAudit'
      return(1)
    End

    Declare @aFileToDel nvarchar(256), @last_Offset_done Bigint 
    While (1=1)
    Begin
      Select top 1 @aFileToDel=file_Name, @last_Offset_done=last_Offset_done From @FilesToDel
      If @@ROWCOUNT = 0 Break

      -- clear files on disk 
      Begin Try
        Exec master.sys.xp_delete_files @afileToDel
      End Try
      Begin Catch
        Declare @msg nvarchar(4000)
        Set @Msg = ERROR_MESSAGE()
        -- this error is normal as the last opened file of a trace is in use, otherwise throw the error
        If @Msg Not Like '%xp_delete_files() returned error 32%' Return
      End Catch

      -- log fichier audit terminé
      Insert into dbo.LogTraitementAudit (Msg)
      Select 'Traitement fichier audit terminé: '+@afileToDel+ ' At Offset '+CONVERT(nvarchar(40), @last_Offset_done)+' pour '+CONVERT(nvarchar, @eventsDone)+ ' évènements '

      Delete From dbo.EvenementsTraites Where file_name = @aFileToDel
      Delete From @FilesToDel Where file_name = @aFileToDel
    End

    Commit Tran -- everything is consistent and done here

    -- ralentir plus ou moins la fréquence du traitement dépendant du nombre d'évènements qu'on 
    -- a trouvées comme restant à traiter.
    If @eventsDone < 5000
      Waitfor Delay '00:00:05' 

    If @eventsDone < 1000
      Waitfor Delay '00:00:15' 

    -- On ne veut pas que la table des connexions récentes à l'historique grossise toujours.
    -- Donc detruire les connexions de l'historique qui n'ont plus de session_id existant 
    -- et qui ont une connexion plus récente
    -- un session_id peut cesser d'exister, et ses transactions ne sont pas toutes traitées
    -- mais en pratique on en aura quelques unes
    Delete RC
    From 
      (
      Select LoginName, session_id, LoginTime, connectSeq=ROW_NUMBER() Over (partition by LoginName order by LoginTime Desc)
      From dbo.connectionsRecentes as RC
      ) as Rc
    Where connectSeq > 1 -- connexion passée, parce que connects=1 means most the recent connect
      And Session_id Not in (Select SESSION_ID from sys.dm_exec_sessions) -- connexion fermée
      And DATEDIFF(hh, LoginTime, GETDATE()) > 1 -- déconnecté depuis 1 heure 

  End -- While forever
End
go

/*
-- trace pour tests
Select * From AuditReq.dbo.connectionsRecentes 
Select * From auditReq.dbo.EvenementsTraites with (nolock)
Select * From auditReq.dbo.LogTraitementAudit with (nolock) order by msgDate
Select * From auditReq.dbo.AuditComplet with (nolock)
Select
  ev.server_principal_name
, ev.session_id
, ev.event_time
, Hc.program_name
, Hc.Client_net_address
, ev.database_name
, ev.sql_text 
, Ev.file_name
, ev.file_Offset
From 
  ( -- function sys.fn_xe_file_target_read_file needs file to read from and last_offset_done
    -- to skip events already done
  Select file_name, last_Offset_done From AuditReq.dbo.EvenementsTraites 
  UNION ALL
  -- La fonction sys.fn_xe_file_target_read_file a besoin de ces param au départ
  Select NULL, NULL Where Not Exists (Select * From dbo.EvenementsTraites)
  ) as StartP
  CROSS APPLY
  (
  SELECT 
    F.file_Name
  , F.file_Offset 
  , event_time = xEvents.event_data.value('(event/@timestamp)[1]', 'datetime2') AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time'
  , server_principal_name = xEvents.event_data.value('(event/action[@name="server_principal_name"]/value)[1]', 'varchar(50)')
  , session_id = xEvents.event_data.value('(event/action[@name="session_id"]/value)[1]', 'int')
  , database_name = xEvents.event_data.value('(event/action[@name="database_name"]/value)[1]', 'varchar(50)')
  , sql_text = xEvents.event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') 
  FROM sys.fn_xe_file_target_read_file('D:\_tmp\AuditReq*.xel', NULL, StartP.file_name, StartP.last_Offset_done) as F --'D:\_tmp\QueryTrackingSession_0_133625926429210000.xel',	9111552) --null, null)
  CROSS APPLY (SELECT CAST(event_data AS XML) AS event_data) AS xEvents
  ) as ev
  OUTER APPLY 
  (
  Select TOP 1 Hc.Program_name, Hc.Client_net_address 
  From Auditreq.dbo.connectionsRecentes as Hc
  Where Hc.LoginName = ev.server_principal_name 
    And Hc.session_id = ev.session_id
    And Hc.LoginTime < ev.event_time
  Order by Session_id, LoginName, LoginTime desc
  ) Hc


Exec AuditReq.dbo.CompleterInfoAudit
if @@TRANCOUNT>0 Rollback -- quand on test la SP et qu'on force son arrêt
*/