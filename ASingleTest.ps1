Set-Location D:\_SQL\QueryAuditToolForMSSql
Import-Module .\Invoke-SqlQueries.psm1 -Force
while ($true) 
{
  $currentTime = Get-Date
  $currentSecond = $currentTime.Second

  # Check if the current second is 30, 00
  if ($currentSecond -in 0, 30) {
      Write-Host "Start test: $currentTime"
      break
  }
       
  # Sleep for a short period to avoid busy waiting
  Start-Sleep -Milliseconds 200
}
$sql = "Select id From (Select id, Title from StackOverflow2013.dbo.Posts TABLESAMPLE (4000 ROWS)) as id Where title is not null"
$ids = Invoke-SqlQueries -ServerInstance '.\SQL2K19' -Database StackOverflow2013 -Queries $sql -ThrowExceptionOnError -GetResultSet 1 -Verbose

Try {
# For loop that runs n times
Foreach ($id in $ids.id) {
  $title = Invoke-SqlQueries -ServerInstance '.\SQL2K19' -Database StackOverflow2013 -Queries "SELECT Login=suser_sname(),title FROM dbo.Posts Where id = $id" -ThrowExceptionOnError -GetResultSet 1 
  Write-Host $title.Login, $title.title
}
 

}
Catch {
throw
}
