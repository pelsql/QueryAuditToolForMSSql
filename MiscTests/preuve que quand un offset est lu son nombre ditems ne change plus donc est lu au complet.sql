-- determiner le dernier fichier de trace du repertoire
--
Drop table if exists #dir
Select top 1 dern_Fich_Rep=full_filesystem_path
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
--
Drop table if exists #tmp
Select *
into #tmp -- obtient nom fichier, et nombre d'Évènements pour avant dernier offset du fichier
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
      (Select dern_Fich_Rep, offset=cast(null as bigint) from #dir) as prm1
      outer apply (select file_name2=prm1.dern_Fich_Rep Where offset is Not null) as file_name2
      cross apply sys.fn_xe_file_target_read_file(dern_Fich_Rep, NULL, File_Name2, offset) as F
    group by F.file_name, F.file_offset
    ) as x
  ) as y
Where offsetSeq=2 -- avant dernier selon ROW_NUMBER()

Select * from #tmp

-- ici on reprend la lecture des tas de fois du dernier offset 
-- (en fournissant l'offset précédent qui est l'avant dernier), car 
-- sys.fn_xe_file_target_read_file lit après cet offset.
-- on veut s'assurer que quand un offset est lu, il n'y aura plus d'autres entrées qui lui sont ajoutés
-- Pourquoi? Parce que dans QueryAuditToolsForMsSql quand on lit le dernier, il n'y a rien de retourné
-- et on fait comme s'il n'y aura plus rien de retourné avec cet offset
declare @lect int = 0
While (@lect < 300)
Begin
  If exists
  (
  Select *
  From
    -- ce file_offset fait passer au file_offset suivant qui est le dernOffset et on compare le count de ce dernier avec le dernier count
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

-- verifie qu'on peut essayer de lire souvent au dernier offset et n'avoir aucune rangée comme résultat
Set @lect = 0
While (@lect < 300)
Begin
  If not exists
  (
  Select *
  From
    (Select FILE_NAME, file_offset, dernCount, dernOffset From #tmp) as prm1
    outer apply (select file_name2=prm1.FILE_NAME Where file_offset is Not null) as file_name2
    cross apply sys.fn_xe_file_target_read_file(File_Name, NULL, File_Name2, dernCount) as F
  )
  Select @lect = @lect + 1
  Else
    Select 'dernier offset lu, a retourné quelque chose, anormal'
End -- While
