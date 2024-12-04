/*
---------------------------------------------------------------------
-- utiliser GetNextEvents et dbo.ExtractConnectionInfoFromEvents
-- pour obtenir a la fois les requetes tracées, et les informations de connexions si event_type = 'User_event'
Select E.*, C.*
from 
  (
  Select *
  from
    (
    select *, lastSeq=ROW_NUMBER() Over(order by dateSuivi) 
    From 
      -- on choisit bien le fichier traité qu'on veut si les fichiers 
      (Select top 1 * from dbo.EvenementsTraitesSuivi order by dateSuivi desc) as Ev
    ) as X
  Where lastSeq=1
  ) as ev
  cross apply dbo.GetNextEvents (Ev.file_Name, Ev.last_Offset_done) as E
  OUTER APPLY (Select * from dbo.ExtractConnectionInfoFromEvents(E.event_data) Where E.event_name = 'user_event') as C
--
Select * from dbo.AuditComplet where Client_net_address like '(Cur)%'
--
*/
/* */
--requete pour output du mode debug 
-- le but : voir pour une requête connue d'un programme connu s'il n'y a pas d'incohérence dans le temps
-- de l'Évènement de connexion par rapport à ce programme.
-- Ex: pvAppNane (precedent value of AppName doit être ici Invoke_sqlQueries et rien d'autre)
-- on compare au changement d'Évènement de la connexion a la requete. La connexion donne le programme, et si on utilise
-- lag on en obtient avec la requete le nom de programme sur la meme ligne
Select *
From
  (
  Select 
    R.*
  , EvAvant=Lag(ev) Over (order by R.ev_Seq)
  , PvAppName=Lag(R.client_app_name) Over (order by R.ev_Seq)
  FROM 
    ( 
    -- In working with a single file at the time, create_Time of its extended event session is all the same because a file 
    -- can't belong to more that a single session
    Select Top 1 ExtendedSessionCreateTime From Dbo.HistoriqueConnexions Order By ExtendedSessionCreateTime Desc
    ) as ExtEvInfo
    CROSS JOIN dbo.TraceDataModel as T
    CROSS APPLY (SELECT CAST(event_data AS XML) AS event_data) AS xEvents
    OUTER APPLY
    (
    Select 
      server_principal_name = T.event_data.value('(event/action[@name="server_principal_name"]/value)[1]', 'varchar(50)')
    , session_id = T.event_data.value('(event/action[@name="session_id"]/value)[1]', 'int')
    , ExtEvInfo.ExtendedSessionCreateTime
    , T.event_time 
    , T.Event_Sequence
    , database_name = T.event_data.value('(event/action[@name="database_name"]/value)[1]', 'varchar(50)')
    -- voir commentaire si on veut tracer les instructions des modules
    --, line_number = Tmp.event_data.value('(event/data[@name="line_number"]/value)[1]', 'int') 
    , statement = T.event_data.value('(event/data[@name="statement"]/value)[1]', 'nvarchar(max)') 
    , DurMicroSec = T.event_data.value('(event/data[@name="duration"]/value)[1]', 'bigint')
    Where T.event_name <> 'user_event'
    ) as S
    OUTER APPLY (Select * from dbo.ExtractConnectionInfoFromEvents(xEvents.event_data) Where event_name = 'user_event') as C
    CROSS APPLY 
    (
    Select 
      SI=SeqImport
    , Ev=IIF(T.event_name='user_event','U','S')
    , Ev_Seq=T.Event_Sequence
    , event_time=ISNULL(C.LoginTime, S.event_time)
    , loginName=ISNULL(S.server_principal_name, C.LoginName) 
    , spid=ISNULL(C.session_Id, S.Session_Id)
    , client_app_name
    , Statement
    ) as R
  ) as R2
  Where R2.EvAvant<>R2.ev
    And statement like 'Select fen%' and PvAppName not like 'invoke%'
order by Ev_Seq

