/*
-- -----------------------------------------------------------------------------------
-- ADJUST ADMIN OPTIONS ON THE FIRST RUN BEFORE EXECUTING THIS SCRIPT (refer to #YourConfig).  
-- The options will be saved, so future upgrades will not require reconfiguration.  
-- This installation script is designed to preserve existing data.  
-- For a full reset, drop the `FullQryAudit` database.

-- AJUSTEZ LES OPTIONS ADMIN LORS DU PREMIER LANCEMENT AVANT D'EXÉCUTER CE SCRIPT (voir #YourConfig).  
-- Les options seront sauvegardées, donc les mises à niveau futures n'exigeront pas de nouvelle configuration.  
-- Ce script d'installation est conçu pour conserver les données existantes.  
-- Pour un redémarrage complet, supprimez la base de données `FullQryAudit`.
-- -----------------------------------------------------------------------------------

FullQryAudit Version 2.8 Repository https://github.com/pelsql/QueryAuditToolForMSSql
To obtain the most recent version go to this link below
(Pour obtenir la version la plus récente ouvrir le lien ci-dessous)
https://raw.githubusercontent.com/pelsql/QueryAuditToolForMSSql/main/QueryAuditToolForMSSql.sql
-------------------------------------------------------------------------------------------------------
FullQryAudit : Tool to produce managed audit of SQL queries by the mean of a SQL Server database
Author       : Maurice Pelchat
Licence      : BSD-3 https://github.com/pelsql/QueryAuditToolForMSSql/blob/main/LICENSE
               Take note of the liability clauses associated with this License at the link above
-------------------------------------------------------------------------------------------------------
FullQryAudit : Outil produisant un audit géré de requêtes SQL par le biais d'une base de données SQL Server
Auteur       : Maurice Pelchat
Licence      : BSD-3 https://github.com/pelsql/QueryAuditToolForMSSql/blob/main/LICENSE
               Prendre note des clauses de responsabilités associées à cette Licence au lien ci-dessus
-------------------------------------------------------------------------------------------------------
*/
-- Register a temporary table.
-- This table contains the version number of this script.
-- It allows the creation of the view dbo.version later in the script once the database is created.
Drop table if exists #version; Select Version='2.8' into #version
------------------------------------------------------------------------------------------------------------------
-- Will Register your config in the database to be created
-- If this is an update and was done in a previous install, leave it unchanged.
-- If FullQryAudit.dbo.ConfigMemory already exists this won't be done, and will be ignored.
-- If you want to RESET parameters, drop table dbo.ConfigMemory in FullQryAudit, and set them here.
------------------------------------------------------------------------------------------------------------------
Drop table if Exists #YourConfig
If OBJECT_ID('FullQryAudit.dbo.ConfigMemory') IS NULL 
  Select 
    -- this space is divided in n 40Meg trace files, from which max_rollover_files param 
    -- is computed for the extended event file target.
    MaxSpaceInGB_ForExEventSessTargetFiles=70 
  , JobName='FullQryAudit' -- name of job / extended event session, not for database
  , RootAboveDir='D:\YourDir\'  -- directory that contains the directory where the trace file are stored ex: L:\Temp\
  , EMailForAlert='YourSqlAdmin@yourDomain.Com' -- domain to show in administrative error message for Audit ex: JoeAdmin@MyCie.com
  , mailserver_name = '1.0.0.1' -- Address of the mail server to use for administrative tasks ex: 127.0.0.1 or SomeEmailSrv
  , SmtpPort = 25 -- port of the mail server to use for administrative tasks ex: usually the default 
  , enable_ssl = 0 -- enable ssl to communicate with mail server to use for administrative tasks ex:
  , EmailUsername = NULL -- (leave as is for anonymous login)
  , EmailPassword = NULL -- (leave as is for anonymous login)
  Into #YourConfig
Go
Use tempdb
go
-- If the FullQryAudit database does not exist, it will be created.
-- The database is set with FULL recovery mode, and file growth settings are adjusted to accommodate potential large audit logs.
If DB_ID('FullQryAudit') IS NULL 
Begin 
  CREATE DATABASE FullQryAudit
  alter DATABASE FullQryAudit Set recovery FULL
  alter database FullQryAudit modify file ( NAME = N'FullQryAudit', SIZE = 100MB, MAXSIZE = UNLIMITED, FILEGROWTH = 100MB )
  alter database FullQryAudit modify file ( NAME = N'FullQryAudit_log', SIZE = 100MB , MAXSIZE = UNLIMITED , FILEGROWTH = 100MB )
End
GO
Use FullQryAudit
GO
DROP TRIGGER IF EXISTS LogonFullQryAuditTrigger ON ALL SERVER;
GO
-- If dbo.configMemory is there, no need to create it. User already choose its params.
If OBJECT_ID('FullQryAudit.dbo.ConfigMemory') IS NULL
  Select * Into dbo.ConfigMemory 
  From #YourConfig
  Where 
      RootAboveDir <> 'Drive:\YourDir\'  -- shows that the user didn't set it
  And EMailForAlert <> 'YourSqlAdmin@yourDomain.Com' -- shows that the user didn't set it
  And mailserver_name <> '1.0.0.1' -- shows that the user didn't set it
GO
-- If table is empty, this means by the previous conditions, that admin config wasn't set. See #YourConfig.
If Not Exists (Select * From FullQryAudit.dbo.ConfigMemory)
  Raiserror ('Admin options were never initially set, See #YourConfig.', 20, 1) With Log
GO
-- This function dynamically replaces placeholders in a template string.
-- It is used for generating SQL statements or configurations by substituting 
-- specific tags (e.g., '#Tag#') with corresponding values ('@Val') at runtime.
-- Helps automate script creation and reduces repetitive code.
-- It also simplify single quote management in string by allowing double quotes in place 
-- of single quotes which is troublesome in string because they needed to be doubled.
-- by replacing " by ''
Create Or Alter Function dbo.TemplateReplace(@tmp nvarchar(max), @Tag nvarchar(max), @Val nvarchar(max))
Returns Nvarchar(max)
as
Begin
  Return(Select rep=REPLACE(Replace(@tmp, '"', ''''), @Tag, @Val))
End
GO
-- Create version view from info stored in #version table.
-- This instruction generates a view that provides the script version 
-- and a corresponding message indicating the version installed.
-- It enables querying the version of the script installed in the database 
-- and ensures traceability of the deployment version.
Declare @Sql Nvarchar(max)
Select @Sql = dbo.TemplateReplace(t, '#version#', t.version)
From 
  (
  Select 
    version
  , t='
Create or Alter View Dbo.Version
as 
(
Select Version, MsgVersion
From 
  (select version="#version#") as Version
  Cross Apply (Select MsgVersion = "Version #Version# installed") as MsgShow
)
' 
  from #version
  ) as t
Print @Sql
Exec (@Sql)
Go
--------------------------------------------------------------------------------------
-- Some items related to this script config.
--------------------------------------------------------------------------------------
Create Or Alter View Dbo.EnumsAndOptions
as
Select 
  MaxFiles
, EC.RootAboveDir, Dir, EC.JobName, RepFichTrc, PathReadFileTargetPrm, TargetFnCreateEvent, RepFich, MatchFichTrc
, EC.EMailForAlert, EC.mailserver_name, EC.SmtpPort, EC.enable_ssl, EC.EmailUserName, EC.EmailPassword 
, EC.LostFileMsgPrefix 
, EC.ErrMsgTemplate
, GenericLostFileMsg=LostFileMsgPrefix+ ' see table dbo.ProcessAuditLog'
, Actions.*
From 
  (
  Select 
    -- Admin config options configured in dbo.ConfigMemory
    CM.MaxSpaceInGB_ForExEventSessTargetFiles
  , CM.JobName -- name of job / extended event session, not for database
  , CM.RootAboveDir -- directory that contains the directory where the trace file are stored
  , CM.EMailForAlert -- domain to show in administrative error message for Audit
  , CM.mailserver_name -- Address of the mail server to use for administrative tasks
  , CM.SmtpPort -- port of the mail server to use for administrative tasks
  , CM.enable_ssl -- enable ssl to communicate with mail server to use for administrative tasks
  , CM.EmailUsername -- (leave as is for anonymous login)
  , CM.EmailPassword -- (leave as is for anonymous login)

  , LostFileMsgPrefix='Lost audit file: '
  , ErrMsgTemplate=
'----------------------------------------------------------------------------------------------
 -- Msg: #ErrMessage#
 -- Error: #ErrNumber# Severity: #ErrSeverity# State: #ErrState##atPos#
 ----------------------------------------------------------------------------------------------'
  , ErrMsgTemplateShort=' Msg: #ErrMessage# Error: #ErrNumber# Severity: #ErrSeverity# State: #ErrState##atPos#'
  From dbo.ConfigMemory as CM
  ) as EC
  -- Valeur calculées
  CROSS APPLY (Select Dir=JobName) as Dir
  CROSS APPLY (Select RepFich=RootAboveDir+Dir) as RootAboveDir
  CROSS APPLY (Select RepFichTrc=RepFich+'\') as RepFichTrc
  CROSS APPLY (Select MatchFichTrc=JobName+'*.xel') As MatchFichTrc  -- ne pas changer
  CROSS APPLY (Select PathReadFileTargetPrm=RepFichTrc+MatchFichTrc) as PathReadFileTargetPrm
  CROSS APPLY (Select TargetFnCreateEvent=RepFichTrc+JobName+'.Xel') as TargetFnCreateEvent
  CROSS APPLY (Select MaxFiles=Convert(nvarchar,EC.MaxSpaceInGB_ForExEventSessTargetFiles*1024/40)) as MaxFiles
  CROSS APPLY
  (
  Select 
    TplExSessStop=
'If Exists (Select * From Sys.dm_xe_sessions where name = "FullQryAudit")
  ALTER EVENT SESSION FullQryAudit ON SERVER STATE = STOP
Else 
  Print "EVENT SESSION FullQryAudit is already stopped, so no attempt to Stop"'
  , TplExSessDrop=
'-- If FullQryAudit Event Session exists, drop it 
If Exists(Select * From sys.server_event_sessions WHERE name = "FullQryAudit")
  DROP EVENT SESSION FullQryAudit ON SERVER
Else 
  Print "EVENT SESSION FullQryAudit does not exists, so no attempt to drop"'
  , TplExSessCreate=
'-- here we don"t test if session status and existence because everything to clear out 
-- previous session would"ve have been generated
-- If FullQryAudit Event Session doesn"t exists create it
If Exists(Select * From sys.server_event_sessions WHERE name = "FullQryAudit") 
Begin
  Print "EVENT SESSION FullQryAudit already exists, so no attempt to create"
  Return
End
CREATE EVENT SESSION FullQryAudit ON SERVER
  ADD EVENT sqlserver.user_event
  (
    ACTION (package0.event_sequence)
    WHERE [sqlserver].[is_system]=(0) 
      -- users and server utilies processes (SQLTelemetry, SQLAgent, DatabaseMail..)
      And [sqlserver].[Session_id] > 50 
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
       -- users and server utilies processes (SQLTelemetry, SQLAgent, DatabaseMail..)
      And [sqlserver].[Session_id] > 50 
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
       -- users and server utilies processes (SQLTelemetry, SQLAgent, DatabaseMail..)
      And [sqlserver].[Session_id] > 50 -- process utilisateur
  )
ADD TARGET package0.asynchronous_file_target(
SET 
  filename = "#TargetFnCreateEvent#"
, max_file_size = (40) -- file in meg unit (MB unité par défaut)
-- push to max rollover because main sp process manage itself removal of files
-- computed from MaxSpaceInGB_ForExEventSessTargetFiles from 40Mb size for files
, max_rollover_files = (#MaxFiles#) 
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
If Not Exists (Select * From Sys.dm_xe_sessions where name = "FullQryAudit")
Begin
  ALTER EVENT SESSION FullQryAudit ON SERVER STATE = START
  Waitfor Delay "00:00:05"
End
Else
  Print "Session FullQryAudit is already started, so no attempt to start"
'
  ) As tpl
  CROSS APPLY
  (
  Select [StopExtendedSession], [DropExtendedSession], [CreateExtendedSession], [StartExtendedSession]
  From
    (
    Select Action, Sql
    From 
      (Select 
         StopES='StopExtendedSession'
       , DropES='DropExtendedSession'
       , CreateES='CreateExtendedSession'
       , StartES='StartExtendedSession'
       ) as TagAct
      Cross Apply
      (
      Values (StopES, tpl.TplExSessStop)
           , (DropES, tpl.TplExSessDrop)
           , (CreateES, tpl.TplExSessCreate)
           , (StartES, tpl.TplExSessStart) 
      ) as Tp (action, tp)
      Cross Apply (Select r1=dbo.TemplateReplace(tp, '#TargetFnCreateEvent#', TargetFnCreateEvent) ) as r1
      Cross Apply (Select Sql=dbo.TemplateReplace(r1, '#MaxFiles#', MaxFiles) ) as Sql
    ) as ActionRows
  PIVOT (Max(Sql) For Action IN ([StopExtendedSession], [DropExtendedSession], [CreateExtendedSession], [StartExtendedSession])) as PivotTable
  ) as Actions

-- select * from Dbo.EnumsAndOptions
GO
-- Validate the directory specified in dbo.EnumsAndOptions.
-- If the directory does not exist, raise a critical error and terminate the script.
-- This ensures that the configured file path is correct before proceeding with further operations.
If Not Exists
   (
   Select * 
   FROM 
     Dbo.EnumsAndOptions as E 
     CROSS APPLY sys.dm_os_enumerate_filesystem(RootAboveDir, Dir) as F
   where is_directory=1
   ) 
Begin
  Declare @repFich sysname; Select @repFich = repfich from Dbo.EnumsAndOptions
  Raiserror ('The directory configured in Dbo.EnumsAndOptions %s does not exist. Please correct it, close this session, and reconnect.', 20, 1, @repfich) With Log
End 
GO
--------------------------------------------------------------------------------------------
-- If a job exists, delete it temporarily to allow replacing the code objects
--------------------------------------------------------------------------------------------
DECLARE @ReturnCode INT = 0
DECLARE @jobId BINARY(16)
Declare @JobName sysName
Select @jobname = 'FullQryAudit'
Select @jobId = job_id From msdb.dbo.sysjobs where name = @JobName

If @jobId IS NOT NULL
Begin
  EXEC @ReturnCode =  msdb.dbo.sp_delete_job @job_name = @JobName
  IF (@ReturnCode <> 0) Raiserror ('Return code of %d from msdb.dbo.sp_delete_job ', 11, 1, @returnCode)

  If exists (Select * From msdb.dbo.sysjobschedules where job_id = @jobId)
  Begin
    EXEC msdb.dbo.sp_detach_schedule @job_Name = @JobName, @schedule_name = N'FullQryAuditAutoRestart';
    Exec @ReturnCode =  msdb.dbo.sp_delete_schedule @schedule_name = 'FullQryAuditAutoStart'
    IF (@ReturnCode <> 0) Raiserror ('Return code of %d from msdb.dbo.sp_delete_schedule ', 11, 1, @returnCode)
  End
End
GO
-- remove any code object from previous version, since all needed code objects are recreated
-- the logon trigger isn't replaced here. And Dbo.EnumsAndOptions must be preserved
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
Where QName NOT IN ('[dbo].[EnumsAndOptions]','[dbo].[TemplateReplace]', '[dbo].[Version]')
Print @Sql  
Exec (@Sql)
GO
-- this procedure sets from email config parameters contains in Dbo.EnumsAndOptions database mail
-- profile and its account, and SQL Agent operator
Create Or Alter Proc Dbo.EmailSetup
As
Begin
  Set nocount on

  -------------------------------------------------------------
  --  database mail setup for FullQryAudit
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

  -- Add email configuration settings to the current setup if they are missing.
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
  SET @profile_name = 'FullQryAudit_EmailProfile';

  SET @account_name = lower(replace(convert(sysname, Serverproperty('servername')), '\', '.'))+'.FullQryAudit'

  -- Init email account name
  SET @email_address = lower(@account_name+'@FullQryAudit.com')
  SET @display_name = lower(convert(sysname, Serverproperty('servername'))+' : FullQryAudit ')
    
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
  From Dbo.EnumsAndOptions as E

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
  
  Declare @oper sysname Set @oper = 'FullQryAudit_Operator'
  If exists(SELECT * FROM msdb.dbo.sysoperators Where name = @oper)
    Exec msdb.dbo.sp_delete_operator @name = @oper;
    
  Declare @email sysname
  Select @email=E.EMailForAlert from Dbo.EnumsAndOptions as E
  Exec msdb.dbo.sp_add_operator @name = @oper, @email_address = @email

  EXEC  Msdb.dbo.sp_send_dbmail
    @profile_name = 'FullQryAudit_EmailProfile'
  , @recipients = @email
  , @importance = 'High'
  , @subject = 'FullQryAudit Email setup completed'
  , @body = 'Test email for Audit Email Setup'
  , @body_format = 'HTML'

End -- dbo.EmailSetup
GO
-- run email setup
Exec dbo.EmailSetup
GO
Create or Alter Function dbo.ViewLastJobExec(@jobName sysname)
Returns Table
as
Return
Select R.Status, H.*
From
  (Select JobName='FullQryAudit') as Prm
  CROSS APPLY
  (
  -- by ordering by DENSE_RANK for the given job_id by jobEndInstanceId Desc, prevJobEndInstanceId
  -- all steps of the job that belong to the same job execution are going to receive the same sequence
  -- Top 1 clause then limits results to the first of DENSE_RANK value returned
  Select Top 1 
    JobLimits.*
  , JobOrderFromLast=DENSE_RANK() Over (Order by jobEndInstanceId Desc, prevJobEndInstanceId)
  From
    ( 
    -- This query identifies last instance_id of the job, named here JobEndInstanceId
    -- and the last instance_id of the previous job, named here prevJobEndInstanceId
    Select 
      job_id
    , jobEndInstanceId
    -- find the instanceId that marks the end of the previous job
    , prevJobEndInstanceId=LAG(jobEndInstanceId, 1, 0) Over (Order by jobEndInstanceId)
    From
      ( -- identify job end dividers
      select H.job_id, jobEndInstanceId=H.instance_id
      from 
        -- limit work to a single job by step_id=0 and name through the job parameter
        (Select job_id, Step_Id=0 From Msdb.dbo.sysjobs as J where j.name = Prm.JobName) as J
        -- find the instance_id that marks the end of the job, 
        -- and only rows that marks the end of the job, not the other steps of jobs
        join msdb.dbo.sysjobhistory as H
        On H.job_id = J.job_id
        And H.step_id=J.Step_Id
      ) as jobEndInstanceId
    ) as JobLimits
  Order By JobOrderFromLast
  ) as JobInOrderFromLast
  -- Those two values will allow to group steps of a given job, and grab complete details
  -- for each steps from sysjobhistory doing a range join
  -- by H.instance_id <= jobEndInstanceId And H.instance_id > prevJobEndInstanceId
  -- for this job_id
  Join Msdb.dbo.sysjobhistory as H
  ON  H.job_id = JobInOrderFromLast.job_id 
  And H.instance_id <= JobInOrderFromLast.jobEndInstanceId 
  And H.instance_id > JobInOrderFromLast.prevJobEndInstanceId

  OUTER APPLY 
  (
  SELECT Status = 'Failed' WHERE run_status = 0     UNION ALL
  SELECT Status = 'Succeeded' WHERE run_status = 1     UNION ALL
  SELECT Status = 'Retry' WHERE run_status = 2    UNION ALL
  SELECT Status = 'Canceled' WHERE run_status = 3    UNION ALL
  SELECT Status = 'In Progress' WHERE run_status = 4
  ) AS R
GO
Create or Alter View dbo.ShowLastJobStatus
as
Select Status, Msgs
from 
  (select crLf=NCHAR(13)+NCHAR(10)) as crlf
  cross apply 
  (
  Select Status=Convert(nvarchar(20),null),Msgs = 'Status from previous FullQryAudit job execution ' Union all
  Select Status, Msgs=Message+CrLf From FullQryAudit.dbo.ViewLastJobExec('FullQryAudit')
  ) as Msgs
GO
-- Procedure to send an email using the Database Mail feature in SQL Server.
-- Parameters:
--   @msg: The body of the email.
--   @Now: Determines the type of email to send (1 for an audit stop alert, 0 for a last execution report).
CREATE OR ALTER PROCEDURE dbo.SendEmail @msg NVARCHAR(MAX), @Now Int = 1
AS
BEGIN
  -- Declare variables for the email profile name and recipient address.
  Declare @profile_name SysName;
  Declare @email_address SysName;

  -- Retrieve email profile and recipient address from the configuration table.
  Select @profile_name = 'FullQryAudit_EmailProfile', @email_address = E.EMailForAlert 
  From FullQryAudit.Dbo.EnumsAndOptions as E;

  -- Declare a variable for dynamically generated SQL.
  Declare @Sql Nvarchar(max);

  -- Generate the email subject dynamically based on the @Now parameter.
  Select @Sql = sql
  From
    (
    -- Case: Audit stopped with an issue to investigate.
    Select Subject = '"FullQryAudit: Audit stopped, problem to investigate in the audit of queries"'
    Where @Now = 1
    UNION ALL
    -- Case: Report of the last execution of FullQryAudit.
    Select Subject = '"FullQryAudit: Report of the last execution of FullQryAudit"'
    Where @Now = 0
    ) as Subject
    CROSS JOIN
    (
    -- Template for the email to be sent using Database Mail.
    Select 
      t0 =
      N'
      EXEC  Msdb.dbo.sp_send_dbmail
        @profile_name = @profile_name
      , @recipients = @email_Address
      , @importance = "High"
      , @subject = #Subject#
      , @body = @msg
      , @body_format = "HTML"
      '
    ) as t0
    -- Replace the placeholder in the template with the actual subject.
    CROSS APPLY (Select t1 = REPLACE(t0, '#Subject#', subject)) as t1
    -- Replace double quotes in the template with single quotes for SQL compatibility.
    CROSS APPLY (Select Sql = REPLACE(t1, '"', '''')) as Sql;

  -- Execute the dynamically generated SQL to send the email.
  Exec dbo.sp_executeSql
    @Sql
  , N'@profile_name sysname, @email_Address sysname, @msg NVARCHAR(MAX)'
  , @profile_Name
  , @Email_address
  , @Msg;
END
GO
-- Function to format runtime error messages based on a custom template or default template.
-- Parameters:
--   @MsgTemplate: The custom error message template (if NULL, uses the default template from EnumsAndOptions).
--   @error_number: The error number of the runtime error.
--   @error_severity: The severity level of the error.
--   @error_state: The state code of the error.
--   @error_line: The line number where the error occurred.
--   @error_procedure: The name of the stored procedure or function in which the error occurred.
--   @error_message: The text description of the error.
-- Returns:
--   A table with the formatted error message based on the provided inputs and the error message template.
Create Or Alter Function dbo.FormatRunTimeMsg 
(
  @MsgTemplate Nvarchar(max), -- Custom template for error message formatting.
  @error_number Int, -- Error number from the SQL Server error context.
  @error_severity Int, -- Severity level of the error.
  @error_state int, -- Error state code.
  @error_line Int, -- Line number where the error occurred.
  @error_procedure nvarchar(128), -- Name of the module where the error occurred.
  @error_message nvarchar(4000) -- Error message text.
)
Returns Table
as 
Return
(
Select *
From 
  -- Retrieve the error message template from the configuration table or use the provided one.
  (Select ErrorMsgFormatTemplate=ISNULL(@MsgTemplate, E.ErrMsgTemplate) From Dbo.EnumsAndOptions as E) as MsgTemplate
  -- Populate the runtime error details.
  CROSS APPLY (Select ErrMessage=@error_message) as ErrMessage
  CROSS APPLY (Select ErrNumber=@error_number) as ErrNumber
  CROSS APPLY (Select ErrSeverity=@error_severity) as ErrSeverity
  CROSS APPLY (Select ErrState=@error_state) as ErrState
  CROSS APPLY (Select ErrLine=@error_line) as ErrLine
  CROSS APPLY (Select ErrProcedure=@error_procedure) as vStdErrProcedure
  -- Replace placeholders in the template with actual error details.
  CROSS APPLY (Select FmtErrMsg0=Replace(ErrorMsgFormatTemplate, '#ErrMessage#', ErrMessage) ) as FmtStdErrMsg0
  CROSS APPLY (Select FmtErrMsg1=Replace(FmtErrMsg0, '#ErrNumber#', CAST(ErrNumber as nvarchar)) ) as FmtErrMsg1
  CROSS APPLY (Select FmtErrMsg2=Replace(FmtErrMsg1, '#ErrSeverity#', CAST(ErrSeverity as nvarchar)) ) as FmtErrMsg2
  CROSS APPLY (Select FmtErrMsg3=Replace(FmtErrMsg2, '#ErrState#', CAST(ErrState as nvarchar)) ) as FmtErrMsg3
  CROSS APPLY (Select AtPos0=ISNULL(' at Line:'+CAST(ErrLine as nvarchar), '') ) as vAtPos0
  CROSS APPLY (Select AtPos=AtPos0+ISNULL(' in Sql Module:'+ErrProcedure,'')) as AtPos
  CROSS APPLY (Select ErrMsg=Replace(FmtErrMsg3, '#atPos#', AtPos) ) as FmtErrMsg
)
GO

-- Function to generate a formatted error message for the most recent runtime error using the current error context.
-- Parameters:
--   @MsgTemplate: The custom error message template (if NULL, uses the default template).
-- Returns:
--   A table containing the formatted error message using the latest error context (ERROR_* functions).
-- This function is the one mostly typically used for default error messaging
CREATE OR ALTER FUNCTION dbo.FormatCurrentMsg (@MsgTemplate nvarchar(4000))
Returns table
as 
Return
  Select * 
  From 
  dbo.FormatRunTimeMsg 
  (
    @MsgTemplate, -- Custom template for error message formatting.
    ERROR_NUMBER(), -- Number of the last error that occurred in the session.
    ERROR_SEVERITY(), -- Severity of the last error.
    ERROR_STATE(), -- State code of the last error.
    ERROR_LINE(), -- Line number of the last error.
    ERROR_PROCEDURE(), -- Procedure or function where the last error occurred.
    ERROR_MESSAGE() -- Text message of the last error.
  ) as Fmt
GO
DROP TRIGGER IF EXISTS LogonFullQryAuditTrigger ON ALL SERVER;
-- Check if the database user 'FullQryAuditUser' exists in the current database, and if so, drop it.
IF USER_ID('FullQryAuditUser') IS NOT NULL 
    DROP USER FullQryAuditUser;
GO
IF SUSER_SID('FullQryAuditUser') IS NOT NULL 
    DROP LOGIN FullQryAuditUser;
GO
declare @unknownPwd nvarchar(100) = convert(nvarchar(400), HASHBYTES('SHA1', convert(nvarchar(100),newid())), 2)
Exec
(
'
create login FullQryAuditUser 
With Password = '''+@unknownPwd+'''
   , DEFAULT_DATABASE = Tempdb, DEFAULT_LANGUAGE=US_ENGLISH
   , CHECK_EXPIRATION = OFF, CHECK_POLICY = OFF
'
)
Use master
GRANT VIEW SERVER STATE TO FullQryAuditUser;
GRANT ALTER TRACE TO FullQryAuditUser;
Use FullQryAudit
GO
-----------------------------------------------------------------------------------------------------------------
-- Logon trigger to capture login details such as login name, client network address, and application name.
-- This information is sent as a custom event to the FullQryAudit Extended Event session, ensuring both login events
-- and query activities are logged in a synchronized and sequential manner.
-----------------------------------------------------------------------------------------------------------------
CREATE or Alter TRIGGER LogonFullQryAuditTrigger 
ON ALL SERVER WITH EXECUTE AS 'FullQryAuditUser'
FOR LOGON
AS
BEGIN
  -- I take care to avoid reference to external user defined objects and limits
  -- at most references to all objects
  DECLARE @JEventDataBinary Varbinary(8000);
  Begin Try
    Select @JEventDataBinary = JEventDataBinary
    From 
      (Select EventData=EVENTDATA()) as EventData
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
      -- cancel any output if session isn't active yet
      CROSS APPLY (Select XESessionIsThere=1 Where Exists (Select * From sys.dm_xe_sessions Where Name = N'FullQryAudit')) as XESessionIsThere

    -- Event ID (must be between 82 and 91), don't send events if event session isn't started.
    -- see comment above : if session isn't alive no data is produced, so here @@rowcount is 0
    If @@ROWCOUNT > 0
      EXEC sp_trace_generateevent @eventid = 82, @userinfo = N'LoginTrace', @UserData=@JEventDataBinary

  End Try
  Begin Catch
    -- en état d'erreur on ne peut écrire dans aucune table, car la transaction va s'annuler quand même
    -- le mieux qu'on peut faire est de formatter l'erreur qui est redirigée dans le log de SQL Server
    Declare @msg nvarchar(4000) 
    Select @msg = 'Error in Logon trigger: LogonFullQryAuditTrigger'+nchar(10)+ErrMsg 
    From
      (Select ErrorMsgFormatTemplate=
'----------------------------------------------------------------------------------
Error in Logon trigger: LogonFullQryAuditTrigger
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
    Exec ('DISABLE TRIGGER LogonFullQryAuditTrigger ON ALL Server')
    --Exec dbo.SendEmail @Msg='FullQryAudit: Logon trigger detected an error during execution and has automatically disabled itself.'
  End Catch
END;
GO
----------------------------------------------------------------------------------------
-- Perform 

Declare @Sql nvarchar(max)
Select @Sql=[StopExtendedSession] From Dbo.EnumsAndOptions
Print @Sql
Exec (@Sql)

Select @Sql=[DropExtendedSession] From Dbo.EnumsAndOptions
Print @Sql
Exec (@Sql)

Select @Sql=[CreateExtendedSession] From Dbo.EnumsAndOptions
Print @Sql
Exec (@Sql)

Select @Sql=[StartExtendedSession] From Dbo.EnumsAndOptions
Print @Sql
Exec (@Sql)
go
USE FullQryAudit
GO
-- -----------------------------------------------------------------------------------------------
-- Use the trace's event_sequence to determine if a session has been restarted.
-- The event_sequence within a file always increases for an active extended session.
-- During server shutdown, events are flushed to the current file, so processing should continue
-- to ensure no events are missed.

-- The dbo.ExtEvProcessedChkPoint table is used for this tracking.

-- After a restart, if the FullQryAudit extended session is auto-restarted or manually started,
-- a new file is created, and event_sequence restarts at 1.
--
-- When processing this new file, the first event (event_sequence = 1) indicates the session's start
-- and can be used to derive a distinctive reference timestamp (event_time) for the session.

-- The FirstEventTimeOfSession column distinguishes event_sequences from different sessions.
-- This is crucial for managing expired sessions because event_sequence restarts at 1 
-- when extended session restarts.
-- ----------------------------------------------------------------------------------------------------

If Object_id('dbo.ExtEvProcessedChkPoint') IS NULL
Begin
  Create table dbo.ExtEvProcessedChkPoint
  (
    file_name nvarchar(260),
    last_Offset_done bigint,
    ChkPointTime Datetime2 Default SYSDATETIME(),
    FirstEventTimeOfSession Datetime NULL
  );
  create index iChkPointTime on dbo.ExtEvProcessedChkPoint(ChkPointTime);
End;

-- Ensure an index exists for sorting by 'iChkPointTime' in descending order.
If INDEXPROPERTY(Object_id('dbo.ExtEvProcessedChkPoint'), 'iChkPointTime', 'isClustered') IS NULL
  create index iChkPointTime on dbo.ExtEvProcessedChkPoint (ChkPointTime Desc);

-- The Dbo.ConnectionsHistory table stores historical connection data.
-- It captures details such as login names, session IDs, login times, client network addresses, 
-- application names, and the first event time of the extended session.
-- This table helps to correlate login events information with query execution events during auditing.
-- to add them to the final audit table that contains each query and the login information supplied by
-- usr events raised by the login trigger
-- 

If Object_Id('Dbo.ConnectionsHistory') IS NULL
Begin
  CREATE TABLE Dbo.ConnectionsHistory
  (
	   LoginName nvarchar(256) NOT NULL
  , Session_id smallint NOT NULL
  , LoginTime datetime2(7)  NOT NULL
  , Client_net_address nvarchar(48) NULL
  , client_app_name sysname
  , FirstEventTimeOfSession Datetime Not NULL 
  , event_sequence BigInt Not NULL
  ) 
End
GO

If INDEXPROPERTY(object_id('Dbo.ConnectionsHistory'), 'iConnectionsHistory', 'IsClustered') IS NULL
  Create clustered index iConnectionsHistory 
  On Dbo.ConnectionsHistory (Session_id, FirstEventTimeOfSession desc, Event_Sequence Desc, loginTime)

If INDEXPROPERTY(object_id('Dbo.ConnectionsHistory'), 'iFirstEventTimeOfSession', 'IsClustered') IS NULL
  Create index iFirstEventTimeOfSession
  On Dbo.ConnectionsHistory (FirstEventTimeOfSession desc)
GO

--------------------------------------------------------------------------------------------
-- This table is the final result of this script
-- it matches client_net_address and client_app_name with queries
-- plus some extra performance stats about queries
--------------------------------------------------------------------------------------------
If Object_id('dbo.FullAudit') IS NULL
Begin
  CREATE TABLE dbo.FullAudit
  (
    server_principal_name varchar(50) NULL
  , event_time datetimeoffset(7) NULL
  , Client_net_address nvarchar(48) NULL
  ,	session_id int NULL
  , client_app_name sysname NULL
  , database_name sysname NULL
  --, sql_batch nvarchar(max)
  --, line_number int
  , statement nvarchar(max) NULL
  -- cette colonne combinée à event_sequence garantit une clé unique pour l'ordre des evènements 
  -- car event_sequence est remis à zéro lors du rédémarrage d'une session de trace.
  , FirstEventTimeOfSession DateTime
  , event_sequence BigInt 
  , DurMicroSec BigInt NULL
  , cpu_time BigInt NULL
  , logical_reads BigInt NULL
  , writes BigInt NULL
  , row_count BigInt NULL 
  , physical_reads BigInt NULL
  ) 
End

If INDEXPROPERTY(object_id('dbo.FullAudit'), 'iSeqEvents', 'IsUnique') IS NULL
  Create Index iSeqEvents On dbo.FullAudit (event_time, FirstEventTimeOfSession, Event_Sequence)

If INDEXPROPERTY(object_id('dbo.FullAudit'), 'iUserTime', 'IsUnique') IS NULL
  Create Index iUserTime On dbo.FullAudit (server_principal_name, event_time)
GO
-------------------------------------------------------------------
-- this table logs operation and error messages in the database
--------------------------------------------------------------------

If Object_id('dbo.ProcessAuditLog') IS NULL
Begin
  CREATE TABLE dbo.ProcessAuditLog
  (
    MsgDate datetime2 default SYSDATETIME()
  , Msg nvarchar(max) NULL
  ) 
  create index iMsgDate on dbo.ProcessAuditLog(MsgDate)
End
GO
-- 
-- Depending on the edition, select the best compression option.
-- Compress only the tables in the schema .dbo
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
-- This function returns information about a file if it exists,
-- including its name components.
-- --------------------------------------------------------------------------------
USE FullQryAudit
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
    OUTER APPLY (Select * From sys.dm_os_enumerate_filesystem(Directory, FileNamePlain) Where fullPathAndName IS NOT NULL) as Info
    OUTER APPLY (Select Existing=1 Where Info.full_filesystem_path IS NOT NULL) as Existing
-- Select * From dbo.FileInfo ('D:\_Tmp\FullQryAudit\FullQryAudit_0_133728749432040000.Xel')
GO
Create or Alter Function Dbo.GetCurrentTargetFile (@SessionName Sysname)
Returns Table
as
Return
  -- Returns the current file of the target, to avoid removal before time
  SELECT 
    SessionName=s.name 
  , TargetName=t.target_name
  , FileName
  FROM 
    sys.dm_xe_sessions AS s
    JOIN
    sys.dm_xe_session_targets AS t
    ON   s.address = t.event_session_address 
     And t.target_name = 'event_file'
    CROSS APPLY (Select TgData=CAST(t.target_data AS XML) ) as TgData
    CROSS APPLY (Select FileName=TgData.value('(EventFileTarget/File/@name)[1]', 'NVARCHAR(MAX)')) AS FileName
  Where FileName Like '%'+@sessionName+'%'
GO
Create Or Alter Function dbo.FileCanBeDisposed ()
Returns Table
as
Return
  -- --------------------------------------------------------------------------------
  -- This function identifies the first file that is no longer the most recent.
  -- This is required to consider it safely disposable. 
  --
  -- This function returns the file that is the first one only if there are
  -- other trace files after it, because the last trace file is never deleted.
  -- --------------------------------------------------------------------------------
  Select full_filesystem_path, Ordre, nbfich 
  From
    (
    Select 
      Dir.full_filesystem_path
    , ordre=row_number() Over (order by Dir.full_filesystem_path)
    , nbFich=count(*) Over (Partition By NULL)
    FROM 
      Dbo.EnumsAndOptions as Opt
      CROSS APPLY sys.dm_os_enumerate_filesystem(Opt.RepFichTrc, MatchFichTrc) as Dir -- take care of possible recursion!
    Where 
      Dir.full_filesystem_path Like RepFichTrc+'FullQryAudit[_][0-9]%' -- remove recursion results if it happens
    ) as FichierEnOrdre
  Where Ordre=1 And nbFich>1 -- if the first file is followed by other, return it.
GO
Create Or Alter Function dbo.GetNextEvents (@fileName Nvarchar(256), @lastOffsetDone BigInt)
Returns Table
as
Return
  --------------------------------------------------------------------------------------------------------------
  --
  -- This function, originally part of the dbo.CompleteQueryAuditWithConnectionInfo procedure,
  -- was extracted from the query inserting into #Tmp to be reused as a tool
  -- for examining recorded events without disrupting the current processing state.
  -- The parameters are only used when exploring events for testing purposes;
  -- otherwise, the function continues from the latest events in dbo.ExtEvProcessedChkPoint.
  --
  --------------------------------------------------------------------------------------------------------------

  Select 
    ev.file_name
  , ev.file_Offset
  , Event_name
  , Event_Sequence 
  , Ev.Event_time
  , ev.event_data
  from
    (Select *, pFileName=@fileName, pLastOffsetDone=@lastOffsetDone From Dbo.EnumsAndOptions) AS opt
    OUTER APPLY
    (
    -- We are fortunate that sys.fn_xe_file_target_read_file provides events in order by their Offset.
    -- Tests confirmed that once events with an offset are read, no new events are added to that offset.
    -- This OUTER APPLY confirms whether there is still something to read in the file,
    -- meaning whether a new offset is found after the last offset.
    Select E.file_name, LastOffsetDone=E.last_Offset_done
    From 
      (
      Select Top 1 File_Name, last_Offset_done From dbo.ExtEvProcessedChkPoint Where pfileName Is NULL Order by ChkPointTime desc
      UNION ALL
      Select File_Name=pfileName, last_Offset_done=plastOffsetDone Where pfileName IS NOT NULL
      ) As E 
      CROSS APPLY (Select * From dbo.FileInfo(E.file_name) Where Existing=1) as Existing -- file must exists
      -- Limit to a single row, as we only want to confirm the existence of the file and its offset.
      cross apply (Select top 1 * From sys.fn_xe_file_target_read_file(E.file_name, NULL, E.file_name, E.last_Offset_done)) as F -- otherwise the is an error here
    ) as SameFileFollowUp 
    CROSS APPLY
    ( 
    -- This UNION ALL performs a switch of returned values:
    -- The first query returns the existing file with the latest offset
    --     if a new offset is found in the last file read.
    -- The second query returns the next file
    --     provided there is a next file and the last file read (outer apply)
    --     returned nothing.

    -- If both queries in the union return nothing, the CROSS APPLY (alias startP)
    --     that wraps them returns nothing, and nothing will be inserted into #Tmp.

    Select -- if some data exists in the same file after the offset tested
      SameFileFollowUp .file_name
    , FileNameForOffsetOnly=SameFileFollowUp .file_name 
    , SameFileFollowUp .LastOffsetDone -- NULL fera la job
    Where SameFileFollowUp .file_name is NOT NULL

    UNION ALL 
    Select NextF.file_name, FileNameForOffsetOnly=NULL, LastOffsetDone=NULL
    From
      -- Nothing more must be found from the previous file, otherwise this query stops
      (Select FichierAvantTermine=1 Where SameFileFollowUp.file_name is NULL) as FichierAvantTermine 
      CROSS JOIN
      ( -- The next file in the directory after the last processed one, or the very first file if none have been processed yet.
      Select top 1 File_Name=Dir.full_filesystem_path 
      FROM 
        ( 
        -- If there is no last file in dbo.EvenementsTraites (e.g., when the procedure starts),
        -- begin processing from the start of the file list.
        Select file_name='' Where Not exists (Select * From dbo.ExtEvProcessedChkPoint) -- point de départ si rien traité
        UNION ALL
        -- If a file exists in in dbo.EvenementsTraites, take the latest one to find the next file on disk.
        Select top 1 file_name From dbo.ExtEvProcessedChkPoint Order by ChkPointTime desc 
        ) as ET
        -- Retrieve the subsequent files. Caution: sys.dm_os_enumerate_filesystem may recurse into subdirectories,
        -- for example, when a subdirectory of trace files is placed in the current directory.
        -- This situation is avoided by ensuring in the WHERE clause that the results are limited to the same directory 
        -- and the specific type of files being searched.
        JOIN sys.dm_os_enumerate_filesystem(Opt.RepFichTrc, Opt.MatchFichTrc) as Dir 
        ON  
            Dir.full_filesystem_path > ET.file_name -- first file or next one
        And Dir.full_filesystem_path Like RepFichTrc+'FullQryAudit[_][0-9]%' -- forbid recursion effect of dm_os_enumerate_filesystem
        -- Eliminate the rare case where the next file might be found empty while there are other non-empty files after it.
        -- This is likely due to an interruption or resumption of the trace.
        And Exists (Select * From sys.fn_xe_file_target_read_file(Dir.full_filesystem_path, NULL, NULL, NULL))
      Order By Dir.full_filesystem_path 
      ) as NextF
    ) as StartP -- starting point for next set of events
    CROSS APPLY -- Get events details from target, limited to file found, at offset when 
    (
    Select event_data = xEvents.event_data, Event_name, Event_Sequence, F.file_name, F.file_offset, Event_time
    FROM 
      sys.fn_xe_file_target_read_file(StartP.file_name, NULL, StartP.FileNameForOffsetOnly, StartP.LastOffsetDone) as F 
      CROSS APPLY (SELECT CAST(event_data AS XML) AS event_data) AS xEvents
      CROSS APPLY (Select event_name = xEvents.event_data.value('(event/@name)[1]', 'varchar(50)')) as Event_name
      CROSS APPLY (Select Event_Sequence = xEvents.event_data.value('(event/action[@name="event_sequence"]/value)[1]', 'bigint')) as Event_Sequence
      CROSS APPLY (select event_time = xEvents.event_data.value('(event/@timestamp)[1]', 'datetime2(7)') AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time') as Event_time
    ) as ev
go
-- ------------------------------------------------------------------------------------------------------------
-- This table is updated by dbo.CompleteQueryAuditWithConnectionInfo
-- Events are unique by Session_id, FirstEventTimeOfSession, event_sequence
--
-- Its purpose is to distinguish session_id by event session run, because event_sequence
-- resets to one when a new run of FullQryAudit event session happen (after a shutdown, because it is autostart
-- or after a explicit manual restart
--
-- see more comments in dbo.CompleteQueryAuditWithConnectionInfo
-- ------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS dbo.FirstEventTimeOfSession;
CREATE TABLE dbo.FirstEventTimeOfSession
(
  FirstEventTimeOfSession DATETIME DEFAULT Getdate()
);

INSERT INTO dbo.FirstEventTimeOfSession VALUES (DEFAULT);
go
--------------------------------------------------------------------------------------------------------------
--
-- This function extracts information from user events originating from the logon trigger,
-- which will be needed to update the connection history table.
-- 
--------------------------------------------------------------------------------------------------------------
Create Or Alter Function dbo.ExtractConnectionInfoFromEvents (@event_data as Xml)
Returns Table
as
Return
Select 
  J.LoginName, J.LoginTime, J.Session_id, J.client_net_address, J.client_app_name
, Stable.FirstEventTimeOfSession
, UserData, UserDataBin, UserDataHexString, event_data
From 
  (Select event_data=@event_data) as Prm 
  -- user data is stored in the events as a hex string representation
  CROSS APPLY (SELECT UserDataHexString=event_data.value('(event/data[@name="user_data"]/value)[1]', 'nvarchar(max)')) AS UserDataHexString
  -- hex string conversion to varbinary
  CROSS APPLY (SELECT UserDataBin = CONVERT(VARBINARY(MAX), '0x'+UserDataHexString, 1)) as UserDataBin
  -- convert text concealed in varbinary from the trigger
  CROSS APPLY (Select UserData=CAST(UserDataBin as NVARCHAR(4000))) as UserData
  -- extract JSON values from UserData
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
  ) as J
  -- this column help discriminate in Dbo.ConnectionsHistory, (ConnectionHistory) session login events
  -- that belongs to different run if extended session FullQryAudit
  CROSS JOIN dbo.FirstEventTimeOfSession as Stable
GO
--Drop Sequence if Exists dbo.SeqImport
go
If OBJECT_ID('Dbo.SeqImport') IS NULL 
  Create Sequence dbo.SeqImport as BigInt Start With 1 Increment by 1; 
go
-- this function's use is to turn on some tracing capabilities of source data processed
-- by the stored proc.  When set to off (0) run code to recreate the table below.
Create Or Alter Function dbo.ModeDebug () 
Returns int 
Begin 
 Return 0 -- default for production
End
GO
-- this table have 2 uses.  First it supply columns definition for the #tmp table used in 
-- Dbo.CompleterAudit. If the function dbo.ModeDebug()=0, run code below to recreate the table.
If dbo.ModeDebug()=0 Drop table if exists dbo.TraceDataModel
GO
Create table dbo.TraceDataModel
(
  SeqImport Bigint
, file_name nvarchar(260) NOT NULL -- selon donc sys.fn_xe_file_target_read_file
,	file_Offset bigint NOT NULL -- selon donc sys.fn_xe_file_target_read_file
, event_name nvarchar(128)
, Event_Sequence BigInt
, event_time datetimeoffset(7) NULL
, event_data XML NULL
)
Go
-------------------------------------------------------------------------------
--
-- This procedure is the main processing unit of QueryAuditToolForMsSql
-- It managed extented events target file of extended events session FullQryAudit
-- by reading events by one file at the time
-- It extracts events, separate login events to maintain an Connection history 
-- from login events
-- It reads again the events to extract SQL Queries and add to them connection info
-- namely client_net_address and client_app_name, from connection history
-- It checks for completed processed file to drop and does the cleanup
-- of deprecated connection, ans a final cleanup of stuff beyond the 45 days retention date
--
--------------------------------------------------------------------------------------------
Create or Alter Proc dbo.CompleteQueryAuditWithConnectionInfo
as
Begin
  Set nocount on

  Declare @StartExEvSessIfNot Nvarchar(max)
  Select @StartExEvSessIfNot =[StartExtendedSession] From Dbo.EnumsAndOptions
  Exec (@StartExEvSessIfNot)

  declare @CatchPassThroughMsgInTx table (msg nvarchar(max))

  If Exists (Select * from FullQryAudit.dbo.ShowLastJobStatus Where Status <> 'Succeeded')
  Begin
    Declare @MsgStart Nvarchar(4000)
    Declare @br nvarchar(5) = '<br>'
    Set @MsgStart = 
    N'<body>FullQryAudit Job is <b><u>NOW RESTARTED AND RUNNING</u></b> '+@br+@br+
    N'Please check reason of previous Shutdown of FullQryAudit Job with query:'+@br+@br+
    N'<b>Select * from FullQryAudit.dbo.ShowLastJobStatus<b> </body>'
    Exec dbo.SendEmail @msg=@MsgStart, @now=0
  End

  Begin Try

  Drop table if Exists #RcCount
  Create table #RcCount (name sysname, cnt bigint)
  
  Drop table if Exists #tmp
  Select Top 0 -- create the table with top 0 (to get only the model, no rows) and select into.
    file_name 
  ,	file_Offset    
  , event_name     
  , Event_Sequence 
  , event_time     
  , event_data     
  Into #Tmp
  From dbo.TraceDataModel

  While (1=1) -- this stored proc is meant to run forever, with some waitfor to slowdown where there is nothing to do
  Begin

    Truncate table #tmp -- store events in #tmp to do more than one actions on it
    Insert into #tmp
    Select 
      ev.file_name
    , ev.file_Offset
    , ev.Event_name
    , ev.Event_Sequence 
    , Ev.Event_time
    , ev.event_data
    From 
      -- This function refers to dbo.ExtEvProcessedChkPoint for it parameters
      -- parameters are intended to allow derogation of event read order, by specifying the file and event_sequence
      -- which is useful for debugging pourposes
      dbo.GetNextEvents(null, null) as Ev 
    Option (maxDop 1)

    -- If no new events are found into the current target, wait.
    If @@rowcount=0 
    Begin
      -- @@rowcount=0 is the proof that there is no new event in the current file, and no newer file than 
      -- the one I tried to access (which means that extended session FullQryAudit didn't flush events at all yet)
      Waitfor Delay '00:00:05' 
      Continue 
    End

    -- When the file is first read into #Tmp, if the trace was restarted, we took the event_time of the first event
    -- of the file (Event_sequence=1), and this value holds true as long as no other trace is started
    -- which implicitely means that it is going to happen only with a new file. 
    -- It is possible that many files may exists for a same event_session but only one will have event_sequence = 1
    -- So we only update FirstEventTimeOfSession when this happens
    Update B
    Set FirstEventTimeOfSession = Event_time -- set a new date 
    From 
      -- If event_sequence = 1 which must happen only once in the target of a trace file
      -- I limit the result to the first row found (optimization)
      -- If it is not there, the derived table is empty which "kills" the update (no row to join), so no update
      (Select Top 1 event_time From #Tmp Where event_sequence=1 Order by event_time) as Event_time
      CROSS JOIN dbo.FirstEventTimeOfSession as B
      
    -- store source data in case of the need for debug.
    declare @SeqImport BigInt 
    Set @SeqImport = Next Value For dbo.SeqImport

    Insert into dbo.TraceDataModel -- only insert if function dbo.ModeDebug() = 1
    Select *
    From
      -- could it be done without @SeqImport if "Next Value For dbo.SeqImport" could be in place of @SeqImport
      (Select SeqImport=@SeqImport Where dbo.ModeDebug()=1) as SeqImport
      CROSS JOIN #Tmp


    BEGIN TRANSACTION -- keep coherent changes that recover info from event files and ongoing steps of processing

    -- add connection events extracted from trace to Dbo.ConnectionsHistory
    -- this table will allow to match connection info with queries.
    Insert Into Dbo.ConnectionsHistory
      (LoginName, Session_id, LoginTime, client_net_address, client_app_name, FirstEventTimeOfSession,  Event_Sequence)
    Select Distinct J.LoginName, J.Session_id, J.LoginTime, J.client_net_address , J.client_app_name, J.FirstEventTimeOfSession, Tmp.Event_Sequence
    From 
      (Select * from #Tmp as Tmp Where Tmp.event_name = 'user_event') as Tmp
      CROSS APPLY dbo.ExtractConnectionInfoFromEvents (Tmp.Event_Data) as J
      -- Only one process performs the insert, and the Not Exists clause provides resilience in case a major failure occurs,
      -- allowing the process to be restarted without duplicating data.
    Where
      Not Exists 
      (
      Select * 
      From Dbo.ConnectionsHistory CE 
      Where 
            CE.Session_id = J.Session_id 
        And CE.FirstEventTimeOfSession = J.FirstEventTimeOfSession
        And CE.event_sequence = Tmp.Event_Sequence
      )            
    --select * from Dbo.ConnectionsHistory order by Session_id, FirstEventTimeOfSession, event_sequence, loginTime

    -- This table is central to target file processing in the proper order. We need to know what is done to 
    -- start from there to do next.
    Insert into dbo.ExtEvProcessedChkPoint (file_name, last_Offset_done, FirstEventTimeOfSession)
    Select 
      EvInfo.file_name, EvInfo.last_offset_done, FT.FirstEventTimeOfSession
    From
      Dbo.FirstEventTimeOfSession as FT -- reference value to keep
      -- get last offset of the file to continue from there. In this procedure extended events are read from 
      -- one single file at the time and the events belong to the extended session
      -- so the file_name value is the same everywhere, but we want a single row 
      -- containing the file_name and the last_offset, and to avoid a group by
      -- we do file_name=max(file_name) to get the file_name
      CROSS APPLY 
      (
      Select file_name=MAX(file_Name), last_offset_done=MAX(file_offset)
      From #Tmp -- dbo.GetNextEvents process only one file at the time
      ) as EvInfo
    Where 
      not Exists 
      (
      Select * 
      From dbo.ExtEvProcessedChkPoint ES 
      Where Es.file_name = EvInfo.file_name 
        And Es.last_offset_done = EvInfo.Last_offset_done
      )
    -- Select * From dbo.ExtEvProcessedChkPoint order by ChkPointTime desc

    declare @DebutPourProfiler nvarchar(max)
    Select @DebutPourProfiler  = 'Declare @x sysname; set @x='''+file_name+' '+str(file_offset)+''''
    From (Select top 1 file_name, file_offset from #Tmp order by file_name desc, file_offset desc) as x
    Exec (@DebutPourProfiler )

    -- finally we complete full audit info combining connection info from connection events with SQL events
    -- we also specify event order info, and performance info.
    -- in this table event_sequence missing are connection events (so there is gap in event_sequence).
    Delete #RcCount Where name = 'insertAuditComplet' 
    Insert into dbo.FullAudit 
    (
      server_principal_name
    , session_id
    , event_time
    , FirstEventTimeOfSession
    , event_sequence
    , database_name
    , Client_net_address
    , client_app_name
      --, sql_batch
      --, line_number
    , statement
    , DurMicroSec
    , cpu_time
    , physical_reads
    , Logical_reads
    , Writes
    , Row_Count
    )
    SELECT 
      R.server_principal_name
    , R.session_id
    , R.event_time
    , R.FirstEventTimeOfSession
    , R.event_sequence
    , RC.database_name
    , Client_net_address.Client_net_address
    , client_app_name.client_app_name
    , R.statement 
      --, sql_batch
      --, line_number
    , R.DurMicroSec
    , R.cpu_time
    , R.physical_reads
    , R.Logical_reads
    , R.Writes
    , R.Row_Count
    From
      (
      Select 
        server_principal_name = Tmp.event_data.value('(event/action[@name="server_principal_name"]/value)[1]', 'varchar(50)')
      , session_id = Tmp.event_data.value('(event/action[@name="session_id"]/value)[1]', 'int')
      , Stable.FirstEventTimeOfSession
      , Tmp.event_time 
      , Tmp.Event_Sequence
      , database_name = Tmp.event_data.value('(event/action[@name="database_name"]/value)[1]', 'varchar(50)')
      -- voir commentaire si on veut tracer les instructions des modules
      --, line_number = Tmp.event_data.value('(event/data[@name="line_number"]/value)[1]', 'int') 
      , statement = Tmp.event_data.value('(event/data[@name="statement"]/value)[1]', 'nvarchar(max)') 
      , DurMicroSec = Tmp.event_data.value('(event/data[@name="duration"]/value)[1]', 'bigint')
      , cpu_time = Tmp.event_data.value('(event/data[@name="cpu_time"]/value)[1]', 'int')
      , logical_reads = Tmp.event_data.value('(event/data[@name="logical_reads"]/value)[1]', 'int')
      , writes = Tmp.event_data.value('(event/data[@name="cpu_time"]/value)[1]', 'int')
      , row_count = Tmp.event_data.value('(event/data[@name="row_count"]/value)[1]', 'int')
      , physical_reads = Tmp.event_data.value('(event/data[@name="physical_reads"]/value)[1]', 'int')
      From 
        -- we don't keep connection events, since their info is merged with Sql events
        (Select * from #Tmp as Tmp Where Tmp.event_name <> 'user_event') as Tmp
        -- keep in data FirstEventTimeOfSession to discriminate extended sessions, event_sequence and the session_id
        CROSS JOIN Dbo.FirstEventTimeOfSession as Stable 
      ) as R
      CROSS APPLY (Select Database_Name=ISNULL(R.database_name, 'nom de base de données absent')) as RC
      --
      -- Here we deal with the fact that a same session (session_id) can be closed and reopen by differents users/processes
      -- Connection info to be added to queries must be matched in time with the previous connection that
      -- match the query.
      --
      -- A Sql queries matches with the first connection with same session_id that is found to be closer in event
      -- order which is: Session_id, FirstEventTimeOfSession desc, event_Sequence desc
      --
      -- The session_id must always match, and if FirstEventTimeOfSession do not we go to the previous where it is, 
      -- to the latest event_sequence
      --
      -- FirstEventTimeOfSession help descriminate sessions, because event_Sequence restarts to 1 when 
      -- extended events session restarts, typically when the server restart, 
      -- or if the extended events session is stopped/restarted
      --
      -- le Outer apply is a fallback mecanism in case of session_id existed before the extended events session started
      -- a rare case is that the session existed, closed and there is no more session_id, before the trace.
      -- This cases only happen at the very start of extended events sessions

      OUTER APPLY 
      (
      Select TOP 1 Hc.client_app_name, Hc.Client_net_address 
      From FullQryAudit.Dbo.ConnectionsHistory as Hc
      Where 
          Hc.session_id = R.session_id -- session_id to link with login events to queries
          -- events must belongs to the same extended event sessions or a previous one
      And Hc.FirstEventTimeOfSession <= R.FirstEventTimeOfSession 
          -- if same extended event session (mostly) with a previous sequence
          -- or if there isn't a previous sequence, in the previous FirstEventTimeOfSession 
      And (Hc.event_Sequence < R.event_Sequence OR Hc.FirstEventTimeOfSession < R.FirstEventTimeOfSession)
      -- ensure we get only the most recents connection event of both case.
      Order by Session_id, FirstEventTimeOfSession desc, event_Sequence desc
      ) Hc
      -- If the session ins't in the events it is because it login existed BEFORE the extended session started
      -- or before in previous extended session 
      -- we get the existing info from sys.dm_exec_connections. In that context the user can modify the hotsname() returned
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
      -- 1) Client connections was found in events. Even if events are old, user_event 
      --    reporting connections are of the same age too.
      --
      -- Cases 2 and 3 are very rare.
      -- 2) If not recorded in events, this may be that extended session was started after the connection. This is quite unlikely
      --    because events and trigger are meant to be active at all time. In that case if session was started after, 
      --    get it from actual sys.dm_exec_ views, which is quite accurate, but not 100% reliable
      -- 3) If not found, give an explantion why the spid isn't there anymore. 
      CROSS APPLY (Select client_app_name = COALESCE(hc.client_app_name, '(Cur)-> '+Ci.Program_name, 'Client program disconnected')) as client_app_name
      CROSS APPLY (Select client_net_address = COALESCE(hc.client_net_address, '(Cur)-> '+Ci.client_net_Address, 'session is gone')) as client_net_Address

    Where
      -- We manage the processed events files and delete them. If an issue occurs and they are not deleted, this Not Exists clause
      -- prevents duplication errors. Additionally, if event files are restored, their reprocessing will not generate duplicates.
      Not Exists
      (
      Select * 
      From dbo.FullAudit AC
      Where AC.event_time = R.event_time 
        AND AC.FirstEventTimeOfSession = R.FirstEventTimeOfSession
        And AC.event_sequence = R.event_Sequence
      )

    /* ======================================================================================
    This audit can be more deep, by tracing all queries of SQL modules
    In that case we could put module SQL code in SQL+Batch only
    When line number data is 1, get all the module code.
    Actually this isn't done and statetment is all the module code
    This extra code do that

    OUTER APPLY 
    (
    Select Sql_batch= ev.event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') 
    Where line_number = 1
    ) as Sql_Batch
    */

    -- record the number of events processed, for throttling purpose
    Insert into #RcCount(name, cnt) Values ('insertAuditComplet', @@rowcount)

    -- Check if a file to process disappaered and notify it to the log
    Insert into dbo.ProcessAuditLog (Msg)
    Select Msg=LostFileMsgPrefix+Diff.file_name
    From
      (Select LostFileMsgPrefix, RepFichTrc, MatchFichTrc From Dbo.EnumsAndOptions) as MsgPrefix
      CROSS APPLY
      (
      Select top 1 file_Name from dbo.ExtEvProcessedChkPoint Order By ChkPointTime desc
      Except
      Select full_filesystem_path  FROM sys.dm_os_enumerate_filesystem(RepFichTrc, MatchFichTrc) -- attention recursion possible!
      Where full_filesystem_path Like RepFichTrc+'FullQryAudit[_][0-9]%' -- pour ôter résultats de récursion possible
      ) as Diff
    -- the message was generated because the issue is verified
    If @@ROWCOUNT>0 
    Begin
      Declare @msgPerte nvarchar(4000)
      Select @msgPerte=E.GenericLostFileMsg From Dbo.EnumsAndOptions as E
      Insert into dbo.ProcessAuditLog (Msg) Values (@msgPerte)
    End

    Declare @aFileToDel nvarchar(256)
    Select @aFileToDel = Autres.full_filesystem_path
    From
      (Select * From dbo.EnumsAndOptions) AS opt
      CROSS APPLY (select top 1 file_name From dbo.ExtEvProcessedChkPoint Order by ChkPointTime desc) Dernfich
      -- When I switch to a new file, so the previous file exists, it is safe to delete it
      CROSS APPLY 
      (
      Select top 1 Autres.full_filesystem_path
      From 
        sys.dm_os_enumerate_filesystem(Opt.RepFichTrc, opt.MatchFichTrc) Autres -- attention récursion possible!
      Where Autres.full_filesystem_path < DernFich.file_name
        And Autres.full_filesystem_path Like Opt.RepFichTrc+'FullQryAudit[_][0-9]%' -- pour ôter résultats de récursion possible
      ) as Autres
    Where Autres.full_filesystem_path IS NOT NULL
    -- if condition is verified, proceed
    If @@ROWCOUNT > 0
    Begin
      Insert into dbo.ProcessAuditLog(Msg)  Select 'Suppression de '+@aFileToDel
      Exec master.sys.xp_delete_files @afileToDel
    End

    -- We do not want the recent connections history table to grow indefinitely.
    -- We know that if a session_id exists in multiple copies (login/logout), they are not necessarily all
    -- from the same user, as happens during reconnections.
    -- Therefore, we need to find the most recent login event.
    -- Once the most recent connections have been linked to queries, the connections with the same session_id
    -- from the same extended event session no longer serve a purpose. Thus, we remove them.
    -- It is sufficient to keep only the most recent session_ids for each extended event session.
    

    -- Select * From Dbo.ConnectionsHistory as C Order by Session_id, FirstEventTimeOfSession, event_sequence
    Delete C
    From
      (
      Select 
        Session_id
      , FirstEventTimeOfSession
      , event_sequence
      -- Assign a descending sequence number for the same session_id so that
      -- the most recent entry corresponds to the latest extended event session 
      -- and the most recent event sequence for this session.
      , SessionIdInstance = ROW_NUMBER() Over (Partition By Session_id, FirstEventTimeOfSession Order by event_Sequence Desc)
      From Dbo.ConnectionsHistory
      ) as Ord
      JOIN 
      Dbo.ConnectionsHistory as C
      ON  Ord.SessionIdInstance > 1 -- toutes les autres ocurences passées de ce session_id
      And C.Session_Id = Ord.Session_id
      And C.FirstEventTimeOfSession = Ord.FirstEventTimeOfSession
      And C.event_Sequence = Ord.event_sequence

    -- Do some cleanup to limit retention which is designed here to be 45 days
    -- Delete data before this time
    -- Limit the size of the delete in case some cleanup would've been missed from a previous version
    -- The size is more than enough to cover many insert into FullAudit (by experience)
    Delete TOP (100000) From dbo.FullAudit 
    Where event_time < DATEADD(dd, -45, getdate()) 

    -- normally a server is always on, we have only one run of FullQryAudit, and normally a single 
    -- FirstEventTimeOfSession. If we have more than one, there will be deleted 
    -- with older that 45 days
    Delete C
    From 
      (
      Select *, SessionHistoryRank=DENSE_RANK() Over (Order By FirstEventTimeOfSession Desc)
      From 
        Dbo.ConnectionsHistory
      ) as C
    Where SessionHistoryRank > 1
      And FirstEventTimeOfSession < DATEADD(dd, -45, getdate()) 

    Delete From dbo.ExtEvProcessedChkPoint 
    Where ChkPointTime < DATEADD(dd, -45, getdate()) 

    Delete From dbo.ProcessAuditLog
    Where MsgDate < DATEADD(dd, -45, getdate()) 

    Delete Cn
    From Dbo.ConnectionsHistory as Cn
    Where Cn.LoginTime < DATEADD(dd, -45, getdate()) 

    Commit -- Keep this batch of events coherent 

    -- We dont want to do wait in transactions, because when testing
    -- and trying to check table content, this extended wait adds up when trying to get results
    If Exists (Select * From #RcCount Where name='insertAuditComplet'  and cnt < 100)
       And Not Exists (Select * From Dbo.FileCanBeDisposed()) 
    Begin
      Waitfor Delay '00:00:15' 
    End

    If Not Exists 
       (
       Select * 
       From 
         Dbo.EnumsAndOptions as E 
         CROSS JOIN sys.dm_xe_sessions
       Where name = E.JobName
       )
     Raiserror('Session FullQryAudit was detected as stopped', 11, 1);

    If Not Exists 
       (
       Select * 
       From 
         Dbo.EnumsAndOptions as E 
         CROSS JOIN sys.server_triggers as T
       Where name = 'Logon'+jobName+'Trigger'
         And T.is_disabled = 0
       )
     Raiserror('Session LogonFullQryAuditTrigger was detected as missing or disabled', 11, 1);

  End -- While forever

  End Try
  Begin Catch
    IF @@TRANCOUNT > 0
    BEGIN
       ROLLBACK TRANSACTION;
    END
    Declare @msg nvarchar(max)
    Select @msg='Error from FullQryAudit.Dbo.CompleteQueryAuditWithConnectionInfo '+nchar(13)+nchar(10)+Fmt.ErrMsg
    From 
      (Select ErrMsgTemplate From Dbo.EnumsAndOptions) as E
      CROSS APPLY dbo.FormatRunTimeMsg (E.ErrMsgTemplate, ERROR_NUMBER (), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE (), ERROR_MESSAGE ()) as Fmt
    Insert into @CatchPassThroughMsgInTx Values (@Msg)
    Insert into dbo.ProcessAuditLog (msg) Select Msg From @CatchPassThroughMsgInTx
    If Exists(Select * From sys.Dm_xe_sessions Where name = N'FullQryAudit')
      Exec ('ALTER EVENT SESSION FullQryAudit ON SERVER STATE = Stop')
    Exec dbo.SendEmail @msg
    RAISERROR(@msg,16,1) WITH Log -- erreur goes to SQL Server ErrorLog
  End Catch
  
End -- dbo.CompleteQueryAuditWithConnectionInfo
go
Create or Alter Function dbo.HostMostUsedByLoginName(@LoginName sysname = 'SomeOne')
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
      FROM FullQryAudit.Dbo.ConnectionsHistory
      Where LoginName=P.PrmUtil
      Order By LoginName, LoginTime Desc
      ) As DixDerniersPostesParLoginName
    ) as DecompteOrdis
  ) as LigneFreq
Where nbOcc_Client_net_address=plusFrequent
go
USE [msdb]
GO
/****** Object:  Job FullQryAudit    Script Date: 2024-06-29 09:23:36 ******/
Begin Try 

  BEGIN TRANSACTION;

  DECLARE @ReturnCode INT = 0
  DECLARE @jobId BINARY(16)
  Declare @JobName sysName
  Declare @context sysname
  Select @jobname = 'FullQryAudit'
  Select @jobId = job_id From msdb.dbo.sysjobs where name =@JobName
  
  If @jobId IS NOT NULL
  Begin
    Set @context = 'delete la job'
    EXEC @ReturnCode =  msdb.dbo.sp_delete_job @job_name=@JobName
    IF (@ReturnCode <> 0) Raiserror ('Return code %d frommsdb.dbo.sp_delete_schedule ',11,1,@returnCode)

    If exists (Select * From msdb.dbo.sysjobschedules where job_id=@jobId)
    Begin
      EXEC sp_detach_schedule @job_name = @JobName, @schedule_name = N'FullQryAuditAutoRestart';
      Exec @ReturnCode =  msdb.dbo.sp_delete_schedule @schedule_name ='FullQryAuditAutoStart'
      IF (@ReturnCode <> 0) Raiserror ('Return code %d frommsdb.dbo.sp_delete_schedule ',11,1,@returnCode)
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
  IF (@ReturnCode <> 0) Raiserror ('Return code %d frommsdb.dbo.sp_add_job ',11,1,@returnCode)

  Set @context = 'ajout du step Run'
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
  EXECUTE [dbo].[CompleteQueryAuditWithConnectionInfo]
End Try
Begin catch
  Declare @msg nvarchar(max)
  Select @msg = F.ErrMsg
  From 
    FullQryAudit.dbo.FormatCurrentMsg (NULL) as F
  Print @msg
End catch	
', 
		  @database_name=N'FullQryAudit', 
		  @flags=4
  IF (@ReturnCode <> 0) Raiserror ('Return code %d frommsdb.dbo.sp_add_job_Step ',11,1,@returnCode)

  Set @context = 'Add schedule for FullQryAuditAutoStart'
  EXEC @ReturnCode = msdb.dbo.sp_add_schedule 
    @schedule_name=N'FullQryAuditAutoStart',
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
  IF (@ReturnCode <> 0) Raiserror ('Return code %d frommsdb.dbo.sp_add_schedule pour FullQryAuditAutoStart',11,1,@returnCode)

  Set @context = 'Attach schedule for FullQryAuditAutoStart'
  EXEC sp_attach_schedule @job_name = @JobName, @schedule_name = N'FullQryAuditAutoStart';

  Set @context = 'Add schedule for FullQryAuditAutoRestart'
  EXEC @ReturnCode = msdb.dbo.sp_add_schedule 
  @schedule_name=N'FullQryAuditAutoRestart', 
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
  IF (@ReturnCode <> 0) Raiserror ('Return code %d frommsdb.dbo.sp_add_schedule pour FullQryAuditAutoRestart',11,1,@returnCode)

  Set @context = 'Attach schedule for FullQryAuditAutoRestart a la job'
  EXEC sp_attach_schedule @job_name = @JobName, @schedule_name = N'FullQryAuditAutoRestart';

  Set @context = 'Set (local) as job server for the job'
  EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
  IF (@ReturnCode <> 0) Raiserror ('Return code %d frommsdb.dbo.sp_add_jobserver ',11,1,@returnCode)

EXEC msdb.dbo.sp_update_job @job_id=@jobId,
		@notify_level_email=2, 
		@notify_level_page=2, 
		@notify_email_operator_name=N'FullQryAudit_Operator'

  Set @context = 'Start the job'
  EXEC dbo.sp_start_job @JobName;
  IF (@ReturnCode <> 0) Raiserror ('Return code %d frommsdb.dbo.sp_start_job ',11,1,@returnCode)

  COMMIT
End Try
Begin catch
  Declare @msg nvarchar(max)
  Select @msg = @context + nChar(10)+F.ErrMsg
  From 
    FullQryAudit.dbo.FormatCurrentMsg (NULL) as F
  Print 'Error when defining or lauching the job: '+@msg
  ROLLBACK
End catch
GO
Use FullQryAudit
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
    dbo.FullAudit
    cross apply (Select F=cast(SUBSTRING(statement,12,3) as int)) as f
    cross apply (select S=cast(SUBSTRING(statement,20,5) as int)) as s
  where statement like 'SELECT Fen=%,Seq=%' 
  ) as r
Where S-bs<>@diff -- should be 1 if no gap or missing 
go
Select MsgVersion From dbo.version
GO
/* -- useful queries for debug
--SELECT sqlserver_start_time AS ServerRestartTime FROM sys.dm_os_sys_info;
select * from dbo.FirstEventTimeOfSession
select * from Dbo.ConnectionsHistory order by FirstEventTimeOfSession desc, Session_id, event_sequence desc
select * from dbo.FullAudit Order by event_time desc
Select * from FullQryAudit.dbo.ShowLastJobStatus 
select event_time, FirstEventTimeOfSession, event_sequence, Client_net_address,session_id, client_app_name, database_name, statement 
from dbo.FullAudit 
where Client_net_address like 'Cur%'
Order by event_time desc
*/
