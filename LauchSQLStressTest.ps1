clear-host
Set-Location D:\_SQL\QueryAuditToolForMSSql

 # Path to the .ps1 script you want to run in each new window
$scriptPath = "D:\_SQL\QueryAuditToolForMSSql\ASingleTest.ps1"

# Define the number of windows you want to open
$n = 20


$filePath = "D:\_SQL\QueryAuditToolForMSSql\stopwatch.txt"
New-Item -Path $filePath -ItemType File

# Loop to start n PowerShell windows, each running the same script
for ($i = 1; $i -le $n; $i++) {
    Start-Process powershell  -WindowStyle Minimized -ArgumentList "-NoExit", "-File", $scriptPath, "-fenetre $i" 
    #Start-Process powershell  -ArgumentList "-NoExit", "-File", $scriptPath, "-fenetre $i" 
    Write-Host "Started PowerShell window $i running $scriptPath" "-fenetre $i"
}

# attendre a un moment  précis 0 ou 30 secondes
$currentTime = Get-Date
$currentSecond = $currentTime.Second
if ($currentSecond -lt 30) {
  $top = 00
}
else
{
  $top = 30
}

write-host "Actually $currentSecond and start at $top"
while ($true) 
{
  $currentTime = Get-Date
  If ($currentSecond -ne $currentTime.Second) {
    $currentSecond = $currentTime.Second
    write-host $currentSecond
  }

  # Check if the current second is 30, 00
  if ($currentSecond -eq $top) {
      Write-Host "Start test: $currentTime"
      break
  }
       
  # Sleep for a short period to avoid busy waiting
  Start-Sleep -Milliseconds 200
}
Remove-Item -Path $filepath
