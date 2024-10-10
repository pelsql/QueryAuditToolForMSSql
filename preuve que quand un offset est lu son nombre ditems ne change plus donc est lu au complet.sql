Drop table if exists #dir
Select top 1 file_name=full_filesystem_path
into #dir
From
  (
  Select top 1 FS.full_filesystem_path, RepFichTrc, MatchFichTrc 
  From 
    (Select * From dbo.EnumsEtOpt) as Opt
    Cross Apply sys.dm_os_enumerate_filesystem(RepFichTrc, MatchFichTrc) as FS
  Where FS.full_filesystem_path Like RepFichTrc+'AuditReq[_][0-9]%'
  Order By full_filesystem_path desc -- dernier fichier actif
  ) as dir
Select * from #dir
Drop table if exists #tmp
Select *
into #tmp
From
  (
  Select *, dernCount=Lag(n,1) over (order by File_Name Desc) 
  From
    (
    Select 
      F.file_name, f.file_offset, n=COUNT(*)
    , offsetSeq=ROW_NUMBER() over (partition by F.File_name order by F.File_offset desc)
    , dernOffset=Lag(file_offset,1) over (partition by F.File_Name order by F.file_Offset desc) 
    From
      (Select FILE_NAME, offset=cast(null as bigint) from #dir) as prm1
      outer apply (select file_name2=prm1.FILE_NAME Where offset is Not null) as file_name2
      cross apply sys.fn_xe_file_target_read_file(File_Name, NULL, File_Name2, offset) as F
    group by F.file_name, F.file_offset
    ) as x
  ) as y
Where offsetSeq=2
Select * from #tmp

declare @lect int = 0
While (@lect < 300)
Begin
  If exists
  (
  Select *
  From
    -- ce file_offset fait passer au file_osset suivant qui est le dernOffset et on compare le count de ce dernier avec le dernier count
    (Select FILE_NAME, file_offset, dernCount, dernOffset From #tmp) as prm1
    outer apply (select file_name2=prm1.FILE_NAME Where file_offset is Not null) as file_name2
    cross apply sys.fn_xe_file_target_read_file(File_Name, NULL, File_Name2, file_offset) as F
  group by F.file_name, F.file_offset, dernOffset, derncount
  having COUNT(*) > derncount and f.file_offset = dernOffset
  )
    Select 'nombre a change pour le dernier offset'
  else
    Select @lect = @lect + 1
End

--select 
