-- table pour suivre les vérifications et les alertes
If OBJECT_ID('tempdb..VerifAuditReq') IS NULL
  Select LastVerif=Cast (null as datetime2(7)), LastAlert=Cast (null as datetime2(7)) 
  Into tempDb..VerifAuditReq

Declare @Msg Nvarchar(4000) = NULL
Declare @timeToVerif Int = 0
Declare @timeToAlert Int = 0
Declare @ToolingForEmailPresent Int = 0
Select 
  @ToolingForEmailPresent=ToolingForEmailPresent
, @Msg=COALESCE(JobStopped+NCHAR(10)+ExEvSessionStopped, JobStopped, ExEvSessionStopped)
, @timeToVerif = TimeToVerif
, @TimeToAlert = TimeToAlert
From
  ( -- query stop here if AuditReq.dbo.SendEmail is not there
  Select ToolingForEmailPresent=1
  Where OBJECT_ID('AuditReq.dbo.SendEmail') IS NOT NULL
  ) as ToolingForEmailPresent
  CROSS APPLY -- query stop here if not next verif and @msg remains NULL
  (
  select TimeToVerif=1
  From Tempdb..VerifAuditReq 
  Where LastVerif is NULL Or Datediff(SS, LastVerif, Sysdatetime()) > 5
  ) as TimeToTest
  CROSS APPLY -- query stop here if last alert is within 15 min (useless to flood alert of the same message)
  (
  select TimeToAlert=1
  From Tempdb..VerifAuditReq 
  Where LastAlert is NULL Or Datediff(MI, lastAlert, Sysdatetime()) > 1
  ) as TimeToAlert
  OUTER APPLY -- if still running last alert not too close and time to check For Job stopped 
  (
  Select JobStopped='La tâche AuditReq est arrêté, voir son historique d''erreur'
  Where 
    Not Exists -- negate test condition to find the job running
    (
    Select *
    From 
      msdb.dbo.sysjobs as J
      JOIN 
      msdb.dbo.sysjobactivity AS A ON A.job_id = j.job_id
      Where J.Name='AuditReq' 
        And a.start_execution_date IS NOT NULL AND a.stop_execution_date IS NULL
    ) 
  ) As JobStopped
  OUTER APPLY -- if still running last alert not too close and time to check For extended event session stopped 
  (
  Select FlagExSessStop=1, ExEvSessionStopped='Extended Event Session AuditReq est arrêtée'
  Where Not Exists (Select * From sys.dm_xe_sessions Where name = 'AuditReq')
  ) ExEvSessionStopped

If @ToolingForEmailPresent =1 And @Msg IS NOT NULL 
Begin
  Exec Sp_executeSql N'Exec AuditReq.dbo.SendEmail @Msg', N'@Msg Nvarchar(4000)', @Msg
End

If @ToolingForEmailPresent=1 And  @timeToVerif=1 Or @timeToAlert=1
  Update VA WITH(Rowlock) 
  Set 
    LastVerif = NextVerifAt -- empêche les autres requêtes dans la meme sec d'agir
  , LastAlert = ISNULL(NewLastAlert, LastAlert) 
  From
    (
    Select 
      LastVerif, LastAlert -- column to update
    , TimeToVerif=@timeToVerif
    , TimeToAlert=@timeToAlert
    , Msg=@Msg 
    From Tempdb..VerifAuditReq
    ) as VA
    CROSS APPLY (Select NextVerifAt=DATEADD(SS, 1, Getdate())) as NextVerifAt
    OUTER APPLY 
    (
    Select NewLastAlert=SYSDATETIME()
    Where Msg IS NOT NULL And VA.TimeToVerif=1 And TimeToALert=1
    ) as NewLastAlert

Select vt=@ToolingForEmailPresent, tv=@timeToVerif, ta=@timeToAlert, Msg=@msg
, Lastverif, time=SYSDATETIME(), LastAlert
From tempdb..VerifAuditReq



------------------------------------------------------------------
DROP CERTIFICATE EmailCertForAuditReq
go
USE AuditReq
GO

CREATE OR ALTER PROCEDURE dbo.SendEmail @msg NVARCHAR(MAX)
With Execute As 'AuditReqUser'
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
GRANT EXECUTE ON MSdb.dbo.spExecuteSql to AuditUserReq
GRANT EXECUTE ON Dbo.SendEMail To Public
GO
