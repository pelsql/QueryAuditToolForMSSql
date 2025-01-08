-----------------------------------------------------------------------------
-- configurer au préalable le répertoire parent et le sous-répertoire d'audit
-----------------------------------------------------------------------------
Drop table if exists #RepAudit
Select maindir='D:\_tmp\', SubDirAudit='AuditReq', NewNaming='FullQryAudit'
Into #RepAudit
--------------------------------------------------------------------------------------------
-- If a job exists, delete it temporarily to allow replacing the code objects
--------------------------------------------------------------------------------------------
Use Msdb
Declare @profile_name sysname
Declare @account_name sysname
SET @profile_name = 'AuditReq_EmailProfile';
SET @account_name = lower(replace(convert(sysname, Serverproperty('servername')), '\', '.'))+'.AuditReq'
Exec msdb.dbo.sysmail_delete_account_sp  @account_name = @account_name
Exec msdb.dbo.sysmail_delete_profile_sp @profile_name = @profile_name
Exec msdb.dbo.sp_delete_operator @name = 'AuditReq_Operator'

DECLARE @ReturnCode INT = 0
DECLARE @jobId BINARY(16)
Declare @JobName sysName
Select @jobname = 'AuditReq'
Select @jobId = job_id From msdb.dbo.sysjobs where name = @JobName

If @jobId IS NOT NULL
Begin
  EXEC @ReturnCode =  msdb.dbo.sp_delete_job @job_name = @JobName
  IF (@ReturnCode <> 0) Raiserror ('Return code of %d from msdb.dbo.sp_delete_job ', 11, 1, @returnCode)

  If exists (Select * From msdb.dbo.sysjobschedules where job_id = @jobId)
  Begin
    EXEC msdb.dbo.sp_detach_schedule @job_Name = @JobName, @schedule_name = N'AuditReqAutoRestart';
    Exec @ReturnCode =  msdb.dbo.sp_delete_schedule @schedule_name = 'AuditReqAutoStart'
    IF (@ReturnCode <> 0) Raiserror ('Return code of %d from msdb.dbo.sp_delete_schedule ', 11, 1, @returnCode)
  End
End
GO
Use AuditReq
GO
IF EXISTS (select * from sys.server_triggers where name = 'LogonAuditReqTrigger')
Begin
  Exec ('DROP TRIGGER LogonAuditReqTrigger ON ALL SERVER;')
End
GO
IF USER_ID('AuditReqUser') IS NOT NULL 
    DROP USER AuditReqUser;
GO
IF SUSER_SID('AuditReqUser') IS NOT NULL 
    DROP LOGIN AuditReqUser;
GO
If Exists (Select * From Sys.dm_xe_sessions where name = 'AuditReq')
  ALTER EVENT SESSION AuditReq ON SERVER STATE = STOP
Else 
  Print 'EVENT SESSION AuditReq is already stopped, so no attempt to Stop'

-- If AuditReq Event Session exists, drop it 
If Exists(Select * From sys.server_event_sessions WHERE name = 'AuditReq')
  DROP EVENT SESSION AuditReq ON SERVER
Else 
  Print 'EVENT SESSION AuditReq does not exists, so no attempt to drop'
GO
Use AuditReq
GO
-- remove obsolete object
If Object_id('dbo.SeqExtraction') IS NOT NULL Drop Sequence dbo.SeqExtraction
GO
-- obsolete data to remove from previous versions
Drop table if exists dbo.EvenementsTraites

--------------------------------------------------------------------------------------------

If object_id('dbo.EvenementsTraitesSuivi') IS NOT NULL
  Exec Sp_rename 'dbo.EvenementsTraitesSuivi', 'ExtEvProcessedChkPoint'
GO
-- Upgrade to version 2.50: Remove this code after the upgrade since it applies to only one customer.
If INDEXPROPERTY(Object_id('dbo.ExtEvProcessedChkPoint'), 'iPasseFileName', 'isClustered') IS NOT NULL
  Drop Index iPasseFileName On dbo.ExtEvProcessedChkPoint;
If COL_LENGTH ('dbo.ExtEvProcessedChkPoint', 'NbTotalFich') IS NOT NULL 
  ALTER Table dbo.ExtEvProcessedChkPoint Drop Column NbTotalFich;
If COL_LENGTH ('dbo.ExtEvProcessedChkPoint', 'Passe') IS NOT NULL 
  ALTER Table dbo.ExtEvProcessedChkPoint Drop Column Passe;
If COL_LENGTH ('dbo.ExtEvProcessedChkPoint', 'File_Seq') IS NOT NULL 
  ALTER Table dbo.ExtEvProcessedChkPoint Drop Column File_Seq;
GO
-- Rename column for clarity, applicable to version 2.6.2 changes.
If COL_LENGTH ('dbo.ExtEvProcessedChkPoint', 'ExtEvSessCreateTime') IS NOT NULL 
  Exec sp_rename 'dbo.ExtEvProcessedChkPoint.ExtEvSessCreateTime', 'FirstEventTimeOfSession';

-- Add 'FirstEventTimeOfSession' column if missing, with a default value.
If COL_LENGTH ('dbo.ExtEvProcessedChkPoint', 'FirstEventTimeOfSession') IS NULL 
   And OBJECT_ID('dbo.ExtEvProcessedChkPoint') IS NOT NULL
Begin
  ALTER Table dbo.ExtEvProcessedChkPoint Add FirstEventTimeOfSession Datetime Not NULL Default '20000101';
End;
GO
If INDEXPROPERTY(Object_id('dbo.ExtEvProcessedChkPoint'), 'iDateSuivi', 'isClustered') IS NOT NULL
  Drop Index iDateSuivi ON dbo.ExtEvProcessedChkPoint
GO
IF COL_LENGTH ('dbo.ExtEvProcessedChkPoint', 'DateSuivi') IS Not NULL 
  Exec sp_rename 'dbo.ExtEvProcessedChkPoint.DateSuivi', 'ChkPointTime'

GO  
--------------------------------------------------------------------------------------------

If Object_Id('dbo.HistoriqueConnexions') IS Not NULL
  Exec Sp_rename 'dbo.HistoriqueConnexions', 'ConnectionsHistory'
GO
-- Add 'FirstEventTimeOfSession' column if missing, with a default value.
If COL_LENGTH ('dbo.ConnectionsHistory', 'FirstEventTimeOfSession') IS NULL 
   And OBJECT_ID('dbo.ConnectionsHistory') IS NOT NULL
Begin
  ALTER Table dbo.ConnectionsHistory Add FirstEventTimeOfSession Datetime Not NULL Default '20000101';
End;
GO

If INDEXPROPERTY(object_id('Dbo.ConnectionsHistory'), 'PK_HistoriqueConnexions', 'IsClustered') IS NOT NULL
  Alter table Dbo.ConnectionsHistory Drop constraint PK_HistoriqueConnexions

If INDEXPROPERTY(object_id('Dbo.ConnectionsHistory'), 'iExtendedSession', 'IsClustered') IS NOT NULL
  Drop index iExtendedSession On Dbo.ConnectionsHistory

If COL_LENGTH ('Dbo.ConnectionsHistory', 'ExtendedSessionCreateTime') IS Not NULL 
  Exec sp_rename 'Dbo.ConnectionsHistory.ExtendedSessionCreateTime', 'FirstEventTimeOfSession'

If INDEXPROPERTY(object_id('Dbo.ConnectionsHistory'), 'iHistoriqueConnexions', 'IsClustered') IS NOT NULL
  DROP INDEX iHistoriqueConnexions ON Dbo.ConnectionsHistory
--------------------------------------------------------------------------
While (1=1)
Begin
    Delete TOP (1000000) From dbo.AuditComplet
    Where event_time < DATEADD(dd, -45, getdate()) 
    If @@ROWCOUNT=0 Break Else Print 'Un autre delete'
End
GO
If Object_id('dbo.AuditComplet') IS NOT NULL
  Exec SP_Rename 'dbo.AuditComplet', 'FullAudit'
GO
If COL_LENGTH ('dbo.FullAudit', 'DurMicroSec') IS NULL 
  And OBJECT_ID('dbo.FullAudit') IS NOT NULL
  ALTER Table dbo.FullAudit Add DurMicroSec BigInt

If COL_LENGTH ('dbo.FullAudit', 'cpu_time') IS NULL 
  And OBJECT_ID('dbo.FullAudit') IS NOT NULL
  ALTER Table dbo.FullAudit Add cpu_time BigInt

If COL_LENGTH ('dbo.FullAudit', 'logical_reads') IS NULL 
  And OBJECT_ID('dbo.FullAudit') IS NOT NULL
  ALTER Table dbo.FullAudit Add logical_reads BigInt

If COL_LENGTH ('dbo.FullAudit', 'writes') IS NULL 
  And OBJECT_ID('dbo.FullAudit') IS NOT NULL
  ALTER Table dbo.FullAudit Add writes BigInt

If COL_LENGTH ('dbo.FullAudit', 'row_count') IS NULL 
  And OBJECT_ID('dbo.FullAudit') IS NOT NULL
  ALTER Table dbo.FullAudit Add row_count BigIntt

If COL_LENGTH ('dbo.FullAudit', 'physical_reads') IS NULL 
  And OBJECT_ID('dbo.FullAudit') IS NOT NULL
  ALTER Table dbo.FullAudit Add physical_reads BigInt

If INDEXPROPERTY(object_id('dbo.FullAudit'), 'iSeqEvents', 'IsUnique') IS Not NULL
  Drop Index iSeqEvents On dbo.FullAudit 

If COL_LENGTH ('dbo.FullAudit', 'ExtendedSessionCreateTime') IS NULL 
  ALTER Table dbo.FullAudit Add ExtendedSessionCreateTime datetime NULL
GO
  
If COL_LENGTH ('dbo.FullAudit', 'ExtendedSessionCreateTime') IS Not NULL 
  Exec sp_rename 'dbo.FullAudit.ExtendedSessionCreateTime', 'FirstEventTimeOfSession'
GO
If Object_id('dbo.LogTraitementAudit') IS NOT NULL
  Exec sp_rename 'dbo.LogTraitementAudit', 'ProcessAuditLog'


GO
Drop table if exists dbo.PipelineDeTraitementFinalDAudit
GO
If Object_id('dbo..XpCmdShellWasOff') IS NULL
Begin
  Create Table dbo.XpCmdShellWasOff (i Int)
End
If Object_id('dbo.XpCmdShellWasOff') IS NOT NULL
Begin
  Exec sp_configure 'Xp_CmdShell', '1'
  Reconfigure
End
GO
USE tempdb
GO
Create or Alter Function Dbo.ScriptFullDbRename (@OldDbName SysName, @NewDbName SysName)
Returns Table
as
Return
Select Sql=STRING_AGG(Sql3,'')
From
  (Select crlf=nChar(13)+nchar(10), Q='''') as Const
  CROSS APPLY (Select OldDbName=@OldDbName, NewDbName=@NewDbName) as Prm
  -- stops the query if database do not exists 
  CROSS APPLY (Select DbIdFound=database_id From sys.databases Where name=OldDbName) as DbIdFound
  CROSS APPLY
  (
  Select Sql0 = 'Alter Database #OldDbName# Set Single_User With Rollback immediate;'+crLf
  UNION All
  Select Sql = 'Exec sp_renamedb |#OldDbName#|, |#NewDbName#|'+crLf
  UNION All
  Select Sql0
  From 
    (Select t0=
    N'ALTER DATABASE #NewDbName# MODIFY FILE (NAME = |#Ln#|, FILENAME = |#nPn#|);'+crlf+
    N'ALTER DATABASE #NewDbName# MODIFY FILE (NAME = |#Ln#|, NEWNAME=|#nLn#|);'+crLf+
    N'ALTER DATABASE #NewDbName# SET OFFLINE;'+crLf+
    N'EXEC XP_CMDSHELL |cmd /c REN "#Pn#" #nLn#.#Ext#|, NO_OUTPUT'+crLf+
    N'ALTER DATABASE #NewDbName# SET ONLINE;'+crLf
    ) as t0
    CROSS APPLY
    (
    SELECT Ln, Pn, nLn, nPn, type_desc, ext
    FROM 
      sys.master_files
      CROSS APPLY (Select Ln=name, pn=physical_name) as N
      CROSS APPLY (Select nLn=REPLACE(N.Ln, OldDbName, NewDbName)) as nLn
      CROSS APPLY (Select nPn=REPLACE(N.pn, OldDbName, NewDbName)) as nPn
      CROSS APPLY (Select ext=IIF(type_desc='ROWS', 'Mdf', 'Ldf')) as Ext
    WHERE database_id = DbIdFound
    ) as F
    CROSS APPLY (Select t1=replace(t0, '#Ln#', F.Ln)) as t1
    CROSS APPLY (Select t2=replace(t1, '#nPn#', F.nPn)) as t2  
    CROSS APPLY (Select t3=replace(t2, '#nLn#', F.nLn)) as t3
    CROSS APPLY (Select t4=replace(t3, '#Pn#', F.Pn)) as t4
    CROSS APPLY (Select t5=replace(t4, '#Ext#', F.Ext)) as t5
    CROSS APPLY (Select Sql0=t5) as Sql0
  UNION All
  Select Sql0 = 'Alter Database #NewDbName# Set Multi_User With Rollback immediate;'+CrLf
  ) as Sql0
  CROSS APPLY (Select Sql1=REPLACE(Sql0, '#OldDbName#',OldDbName)) as Sql1
  CROSS APPLY (Select Sql2=REPLACE(Sql1, '#NewDbName#',NewDbName)) as Sql2
  CROSS APPLY (Select Sql3=REPLACE(Sql2, '|',Q)) as Sql3
GO
Create or Alter Function dbo.ScalarScriptFullDbRename(@OldDbName SysName, @NewDbName SysName)
Returns Nvarchar(max)
as
Begin
  Return(Select Sql From dbo.ScriptFullDbRename(@OldDbName, @NewDbName))
End
GO
Declare @Sql Nvarchar(max) = dbo.ScalarScriptFullDbRename('AuditReq', 'FullQryAudit')
If @@ROWCOUNT>0
Begin
  --Declare @Sql Nvarchar(max) = dbo.ScalarScriptFullDbRename('FullQryAudit', 'AuditReq')
  Print @Sql
  Exec (@Sql)
End
GO
If Not Exists
   (
   Select * 
   FROM 
     #RepAudit as R
     CROSS APPLY sys.dm_os_enumerate_filesystem(R.maindir, R.SubDirAudit) as F
   where is_directory=1
   ) 
Begin
  Print 'La connexion va être arrêter pour ne pas aller plus loin. Fermer et reconnecter'
  Raiserror ('Le répertoire configuré n''est pas trouvé', 20, 1)
End 
GO
drop table if exists  #renCmd
Select cmd
into #renCmd
FROM 
  #RepAudit as R
  CROSS APPLY sys.dm_os_enumerate_filesystem(R.maindir+R.SubDirAudit, '\*.Xel') as F
  CROSS APPLY (Select NewFileName=REPLACE(file_Or_directory_name, 'AuditReq', 'FullQryAudit')) as NewFileName
  CROSS APPLY (Select Ren='Ren '+F.full_filesystem_path+' '+NewFileName) as ren
  CROSS APPLY (Select cmd='Exec XP_CMDSHELL '''+Ren+''', NO_OUTPUT') as Cmd

Declare @Sql nvarchar(max)
While (1=1)
Begin
  Select Top 1 @Sql=cmd From #renCmd
  If @@ROWCOUNT = 0 Break
  Print @Sql
  Exec (@Sql)
  Delete from #renCmd Where cmd = @Sql
End

Declare @Cmd Nvarchar(max)
Select @Cmd=Ren
FROM 
  #RepAudit as R
  CROSS APPLY sys.dm_os_enumerate_filesystem(R.maindir, R.SubDirAudit) as F
  CROSS APPLY (Select Ren='Ren '+R.maindir+R.SubDirAudit+' '+R.NewNaming) as ren
  cross apply (Select cmd='Exec XP_CmdShell '''+ren+'''') as cmd
Where F.is_Directory = 1
Print 'Pour finaliser cette étape faites la commande suivante en mode powershell administrateur'
Print 'Vérifier que le nom de répertoire a changé, sinon faites le changement manuellement'
Print @Cmd

If Object_id('dbo.XpCmdShellWasOff') IS NOT NULL
Begin
  Exec sp_configure 'Xp_CmdShell', '0'
  Reconfigure
  Drop Table if exists dbo.XpCmdShellWasOff
End
GO
