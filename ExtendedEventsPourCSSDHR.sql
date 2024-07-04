-- -----------------------------------------------------------------------------------
-- Avant de démarrer ce script ajuster les options de nom de fichier et de répertoire
-- dans la vue Dbo.EnumsEtOpt
-- -----------------------------------------------------------------------------------
Use tempdb
go
If DB_ID('AuditReq') IS NULL -- créer database si absente
Begin 
  CREATE DATABASE [AuditReq]
  alter DATABASE [AuditReq] Set recovery simple
  alter database  [AuditReq] modify file ( NAME = N'AuditReq', SIZE = 100MB, MAXSIZE = UNLIMITED, FILEGROWTH = 100MB )
  alter database  [AuditReq] modify file ( NAME = N'AuditReq_log', SIZE = 100MB , MAXSIZE = UNLIMITED , FILEGROWTH = 100MB )
End
go
USE AuditReq
go
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
  (Select ErrorMsgFormatTemplate=@MsgTemplate) as MsgTemplate
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
Create Or Alter View Dbo.EnumsEtOpt
as
Select *, MsgFichPerduGenerique=PrefixMsgFichPerdu+ ' voir table dbo.LogTraitementAudit'
From 
  (
  Select 
    MatchFichTrc='AuditReq*.xel'
  , BaseFn='AuditReq.Xel'
  , RootAboveDir='D:\_Tmp\'
  , Dir='AuditReq'
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
drop trigger if exists LogonAuditReqTrigger on all server
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
-- DISABLE TRIGGER LogonAuditReqTrigger ON ALL SERVER;
Use master;
DROP TRIGGER IF EXISTS LogonAuditReqTrigger ON ALL SERVER;
IF SUSER_SID('AuditReqUser') IS NOT NULL DROP LOGIN AuditReqUser;
go
Use AuditReq;
IF USER_ID('AuditReqUser') IS NOT NULL DROP USER AuditReqUser;
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
go
CREATE or Alter TRIGGER LogonAuditReqTrigger
ON ALL SERVER WITH EXECUTE AS 'AuditReqUser'
FOR LOGON
AS
BEGIN
  Begin Try

  Insert into AuditReq.dbo.connectionsRecentes
   (LoginName       , Session_id, LoginTime,     client_net_address   , program_name)
  select
    ORIGINAL_LOGIN(), Evi.Spid,   S.Login_Time,  A.client_net_address , S.program_name 
  From 
    (Select EventData=EVENTDATA()) as EvD
    CROSS APPLY (Select Spid=EventData.value('(/EVENT_INSTANCE/SPID)[1]', 'INT')) as Evi
    CROSS APPLY (Select client_net_address=EventData.value('(/EVENT_INSTANCE/ClientHost)[1]', 'NVARCHAR(30)')) as A
    JOIN (select * from master.sys.dm_exec_sessions) as S
    ON S.session_id = Evi.Spid And S.is_user_process=1
  UNION  -- provoque effet du distinct à cause de très rares cas, peu explicables dans la première et seconde requête

  -- quand on démarre, le logon trigger n'enregistre que les nouvelles
  -- mais il faut faire comme s'il avait enregistré les connexions déjà ouvertes
  -- lorsque la table est vide
  select S.login_name, S.session_id, S.login_time, C.client_net_address, S.program_name
  from 
    (Select * From sys.dm_exec_sessions as S Where S.is_user_process=1) as S
    JOIN 
    sys.dm_exec_connections as C
    ON C.session_id = S.session_id
  Where Not Exists (Select * From AuditReq.dbo.connectionsRecentes)
  End Try
  Begin Catch
    THROW;
  End Catch
END;
GO
Use AuditReq;
CREATE USER AuditReqUser For Login AuditReqUser;
GRANT INSERT ON [dbo].[connectionsRecentes] TO AuditReqUser; -- le user dans la BD AuditReq
GRANT SELECT ON Dbo.EnumsEtOpt TO AuditReqUser;
GRANT SELECT ON Dbo.FormatCurrentMsg TO AuditReqUser;
GO
If Exists(Select * From sys.dm_xe_sessions Where name = 'AuditReq')
  ALTER EVENT SESSION AuditReq ON SERVER STATE = STOP;
GO
-- Supprimer la session si elle existe et nettoyer ses fichiers de trace
Declare @Fn nvarchar(260)
Select @Fn=E.PathReadFileTargetPrm From dbo.EnumsEtOpt as E
IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'AuditReq')
Begin
  DROP EVENT SESSION AuditReq ON SERVER;
  Exec master.sys.xp_delete_files @fn
End
go
declare @FullFn sysname; -- création event Session
Select @FullFn=E.TargetFnCreateEvent From Dbo.EnumsEtOpt as e;
-- sp_statement_completed (statement = chaque requete, sql_text le call)
-- sql_stmt_completed (statement = chaque requete, sql_text le lot)
-- pour sql_stmt_completed on peut donc alléger le traitement en omettant sql_text
-- sql_batch_completed (statement = NULL, sql_text le lot)
Declare @Sql Nvarchar(max) =
'
CREATE EVENT SESSION AuditReq ON SERVER
  ADD EVENT sqlserver.sql_statement_completed
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
Exec (@Sql);
go
ALTER EVENT SESSION AuditReq ON SERVER STATE = START;
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
, Program_name sysname NULL
, database_name sysname 
--, sql_batch nvarchar(max)
--, line_number int
, statement nvarchar(max) 
, passe Int 
, file_seq Int
) 
create index iEvent_Time on dbo.AuditComplet(Event_time)
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
  If @@ROWCOUNT = 0 Return

  -- remember this table is always empty. It is just a pipeline
  -- In care there us non-sense attempts of deletes or update (since table is empty)
  -- there is nothing to do, since in both case inserted table is going to be empty.
  Declare @msg nvarchar(4000)

  Begin Try

  Insert into dbo.AuditComplet 
    ( server_principal_name, event_time, Client_net_address
    , session_id, Program_name, database_name
    --, sql_batch
    --, line_number
    , statement, passe, file_seq)
  Select 
    I.server_principal_name, I.event_time, Hc.Client_net_address
  , I.session_id, Hc.Program_name, I.database_name
  --, I.sql_batch
  --, I.Line_number
  , I.statement, I.passe, I.file_seq
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
    , fileSeq=ROW_NUMBER() Over (Order by file_Name)
    , file_name
    , last_offset_done
    , NbTotalFich=COUNT(*) Over (Partition By NULL)
    From
      (
      Select file_name, last_offset_done=MAX(file_offset)
      From Inserted
      Group by file_name 
      ) as files

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
    RAISERROR(@msg,11,1)
  End Catch

End
GO
Create or Alter Proc dbo.CompleterInfoAudit
as
Begin
  Set nocount on

  Begin Try

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
  While (1=1) -- cette proc est prévue pour rouler constamment avec des Waits selon le volume restant à traiter.
  Begin

    -- voir le instead of trigger qui traite Dbo.PipelineDeTraitementFinalDAudit
    -- c'est lui qui ré-initialise aussi le contenu de dbo.evenements traités
    Insert into Dbo.PipelineDeTraitementFinalDAudit
      ( server_principal_name, session_id, event_time, Database_Name
      --, sql_batch
      --, line_number
      , statement, file_name, file_Offset, passe, file_seq)
    Select
      ev.server_principal_name
    , ev.session_id
    , ev.event_time
    , ev.database_name
    --, sql_batch.sql_batch
    --, ev.line_number
    , ev.statement 
    , Ev.file_name
    , ev.file_Offset
    , StartP.passe
    , StartP.file_seq
    From 
      ( -- la fonction sys.fn_xe_file_target_read_file a besoin du dernier fichier lu et l'offset lu
        -- Elle se rend à ce fichier sans parcourir les autres puis se positionne après l'offset lu
        -- pour y poursuivre la suite de la lecture des évènements.

      Select file_name, last_Offset_done, passe, file_seq From dbo.EvenementsTraites Where file_seq = NbTotalFich
      UNION ALL
      -- La fonction sys.fn_xe_file_target_read_file a besoin de ces param au départ, après ça ne devrait plus arriver
      Select NULL, NULL, NULL, NULL Where Not Exists (Select * From dbo.EvenementsTraites)
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
      --, line_number = xEvents.event_data.value('(event/data[@name="line_number"]/value)[1]', 'int') 
      , statement = xEvents.event_data.value('(event/data[@name="statement"]/value)[1]', 'nvarchar(max)') 
      , event_data = xEvents.event_data
      FROM sys.fn_xe_file_target_read_file(E.PathReadFileTargetPrm, NULL, StartP.file_name, StartP.last_Offset_done) as F 
      CROSS APPLY (SELECT CAST(event_data AS XML) AS event_data) AS xEvents
      ) as ev
      --OUTER APPLY 
      --(
      --Select Sql_batch= ev.event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') 
      --Where line_number = 1
      --) as Sql_Batch
    Set @eventsDone = @@ROWCOUNT 

    -- vérifier si j'ai un fichier à traiter que je ne retrouve plus sur disque pcq un évènement
    -- l'aurait détruit.
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
      -- pourquoi dexu plutôt qu'un seul?
      -- il arrive au switch de fichier que le dernier soit écrit et devienne avant dernier
      -- et n'est pas fini de lire. La fonction de lecture va donc se plaindre qu'il manque
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
        -- donc pas dans dbo.evenementstraites non plus pour la même raison.
        -- C'est possible à cause d'un rollover qui se ferait et qui éliminerait un fichier qu'on a vraiment fini de lire
        -- mais comme on ne sait pas si c'est le cas, l'algorithnme de l'élimine pas. 
        -- Il attend qu'il tombe en second à la prochaine lecture. Mais comme le RollOver supprime le fichier
        -- avant qu'on aille relire, sys.fn_xe_file_target_read_file n'en retourne plus la trace. Ici on fait 
        -- ménage "lazy" qui n'en fait qu'un à la fois, et ne touche jamais au dernier présent sur disque
        -- qu'on présume comme appartenant à la trace active.
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
    If @eventsDone=0 Or Not Exists (Select * From Dbo.EvenementsTraites Where NbTotalFich > 1)
      Waitfor Delay '00:00:05' 
    
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
    Where connectSeq > 1 -- connexion passée, parce que connects=1 
      And Not Exists -- si une session d'un utilisateur semble être du passé, on patiente 1 heure pour être sûr qu'elle a été traitée
          (
          Select SESSION_ID 
          from sys.dm_exec_sessions S 
          Where S.Login_Name = Rc.LoginName and S.Session_id= Rc.Session_id      
          ) -- connexion fermée
      And DATEDIFF(hh, LoginTime, GETDATE()) > 1 -- déconnecté depuis 1 heure 

  End -- While forever

  End Try
  Begin Catch
    Declare @msg nvarchar(max)
    Select @msg=Fmt.ErrMsg
    From 
      (Select ErrMsgTemplate From dbo.EnumsEtOpt) as E
      CROSS APPLY dbo.FormatRunTimeMsg (E.ErrMsgTemplate, ERROR_NUMBER (), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE (), ERROR_MESSAGE ()) as Fmt
    RAISERROR(@msg,11,1)
    Insert into dbo.LogTraitementAudit (Msg) values (@msg)
  End Catch
End
go
USE [msdb]
GO

/****** Object:  Job [AuditReq]    Script Date: 2024-06-29 09:23:36 ******/
Begin Try 

  BEGIN TRANSACTION;

  DECLARE @ReturnCode INT = 0

  DECLARE @jobId BINARY(16)
  Select @jobId = job_id From msdb.dbo.sysjobs where name =N'AuditReq'

  If @jobId IS NOT NULL
  Begin
    If exists (Select * From msdb.dbo.sysjobschedules where job_id=@jobId)
    Begin
      EXEC sp_detach_schedule @job_name = N'AuditReq', @schedule_name = N'AuditReqSchedule';
      Exec @ReturnCode =  msdb.dbo.sp_delete_schedule @schedule_name ='AuditReqSchedule'
      IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_delete_schedule ',11,1,@returnCode)
    End
    EXEC @ReturnCode =  msdb.dbo.sp_delete_job @job_name=N'AuditReq'
    IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_delete_schedule ',11,1,@returnCode)
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
		  @on_success_action=1, 
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
    AuditReq.dbo.EnumsEtOpt as E
    CROSS APPLY AuditReq.dbo.FormatCurrentMsg (E.ErrMsgTemplate) as F
  Print @msg
End catch	
', 
		  @database_name=N'AuditReq', 
		  @flags=4
  IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_add_job_Step ',11,1,@returnCode)

  EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
  IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_update_Job ',11,1,@returnCode)

  EXEC @ReturnCode = msdb.dbo.sp_add_schedule 
    @schedule_name=N'AuditReqSchedule',
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
  IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_add_schedule ',11,1,@returnCode)

  EXEC sp_attach_schedule @job_name = N'AuditReq', @schedule_name = N'AuditReqSchedule';

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
    AuditReq.dbo.EnumsEtOpt as E
    CROSS APPLY AuditReq.dbo.FormatCurrentMsg (E.ErrMsgTemplate) as F
  Print @msg
  ROLLBACK
End catch
GO

--Select file_name, last_Offset_done, count(*), MIN (passe), MAX(passe)
--From auditReq.dbo.EvenementsTraitesSuivi with (nolock) 
--group by file_name, last_Offset_done
--order by file_name, last_Offset_done

/*
Select session_id--, sql_batch
, statement 
From auditReq.dbo.AuditComplet with (nolock) 
order by event_time

-- trace pour tests
Select * From AuditReq.dbo.connectionsRecentes 
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
, Hc.program_name
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
  Select TOP 1 Hc.Program_name, Hc.Client_net_address 
  From Auditreq.dbo.connectionsRecentes as Hc
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