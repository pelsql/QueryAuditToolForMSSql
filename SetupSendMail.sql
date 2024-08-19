DECLARE 
    @profile_name sysname
  , @account_name sysname
  , @SMTP_servername sysname
  , @email_address NVARCHAR(128)
  , @display_name NVARCHAR(128)
  , @rv INT
  

  -- Set profil name here
  SET @profile_name = 'AuditReq_EmailProfile';

  SET @account_name = lower(replace(convert(sysname, Serverproperty('servername')), '\', '.'))

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
 