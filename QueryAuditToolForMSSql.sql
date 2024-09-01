/*
AuditReq Version 2.0
-- -----------------------------------------------------------------------------------
-- AVANT DE DÉMARRER CE SCRIPT AJUSTER LES OPTIONS DE NOM DE FICHIER ET DE RÉPERTOIRE
-- DANS LA VUE DBO.ENUMSETOPT
-- -----------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
AuditReq : Outil produisant un audit géré de requêtes SQL par le biais d'une base de données SQL Server
Auteur   : Maurice Pelchat
Licence  : BSD-3 https://github.com/pelsql/QueryAuditToolForMSSql/blob/main/LICENSE
           Prendre note des clauses de responsabilités associées à cette Licence au lien ci-dessus
-------------------------------------------------------------------------------------------------------
AuditReq : Tool to produce managed audit of SQL queries by the mean of a SQL Server database
Auteur   : Maurice Pelchat
Licence  : BSD-3 https://github.com/pelsql/QueryAuditToolForMSSql/blob/main/LICENSE
           Take note of the liability clauses associated with this License at the link above
-------------------------------------------------------------------------------------------------------
*/
Use tempdb
go
-- si on repasse le script il faut faire sauter le trigger
DROP TRIGGER IF EXISTS LogonAuditReqTrigger ON ALL SERVER; --repeated here for convenience when testing
GO
If DB_ID('AuditReq') IS NOT NULL -- déconecter tout le monde de la database si présente
Begin
  Print 'Kick tout le monde dehors de AuditReq'
  Use AuditReq
  Alter database AuditReq Set Single_User With Rollback Immediate
End
Go
If DB_ID('AuditReq') IS NOT NULL -- détruire database si présente
Begin
  Use Tempdb
  Print 'Drop Database AuditReq'
  Drop database AuditReq
ENd
GO
If DB_ID('AuditReq') IS NULL -- créer database si absente
Begin 
  CREATE DATABASE AuditReq
  alter DATABASE AuditReq Set recovery FULL
  alter database AuditReq modify file ( NAME = N'AuditReq', SIZE = 100MB, MAXSIZE = UNLIMITED, FILEGROWTH = 100MB )
  alter database AuditReq modify file ( NAME = N'AuditReq_log', SIZE = 100MB , MAXSIZE = UNLIMITED , FILEGROWTH = 100MB )
END
go
USE master 
DROP TRIGGER IF EXISTS LogonAuditReqTrigger ON ALL SERVER; --repeated here for convenience when testing
GO
Use AuditReq;
GO
-- cette table permet de conserver les connexions 
Drop table if exists dbo.HistoriqueConnexions
CREATE TABLE dbo.HistoriqueConnexions
(
	 LoginName nvarchar(256) NOT NULL
, Session_id smallint NOT NULL
, LoginTime datetime2(7)  NOT NULL
, Client_net_address nvarchar(48) NULL
, client_app_name sysname
, event_sequence BigInt
, CONSTRAINT PK_HistoriqueConnexions 
  PRIMARY KEY CLUSTERED (Session_id, Event_Sequence Desc, loginTime)
) 
go
Drop function if exists dbo.FormatCurrentMsg
Drop procedure if exists dbo.SendEMail
go
IF USER_ID('AuditReqUser') IS NOT NULL DROP USER AuditReqUser;
go
IF SUSER_SID('AuditReqUser') IS NOT NULL DROP LOGIN AuditReqUser;
go
Use AuditReq
GO
Create Or Alter View Dbo.EnumsEtOpt
as
Select *, MsgFichPerduGenerique=PrefixMsgFichPerdu+ ' voir table dbo.LogTraitementAudit'
From 
  (
  Select 
    MatchFichTrc='AuditReq*.xel' -- ne pas changer
  , BaseFn='AuditReq.Xel' -- ne pas changer
  , RootAboveDir='D:\_Tmp\' -- ajuster
  , Dir='AuditReq' -- ne pas changer
  , PrefixMsgFichPerdu='Fichier audit perdu: '
  , ErrMsgTemplate=
'----------------------------------------------------------------------------------------------
 -- Msg: #ErrMessage#
 -- Error: #ErrNumber# Severity: #ErrSeverity# State: #ErrState##atPos#
 ----------------------------------------------------------------------------------------------'
  , ErrMsgTemplateShort=' Msg: #ErrMessage# Error: #ErrNumber# Severity: #ErrSeverity# State: #ErrState##atPos#'
  ) as Base
  CROSS APPLY (Select RepFich=RootAboveDir+Dir) as RootAboveDir
  CROSS APPLY (Select RepFichTrc=RepFich+'\') as RepFichTrc
  CROSS APPLY (Select PathReadFileTargetPrm=RepFichTrc+MatchFichTrc) as PathReadFileTargetPrm
  CROSS APPLY (Select TargetFnCreateEvent=RepFichTrc+BaseFn) as TargetFnCreateEvent
-- select * from Dbo.EnumsEtOpt
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
Create Or Alter Function dbo.FormatRunTimeMsg 
(
  @MsgTemplate Nvarchar(max)
, @error_number Int 
, @error_severity Int 
, @error_state int
, @error_line Int 
, @error_procedure nvarchar(128)
, @error_message nvarchar(4000)
)
Returns Table
as 
Return
(
Select *
From 
  (Select ErrorMsgFormatTemplate=ISNULL(@MsgTemplate, E.ErrMsgTemplate) From dbo.EnumsEtOpt as E) as MsgTemplate
  CROSS APPLY (Select ErrMessage=@error_message) as ErrMessage
  CROSS APPLY (SeLect ErrNumber=@error_number) as ErrNumber
  CROSS APPLY (SeLect ErrSeverity=@error_severity) as ErrSeverity
  CROSS APPLY (SeLect ErrState=@error_state) as ErrState
  CROSS APPLY (SeLect ErrLine=@error_line) as ErrLine
  CROSS APPLY (SeLect ErrProcedure=@error_procedure) as vStdErrProcedure
  Cross Apply (Select FmtErrMsg0=Replace(ErrorMsgFormatTemplate, '#ErrMessage#', ErrMessage) ) as FmtStdErrMsg0
  Cross Apply (Select FmtErrMsg1=Replace(FmtErrMsg0, '#ErrNumber#', CAST(ErrNumber as nvarchar)) ) as FmtErrMsg1
  Cross Apply (Select FmtErrMsg2=Replace(FmtErrMsg1, '#ErrSeverity#', CAST(ErrSeverity as nvarchar)) ) as FmtErrMsg2
  Cross Apply (Select FmtErrMsg3=Replace(FmtErrMsg2, '#ErrState#', CAST(ErrState as nvarchar)) ) as FmtErrMsg3
  Cross Apply (Select AtPos0=ISNULL(' at Line:'+CAST(ErrLine as nvarchar), '') ) as vAtPos0
  Cross Apply (Select AtPos=atPos0+ISNULL(' in Sql Module:'+ErrProcedure,'')) as atPos
  Cross Apply (Select ErrMsg=Replace(FmtErrMsg3, '#atPos#', atPos) ) as FmtErrMsg
)
GO
CREATE OR ALTER FUNCTION dbo.FormatCurrentMsg (@MsgTemplate nvarchar(4000))
Returns table
as 
Return
  Select * 
  From 
  dbo.FormatRunTimeMsg 
  (  @MsgTemplate
  , ERROR_NUMBER ()
  , ERROR_SEVERITY()
  , ERROR_STATE()
  , ERROR_LINE()
  , ERROR_PROCEDURE ()
  , ERROR_MESSAGE ()
  ) as Fmt
/*
Begin try 
  Select 1/0
End Try 
Begin Catch
  Select errMsg From Dbo.EnumsEtOpt as E Cross apply dbo.FormatCurrentMsg(E.ErrMsgTemplate)
End catch
*/
GO
-- DISABLE TRIGGER LogonAuditReqTrigger ON ALL SERVER;
Use master;
DROP TRIGGER IF EXISTS LogonAuditReqTrigger ON ALL SERVER;
go
Use Master;
declare @unknownPwd nvarchar(100) = convert(nvarchar(400), HASHBYTES('SHA1', convert(nvarchar(100),newid())), 2)
Exec
(
'
create login AuditReqUser 
With Password = '''+@unknownPwd+'''
   , DEFAULT_DATABASE = AuditReq, DEFAULT_LANGUAGE=US_ENGLISH
   , CHECK_EXPIRATION = OFF, CHECK_POLICY = OFF'
)
GRANT VIEW SERVER STATE TO [AuditReqUser];
GRANT ALTER TRACE TO [AuditReqUser];
GO
Use AuditReq;
CREATE USER AuditReqUser For Login AuditReqUser;
GO
GRANT SELECT ON dbo.FormatCurrentMsg TO AuditReqUser; -- Utiles pour former msg erreur
GO
USE master
GO
DROP TRIGGER IF EXISTS LogonAuditReqTrigger ON ALL SERVER; --repeated here for convenience when testing
GO
-- initialiser le plus près possible les connexions déjà existantes et laisser 
-- le trigger permettre l'enregistrement des suivantes
-- on a des cas ou la jointure vers sys.dm_exec_connections donne plus d'une rangée par session_id d'ou le distinct
Insert into AuditReq.dbo.HistoriqueConnexions
(LoginName, Session_id, LoginTime, Client_net_address, client_app_name, event_sequence)
Select distinct S.login_name, S.session_id, S.login_time, C.client_net_address, S.program_name, 0
From 
  (Select * From sys.dm_exec_sessions as S Where S.is_user_process=1) as S
  JOIN 
  sys.dm_exec_connections as C
  ON C.session_id = S.session_id
GO
CREATE or Alter TRIGGER LogonAuditReqTrigger 
ON ALL SERVER WITH EXECUTE AS 'AuditReqUser'
FOR LOGON
AS
BEGIN

  DECLARE @JEventDataBinary Varbinary(8000);
  Begin Try
    Select @JEventDataBinary = JEventDataBinary
    From 
      (Select EventData=EVENTDATA()) as EvD
      CROSS APPLY (Select Spid=EventData.value('(/EVENT_INSTANCE/SPID)[1]', 'INT')) as Evi
      CROSS APPLY (Select client_net_address=EventData.value('(/EVENT_INSTANCE/ClientHost)[1]', 'NVARCHAR(30)')) as A
      LEFT JOIN (select * from master.sys.dm_exec_sessions) as S 
      ON S.session_id = Evi.Spid And S.is_user_process=1 
      CROSS APPLY 
      (
      Select -- met en json plusieurs données propre au login, dont le client_net_address
        JEventData= 
        (
        Select 
          LoginName=ORIGINAL_LOGIN()
        , LoginTime=SYSDATETIME()
        , Evi.spid 
        , A.client_net_address
        , client_app_name = S.program_name 
        For Json PATH
        )
      ) as JEventData
      CROSS APPLY (Select JEventDataBinary=CAST(JEventData as Varbinary(8000))) as JEventDataBinary

    -- Event ID (must be between 82 and 91)
    EXEC sp_trace_generateevent @eventid = 82, @userinfo = N'LoginTrace', @UserData=@JEventDataBinary

  End Try
  Begin Catch
    -- en état d'erreur on ne peut écrire dans aucune table, car la transaction va s'annuler quand même
    -- le mieux qu'on peut faire est de formatter l'erreur qui est redirigée dans le log de SQL Server
    Declare @msg nvarchar(4000) 
    Select @msg = 'Error in Logon trigger: LogonAuditReqTrigger'+nchar(10)+ErrMsg 
    From AuditReq.dbo.FormatCurrentMsg (null)
    Print @Msg
  End Catch
END;
GO
If Exists(Select * From sys.dm_xe_sessions Where name = 'AuditReq')
  ALTER EVENT SESSION AuditReq ON SERVER STATE = STOP;
GO
-- Supprimer la session si elle existe et nettoyer ses fichiers de trace
Declare @Fn nvarchar(260)
Select @Fn=E.PathReadFileTargetPrm From AuditReq.dbo.EnumsEtOpt as E
IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'AuditReq')
Begin
  DROP EVENT SESSION AuditReq ON SERVER;
  Exec master.sys.xp_delete_files @fn
End
go
declare @FullFn sysname; -- création event Session
Select @FullFn=E.TargetFnCreateEvent From AuditReq.Dbo.EnumsEtOpt as e;
-- sp_statement_completed (statement = chaque requete, sql_text le call)
-- sql_stmt_completed (statement = chaque requete, sql_text le lot)
-- pour sql_stmt_completed on peut donc alléger le traitement en omettant sql_text
-- sql_batch_completed (statement = NULL, sql_text le lot)
Declare @Sql Nvarchar(max) =
'
CREATE EVENT SESSION AuditReq ON SERVER
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
ADD TARGET package0.asynchronous_file_target(
SET 
  filename = ''#FullFn#''
, max_file_size = (40) -- fichier 40 meg file par défaut MB est le default
-- pas de rollover puisque la procédure gère elle-même quand ôter les évènements quand elle les a traité
, max_rollover_files = (1000) -- environ 40 gb
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
Print @sql
Exec (@Sql);
go
ALTER EVENT SESSION AuditReq ON SERVER STATE = START;
GO
USE AuditReq
GO
Drop table if exists dbo.EvenementsTraites
Create table dbo.EvenementsTraites
(
  passe Int
, NbTotalFich Int
, file_seq Int
, file_name nvarchar(260) NULL
,	last_Offset_done bigint NULL
)
GO
Drop table if exists dbo.EvenementsTraitesSuivi
Create table dbo.EvenementsTraitesSuivi
(
  Passe Int 
, NbTotalFich Int
, file_seq Int
, file_name nvarchar(260) NULL
, last_Offset_done bigint NULL
, dateSuivi Datetime2 Default SYSDATETIME()
)
create index iDateSuivi on dbo.EvenementsTraitesSuivi(dateSuivi)
create index iPasseFileName on dbo.EvenementsTraitesSuivi (passe, file_name) 
GO
-- just a transaction table processed by an instead of trigger
-- the trigger processed data in Inserted but never make it to the table
Drop table if exists dbo.PipelineDeTraitementFinalDAudit
CREATE TABLE dbo.PipelineDeTraitementFinalDAudit
(
  server_principal_name varchar(50) NULL
,	session_id int NULL
,	event_time datetimeoffset(7) NULL
, event_Sequence BigInt NULL
, Database_name sysname NULL
--, sql_batch nvarchar(max)
--, line_number int
,	statement nvarchar(max) NULL
,	file_name nvarchar(260) NOT NULL -- selon donc sys.fn_xe_file_target_read_file
,	file_Offset bigint NOT NULL -- selon donc sys.fn_xe_file_target_read_file
, passe int NULL
, file_seq int null
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
, client_app_name sysname NULL
, database_name sysname 
--, sql_batch nvarchar(max)
--, line_number int
, statement nvarchar(max) 
, event_sequence BigInt
, passe Int 
, file_seq Int
) 
create index iEvent_Time on dbo.AuditComplet(Event_time, event_Sequence)
go
Drop table if Exists dbo.LogTraitementAudit
CREATE TABLE dbo.LogTraitementAudit
(
  MsgDate datetime2 default SYSDATETIME()
, Msg nvarchar(max) NULL
) 
create index iMsgDate on dbo.LogTraitementAudit(MsgDate)
go
drop sequence if exists dbo.SeqExtraction
Create Sequence dbo.SeqExtraction as Int start with 0;
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
-- Ce déclencheur ne sert que de moyen d'implanter un pipeline de traitement 
-- d'évènemets. En tant qu'instead trigger, il fait jamais d'opération réelle sur
-- sa table qui reste vide.
-- Il finalise l'ajout de l'information de connexion à l'audit et
-- et fait le suivi des fichiers lus et des prochains fichiers à lire
-- en tenant compte de leur offset (où ils en sont rendus)
-- --------------------------------------------------------------------------------
Create or Alter Trigger trgPipelineDeTraitementFinalDAudit 
ON dbo.PipelineDeTraitementFinalDAudit
Instead of Insert, Update, Delete -- just handle insert, discard Delete, Update
AS -- just a mean to implement a pipeline, handle inserts and discard Delete, Update
Begin
  If @@ROWCOUNT = 0 Return

  -- remember this table is always empty. It is just a pipeline
  -- In care there us non-sense attempts of deletes or update (since table is empty)
  -- there is nothing to do, since in both case inserted table is going to be empty.
  Declare @msg nvarchar(4000)

  Begin Try

    Insert into dbo.AuditComplet 
      ( server_principal_name, event_time, Client_net_address, event_sequence
      , session_id, client_app_name, database_name
      --, sql_batch
      --, line_number
      , statement, passe, file_seq)
    Select 
      I.server_principal_name, I.event_time, Hc.Client_net_address, I.event_Sequence
    , I.session_id, Hc.client_app_name, I.database_name
    --, I.sql_batch
    --, I.Line_number
    , I.statement, I.passe, I.file_seq
    From 
      Inserted as I
      -- Un même login peut se connecter et se reconnecter avec un numéro de session différent
      -- mais ce qu'on cherche c'est le login avec le même session_id
      -- mais qui a la sequence la plus proche dans les évènements de requête
      -- exemple le login de session_id=120 avec event_Sequence=130
      -- il y a des requêtes pour cette session_id=120 avec event_sequence > 130 et < 400
      -- cette session se termine puis une autre s'ouvre qui réutilise le même session_id 
      -- exemple le login de session_id=120 avec event_Sequence=401
      -- il y a  des requêtes pour ce session_id=120 avec  event_sequence > 401
      -- donc si on veut associer les requêtes au bon login, il faut qu'il y ait égalité sur le session_id
      -- et trouver celui dont le event_sequence est plus petit que la requête

      OUTER APPLY 
      (
      Select TOP 1 Hc.client_app_name, Hc.Client_net_address 
      From Auditreq.dbo.HistoriqueConnexions as Hc
      Where Hc.session_id = I.session_id
        And Hc.event_Sequence < I.event_Sequence 
      Order by Session_id, event_Sequence desc
      ) Hc
       -- en dehors du trigger il y a une gestion des fichiers d'évènements traités
       -- s'il en sont pas traités comme supprimés, il y aura risque de relecture
       -- des évènements et ce Where Not Exists évite les duplications.
    Where
      Not Exists
      (
      Select * 
      From dbo.AuditComplet AC
      Where AC.event_time = I.event_time 
        And AC.event_sequence = I.event_Sequence
      )

    Delete From dbo.AuditComplet 
    Where event_time < DATEADD(dd, -45, getdate()) -- détruit audit plus vieux que 45 jours.

    -- On se sert de Inserted qui est une image gelée de ce qu'on vient de traiter.
    -- on veut la liste des fichiers passés par la fonction, leur ordre et nombre et leur dernier offSet
    -- Quand on appelle la fonction de lecture dans CompleterAuditInfo, la fonction de lecture
    -- veut juste savoir à quel fichier on étai rendu et l'Offset après lequel il continuera.
    -- Par contre quand on supprime les fichiers, on a besoin de la liste des fichiers passés
    -- et le nombre total, pour éviter de supprimer le dernier.

    Declare @passe Int = Next Value For dbo.SeqExtraction
    Delete dbo.EvenementsTraites -- on réévalue par ce que la fonction a retourné
    Insert into dbo.EvenementsTraites (passe, file_Seq, file_name, last_Offset_done, NbTotalFich)
    Select 
      @passe
      -- le nom des fichiers "croît" dans le temps, fileSeq permet de voir si on a lu
      -- plus d'un fichier dans une passe.
    , fileSeq=ROW_NUMBER() Over (Order by file_Name) 
    , file_name
    , last_offset_done
    , NbTotalFich=COUNT(*) Over (Partition By NULL) -- nombre de fichiers lus
    From
      (
      -- offset le plus lointain lu pour un fichier, on repartira de là pour lire la suite
      Select file_name, last_offset_done=MAX(file_offset) 
      From Inserted
      Group by file_name 
      ) as files

    -- pour ce qui a été déjà traité
    Insert into dbo.EvenementsTraitesSuivi (passe, file_Seq, file_name, last_Offset_done, NbTotalFich) 
    Select @passe, file_Seq, file_name, last_Offset_done, NbTotalFich from dbo.EvenementsTraites as Et

    Delete From dbo.EvenementsTraitesSuivi 
    Where dateSuivi < DATEADD(dd, -45, getdate()) -- détruit traces plus vieilles que 45 jours.

    Delete From dbo.LogTraitementAudit
    Where MsgDate < DATEADD(dd, -45, getdate()) -- détruit log plus vieux que 45 jours.

  End Try
  Begin Catch
    Select @msg=Fmt.ErrMsg
    From 
      (Select ErrMsgTemplate From dbo.EnumsEtOpt) as E
      CROSS APPLY dbo.FormatRunTimeMsg (E.ErrMsgTemplate, ERROR_NUMBER (), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE (), ERROR_MESSAGE ()) as Fmt
    Insert Into dbo.LogTraitementAudit(Msg) Values (@msg)
    RAISERROR(@msg,11,1)
  End Catch

End
GO
USE AuditReq
GO
Create or Alter Proc dbo.CompleterInfoAudit
as
Begin
  Set nocount on

  Begin Try

  Drop table if Exists #tmp
  Create table #tmp 
  (
   	file_name nvarchar(260) NOT NULL -- selon donc sys.fn_xe_file_target_read_file
  ,	file_Offset bigint NOT NULL -- selon donc sys.fn_xe_file_target_read_file
  , passe int NULL
  , file_seq int null
  , event_name nvarchar(128)
  , event_data XML NULL
  )
  Drop table if Exists #AuditLogins
  Create Table #AuditLogins (event_Data XML NULL)

  Declare @eventsDone BigInt
  While (1=1) -- cette proc est prévue pour rouler constamment avec des Waits selon le volume restant à traiter.
  Begin

    -- c'est comme plus performant de faire ainsi en 2 step que direct 
    Truncate table #tmp
    Insert into #tmp
    Select 
      ev.file_name
    , ev.file_Offset
    , StartP.passe
    , StartP.file_seq
    , Event_name
    , ev.event_data
    From 
      ( -- la fonction sys.fn_xe_file_target_read_file a besoin du dernier fichier lu et l'offset lu
        -- Elle se rend à ce fichier sans parcourir les autres puis se positionne après l'offset lu
        -- pour y poursuivre la suite de la lecture des évènements.

      Select file_name, last_Offset_done, passe, file_seq -- dernier offset lu du dernier fichier, voir trigger
      From dbo.EvenementsTraites 
      Where file_seq = NbTotalFich -- dernier fichier lu la dernière fois.
      UNION ALL
      -- La fonction sys.fn_xe_file_target_read_file a besoin de ces param au départ, 
      -- donc en pratique cette requête ne s'exécute plus par la suite
      Select NULL, NULL, NULL, NULL Where Not Exists (Select * From dbo.EvenementsTraites)
      ) as StartP
      CROSS JOIN Dbo.EnumsEtOpt as E
      CROSS APPLY
      (
      Select event_data = xEvents.event_data, Event_name, F.file_name, F.file_offset
      FROM 
        sys.fn_xe_file_target_read_file(E.PathReadFileTargetPrm, NULL, StartP.file_name, StartP.last_Offset_done) as F 
        CROSS APPLY (SELECT CAST(event_data AS XML) AS event_data) AS xEvents
        CROSS APPLY (Select event_name = xEvents.event_data.value('(event/@name)[1]', 'varchar(50)')) as Event_name
      ) as ev
    --select * from #tmp
    -- enlever de #tmp les evenements de login pour des fins de traitement
    
    Truncate Table #AuditLogins
    Delete #tmp
    OUTPUT deleted.event_data INTO #AuditLogins(event_Data)
    Where event_name = 'user_event'

    --Select * from #AuditLogins
    --Select * from #tmp
    -- inserer les évènements de login à la table d'historique des logins
    -- le trigger en a de besoin pour lier le client_net_address et le client_app_name à l'instruction SQL
    -- on a des cas ou la jointure vers sys.dm_exec_connections donne plus d'une rangée par session_id d'ou le distinct
    Insert Into dbo.HistoriqueConnexions
          (LoginName,   Session_id,   LoginTime,   client_net_address,   client_app_name,   Event_Sequence)
    Select Distinct J.LoginName, J.Session_id, J.LoginTime, J.client_net_address , J.client_app_name, Event_Sequence
    From 
      (SELECT event_data From #AuditLogins) as event_data
      CROSS APPLY (SELECT Event_Sequence=event_data.value('(event/action[@name="event_sequence"]/value)[1]', 'bigint')) as Event_Sequence
      CROSS APPLY (SELECT UserDataHexString=event_data.value('(event/data[@name="user_data"]/value)[1]', 'nvarchar(max)')) AS UserDataHexString
      CROSS APPLY (SELECT UserDataBin = CONVERT(VARBINARY(MAX), '0x'+UserDataHexString, 1)) as UserDataBin
      CROSS APPLY (Select UserData=CAST(UserDataBin as NVARCHAR(4000))) as UserData
      Outer APPLY
      (
      SELECT 
        LoginName=JSON_VALUE(value, '$.LoginName') 
      , LoginTime=JSON_VALUE(value, '$.LoginTime')
      , Session_id=JSON_VALUE(value, '$.spid')
      , client_net_address=JSON_VALUE(value, '$.client_net_address')
      , client_app_name=JSON_VALUE(value, '$.client_app_name') 
      FROM OPENJSON(UserData)
      -- validation for JSON
      Where UserData like '_{"LoginName":"%","LoginTime":"%","spid":%,"client_net_address":"%","client_app_name":"%"}_' 
      ) as J
    -- Ajout de résilience. Si le processus de traitement des évènements a été interrompu,
    -- et qu'on retraite les évènements de login, ce bout de code évite les cas de duplicate.
    Where
      Not Exists -- Si le processus a planté, et qu'on traite à nouveau les évènements de login
                 -- ce bout de code empêchera l'insertion de duplicate
      (
      Select * 
      From dbo.HistoriqueConnexions CE 
      Where 
            CE.Session_id = J.Session_id 
        And CE.event_sequence = Event_Sequence.Event_Sequence
      )            

    -- voir le instead of trigger qui traite Dbo.PipelineDeTraitementFinalDAudit
    -- c'est lui qui ré-initialise aussi le contenu de dbo.evenements traités
    -- la résilience en cas de problème est garantie par le trigger
    Insert into Dbo.PipelineDeTraitementFinalDAudit
      ( server_principal_name, session_id, event_time, Event_Sequence, Database_Name
      --, sql_batch
      --, line_number
      , statement, file_name, file_Offset, passe, file_seq)
    SELECT R.*
    From
      (
      Select 
        server_principal_name = event_data.value('(event/action[@name="server_principal_name"]/value)[1]', 'varchar(50)')
      , session_id = event_data.value('(event/action[@name="session_id"]/value)[1]', 'int')
      , event_time = event_data.value('(event/@timestamp)[1]', 'datetime2(7)') AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time'
      , Event_Sequence = event_data.value('(event/action[@name="event_sequence"]/value)[1]', 'bigint')
      , database_name = event_data.value('(event/action[@name="database_name"]/value)[1]', 'varchar(50)')
      --, line_number = xEvents.event_data.value('(event/data[@name="line_number"]/value)[1]', 'int') 
      , statement = event_data.value('(event/data[@name="statement"]/value)[1]', 'nvarchar(max)') 
      , file_name
      , file_Offset
      , passe
      , file_seq
      From #tmp    
      ) as R
    Where session_id>50
    Set @eventsDone = @@ROWCOUNT 
    -- si on traitait toute les requêtes on pourrait mettre le code du module SQL dans SQL+Batch seulement
    -- quand le numéro de ligne est 1, la donnée statement ci-dessus donnant chaque requête.
    -- actuellement on ne le fait pas, et statement est tout le module au démarrage de ce dernier.
    --OUTER APPLY 
    --(
    --Select Sql_batch= ev.event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') 
    --Where line_number = 1
    --) as Sql_Batch

    -- vérifier si j'ai un fichier à traiter que je ne retrouve plus sur disque pcq un évènement
    -- manuel ou système l'aurait détruit.
    Insert into dbo.LogTraitementAudit (Msg)
    Select Msg=PrefixMsgFichPerdu+Diff.file_name
    From
      (Select PrefixMsgFichPerdu, RepFichTrc, MatchFichTrc From Dbo.EnumsEtOpt) as MsgPrefix
      CROSS APPLY
      (
      Select file_Name from dbo.EvenementsTraites
      Except
      Select full_filesystem_path  FROM sys.dm_os_enumerate_filesystem(RepFichTrc, MatchFichTrc)
      ) as Diff
    If @@ROWCOUNT>0 
    Begin
      Declare @msgPerte nvarchar(4000)
      Select @msgPerte=E.MsgFichPerduGenerique From dbo.EnumsEtOpt as E
      Raiserror (@msgPerte, 11, 1)
    End

    -- cleanup des fichiers traités (exclure le dernier qui reste en usage)
    Declare 
      @aFileToDel nvarchar(256)
    , @last_Offset_done Bigint 
    , @file_Seq Int = 0 -- pré valeur, car la séquence commence à 1 et on veut un @file_Seq=à celui du courant
    , @nbTotalFich Int
    , @progres nvarchar(100)
    While (1=1)
    Begin
      -- obtient prochain fichier relatif au @file_Seq courant, mais exclue les deux derniers
      -- pourquoi deux plutôt qu'un seul?
      -- il arrive au switch de fichier que le dernier soit écrit et devienne avant dernier
      -- et n'est pas fini de lire. La fonction de lecture va donc se plaindre qu'il est manquant
      Select Top 1 -- pour stopper la recherche car chaque rangée possède sa séquence unique
        @file_Seq = File_Seq -- ordre des fichiers
      , @aFileToDel = file_Name
      , @nbTotalFich = NbTotalFich -- même valeur pour chaque rangée
      , @last_Offset_done = last_Offset_done 
      -- on fait -1 sur le nombre de fichiers à supprimer,  car on ne supprime pas le dernier.
      , @progres=' ('+Convert(nvarchar, @File_Seq)+'/'+Convert(nvarchar, @NbTotalFich-1)+') '
      From 
        Dbo.EvenementsTraites CROSS APPLY (Select SeqFichSuiv=@file_Seq+1) as SeqFichSuiv
      Where SeqFichSuiv < NbTotalFich And file_seq = SeqFichSuiv
      Order by file_seq

      If @@ROWCOUNT = 0 -- plus de noms de fichiers à supprimer déduit des dbo.evenementstraités.
      Begin
        -- Menage des fichiers dont les noms ne sont plus retournés par sys.fn_xe_file_target_read_file
        -- Ils ne sont pas plus dans dbo.evenementstraites pour la même raison.
        -- C'est possible à cause d'un rollover qui se ferait et qui éliminerait un fichier qu'on a vraiment fini de lire
        -- mais comme on ne sait pas si c'est le cas, l'algorithnme de l'élimine pas. 
        -- Il attend qu'il tombe en second à la prochaine lecture. Mais comme le RollOver supprime le fichier
        -- avant qu'on aille relire, sys.fn_xe_file_target_read_file n'en retourne plus la trace. Ici on fait 
        -- ménage "lazy" qui n'en fait qu'un à la fois, et ne touche jamais au dernier (plus récent)
        -- qui est présent sur disque. On le présume comme appartenant à la trace active.
        Select TOP 1 @aFileToDel = full_filesystem_path
        FROM dbo.EnumsEtOpt cross apply sys.dm_os_enumerate_filesystem(RepFichTrc, MatchFichTrc)
        Where 
          DateDiff(mi, last_write_time, GETUTCDATE()) > 1 -- fichiers plus écrits depuis plus d'une minute
          And Not Exists -- et pas présents dans la liste des ficiers retournés par la fonction, alors qu'elle n'en voit plus qu'un
          (
          Select *
          From dbo.EvenementsTraites 
          Where file_name = full_filesystem_path 
          )
        Order by full_filesystem_path
        If @@ROWCOUNT = 0 -- pas de fichier à traiter ici non plus, on passe, sinon on laisse détruire
          Break
        Set @last_Offset_done=NULL -- inconnu
      End

      -- on ne laisse pas faire de rollover au niveau des evènements, mais on détruit les fichiers qu'on a traité
      -- toutefois même si on a fini de traiter les évènements du fichier, d'autres peuvent s'y ajouter entretemps
      -- et il reste en usage, aussi on accepte l'erreur.
      Begin Try
        -- truc pour passer de l'information au profiler avec une instruction d'initialisation
        Declare @trc Nvarchar(4000) = 'declare @trcPourProfiler varchar(4000) =''Fichier à ôter :'+ @afileToDel+@progres+''''
        Exec(@trc)
        Exec master.sys.xp_delete_files @afileToDel
        Insert into dbo.LogTraitementAudit (Msg) 
        Select 'Suppression/traitement fichier audit terminé: '+afileTodel+Msg
        From 
          (Select afileTodel= @afileToDel) as aFileToDel
          CROSS APPLY
          (
          Select Msg = ' '+ @progres + 'At Offset '+CONVERT(nvarchar(40), @last_Offset_done)
                    + ' pour '+CONVERT(nvarchar, @eventsDone)+ ' évènements '
          Where @last_Offset_done is not null
          UNION ALL
          Select Msg = '. Fichier sans info car non retourné par sys.fn_xe_file_target_read_file, car Rollover l''a supprimé entre 2 lectures '
          Where @last_Offset_done IS NULL
          ) as Msg

        -- élimine des évènements traités seulement celui qu'on vient de faire 
        -- ne pas oublier qu'il en restera deux qui seront à traiter
        -- si une panne empêche l'exécution de ce bout, ce qui ferait que les évènements seraient
        -- reinsérés, le trigger teste que les évènements ne sont pas déjà insérés
        Delete From dbo.EvenementsTraites Where file_seq=@File_Seq And @last_Offset_done IS NOT NULL
      End Try
      Begin Catch 
        -- Si ce n'est pa une erreur de fichier en usage, renvoie la.
        -- mais ce n'est pas supposé être jamais le cas d'un fichier en usage
        Declare @msgDel nvarchar(4000) = ERROR_MESSAGE() 
        Insert into dbo.LogTraitementAudit (Msg) 
        Select 'Suppression fichier audit avec erreur: '+@afileToDel + @msgDel
        If @MsgDel Not Like '%xp_delete_files() returned error 32%' 
          THROW;
      End Catch
    End

    -- ralentir plus ou moins la fréquence du traitement dépendant du nombre d'évènements qu'on 
    -- a trouvées comme restant à traiter.
    If @eventsDone<500 
      Waitfor Delay '00:00:05' 
    
    -- On ne veut pas que la table des connexions récentes à l'historique grossise toujours.
    -- Donc detruire les connexions de l'historique qui n'ont plus de session_id existant 
    -- et qui ont une connexion plus récente
    -- un session_id peut cesser d'exister, sans que ses transactions soient toutes traitées
    -- mais en pratique on en aura quelques unes
    Delete RC 
    From 
      (
      Select LoginName, session_id, LoginTime, connectSeq=ROW_NUMBER() Over (partition by LoginName order by LoginTime Desc)
      From dbo.HistoriqueConnexions as RC
      ) as Rc
    Where connectSeq > 1 -- connexion passée, parce que connects=1 
      And Not Exists -- si une session d'un LoginName semble être du passé, on patiente 1 heure pour être sûr qu'elle a été traitée
          (
          Select SESSION_ID 
          from sys.dm_exec_sessions S 
          Where S.Login_Name = Rc.LoginName and S.Session_id= Rc.Session_id      
          ) -- connexion fermée
      And DATEDIFF(minute, LoginTime, GETDATE()) > 60 -- déconnecté depuis 1 heure 

  End -- While forever

  End Try
  Begin Catch
    Declare @msg nvarchar(max)
    Select @msg=Fmt.ErrMsg
    From 
      (Select ErrMsgTemplate From dbo.EnumsEtOpt) as E
      CROSS APPLY dbo.FormatRunTimeMsg (E.ErrMsgTemplate, ERROR_NUMBER (), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE (), ERROR_MESSAGE ()) as Fmt
    Insert into dbo.LogTraitementAudit (Msg) values (@msg)
    RAISERROR(@msg,11,1)
  End Catch
End -- dbo.CompleterInfoAudit
go
Create or Alter Function dbo.HostMostUsedByLoginName(@LoginName sysname = 'Pelletierr')
Returns Table
as
Return
Select Top 1 LoginName, client_net_address -- parce que les rangées sont toutes pareilles
From 
  (
  Select 
    LoginName
  , client_net_address
  , nbOcc_Client_net_address
  , plusFrequent=MAX(nbOcc_Client_net_address) Over (Partition by LoginName)
  From
    ( -- ajouter 
    Select LoginName, client_net_address, nbOcc_Client_net_address=count(*) Over (Partition by LoginName, client_net_address)
    From
      (Select PrmUtil=@LoginName) as P
      CROSS APPLY 
      (
      Select Top 10 LoginName, client_net_address, LoginTime
      FROM AuditReq.dbo.HistoriqueConnexions
      Where LoginName=P.PrmUtil
      Order By LoginName, LoginTime Desc
      ) As DixDerniersPostesParLoginName
    ) as DecompteOrdis
  ) as LigneFreq
Where nbOcc_Client_net_address=plusFrequent
go
USE [msdb]
GO
/****** Object:  Job AuditReq    Script Date: 2024-06-29 09:23:36 ******/
Begin Try 

  BEGIN TRANSACTION;

  DECLARE @ReturnCode INT = 0

  DECLARE @jobId BINARY(16)
  Select @jobId = job_id From msdb.dbo.sysjobs where name =N'AuditReq'

  If @jobId IS NOT NULL
  Begin
    EXEC @ReturnCode =  msdb.dbo.sp_delete_job @job_name=N'AuditReq'
    IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_delete_schedule ',11,1,@returnCode)

    If exists (Select * From msdb.dbo.sysjobschedules where job_id=@jobId)
    Begin
      EXEC sp_detach_schedule @job_name = N'AuditReq', @schedule_name = N'AuditReqAutoRestart';
      Exec @ReturnCode =  msdb.dbo.sp_delete_schedule @schedule_name ='AuditReqAutoStart'
      IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_delete_schedule ',11,1,@returnCode)
    End
  End

  Set @jobId = NULL
  EXEC @ReturnCode =  msdb.dbo.sp_add_job 
    @job_name=N'AuditReq', 
		  @enabled=1, 
		  @notify_level_eventlog=0, 
		  @notify_level_email=0, 
		  @notify_level_netsend=0, 
		  @notify_level_page=0, 
		  @delete_level=0, 
		  @description=N'No description available.', 
		  @category_name=N'Data Collector', 
		  @owner_login_name=N'sa',
    @job_id = @jobId OUTPUT
  IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_add_job ',11,1,@returnCode)

  EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Run', 
		  @step_id=1, 
		  @cmdexec_success_code=0, 
		  @on_success_action=2, -- si la job arrête, c'est un erreur à rapporter, elle ne devrait pas
		  @on_success_step_id=0, 
		  @on_fail_action=2, 
		  @on_fail_step_id=0, 
		  @retry_attempts=0, 
		  @retry_interval=0, 
		  @os_run_priority=0, @subsystem=N'TSQL', 
		  @command=
    N'
Begin try
  EXECUTE [dbo].[CompleterInfoAudit]
End Try
Begin catch
  Declare @msg nvarchar(max)
  Select @msg = F.ErrMsg
  From 
    AuditReq.dbo.FormatCurrentMsg (NULL) as F
  Print @msg
End catch	
', 
		  @database_name=N'AuditReq', 
		  @flags=4
  IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_add_job_Step ',11,1,@returnCode)

  EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
  IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_update_Job ',11,1,@returnCode)

  EXEC @ReturnCode = msdb.dbo.sp_add_schedule 
    @schedule_name=N'AuditReqAutoStart',
		  @enabled=1, 
		  @freq_type=64, 
		  @freq_interval=0, 
		  @freq_subday_type=0, 
		  @freq_subday_interval=0, 
		  @freq_relative_interval=0, 
		  @freq_recurrence_factor=0, 
		  @active_start_date=20240614, 
		  @active_end_date=99991231, 
		  @active_start_time=0, 
		  @active_end_time=235959, 
		  @schedule_uid=N'125473bc-5be4-482d-a983-6429de1eb934'
  IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_add_schedule pour AuditReqAutoStart',11,1,@returnCode)

  EXEC sp_attach_schedule @job_name = N'AuditReq', @schedule_name = N'AuditReqAutoStart';

  EXEC @ReturnCode = msdb.dbo.sp_add_schedule 
  @schedule_name=N'AuditReqAutoRestart', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=15, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240831, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'0d25ae92-b4d3-4c26-868a-046121824dc8'
  IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_add_schedule pour AuditReqAutoRestart',11,1,@returnCode)

  EXEC sp_attach_schedule @job_name = N'AuditReq', @schedule_name = N'AuditReqAutoRestart';


  EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
  IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_add_jobserver ',11,1,@returnCode)

  EXEC dbo.sp_start_job N'AuditReq';
  IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_start_job ',11,1,@returnCode)

  COMMIT
End Try
Begin catch
  Declare @msg nvarchar(max)
  Select @msg = F.ErrMsg
  From 
    AuditReq.dbo.FormatCurrentMsg (NULL) as F
  Print 'erreur à la définition ou au lancement de la job: '+@msg
  ROLLBACK
End catch
GO
Use AuditReq
go
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
create or alter function dbo.findMissingSeq (@diff int) -- intented to be run with fresh install after a run of LauchSQLStressTest.ps1
returns table
as
return
select *
From
  (
  select event_sequence, event_time, statement, f, s, bs=isnull(lag(s,1,0) Over (partition by f order by s),'00000')
  from 
    dbo.AuditComplet
    cross apply (Select F=cast(SUBSTRING(statement,12,3) as int)) as f
    cross apply (select S=cast(SUBSTRING(statement,20,5) as int)) as s
  where statement like 'SELECT Fen=%,Seq=%' 
  ) as r
Where S-bs<>@diff -- should be 1 if no gap or missing 
go
--Select * From dbo.EquivExEventsVsTrace where EventClass like 'UserCon%'--

--Select file_name, last_Offset_done, count(*), MIN (passe), MAX(passe)
--From auditReq.dbo.EvenementsTraitesSuivi with (nolock) 
--group by file_name, last_Offset_done
--order by file_name, last_Offset_done

/*

Select *--session_id--, sql_batch, statement 
From auditReq.dbo.AuditComplet with (nolock) 
order by event_time

-- trace pour tests
Select ntile(3) over (order by logintime), * 
From AuditReq.dbo.connexionsRecentes order by logintime
Select * From auditReq.dbo.EvenementsTraites with (nolock)
Select * From auditReq.dbo.EvenementsTraitesSuivi with (nolock) 
order by dateSuivi
Select file_name, last From auditReq.dbo.EvenementsTraitesSuivi with (nolock) 
group by dateSuivi
Select * From auditReq.dbo.LogTraitementAudit 
where msg like '%D:\_Tmp\AuditReq\AuditReq_0_133635856879820000.Xel%'
with (nolock) order by msgDate
Select * From auditReq.dbo.LogTraitementAudit 
where MsgDate <= '2024-06-22 21:03:20.8561224'
Select stuff(msg, 87, 3, '') From auditReq.dbo.LogTraitementAudit with (nolock) order by stuff(msg, 87, 3, '')
Select * From auditreq.dbo.EvenementsTraitesSuivi 


Select *, 
From 
  auditReq.dbo.EvenementsTraitesSuivi with (nolock) 
  left join 
  (values ('AuditReq_0_133636748038350000'), ('AuditReq_0_133636749713830000'), ('AuditReq_0_133636750202440000'), ('AuditReq_0_133636750291350000')
  ) as L(l)
  on file_name like '%'+l.l+'%'
  left join AuditReq.dbo.LogTraitementAudit as A
  on A.Msg Like '%'+file_name+'%'
order by dateSuivi


Select event_time, SeqInQuery, row_number() Over (order by SeqInQuery), statement
From 
  auditReq.dbo.AuditComplet with (nolock)
  cross apply (select seqInQuery=substring(statement,3,6)) as SeqInQuery
where statement  like '--[0-9][0-9][0-9][0-9][0-9][0-9]%'
order by seqInQuery


Select *, convert (varbinary(max),statement)  From auditReq.dbo.AuditComplet with (nolock) 
--where rtrim(statement) = '' 
where event_time = '2024-06-23 15:16:15.2220000 -04:00'
order by event_time 
where statement  like '%Create%Or%Alter%Function%S#.ColInfo%'
Select top 3
  ev.server_principal_name
, ev.session_id
, ev.event_time
, Hc.client_app_name
, Hc.Client_net_address
, ev.database_name
, ev.statement 
, ev.sql_batch
, startP.file_Name
, StartP.last_Offset_done
, Ev.file_name
, ev.file_Offset
, ev.Event_Data
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
  , statement = xEvents.event_data.value('(event/data[@name="statement"]/value)[1]', 'nvarchar(max)') 
  , sql_batch = xEvents.event_data.value('(event/action[@name="sql_batch"]/value)[1]', 'nvarchar(max)') 
  , xEvents.event_data
  FROM sys.fn_xe_file_target_read_file('D:\_tmp\AuditReq\AuditReq*.xel', NULL, StartP.file_name, StartP.last_Offset_done) as F --'D:\_tmp\QueryTrackingSession_0_133625926429210000.xel',	9111552) --null, null)
  CROSS APPLY (SELECT CAST(event_data AS XML) AS event_data) AS xEvents
  ) as ev
  OUTER APPLY 
  (
  Select TOP 1 Hc.client_app_name, Hc.Client_net_address 
  From Auditreq.dbo.connexionsRecentes as Hc
  Where Hc.LoginName = ev.server_principal_name 
    And Hc.session_id = ev.session_id
    And Hc.LoginTime < ev.event_time
  Order by Session_id, LoginName, LoginTime desc
  ) Hc

cd d:\_tmp\AuditReq
sqlcmd -E -S.\sql2k19 -dS# -i GrosseCharge.Sql
Exec AuditReq.dbo.CompleterInfoAudit
if @@TRANCOUNT>0 Rollback -- quand on test la SP et qu'on force son arrêt
*/
