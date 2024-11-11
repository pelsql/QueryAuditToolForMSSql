/*
AuditReq Version 2.6.2  Repository https://github.com/pelsql/QueryAuditToolForMSSql
Pour obtenir la version la plus récente ouvrir le lien ci-dessous 
(To obtain the most recent version go to this link below)
https://raw.githubusercontent.com/pelsql/QueryAuditToolForMSSql/main/QueryAuditToolForMSSql.sql
-- -----------------------------------------------------------------------------------
-- AVANT DE DÉMARRER CE SCRIPT AJUSTER LES OPTIONS DE NOM DE FICHIER ET DE RÉPERTOIRE
-- DANS LA VUE DBO.ENUMSETOPT
-- L'installation préserve le data déjà là. Pour un vrai redémarrage, supprimer AuditReq
-- BEFORE RUNNING THIS SCRIPT ADJUST FILE NAME AND DIRECTORY OPTIONS 
-- IN VIEW DBO.ENUMSETOPT
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
If DB_ID('AuditReq') IS NULL -- créer database si absente
Begin 
  CREATE DATABASE AuditReq
  alter DATABASE AuditReq Set recovery FULL
  alter database AuditReq modify file ( NAME = N'AuditReq', SIZE = 100MB, MAXSIZE = UNLIMITED, FILEGROWTH = 100MB )
  alter database AuditReq modify file ( NAME = N'AuditReq_log', SIZE = 100MB , MAXSIZE = UNLIMITED , FILEGROWTH = 100MB )
END
GO
Use AuditReq
GO
Create Or Alter Function dbo.TemplateReplace(@tmp nvarchar(max), @Tag nvarchar(max), @Val nvarchar(max))
Returns Nvarchar(max)
as
Begin
  Return(Select rep=REPLACE(Replace(@tmp, '"', ''''), @Tag, @Val))
End
GO
--------------------------------------------------------------------------------------
-- Some items related to 
Create Or Alter View Dbo.EnumsEtOpt
as
Select 
  MaxFichier
, EC.RootAboveDir, Dir, EC.JobName, RepFichTrc, PathReadFileTargetPrm, TargetFnCreateEvent, RepFich, MatchFichTrc
, EC.EMailForAlert, EC.mailserver_name, EC.SmtpPort, EC.enable_ssl, EC.EmailUserName, EC.EmailPassword 
, EC.PrefixMsgFichPerdu 
, EC.ErrMsgTemplate
, MsgFichPerduGenerique=PrefixMsgFichPerdu+ ' voir table dbo.LogTraitementAudit'
, Actions.*
From 
  (
  Select 
    EspaceDisquePourTraceEnGB=70
  , JobName='AuditReq' -- AJUSTER SELON VOTRE CONVENANCE
  , RootAboveDir='D:\_Tmp\' -- AJUSTER SELON VOTRE ENVIRONNEMENT
  , EMailForAlert='admin@yourDomain.Com' -- AJUSTER SELON VOTRE ENVIRONNEMENT
  , mailserver_name = '127.0.0.1' -- AJUSTER SELON VOTRE ENVIRONNEMENT
  , SmtpPort = 25 -- AJUSTER SELON VOTRE ENVIRONNEMENT
  , enable_ssl = 0 -- AJUSTER SELON VOTRE ENVIRONNEMENT
  , EmailUsername = NULL -- AJUSTER SELON VOTRE ENVIRONNEMENT
  , EmailPassword = NULL -- AJUSTER SELON VOTRE ENVIRONNEMENT
  , PrefixMsgFichPerdu='Fichier audit perdu: '
  , ErrMsgTemplate=
'----------------------------------------------------------------------------------------------
 -- Msg: #ErrMessage#
 -- Error: #ErrNumber# Severity: #ErrSeverity# State: #ErrState##atPos#
 ----------------------------------------------------------------------------------------------'
  , ErrMsgTemplateShort=' Msg: #ErrMessage# Error: #ErrNumber# Severity: #ErrSeverity# State: #ErrState##atPos#'
  ) as EC
  -- Valeur calculées
  CROSS APPLY (Select Dir=JobName) as Dir
  CROSS APPLY (Select RepFich=RootAboveDir+Dir) as RootAboveDir
  CROSS APPLY (Select RepFichTrc=RepFich+'\') as RepFichTrc
  CROSS APPLY (Select MatchFichTrc=JobName+'*.xel') As MatchFichTrc  -- ne pas changer
  CROSS APPLY (Select PathReadFileTargetPrm=RepFichTrc+MatchFichTrc) as PathReadFileTargetPrm
  CROSS APPLY (Select TargetFnCreateEvent=RepFichTrc+JobName+'.Xel') as TargetFnCreateEvent
  CROSS APPLY (Select MaxFichier=Convert(nvarchar,EC.EspaceDisquePourTraceEnGB*1024/40)) as MaxFichier
  CROSS APPLY
  (
  Select 
    TplExSessStop=
'If Exists (Select * From Sys.dm_xe_sessions where name = "AuditReq")
  ALTER EVENT SESSION AuditReq ON SERVER STATE = STOP
Else 
  Print "EVENT SESSION AuditReq is already stopped, so no attempt to Stop"'
  , TplExSessDrop=
'-- If AuditReq Event Session exists, drop it 
If Exists(Select * From sys.server_event_sessions WHERE name = "AuditReq")
  DROP EVENT SESSION AuditReq ON SERVER
Else 
  Print "EVENT SESSION AuditReq does not exists, so no attempt to drop"'
  , TplExSessCreate=
'-- here we don"t test if session status and existence because everything to clear out 
-- previous session would"ve have been generated
-- If AuditReq Event Session doesn"t exists create it
If Exists(Select * From sys.server_event_sessions WHERE name = "AuditReq") 
Begin
  Print "EVENT SESSION AuditReq already exists, so no attempt to create"
  Return
End
CREATE EVENT SESSION AuditReq ON SERVER
  ADD EVENT sqlserver.user_event
  (
    ACTION (package0.event_sequence)
    WHERE [sqlserver].[is_system]=(0) 
      And [sqlserver].[Session_id] > 50 -- process utilisateur
  )
, ADD EVENT sqlserver.rpc_completed
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
      And [sqlserver].[Session_id] > 50 -- process utilisateur
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
      And [sqlserver].[Session_id] > 50 -- process utilisateur
  )
ADD TARGET package0.asynchronous_file_target(
SET 
  filename = "#TargetFnCreateEvent#"
, max_file_size = (40) -- fichier n meg (MB unité par défaut)
-- essayer de repousser au maximum le rollover 
-- puisque la procédure gère elle-même quand ôter les évènements quand elle les a traité
, max_rollover_files = (#MaxFichier#) -- ajusté en fonction du parametre EspaceDisquePourTraceEnGB
)
WITH 
  (
    MAX_MEMORY=40MB
  , EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS
  , MAX_DISPATCH_LATENCY=15 SECONDS 
  , MAX_EVENT_SIZE=40MB
  , MEMORY_PARTITION_MODE=NONE
  , TRACK_CAUSALITY=OFF
  , STARTUP_STATE=ON -- I want the audit live by itself even after server restarts
  )'
  , TplExSessStart =
'
If Not Exists (Select * From Sys.dm_xe_sessions where name = "AuditReq")
  ALTER EVENT SESSION AuditReq ON SERVER STATE = START
Else
  Print "Session AuditReq is already started, so no attempt to start"
'
  ) As tpl
  CROSS APPLY
  (
  Select [STOP], [Drop], [Create], [Start]
  From
    (
    Select Action, Sql
    From 
      (Select StopES='Stop', DropES='Drop', CreateES='Create', StartES='Start') as TagAct
      Cross Apply
      (
      Values (StopES, tpl.TplExSessStop)
           , (DropES, tpl.TplExSessDrop)
           , (CreateES, tpl.TplExSessCreate)
           , (StartES, tpl.TplExSessStart) 
      ) as Tp (action, tp)
      Cross Apply (Select r1=dbo.TemplateReplace(tp, '#TargetFnCreateEvent#', TargetFnCreateEvent) ) as r1
      Cross Apply (Select Sql=dbo.TemplateReplace(r1, '#MaxFichier#', MaxFichier) ) as Sql
    ) as ActionRows
  PIVOT (Max(Sql) For Action IN ([STOP], [DROP], [CREATE], [START])) as PivotTable
  ) as Actions

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
  Raiserror ('Le répertoire configuré dans dbo.EnumsEtOpt %s n''existe pas, veuiller corriger et vous reconnecter', 20, 1, @repfich)
End 
GO
--------------------------------------------------------------------------------------------
-- Si une job existe, la supprimer le temps du remplacement des objets de code
--------------------------------------------------------------------------------------------
DECLARE @ReturnCode INT = 0
DECLARE @jobId BINARY(16)
Declare @JobName sysName
Select @jobname = 'AuditReq'
Select @jobId = job_id From msdb.dbo.sysjobs where name =@JobName

If @jobId IS NOT NULL
Begin
  EXEC @ReturnCode =  msdb.dbo.sp_delete_job @job_name=@JobName
  IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_delete_schedule ',11,1,@returnCode)

  If exists (Select * From msdb.dbo.sysjobschedules where job_id=@jobId)
  Begin
    EXEC msdb.dbo.sp_detach_schedule @job_Name = @JobName, @schedule_name = N'AuditReqAutoRestart';
    Exec @ReturnCode =  msdb.dbo.sp_delete_schedule @schedule_name ='AuditReqAutoStart'
    IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_delete_schedule ',11,1,@returnCode)
  End
End
GO
-- remove any code object from previous version, since all needed code objects are recreated
-- the logon trigger isn't replace here. And Dbo.EnumsEtOpt must be preserved
Declare @Sql nvarchar(max) = ''
Select @Sql=@Sql+Sql
From
  Sys.Objects As Ob
  JOIN 
  (
  Values ('%Procedure%', 'Procedure')  , ('%Function', 'Function')  , ('%View%', 'View')  , ('%Trigger%', 'Trigger')
  ) as T(Islike, ObjTyp)
  ON Ob.Type_Desc Like T.IsLike
  CROSS JOIN (Select Dot='.', CrLf=Nchar(13)+nchar(10)) as const
  CROSS APPLY (Select QName=QUOTENAME(Object_schema_Name(object_id))+'.'+Quotename(name)) as QName
  CROSS APPLY (Select Sql='Drop '+T.ObjTyp+' IF Exists '+QName+CrLf) as Sql
Where QName NOT IN ('[dbo].[EnumsEtOpt]','[dbo].[TemplateReplace]')
Print @Sql  
Exec (@Sql)
GO
Create Or Alter Proc Dbo.EmailSetup
As
Begin
  Set nocount on

  -------------------------------------------------------------
  --  database mail setup for AuditReq
  -------------------------------------------------------------
  If not Exists
     (
     Select *
     From  sys.configurations
     Where name = 'show advanced options' 
       And value_in_use = 1
     )
  Begin
    EXEC sp_configure 'show advanced options', 1
    Reconfigure
  End  

  -- To enable the feature.
  If not Exists
     (
 		  Select *
		   From  sys.configurations
		   Where name = 'Database Mail XPs' 
		     And value_in_use = 1
		   )
  Begin		 
    EXEC sp_configure 'Database Mail XPs', 1
    Reconfigure
  End  

  DECLARE 
    @profile_name sysname
  , @account_name sysname
  , @SMTP_servername sysname
  , @email_address NVARCHAR(128)
  , @display_name NVARCHAR(128)
  , @rv INT
  

  -- Set profil name here
  SET @profile_name = 'AuditReq_EmailProfile';

  SET @account_name = lower(replace(convert(sysname, Serverproperty('servername')), '\', '.'))+'.AuditReq'

  -- Init email account name
  SET @email_address = lower(@account_name+'@AuditReq.com')
  SET @display_name = lower(convert(sysname, Serverproperty('servername'))+' : AuditReq ')
    
  -- if account exists remove it
  If Exists (Select * From msdb.dbo.sysmail_account WHERE name = @account_name )
  Begin
    Exec @rv = msdb.dbo.sysmail_delete_account_sp  @account_name = @account_name
    If @rv <> 0 
    Begin  
      Raiserror('Cannot remove existing database mail account (%s)', 16, 1, @account_Name);
      return
    End
  End;

  -- if profile exists remove it
  If Exists (Select * From msdb.dbo.sysmail_profile WHERE name = @profile_name)
  Begin
    Exec @rv = msdb.dbo.sysmail_delete_profile_sp @profile_name = @profile_name
    If @rv <> 0 
    Begin  
      Raiserror('Cannot remove existing database mail profile (%s)', 16, 1, @profile_name);
      return
    End
  End

  -- Proceed email config in a single tx to leave nothing inconsistent
  Begin transaction ;

  declare @profileId Int

  -- Add the profile
  Exec @rv = msdb.dbo.sysmail_add_profile_sp @profile_name = @profile_name

  If @rv<>0
  Begin
    Raiserror('Failure to create database mail profile (%s).', 16, 1, @profile_Name);
 	  Rollback transaction;
    return
  End;

    -- Grant access to the profile to the DBMailUsers role  
  EXECUTE msdb.dbo.sysmail_add_principalprofile_sp  
      @profile_name = @profile_name,  
      @principal_name = 'public',  
      @is_default = 1 ;

  Declare 
    @SmtpMailServer Sysname
  , @SmtpMailPort Int
  , @SmtpMailEnableSSL Int
  , @EmailServerAccount sysname
  , @EmailServerPassword sysname

  Select 
    @SmtpMailServer = E.mailserver_name 
  , @SmtpMailPort = E.smtpPort
  , @SmtpMailEnableSSL = E.enable_ssl
  , @EmailServerAccount = E.EmailUsername
  , @EmailServerPassword = E.EmailPassword
  From Dbo.EnumsEtOpt as E

  -- Add the account
  Exec @rv = msdb.dbo.sysmail_add_account_sp
    @account_name = @account_name
  , @email_address = @email_address
  , @display_name = @display_name
  , @mailserver_name = @SmtpMailServer
  , @port = @SmtpMailPort
  , @enable_ssl = @SmtpMailEnableSSL
  , @username = @EmailServerAccount
  , @password = @EmailServerPassword;

  If @rv<>0
  Begin
    Raiserror('Failure to create database mail account (%s).', 16, 1, @account_Name) ;
 	  Rollback transaction;
    return
  End

  -- Associate the account with the profile.
  Exec @rv = msdb.dbo.sysmail_add_profileaccount_sp
    @profile_name = @profile_name
  , @account_name = @account_name
  , @sequence_number = 1 ;

  If @rv<>0
  Begin
    Raiserror('Failure when adding account (%s) to profile (%s).', 16, 1, @account_name, @profile_Name) ;
 	  Rollback transaction;
    return
  End;

  COMMIT transaction;
  
  Declare @oper sysname Set @oper = 'AuditReq_Operator'
  If exists(SELECT * FROM msdb.dbo.sysoperators Where name = @oper)
    Exec msdb.dbo.sp_delete_operator @name = @oper;
    
  Declare @email sysname
  Select @email=E.EMailForAlert from Dbo.EnumsEtOpt as E
  Exec msdb.dbo.sp_add_operator @name = @oper, @email_address = @email

  EXEC  Msdb.dbo.sp_send_dbmail
    @profile_name = 'AuditReq_EmailProfile'
  , @recipients = @email
  , @importance = 'High'
  , @subject = 'AuditReq Email setup completed'
  , @body = 'Test email for Audit Email Setup'
  , @body_format = 'HTML'

End -- dbo.EmailSetup
GO
Exec dbo.EmailSetup
GO
CREATE OR ALTER PROCEDURE dbo.SendEmail @msg NVARCHAR(MAX)
AS
BEGIN
  Declare @profile_name SysName;
  Declare @email_address SysName;
  Select @profile_name = 'AuditReq_EmailProfile', @email_address=E.EMailForAlert From AuditReq.dbo.EnumsEtOpt as E

  Exec dbo.sp_executeSql
    N'
    EXEC  Msdb.dbo.sp_send_dbmail
      @profile_name = @profile_name
    , @recipients = @email_Address
    , @importance = ''High''
    , @subject = ''AuditReq : Audit stoppé, problème à investiguer dans l''''audit des requêtes''
    , @body = @msg
    , @body_format = ''HTML''
    '
  , N'@profile_name sysname, @email_Address sysname, @msg NVARCHAR(MAX)'
  , @profile_Name
  , @Email_address
  , @Msg
END
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
GO
Use AuditReq
DROP TRIGGER IF EXISTS LogonAuditReqTrigger ON ALL SERVER;
IF USER_ID('AuditReqUser') IS NOT NULL DROP USER AuditReqUser;
go
IF SUSER_SID('AuditReqUser') IS NOT NULL DROP LOGIN AuditReqUser;
go
USE MASTER
declare @unknownPwd nvarchar(100) = convert(nvarchar(400), HASHBYTES('SHA1', convert(nvarchar(100),newid())), 2)
Exec
(
'
create login AuditReqUser 
With Password = '''+@unknownPwd+'''
   , DEFAULT_DATABASE = AuditReq, DEFAULT_LANGUAGE=US_ENGLISH
   , CHECK_EXPIRATION = OFF, CHECK_POLICY = OFF
'
)
GRANT VIEW SERVER STATE TO [AuditReqUser];
GRANT ALTER TRACE TO [AuditReqUser];
Go
Use AuditReq;
CREATE USER AuditReqUser For Login AuditReqUser;
GO
GRANT SELECT ON dbo.FormatCurrentMsg TO AuditReqUser; -- Utiles pour former msg erreur
GO
GRANT SELECT ON dbo.EnumsEtOpt TO AuditReqUser; -- Utiles pour former msg erreur
GO
-- login trigger to keep track of logins, and extended session running at logon (by its create time)
CREATE or Alter TRIGGER LogonAuditReqTrigger 
ON ALL SERVER WITH EXECUTE AS 'AuditReqUser'
FOR LOGON
AS
BEGIN
  -- By experience avoid at all costs direct reference to EXTERNAL USER OBJECTS in this trigger
  -- if they are missing, they cause error, and this type of error means locking out everybody
  -- from login. It is possible to refer to external user objects through dynamic execution
  -- which allow to catch error.
  
  DECLARE @JEventDataBinary Varbinary(8000);
  Begin Try
    Select @JEventDataBinary = JEventDataBinary
    From 
      (
      Select 
        EventData=EVENTDATA() -- has nothing to do with tables below
      , ExtendedSessionCreateTime
      From 
        (
        -- if session isn't alive no data is produced
        select ExtendedSessionCreateTime=create_time -- to make unique event_sequence by session
        From Sys.dm_xe_sessions 
        Where name = 'AuditReq'
        ) as ExSess
      ) as EvD
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
        , EVd.ExtendedSessionCreateTime 
        For Json PATH
        )
      ) as JEventData
      CROSS APPLY (Select JEventDataBinary=CAST(JEventData as Varbinary(8000))) as JEventDataBinary

    -- Event ID (must be between 82 and 91), don't send events if event session isn't started.
    -- see comment above : if session isn't alive no data is produced, so here @@rowcount is 0
    If @@ROWCOUNT > 0
      EXEC sp_trace_generateevent @eventid = 82, @userinfo = N'LoginTrace', @UserData=@JEventDataBinary

  End Try
  Begin Catch
    -- en état d'erreur on ne peut écrire dans aucune table, car la transaction va s'annuler quand même
    -- le mieux qu'on peut faire est de formatter l'erreur qui est redirigée dans le log de SQL Server
    Declare @msg nvarchar(4000) 
    Select @msg = 'Error in Logon trigger: LogonAuditReqTrigger'+nchar(10)+ErrMsg 
    From
      (Select ErrorMsgFormatTemplate=
'----------------------------------------------------------------------------------
Error in Logon trigger: LogonAuditReqTrigger
Msg: #ErrMessage#
Error: #ErrNumber# Severity: #ErrSeverity# State: #ErrState##atPos#
-----------------------------------------------------------------------------------') 
      as ErrorMsgFormatTemplate
      CROSS APPLY (Select ErrMessage=error_message()) as ErrMessage
      CROSS APPLY (SeLect ErrNumber=error_number()) as ErrNumber
      CROSS APPLY (SeLect ErrSeverity=error_severity()) as ErrSeverity
      CROSS APPLY (SeLect ErrState=error_state()) as ErrState
      CROSS APPLY (SeLect ErrLine=error_line()) as ErrLine
      CROSS APPLY (SeLect ErrProcedure=error_procedure()) as vStdErrProcedure
      Cross Apply (Select FmtErrMsg0=Replace(ErrorMsgFormatTemplate, '#ErrMessage#', ErrMessage) ) as FmtStdErrMsg0
      Cross Apply (Select FmtErrMsg1=Replace(FmtErrMsg0, '#ErrNumber#', CAST(ErrNumber as nvarchar)) ) as FmtErrMsg1
      Cross Apply (Select FmtErrMsg2=Replace(FmtErrMsg1, '#ErrSeverity#', CAST(ErrSeverity as nvarchar)) ) as FmtErrMsg2
      Cross Apply (Select FmtErrMsg3=Replace(FmtErrMsg2, '#ErrState#', CAST(ErrState as nvarchar)) ) as FmtErrMsg3
      Cross Apply (Select AtPos0=ISNULL(' at Line:'+CAST(ErrLine as nvarchar), '') ) as vAtPos0
      Cross Apply (Select AtPos=atPos0+ISNULL(' in Sql Module:'+ErrProcedure,'')) as atPos
      Cross Apply (Select ErrMsg=Replace(FmtErrMsg3, '#atPos#', atPos) ) as FmtErrMsg
    Print @Msg
    Exec ('DISABLE TRIGGER LogonAuditReqTrigger ON ALL Server')
    --Exec dbo.SendEmail @Msg='AuditReq: Logon trigger detected an error during execution and has automatically disabled itself.'
  End Catch
END;
GO
Declare @Sql nvarchar(max)
Select @Sql=[Stop] From dbo.EnumsEtOpt
Print @Sql
Exec (@Sql)

Select @Sql=[Drop] From dbo.EnumsEtOpt
Print @Sql
Exec (@Sql)

Select @Sql=[Create] From dbo.EnumsEtOpt
Print @Sql
Exec (@Sql)

Select @Sql=[Start] From dbo.EnumsEtOpt
Print @Sql
Exec (@Sql)
go
USE AuditReq
GO
-- remove obsolete object
If Object_id('dbo.SeqExtraction') IS NOT NULL Drop Sequence dbo.SeqExtraction
GO
-- obsolete data to remove from previous versions
Drop table if exists dbo.EvenementsTraites
-- obsolete data to remove from previous versions

-- upgrade To 2.50, after upgrade remove this code since only one customer use it
If INDEXPROPERTY(Object_id('dbo.EvenementsTraitesSuivi'), 'iPasseFileName', 'isClustered') IS NOT NULL
  Drop Index iPasseFileName On dbo.EvenementsTraitesSuivi
If COL_LENGTH ('dbo.EvenementsTraitesSuivi', 'NbTotalFich') IS NOT NULL 
  ALTER Table dbo.EvenementsTraitesSuivi Drop Column NbTotalFich
If COL_LENGTH ('dbo.EvenementsTraitesSuivi', 'Passe') IS NOT NULL 
  ALTER Table dbo.EvenementsTraitesSuivi Drop Column Passe
If COL_LENGTH ('dbo.EvenementsTraitesSuivi', 'File_Seq') IS NOT NULL 
  ALTER Table dbo.EvenementsTraitesSuivi Drop Column File_Seq
--default values for something only managed from version 2.5
If COL_LENGTH ('dbo.EvenementsTraitesSuivi', 'ExtEvSessCreateTime') IS NULL And OBJECT_ID('dbo.EvenementsTraitesSuivi') IS NOT NULL
Begin
  ALTER Table dbo.EvenementsTraitesSuivi Add ExtEvSessCreateTime Datetime Not NULL Default '20000101'
End 
-- -----------------------------------------------------------------------------------------------
-- On se base sur le Event_sequence des traces pour savoir si une session a été redémarrée.
-- Le event_sequence d'un fichier croît toujours, car cela vient d'une extended session active.
-- Au Shutdown du serveur, il y a un flush d'évènements au fichier courant, donc on devra
-- continuer à le lire, car on n'a pu le lire en entier.

-- La table dbo.EvenementsTraitesSuivi nous permet de faire ce premier suivi.

-- Après redémarrage, si extended session est auto-restart, ou si elle est démarrée manuellement
-- un nouveau fichier est crée est l'Event_Sequence redémarre à 1.
-- Donc si le premier résultat retourné a un event_sequence à 1, on peut incrémenter le ExtEvSessSeq et ajuster
-- ExtEvSessCreateTime à la date de création de la session.
--
-- ExtEvSessSeq sert à distinguer les event_Sequence de deux sessions différentes.
-- Cela a son importance pour la gestion des sessions périmées, car event_sequence peut redémarrer à 1 dans le temps
-- ----------------------------------------------------------------------------------------------------
If Object_id('dbo.EvenementsTraitesSuivi') IS NULL
Begin
  Create table dbo.EvenementsTraitesSuivi
  (
    file_name nvarchar(260) 
  , last_Offset_done bigint 
  , dateSuivi Datetime2 Default SYSDATETIME()
  , ExtEvSessCreateTime Datetime NULL
  )
  create index iDateSuivi on dbo.EvenementsTraitesSuivi(dateSuivi)
End
If INDEXPROPERTY(Object_id('dbo.EvenementsTraitesSuivi'), 'iDateSuivi', 'isClustered') IS NULL
  create index iDateSuivi on dbo.EvenementsTraitesSuivi (dateSuivi Desc) 

-- cette table permet de conserver les connexions 

If COL_LENGTH ('dbo.HistoriqueConnexions', 'ExtendedSessionCreateTime') IS NULL 
  And OBJECT_ID('dbo.HistoriqueConnexions') IS NOT NULL
Begin
  ALTER Table dbo.HistoriqueConnexions Add ExtendedSessionCreateTime Datetime
  -- the trace is already running
  Exec
  (
  '
  Update dbo.HistoriqueConnexions 
  Set ExtendedSessionCreateTime=Create_time
  From (Select create_time From Sys.dm_xe_sessions where name = ''AuditReq'') as tx
  '
  )
End 

If INDEXPROPERTY(object_id('dbo.HistoriqueConnexions'), 'PK_HistoriqueConnexions', 'IsClustered') IS NOT NULL
  Alter table dbo.HistoriqueConnexions Drop constraint PK_HistoriqueConnexions

If Object_Id('dbo.HistoriqueConnexions') IS NULL
Begin
  CREATE TABLE dbo.HistoriqueConnexions
  (
	   LoginName nvarchar(256) NOT NULL
  , Session_id smallint NOT NULL
  , LoginTime datetime2(7)  NOT NULL
  , Client_net_address nvarchar(48) NULL
  , client_app_name sysname
  , ExtendedSessionCreateTime Datetime Not NULL 
  , event_sequence BigInt Not NULL
  ) 
End
If INDEXPROPERTY(object_id('dbo.HistoriqueConnexions'), 'iHistoriqueConnexions', 'IsClustered') IS NULL
  Create clustered index iHistoriqueConnexions 
  On dbo.HistoriqueConnexions (Session_id, ExtendedSessionCreateTime desc, Event_Sequence Desc, loginTime)
If INDEXPROPERTY(object_id('dbo.HistoriqueConnexions'), 'iExtendedSession', 'IsClustered') IS NULL
  Create index iExtendedSession
  On dbo.HistoriqueConnexions (ExtendedSessionCreateTime desc)
GO

-- obsolete data to remove from previous versions
If INDEXPROPERTY(object_id('dbo.AuditComplet'), 'iEvent_time', 'IsUnique') IS NOT NULL
  Drop index iEvent_time On dbo.AuditComplet
If COL_LENGTH ('dbo.AuditComplet', 'file_seq') IS NOT NULL 
  ALTER Table dbo.AuditComplet Drop Column file_seq
If COL_LENGTH ('dbo.AuditComplet', 'passe') IS NOT NULL 
  ALTER Table dbo.AuditComplet Drop Column passe
If COL_LENGTH ('dbo.AuditComplet', 'ExtendedSessionCreateTime') IS NULL 
  And OBJECT_ID('dbo.AuditComplet') IS NOT NULL
  ALTER Table dbo.AuditComplet Add ExtendedSessionCreateTime Datetime
  
If Object_id('dbo.AuditComplet') IS NULL
Begin
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
  -- cette colonne combinée à event_sequence garantit une clé unique pour l'ordre des evènements 
  -- car event_sequence est remis à zéro lors du rédémarrage d'une session de trace.
  , ExtendedSessionCreateTime DateTime
  , event_sequence BigInt 
  ) 
End
If INDEXPROPERTY(object_id('dbo.AuditComplet'), 'iSeqEvents', 'IsUnique') IS NULL
  Create Index iSeqEvents On dbo.AuditComplet (event_time, ExtendedSessionCreateTime, Event_Sequence)

If INDEXPROPERTY(object_id('dbo.AuditComplet'), 'iUserTime', 'IsUnique') IS NULL
  Create Index iUserTime On dbo.AuditComplet (server_principal_name, event_time)

If Object_id('dbo.LogTraitementAudit') IS NULL
Begin
  CREATE TABLE dbo.LogTraitementAudit
  (
    MsgDate datetime2 default SYSDATETIME()
  , Msg nvarchar(max) NULL
  ) 
  create index iMsgDate on dbo.LogTraitementAudit(MsgDate)
End
GO
--
-- Selon edition aller chercher meilleur option de compression
-- Compresser seulement les tables du schema .dbo
-- 
Set Nocount on
Declare @Sql nvarchar(max)=''
select @Sql=@Sql+Sql+NCHAR(10) -- façon cheap de concatener toutes les requetes
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
  CROSS APPLY 
  (
  select Tab=OBJECT_SCHEMA_NAME(object_id)+Dot+name, object_id
  From sys.tables
  Where OBJECT_SCHEMA_NAME(object_id)='dbo'
  ) as Tab
  CROSS APPLY (Select Sql0=Replace(CompressTemplate, '#Tab#', Tab) ) as Sql0
  CROSS APPLY (Select Sql=Replace(sql0, '#Opt#', Opt) ) as Sql
  CROSS APPLY -- remove those who are already compressed
  (
  SELECT 
    p.data_compression_desc AS CompressionType
  FROM
    sys.partitions AS p 
    JOIN sys.indexes AS i 
    ON  p.object_id = i.object_id 
    AND p.index_id = i.index_id 
    AND (I.index_id=0 Or i.type_desc = 'CLUSTERED') -- index 0 est assimilé à la table si c'est un Heap, sinon c'est la clustered (1)
  Where 
      p.object_id = Tab.object_id 
  And p.data_compression_desc = 'NONE'
  ) as ACompresser
Print @Sql
Exec (@Sql)
GO
-- --------------------------------------------------------------------------------
-- Cette fonction retourne l'information sur un fichier s'il existe
-- dont les parties de son nom
-- --------------------------------------------------------------------------------
USE AuditReq
GO
Create Or Alter Function dbo.FileInfo (@fullPathAndName sysname)
Returns Table
as
Return
  Select *
  From
    (Select fullPathAndName=@fullPathAndName) as FullPathAndName
    CROSS APPLY (Select posBS=len(fullPathAndName)-CHARINDEX('\', Reverse(fullPathAndName))+1) as PosBS
    CROSS APPLY (Select FileNamePlain=STUFF(fullPathAndName, 1, posBs, '')) as FileNamePlain
    CROSS APPLY (Select Directory=Substring(fullPathAndName, 1, posBs)) as Directory
    OUTER APPLY (Select * From sys.dm_os_enumerate_filesystem(Directory, FileNamePlain)) as Info
    OUTER APPLY (Select Existing=1 Where Info.full_filesystem_path IS NOT NULL) as Existing
-- Select * From dbo.FileInfo ('D:\_Tmp\AuditReq\AuditReq_0_133728749432040000.Xel')
GO
-- --------------------------------------------------------------------------------
-- Cette fonction indique quel est le premier fichier qui n'est plus le dernier 
-- --------------------------------------------------------------------------------
Create Or Alter Function dbo.FichierLiberable ()
Returns Table
as
Return
  --
  -- Cette fonction retourne le fichier qui est le premier que s'il existe d'autres fichiers de trace après
  -- car on ne supprime jamais le dernier fichier de trace
  --
  Select full_filesystem_path, Ordre, nbfich 
  From
    (
    Select 
      Dir.full_filesystem_path
    , ordre=row_number() Over (order by Dir.full_filesystem_path)
    , nbFich=count(*) Over (Partition By NULL)
    FROM 
      dbo.EnumsEtOpt as Opt
      CROSS APPLY sys.dm_os_enumerate_filesystem(Opt.RepFichTrc, MatchFichTrc) as Dir -- attention recursion possible!
    Where 
      Dir.full_filesystem_path Like RepFichTrc+'AuditReq[_][0-9]%' -- pour ôter résultats de récursion possible
    ) as FichierEnOrdre
  Where Ordre=1 And nbFich>1 -- retourne ce premier fichier seulement s'il y en a d'autres
GO
--------------------------------------------------------------------------------------------------------------
--
-- Cette fonction qui était un morceau de code intégral de la procedure dbo.CompleterAudit
-- a été isolé de la requête qui insère dans #Tmp afin de s'en servir aussi comme moyen de 
-- faire de l'examen des évènements enregistrés sans perturber l'état du traitement en cours
-- Les paramètres sont utiisés seulement lorsque on veut explorer les évènements pour faire des tests,
-- sinon la fonction suit continue à partir des derniers évènements de dbo.EvenementsTraitesSuivi 
-- 
--------------------------------------------------------------------------------------------------------------
Create Or Alter Function dbo.GetNextEvents (@fileName Nvarchar(256), @lastOffsetDone BigInt)
Returns Table
as
Return
  Select 
    ev.file_name
  , ev.file_Offset
  , Event_name
  , Event_Sequence 
  , Ev.Event_time
  , ev.event_data
  from
    (Select * From dbo.EnumsEtOpt) AS opt
    OUTER APPLY
    (
    -- on est chanceux que sys.fn_xe_file_target_read_file donne les évènements en ordre avec les Offset
    -- on a vérifié par des tests que lorsqu'un les evènements d'offset sont lu, il ne s'y en ajoute plus
    -- cet Outer Apply me confirme si oui on non on trouve encore quelque chose à lire dans le fichier
    -- donc qu'après le dernier offset, on a trouvé un nouvel offset.
    Select E.file_name, DernierOffsetConfirme=E.last_Offset_done
    From 
      (
      Select Top 1 File_Name, last_Offset_done From dbo.EvenementsTraitesSuivi Where @fileName Is NULL Order by dateSuivi desc
      UNION ALL
      Select File_Name=@fileName, last_Offset_done=@lastOffsetDone Where @fileName IS NOT NULL
      ) As E -- c'est une table à rangée unique
      CROSS APPLY (Select * From dbo.FileInfo(E.file_name) Where Existing=1) as Existing -- file must exists
      -- limite à une rangée, parce qu'on veut juste confirmer existance du fichier et offset
      cross apply (Select top 1 * From sys.fn_xe_file_target_read_file(E.file_name, NULL, E.file_name, E.last_Offset_done)) as F -- otherwise the is an error here
    ) as SuiteMemeFich
    CROSS APPLY
    ( 
    -- cet UNION ALL fait faire un switch de valeurs retournées
    -- la première requête retourne le fichier existant avec le dernier offset
    --    si on trouve un nouvel offset dans le dernier fichier lu
    -- la seconde partie retourne le prochain fichier
    --    a condition qu'il y ait un prochain fichier et que le dernier fichier lu (outer apply) 
    --    n'a rien retourné. 

    -- Si les deux requête de l'union ne retournent rien, le cross apply (alias startP) qui 
    -- l'englobe ne retourne rien, et rien ne sera inséré dans #Tmp

    Select -- si nouvel offset existe après
      SuiteMemeFich.file_name
    , FilenamePourOffset=SuiteMemeFich.file_name 
    , SuiteMemeFich.DernierOffsetConfirme -- NULL fera la job
    Where SuiteMemeFich.file_name is NOT NULL

    UNION ALL 
    Select Suivant.file_name, FilenamePourOffset=NULL, DernierOffsetConfirme=NULL
    From
      -- S'il n'y a plus rien de trouvé dans le fichier precedent, sinon arrêt de la requête
      (Select FichierAvantTermine=1 Where SuiteMemeFich.file_name is NULL) as FichierAvantTermine 
      CROSS JOIN
      (
      Select top 1 File_Name=Dir.full_filesystem_path 
      FROM 
        ( 
        -- si il n'y a pas de dernier fichier dans dbo.EvenementsTraites (comme quand la procédure part)
        -- on part au début de la liste de fichiers.
        Select file_name='' Where Not exists (Select * From dbo.EvenementsTraitesSuivi) -- point de départ 
        UNION ALL
        -- s'il y a quelque chose, on prend le dernier pour trouver plus loin ce qui suit sur disque
        Select top 1 file_name From dbo.EvenementsTraitesSuivi Order by dateSuivi desc -- table à rangée unique
        ) as ET
        -- Obtenir les fichiers qui suivent, attention! sys.dm_os_enumerate_filesystem peut récurser dans un sous-répertoire
        -- par exemple comme quand on met un sous-répertoire de fichiers de trace dans le répertoire courant
        -- on évite la situation en s'assurant par le Where que le résultat est du même répertoire pour le type de fichier cherché
        JOIN sys.dm_os_enumerate_filesystem(Opt.RepFichTrc, Opt.MatchFichTrc) as Dir 
        ON  
            Dir.full_filesystem_path > ET.file_name -- premier fichier ou prochain (voir commentaires e ET
        And Dir.full_filesystem_path Like RepFichTrc+'AuditReq[_][0-9]%' -- empêcher résultats de récursion, si survient 
      Order By Dir.full_filesystem_path 
      ) as Suivant
    ) as StartP -- point de départ pour prochain jeu d'évènements
    CROSS APPLY -- on va chercher les évènements et on a besoin en plus du event_data, le nom d'évenements et leur sequence
    (
    Select event_data = xEvents.event_data, Event_name, Event_Sequence, F.file_name, F.file_offset, Event_time
    FROM 
      sys.fn_xe_file_target_read_file(StartP.file_name, NULL, StartP.FilenamePourOffset, StartP.DernierOffsetConfirme) as F 
      CROSS APPLY (SELECT CAST(event_data AS XML) AS event_data) AS xEvents
      CROSS APPLY (Select event_name = xEvents.event_data.value('(event/@name)[1]', 'varchar(50)')) as Event_name
      CROSS APPLY (Select Event_Sequence = xEvents.event_data.value('(event/action[@name="event_sequence"]/value)[1]', 'bigint')) as Event_Sequence
      CROSS APPLY (select event_time = xEvents.event_data.value('(event/@timestamp)[1]', 'datetime2(7)') AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time') as Event_time
    ) as ev
-----------------------------------------------------------------------------------------------------
-- Cette procedure fait joindre l'info sur les connexions avec les requêtes correspondantes
-- Elle supprime aussi elle-même les fichiers traités.
-- Cela est fait dans une boucle, un fichier à la fois pour éviter des surcharges de tempDb
-----------------------------------------------------------------------------------------------------
go
--------------------------------------------------------------------------------------------------------------
--
-- Cette fonction qui était un morceau de code intégral dse la procedure dbo.CompleterAudit
-- a été isolé de la requête qui insère dans #Tmp afin de s'en servir aussi comme moyen de 
-- pour extraire l'information des évènements enregistrés sans perturber l'état du traitement en cours
-- Les paramètres sont utiisés seulement lorsque on veut explorer les évènements pour faire des tests
-- 
--------------------------------------------------------------------------------------------------------------
Create Or Alter Function dbo.ExtractConnectionInfoFromEvents (@event_data as Xml)
Returns Table
as
Return
Select J.*, UserData, UserDataBin, UserDataHexString, event_data
From 
  (Select event_data=@event_data) as Prm 
  CROSS APPLY (SELECT UserDataHexString=event_data.value('(event/data[@name="user_data"]/value)[1]', 'nvarchar(max)')) AS UserDataHexString
  -- conversion en hexadecimal
  CROSS APPLY (SELECT UserDataBin = CONVERT(VARBINARY(MAX), '0x'+UserDataHexString, 1)) as UserDataBin
  -- reconversion de l'hexadecimal en texte pour en tirer le contenu
  CROSS APPLY (Select UserData=CAST(UserDataBin as NVARCHAR(4000))) as UserData
  -- extraction texte JSON du contenu
  Outer APPLY
  (
  SELECT 
    LoginName=JSON_VALUE(value, '$.LoginName') 
  , LoginTime=JSON_VALUE(value, '$.LoginTime')
  , Session_id=JSON_VALUE(value, '$.spid')
  , client_net_address=JSON_VALUE(value, '$.client_net_address')
  , client_app_name=JSON_VALUE(value, '$.client_app_name') 
  , ExtendedSessionCreateTime=JSON_VALUE(value, '$.ExtendedSessionCreateTime') 
  FROM OPENJSON(UserData)
  -- validation for JSON
  ) as J
GO
Create or Alter Proc dbo.CompleterInfoAudit
as
Begin
  Set nocount on

  declare @CatchPassThroughMsgInTx table (msg nvarchar(max))

  Begin Try

  Drop table if Exists #RcCount
  Create table #RcCount (name sysname, cnt bigint)
  
  Drop table if Exists #tmp
  Create table #tmp 
  (
    file_name nvarchar(260) NOT NULL -- selon donc sys.fn_xe_file_target_read_file
  ,	file_Offset bigint NOT NULL -- selon donc sys.fn_xe_file_target_read_file
  , event_name nvarchar(128)
  , Event_Sequence BigInt
  , event_time datetimeoffset(7) NULL
  , event_data XML NULL
  )

  While (1=1) -- cette proc est prévue pour rouler constamment avec des Waits selon le volume restant à traiter.
  Begin

    -- c'est comme plus performant de faire ainsi en 2 step que direct 
    --todo: si on mettait une valeur générée d'une sequence on aurait une sequence absolue
    -- sur laquelle on peut se fier pour classer connexions et statement.
    Truncate table #tmp
    Insert into #tmp
    Select 
      ev.file_name
    , ev.file_Offset
    , ev.Event_name
    , ev.Event_Sequence 
    , Ev.Event_time
    , ev.event_data
    From 
      dbo.GetNextEvents(null, null) as Ev -- le cours normal de l'avancement est basé sur dbo.evenementsTraitesSuivi, d'où les paramètres NULL
    Option (maxDop 1)
--    select * from #tmp
    -- après un traitement précédent si on relit trop vite, on va attendre après des évènements dans le même fichier
    -- et on peut en trouver trop peu ce qui va créer plus d'entrées dans dbo.evenementsTraitesSuivi
    -- et le boucle va se faire trop souvent pour rien. On attend donc un peu, et aussi l'insertion des évènements
    -- dans l'audit va faire attendre plus longtemps s'il n'y pas eu beaucoup d'évènements comme dans une période creuse.
    -- si on est 
    If @@rowcount=0 
    Begin
      -- @@rowcount=0 est la PREUVE QUE:
      -- Il n'y a pas de nouvel évènement (rien dans le fichier de neuf et en même temps pas de nouveau fichier)
      -- on fera un nouvel essai dans 2 secondes
      Waitfor Delay '00:00:05' -- pas de nouveaux evenements et pas de fichiers a detruire.
      Continue 
    End

    -- Insérer dans la table d'historique des logins les événements de connexion
    -- qui sont des événements utilisateurs déclenchés par le trigger LogonAuditReqTrigger.

    -- LogonAuditReqTrigger trigger utilise sp_trace_generateevent qui demande de passer l'information en varbinary et on doit
    -- reconvertir ce userdata en texte. Comme les extended events expriment leur output en XML
    -- XML représente ce varbinary comme une chaîne texte exprimant sa valeur hexadécimale

    -- Une fois le détail de ce que LogonAuditTriggerest récupérer on peut insérer ces informations de connexions
    -- dans l'historique des connexions.

    -- L'utilisation de DISTINCT est nécessaire à l'insertion en raison de cas rares où la jointure avec sys.dm_exec_connections
    -- retourne plus d'une ligne pour un même session_id, car causé par des doublons session_id dans sys.dm_exec_connections.

    -- On ne prend pas le event_time des fichiers de trace qui est moint précis (tronqué au delà du millième de seconde)
    -- On garde le event_sequence qui est plus fiable pour trancher

    BEGIN TRANSACTION -- keep coherent changes that recover info from event files and ongoing steps of processing

    -- extraire tous les évènements de type User_event qui viennent du logon trigger et contiennent de l'information de login
    -- Le fait qu'elles se trouvent dans les évènements garanti qu'on a quelque chose de relativement synchrone par 
    -- rapport aux évènements.
    Insert Into dbo.HistoriqueConnexions
      (LoginName, Session_id, LoginTime, client_net_address, client_app_name, ExtendedSessionCreateTime,  Event_Sequence)
    Select Distinct J.LoginName, J.Session_id, J.LoginTime, J.client_net_address , J.client_app_name, J.ExtendedSessionCreateTime, Tmp.Event_Sequence
    From 
      (Select * from #Tmp as Tmp Where Tmp.event_name = 'user_event') as Tmp
      CROSS APPLY dbo.ExtractConnectionInfoFromEvents (Tmp.Event_Data) as J
    -- Ajout de résilience : Si le processus de traitement des événements est interrompu,
    -- et que les événements de login doivent être retraités, ce Not Exists permet d'éviter les doublons.
    Where
      Not Exists -- Si le processus a planté, et qu'on traite à nouveau les évènements de login
                 -- ce bout de code empêchera l'insertion de duplicate
      (
      Select * 
      From dbo.HistoriqueConnexions CE 
      Where 
            CE.Session_id = J.Session_id 
        And CE.ExtendedSessionCreateTime = J.ExtendedSessionCreateTime
        And CE.event_sequence = Tmp.Event_Sequence
      )            
    --select * from dbo.HistoriqueConnexions order by Session_id, ExtendedSessionCreateTime, event_sequence, loginTime

    -- On garde une trace d'où en est rendu dans le fichier, son dernier offset, et les informations de session associées
    -- on peut reprendre un traitement avec des fichiers d'évènement restaurés, à condition qu'on retraite tout en ordre
    -- sinon on risque de perdre des informations de connexion.
    
    Insert into dbo.EvenementsTraitesSuivi (file_name, last_Offset_done, ExtEvSessCreateTime)
    Select 
      EvInfo.file_name, EvInfo.last_offset_done, ExtEvInfo.ExtendedSessionCreateTime
    From 
      ( 
      -- In working with a single file at the time, create_Time of its extended event session is all the same because a file 
      -- can't belong to more that a single session
      -- Dbo.HistoriqueConnexions contains data that comes from Logon trigger generated events, and it doesn't generate events
      -- if an extended session isn't active (to have coherence with other events)
      Select Top 1 ExtendedSessionCreateTime From Dbo.HistoriqueConnexions Order By ExtendedSessionCreateTime Desc
      ) as ExtEvInfo
      CROSS APPLY -- get last offset of the file to continue from there (the way extended events files are read, there is only one file done at the time)
      (
      Select file_name, last_offset_done=MAX(file_offset)
      From #Tmp
      Group by file_name     
      ) as EvInfo
    Where 
      not Exists 
      (
      Select * 
      From dbo.EvenementsTraitesSuivi ES 
      Where Es.file_name = EvInfo.file_name 
        And Es.last_offset_done = EvInfo.Last_offset_done
      )
    -- Select * From dbo.EvenementsTraitesSuivi order by datesuivi desc

    declare @DebutPourProfiler nvarchar(max)
    Select @DebutPourProfiler  = 'Declare @x sysname; set @x='''+file_name+' '+str(file_offset)+''''
    From (Select top 1 file_name, file_offset from #Tmp order by file_name desc, file_offset desc) as x
    Exec (@DebutPourProfiler )

    Delete #RcCount Where name = 'insertAuditComplet' 
    Insert into dbo.AuditComplet 
    (
      server_principal_name
    , session_id
    , event_time
    , ExtendedSessionCreateTime
    , event_sequence
    , database_name
    , Client_net_address
    , client_app_name
      --, sql_batch
      --, line_number
    , statement
    )
    SELECT 
      R.server_principal_name
    , R.session_id
    , R.event_time
    , R.ExtendedSessionCreateTime
    , R.event_sequence
    , RC.database_name
    , Client_net_address.Client_net_address
    , client_app_name.client_app_name
    , R.statement 
      --, sql_batch
      --, line_number
    From
      (
      Select 
        server_principal_name = Tmp.event_data.value('(event/action[@name="server_principal_name"]/value)[1]', 'varchar(50)')
      , session_id = Tmp.event_data.value('(event/action[@name="session_id"]/value)[1]', 'int')
      , ExtEvInfo.ExtendedSessionCreateTime
      , Tmp.event_time 
      , Tmp.Event_Sequence
      , database_name = Tmp.event_data.value('(event/action[@name="database_name"]/value)[1]', 'varchar(50)')
      -- voir commentaire si on veut tracer les instructions des modules
      --, line_number = Tmp.event_data.value('(event/data[@name="line_number"]/value)[1]', 'int') 
      , statement = Tmp.event_data.value('(event/data[@name="statement"]/value)[1]', 'nvarchar(max)') 
      From 
        (Select * from #Tmp as Tmp Where Tmp.event_name <> 'user_event') as Tmp
        CROSS JOIN
        ( 
        -- In working with a single file at the time, create_Time of its extended event session is all the same because a file 
        -- can't belong to more that a single session
        Select Top 1 ExtendedSessionCreateTime From Dbo.HistoriqueConnexions Order By ExtendedSessionCreateTime Desc
        ) as ExtEvInfo
      ) as R
      CROSS APPLY (Select Database_Name=ISNULL(R.database_name, 'nom de base de données absent')) as RC
      -- Un même login peut se connecter et se reconnecter avec un numéro de session différent
      -- mais ce qu'on cherche c'est le login avec le même session_id
      -- qui a la sequence la plus proche dans les évènements de requête
      -- exemple 
      -- on un login de session_id=500 avec event_Sequence=130 pour fichier 3
      -- le login de suivant de session_id=500 a l'event_Sequence=400 pour fichier 3
      -- il y a des requêtes pour cette session_id=500 avec event_sequence > 130 et < 400 pour fichier 3
      -- Ensuite cette session se termine puis une autre s'ouvre qui réutilise le même session_id 
      -- exemple le login de session_id=500 avec event_Sequence=401 pour fichier 3
      -- il y a  des requêtes pour ce session_id=500 avec  event_sequence > 401 pour fichier 3
      -- donc si on veut associer les requêtes au bon login, il faut qu'il y ait égalité sur le session_id
      -- et trouver celui dont le event_sequence est plus petit et le plus proche que celui de la requête 
      --
      -- le Outer apply est là au cas où on ait des requêtes provenant de sessions non encore capturées et mises en évènements
      -- parce que le login trigger ne capte pas les évènements si l'event session est inactif.
      OUTER APPLY 
      (
      Select TOP 1 Hc.client_app_name, Hc.Client_net_address 
      From Auditreq.dbo.HistoriqueConnexions as Hc
      Where Hc.session_id = R.session_id -- POUR LA MÊME SESSION!
        And 
          (  
              ( -- typiquement les créations de sessions SQL se trouvent proches dans le temps des requêtes qui les suivent
                -- et souvent dans le même fichier/offset
                  Hc.ExtendedSessionCreateTime = R.ExtendedSessionCreateTime
              And Hc.event_Sequence < R.event_Sequence
              )
             -- Mais la session SQL peut aussi avoir été logguée dans le fichier/offset precedent de cette session
          Or Hc.ExtendedSessionCreateTime < R.ExtendedSessionCreateTime
          )
      Order by Session_id, ExtendedSessionCreateTime desc, event_Sequence desc
      ) Hc
      -- If the session ins't in the events it is because it login existed BEFORE the extended session started
      -- so we get the existing info from sys.dm_exec_connections. In that context the user can modify the hotsname() returned
      -- by sys.dm_exec_connecions
      OUTER APPLY 
      (
      Select S.program_name, c.client_net_address 
      from 
        -- Shortcut the query is Client_net_address where resolved before by Hc.Client_net_address IS NULL 
        (select * From sys.dm_exec_sessions as S Where Hc.Client_net_address IS NULL And S.session_id = R.session_id) as S
        JOIN
        sys.dm_exec_connections as C
        ON C.session_id = S.session_id
      ) as Ci
      -- Three case possible, only one true. 
      -- 1) Client connections was found in events. Even if events are old, user_event reporting connections are of the same age too.
      -- case 2 and 3 are very rare.
      -- 2) If not recorded in events, this may be that extended session was started after the connection. This is quite unlikely
      --    because events and trigger are meant to be active at all time. In that case if session was started after, 
      --    get it from actual sys.dm_exec_ views, which is quite accurate, but not 100% reliable
      -- 3) If not found, give an explantion which the spid isn't there anymore. 
      CROSS APPLY (Select client_app_name = COALESCE(hc.client_app_name, '(Cur)-> '+Ci.Program_name, 'Client program disconnected')) as client_app_name
      CROSS APPLY (Select client_net_address = COALESCE(hc.client_net_address, '(Cur)-> '+Ci.client_net_Address, 'session is gone')) as client_net_Address

      -- Quand l'extended session part, il y a une ou deux connexions qui peuvent être déjà ouvertes, phénomène bref
    Where
      -- il y a une gestion des fichiers d'évènements traités
      -- et s'il en sont pas supprimés, il y aura risque de relecture
      -- des évènements et ce Where Not Exists évite les duplications.
      Not Exists
      (
      Select * 
      From dbo.AuditComplet AC
      Where AC.event_time = R.event_time 
        AND AC.ExtendedSessionCreateTime = R.ExtendedSessionCreateTime
        And AC.event_sequence = R.event_Sequence
      )

    -- ralentir plus ou moins la fréquence du traitement s'il n'y a plus d'autres fichiers en avant
    -- et qu'on a peu d'évènements.
    -- sur un serveur actif, le test @@rowcount = 0 est trop drastique, et risque de ne pas se produire
    Insert into #RcCount(name, cnt) Values ('insertAuditComplet', @@rowcount)

    -- si on traitait toute les requêtes (incluant celle des modules) on pourrait mettre le code du module SQL dans SQL+Batch seulement
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
      Select top 1 file_Name from dbo.EvenementsTraitesSuivi Order By dateSuivi desc
      Except
      Select full_filesystem_path  FROM sys.dm_os_enumerate_filesystem(RepFichTrc, MatchFichTrc) -- attention recursion possible!
      Where full_filesystem_path Like RepFichTrc+'AuditReq[_][0-9]%' -- pour ôter résultats de récursion possible
      ) as Diff
    If @@ROWCOUNT>0 
    Begin
      Declare @msgPerte nvarchar(4000)
      Select @msgPerte=E.MsgFichPerduGenerique From dbo.EnumsEtOpt as E
      Insert into dbo.logTraitementAudit (Msg) Values (@msgPerte)
    End

    -- TODO: Ajouter un failsafe - Si on trouve des fichiers qui existent avant celui de dbo.EvenementsTraites
    -- Arrêter le traitement avec message.
    --select * From dbo.EvenementsTraitesSuivi Order by dateSuivi desc
    Declare @aFileToDel nvarchar(256)
    Select @aFileToDel = Autres.full_filesystem_path
    From
      (Select * From EnumsEtOpt) AS opt
      CROSS APPLY (select top 1 file_name From dbo.EvenementsTraitesSuivi Order by dateSuivi desc) Dernfich
      -- je suis passé à traiter un nouveau fichier, car un fichier précédent existe, et que j'ai forcément fini de le traiter
      -- en fonction de l'algorithme qui poursuit la lecture au prochain fichier
      CROSS APPLY 
      (
      Select top 1 Autres.full_filesystem_path
      From 
        sys.dm_os_enumerate_filesystem(Opt.RepFichTrc, opt.MatchFichTrc) Autres -- attention récursion possible!
      Where Autres.full_filesystem_path < DernFich.file_name
        And Autres.full_filesystem_path Like Opt.RepFichTrc+'AuditReq[_][0-9]%' -- pour ôter résultats de récursion possible
      ) as Autres
    Where Autres.full_filesystem_path IS NOT NULL
    If @@ROWCOUNT > 0
    Begin
      Insert into dbo.LogTraitementAudit(Msg)  Select 'Suppression de '+@aFileToDel
      Exec master.sys.xp_delete_files @afileToDel
    End

    -- On ne veut pas que la table des connexions récentes à l'historique grossise indfiniment.
    -- On sait que si une session_id existe en multiples copies (login/logout) et pas nécessairement toutes du même
    -- utilisateur, ce qui arrive lors des reconnexions, il faut s'aligner sur l'info la plus récente.
    -- pendant le traitement des évènements du fichier, on besoin de toutes, mais après
    -- on supprime les connexions périmées, sauf leur dernière occurence qui est peut être toujours ouverte
    -- et pour laquelle s'en viennent d'autres évènements.

    -- Select * From dbo.HistoriqueConnexions as C Order by Session_id, ExtendedSessionCreateTime, event_sequence
    Delete C
    From
      (
      Select 
        Session_id
      , ExtendedSessionCreateTime
      , event_sequence
      -- attribuer pour un même session_Id un numéro de séquence descendant de sorte que 
      -- le plus récent a la session d'extended event la plus récente et la séquence d'évènement la plus récente.
      , OccurenceSessionId = ROW_NUMBER() Over (Partition By Session_id Order by ExtendedSessionCreateTime Desc, event_Sequence Desc)
      From Dbo.HistoriqueConnexions
      ) as Ord
      JOIN 
      dbo.HistoriqueConnexions as C
      ON  Ord.OccurenceSessionId > 1 -- toutes les autres ocurences passées de ce session_id
      And C.Session_Id = Ord.Session_id
      And C.ExtendedSessionCreateTime = Ord.ExtendedSessionCreateTime
      And C.event_Sequence = Ord.event_sequence

    -- ici ça ne sert à rien de garder qqch de plus vieux que la rétention de données
    Delete From dbo.AuditComplet
    Where event_time < DATEADD(dd, -45, getdate()) -- détruit traces plus vieilles que 45 jours.

    Delete From dbo.EvenementsTraitesSuivi 
    Where dateSuivi < DATEADD(dd, -45, getdate()) -- détruit traces plus vieilles que 45 jours.

    Delete From dbo.LogTraitementAudit
    Where MsgDate < DATEADD(dd, -45, getdate()) -- détruit log plus vieux que 45 jours.

    -- Si jamais un mauvais fonctionnement cause un problème on éviter de garder des choses indéfiniment
    Delete Cn
    From dbo.HistoriqueConnexions as Cn
    Where Cn.LoginTime < DATEADD(dd, -45, getdate()) -- détruit historique connexions si on en échappe qui sont plus vieux que 45j

    Commit -- Keep coherent 

    -- on teste dehors du commit pour ne pas faire de wait dans la transaction
    -- c'est malcommode de tester le contenu des tables car la transaction dure trop
    -- longtemps pour rien quand il y a un wait dedans
    If Exists (Select * From #RcCount Where name='insertAuditComplet'  and cnt < 100)
       And Not Exists (Select * From Dbo.FichierLiberable()) 
    Begin
      Waitfor Delay '00:00:15' 
    End

  End -- While forever

  End Try
  Begin Catch
    IF @@TRANCOUNT > 0
    BEGIN
       ROLLBACK TRANSACTION;
    END
    Declare @msg nvarchar(max)
    Select @msg='Error from AuditReq.Dbo.CompleterAudit '+nchar(13)+nchar(10)+Fmt.ErrMsg
    From 
      (Select ErrMsgTemplate From dbo.EnumsEtOpt) as E
      CROSS APPLY dbo.FormatRunTimeMsg (E.ErrMsgTemplate, ERROR_NUMBER (), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE (), ERROR_MESSAGE ()) as Fmt
    Insert into @CatchPassThroughMsgInTx Values (@Msg)
    Insert into dbo.LogTraitementAudit (msg) Select Msg From @CatchPassThroughMsgInTx
    Exec ('ALTER EVENT SESSION AuditReq ON SERVER STATE = Stop')
    Exec dbo.SendEmail @msg
    RAISERROR(@msg,16,1) WITH Log -- erreur mis au log de SQL Server
  End Catch
  
End -- dbo.CompleterInfoAudit
go
-- no more needed, this table and its trigger
Drop table if exists dbo.PipelineDeTraitementFinalDAudit
GO
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
  Declare @JobName sysName
  Declare @context sysname
  Select @jobname = 'AuditReq'
  Select @jobId = job_id From msdb.dbo.sysjobs where name =@JobName
  
  If @jobId IS NOT NULL
  Begin
    Set @context = 'delete la job'
    EXEC @ReturnCode =  msdb.dbo.sp_delete_job @job_name=@JobName
    IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_delete_schedule ',11,1,@returnCode)

    If exists (Select * From msdb.dbo.sysjobschedules where job_id=@jobId)
    Begin
      EXEC sp_detach_schedule @job_name = @JobName, @schedule_name = N'AuditReqAutoRestart';
      Exec @ReturnCode =  msdb.dbo.sp_delete_schedule @schedule_name ='AuditReqAutoStart'
      IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_delete_schedule ',11,1,@returnCode)
    End
  End

  Set @context = 'ajout de la job'
  Set @jobId = NULL
  EXEC @ReturnCode =  msdb.dbo.sp_add_job 
    @job_name=@JobName, 
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

  Set @context = 'ajout du step CheckAndStartExtendedEvent'
  EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'CheckAndStartExtendedEvent', 
		  @step_id=1, 
		  @cmdexec_success_code=0, 
		  @on_success_action=3, -- temporaire a mette a jour
		  @on_fail_action=2, 
		  @on_fail_step_id=0, 
		  @retry_attempts=0, 
		  @retry_interval=0, 
		  @os_run_priority=0, @subsystem=N'TSQL', 
		  @command=
  N'
-- permet à la trace de repartir et de logger la connexion du step suivant
If Not exists (Select * From sys.dm_xe_sessions where name = ''AuditReq'')
Exec (''ALTER EVENT SESSION AuditReq ON SERVER STATE = Start'')
Waitfor delay ''00:00:05''
  ', 
		@database_name=N'AuditReq', 
		@flags=4

  IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_add_job_Step ',11,1,@returnCode)

  Set @context = 'ajout du step Run'
  EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Run', 
		  @step_id=2, 
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

  Set @context = 'Modif du step CheckAndStartExtendedEvent'
  EXEC msdb.dbo.sp_update_jobstep  @job_id=@jobId, @step_name= N'CheckAndStartExtendedEvent',  
    @step_id = 1,
    @on_success_action = 4,
    @on_success_step_id = 2,
    @on_fail_action = 2,
    @on_fail_step_id = 0;

  Set @context = 'Setup du step de départ de la job à CheckAndStartExtendedEvent'
  EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
  IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_update_Job ',11,1,@returnCode)

  Set @context = 'Ajout horaire AuditReqAutoStart'
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

  Set @context = 'Attache horaire AuditReqAutoStart a la job'
  EXEC sp_attach_schedule @job_name = @JobName, @schedule_name = N'AuditReqAutoStart';

  Set @context = 'Ajout horaire AuditReqAutoRestart'
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

  Set @context = 'Attache horaire AuditReqAutoRestart a la job'
  EXEC sp_attach_schedule @job_name = @JobName, @schedule_name = N'AuditReqAutoRestart';

  Set @context = ' specifie (local) comme job server de la job'
  EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
  IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_add_jobserver ',11,1,@returnCode)

EXEC msdb.dbo.sp_update_job @job_id=@jobId,
		@notify_level_email=2, 
		@notify_level_page=2, 
		@notify_email_operator_name=N'AuditReq_Operator'

  Set @context = 'Demarre de la job'
  EXEC dbo.sp_start_job @JobName;
  IF (@ReturnCode <> 0) Raiserror ('Code de retour de %d de msdb.dbo.sp_start_job ',11,1,@returnCode)

  COMMIT
End Try
Begin catch
  Declare @msg nvarchar(max)
  Select @msg = @context + nChar(10)+F.ErrMsg
  From 
    AuditReq.dbo.FormatCurrentMsg (NULL) as F
  Print 'erreur à la définition ou au lancement de la job: '+@msg
  ROLLBACK
End catch
GO
Use AuditReq
go
-- help find mappings of extended events to old Sql trace
Create or alter view dbo.EquivExEventsVsTrace
as
Select top 99.9999 PERCENT *
From
  (
  SELECT DISTINCT
    tb.trace_event_id
  , EventClass = te.name            
  , Package=em.package_name
  , XEventName=em.XE_Event_Name
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
-- Select * from dbo.findMissingSeq (1)--should return nothing for a valid test
-- Select * from dbo.findMissingSeq (0) order by f,s--should return all rows of the test for a valid test
-- select * from AuditComplet
-- select * From dbo.HistoriqueConnexions 
--Select * From dbo.EquivExEventsVsTrace where EventClass like 'UserCon%'--

--Select file_name, last_Offset_done, count(*), MIN (passe), MAX(passe)
--From auditReq.dbo.EvenementsTraitesSuivi with (nolock) 
--group by file_name, last_Offset_done
--order by file_name, last_Offset_done
--Select * From auditReq.dbo.LogTraitementAudit 
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
