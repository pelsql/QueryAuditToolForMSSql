-- disable in advanced options in query : suppress provider messages header and completion time
-- suppress option "include headers in result set" for output in text mode.
use s#
set nocount on
Select SqlLines.Line as [--line]
From 
  (Select Cmt='--', Nl=Nchar(13)+Nchar(10), def=OBJECT_DEFINITION(Object_id('S#.ColInfo'))) as c
  cross join (Select [GO]=Nchar(10)+'GO') as [GO]
  cross apply S#.LoopGenByNums(10000) as L
  cross Apply (Select Sql0=cmt+replace(STR(loopindex,6),' ', '0')+Nl+STUFF(def, 1, 6, 'CREATE OR ALTER')) as Sql0
  cross Apply (Select strcut='===KeyWords===*/') as strCut
  cross apply (Select posCut=CHARINDEX(strCut, Sql0)+LEN(strCut)) as posCut
  cross apply (Select Sql1=Substring(Sql0, 1, posCut)+')'+[go]) as Sql1
  cross apply (Select Sql=REPLACE(Sql1, 'S#.ColInfo', 'S#.TmpColInfoToDelete')) as Sql
  cross apply S#.SplitSqlCodeLinesIntoRows(sql) as SqlLines
order by L.loopindex, LineNum
