sp_cycle_errorlog
delete dbo.connexionsRecentes
Select nb, nbSec, nbParSec
From
  (
  select start=min(loginTime) , fin=max(loginTime), nb=count(*) 
  from dbo.connexionsRecentes where PROGRAM_NAME like 'invoke%'
  ) as x
  cross apply (select nbsec=datediff(ss, start, fin)) as nbsec
  cross apply (select nbParSec=nb*1.0/nbSec) as nbParSec


select GETDATE()