declare @sql nvarchar(max)
Select @sql=Sql
From
  (
  Select unionsAll = STRING_AGG (CONVERT(NVARCHAR(max),'    '+UnionCol), nCHAR(10)) 
  From
    (
      select 
        name, system_type_id, column_id 
      , UnionCol=coalesce(sqlChar, sqldate,sqlnum)
      from 
        (
        select * 
        From 
          sys.columns 
        where object_id=Object_id('dbo.FIN_FOUR_JRNL') 
          And Quotename(name) not in 
              (
               '[NO_HIST_SEQ]'
              ,'[NO_FOUR]'
              ,'[DATE_MODIF]'
              ,'[DATE_DERN_TX]'
              ,'[DATE_MAJ]'
              ,'[CODE_UTIL]'
              ,'[CODE_UTIL_MAJ]'
              ,'[CODE_UTIL_DERN_TX]'
              )
        ) as cols 
        CROSS APPLY (Select tchar='Select nomChp=''#col#'', ValeurAv=T1.#col#, ValeurAp=T2.#col# WHERE T1.#col#<>T2.#col# UNION ALL') as tchar
        OUTER APPLY (Select sqlChar=replace(tchar, '#col#', name) Where system_type_id IN(231,239)) as SqlChar
        CROSS APPLY (Select tDate='Select nomChp=''#col#'', ValeurAv=convert(nvarchar,T1.#col#,120), ValeurAp=convert(nvarchar,T2.#col#,120) WHERE T1.#col#<>T2.#col# UNION ALL' ) as t
        OUTER APPLY (Select sqlDate=replace(tDate, '#col#', name) Where system_type_id IN(61,58)) as SqlDate
        CROSS APPLY (Select tNum='Select nomChp=''#col#'', ValeurAv=convert(nvarchar,T1.#col#), ValeurAp=convert(nvarchar,T2.#col#) WHERE T1.#col#<>T2.#col# UNION ALL') as tNum
        OUTER APPLY (Select sqlNum=replace(tNum, '#col#', name) Where system_type_id IN(56,108,52)) as SqlNum
      UNION ALL
      Select '', 0, 9999, '  Select noChp=null, av=null, ap=null where 1=0'
    ) as UnionCol
  ) as UnionsAll
  CROSS APPLY
  (
  Select tReq=
  '
  drop table if exists #tmp
  Select 
    Seq=ROW_NUMBER() Over (Partition BY NO_FOUR Order by NO_HIST_SEQ)
  , *
  into #tmp
  From
    dbo.FIN_FOUR_JRNL
  Where DATE_MODIF > ''20160107''
  Order by no_four, date_modif 
  create clustered index 
  Select T1.no_four, T2.rsn_Soc, T2.date_modif, T2.code_util_maj, cmp.*
  From
    #tmp as T1
    JOIN #tmp T2
    ON T2.no_four = T1.no_four
    And T2.Seq=T1.Seq+1
    CROSS APPLY
    (
#unionsAll#
    ) as Cmp
  order by T1.no_four, T1.seq
  '
  ) as tReq
  CROSS APPLY (Select Sql=Replace(convert(nvarchar(max),tReq),'#unionsAll#',UnionsAll)) as Sql 
--Select @sql
Exec (@sql)

