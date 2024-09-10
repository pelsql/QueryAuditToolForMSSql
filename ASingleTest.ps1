param (
  [int]$fenetre
)
Set-Location D:\_SQL\QueryAuditToolForMSSql
Import-Module .\Invoke-SqlQueries.psm1 -Force

$sql = "Select top 3000 id, seq=row_number() Over (order by id) From (Select id, Title from StackOverflow2013.dbo.Posts TABLESAMPLE (50000 ROWS)) as id Where title is not null"
$ids = Invoke-SqlQueries -ServerInstance '.\SQL2K19' -Database StackOverflow2013 -Queries $sql -ThrowExceptionOnError -GetResultSet 1 -Verbose

$filePath = "D:\_SQL\QueryAuditToolForMSSql\stopwatch.txt"

while (Test-Path -Path $filePath -PathType Leaf) 
{
  Start-Sleep -Milliseconds 500
}

Try {
# For loop that runs n times
$i=0
if ($fenetre -eq 0){$fenetre=1}
Foreach ($r in $ids) {
  
  $f="{0:D3}" -f $fenetre
  $s="{0:D5}" -f $($r.seq)
  $sqlId="/*$f-$s*/SELECT Fen=$f,Seq=$s,n=$i, Login=suser_sname(),title FROM dbo.Posts Where id = $($r.id)"
  $title = Invoke-SqlQueries -ServerInstance '.\SQL2K19' -Database StackOverflow2013 -Queries $sqlId -ThrowExceptionOnError -GetResultSet 1 
  Write-Host $i $title.Login, $title.title
  $i++
}
 

}
Catch {
throw
}
