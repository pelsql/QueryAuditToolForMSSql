clear-host
Set-Location D:\_SQL\QueryAuditToolForMSSql

 # Path to the .ps1 script you want to run in each new window
$scriptPath = "D:\_SQL\QueryAuditToolForMSSql\ASingleTest.ps1"

# Define the number of windows you want to open
$n = 20

# Loop to start n PowerShell windows, each running the same script
for ($i = 1; $i -le $n; $i++) {
    Start-Process powershell -ArgumentList "-NoExit", "-File", $scriptPath
    Write-Host "Started PowerShell window $i running $scriptPath"
}
