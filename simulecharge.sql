Select sql
From 
  (Select Cmt='--', Nl=Nchar(13)+Nchar(10), def=OBJECT_DEFINITION(Object_id('S#.ColInfo'))) as c
  cross join (Select [GO]=Nchar(10)+'GO') as [GO]
  cross apply S#.LoopGenByNums(1000) as L
  cross apply (Select Sql=Cmt+STR(loopindex)+Nl+STUFF(def, 1, 6, 'CREATE OR ALTER')+[GO]) as Sql