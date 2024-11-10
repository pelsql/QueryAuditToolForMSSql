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
      (Select top 51 * from dbo.EvenementsTraitesSuivi order by dateSuivi desc) as Ev
    ) as X
  Where lastSeq=1
  ) as ev
  cross apply dbo.GetNextEvents (Ev.file_Name, Ev.last_Offset_done) as E
  OUTER APPLY (Select * from dbo.ExtractConnectionInfoFromEvents(E.event_data) Where E.event_name = 'user_event') as C
--
Select * from dbo.AuditComplet where Client_net_address like '(Cur)%'

