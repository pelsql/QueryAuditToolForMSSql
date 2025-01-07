param (
  [int]$fenetre
)
Set-Location D:\_SQL\QueryAuditToolForMSSql\MiscTests
Import-Module .\Invoke-SqlQueries.psm1 -Force

# pre-requisites for the test: Download a copie of the StackOverflow2013 database from https://www.brentozar.com/archive/2015/10/how-to-download-the-stack-overflow-database-via-bittorrent/
# and restore it on a SQL Server instance. The database is about 10GB in size and the Posts table has about 30 million rows.
# a low privilege login is automaticaly created by the script LauchSQLStressTest.ps1 and is used to run the queries in this test.
# The login is -User StackOverflowLowPrivUser -Pwd '6SbCvzN>%p-?' -Verbose
# It is granted the SELECT permission on the Posts table through the command GRANT SELECT ON [dbo].[Posts] TO [guest]

# The test will select 3000 random rows from the Posts table and will run a query for each row. The query will return the title of the post.
# The query will be executed in a loop n times. The loop will run in parallel in n threads. The number identifier is defined by the parameter $fenetre.
# The caller LauchSQLStressTest.ps1 spawns n powershell windows that each call this script with the parameter $fenetre. 
# The purpose of the test is to see how the SQL Server handles the load, and $fenetre is used to identify the from which thread the query audited comes from.

$sql = "Select top 3000 id, seq=row_number() Over (order by id) From (Select id, Title from StackOverflow2013.dbo.Posts TABLESAMPLE (50000 ROWS)) as id Where title is not null"
$ids = Invoke-SqlQueries -ServerInstance '.\SQL2K19' -Database StackOverflow2013 -Queries $sql -ThrowExceptionOnError -GetResultSet 1 -User StackOverflowLowPrivUser -Pwd '6SbCvzN>%p-?' -Verbose

$filePath = "D:\_SQL\QueryAuditToolForMSSql\MiscTests\stopwatch.txt"

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
  $title = Invoke-SqlQueries -ServerInstance '.\SQL2K19' -Database StackOverflow2013 -Queries $sqlId -ThrowExceptionOnError -GetResultSet 1 -User StackOverflowLowPrivUser -Pwd '6SbCvzN>%p-?'
  Write-Host $i $title.Login, $title.title
  $i++
}

}
Catch {
throw
}
