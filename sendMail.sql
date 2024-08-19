CREATE OR ALTER PROCEDURE dbo.SendEmail @msg NVARCHAR(MAX)
WITH EXECUTE AS 'AuditReqUser'
AS
BEGIN
  Declare @profile_name SysName;
  Declare @email_address SysName;
  Select @profile_name = profile_name, @email_address=email_address From AuditReq.dbo.EnumsEtOpt

  EXEC  Msdb.dbo.sp_send_dbmail
    @profile_name = @profile_name
  , @recipients = @email_Address
  , @importance = 'High'
  , @subject = 'AuditReq : Resoudre ce problème avant de réactiver l''audit des requêtes'
  , @body = @Msg
  , @body_format = 'HTML'
END
GO
