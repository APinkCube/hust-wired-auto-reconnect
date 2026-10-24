Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$taskName = "HUST Wired Auto Reconnect"
$root = "C:\ProgramData\hust-network-login"

Write-Host "== Files =="
foreach ($name in @("hust-network-login.exe", "hust-network-login.conf", "run.ps1")) {
    $path = Join-Path $root $name
    Write-Host ("{0}: {1}" -f $name, $(if (Test-Path -LiteralPath $path) { "OK" } else { "MISSING" }))
}

Write-Host "`n== Scheduled task =="
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
    $info = Get-ScheduledTaskInfo -TaskName $taskName
    Write-Host "State: $($task.State)"
    Write-Host "Last run: $($info.LastRunTime)"
    Write-Host "Last result: $($info.LastTaskResult)"
}
else {
    Write-Host "MISSING"
}

Write-Host "`n== Login process =="
$process = Get-Process -Name "hust-network-login" -ErrorAction SilentlyContinue
if ($process) {
    $process | Select-Object Id, StartTime, CPU | Format-Table -AutoSize
}
else {
    Write-Host "NOT RUNNING"
}

Write-Host "`n== Active wired adapters =="
$wired = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object {
    $_.Status -eq "Up" -and
    $_.Name -notmatch "WLAN|Wi-?Fi|Wireless|Bluetooth" -and
    $_.InterfaceDescription -notmatch "WLAN|Wi-?Fi|Wireless|802\.11|Bluetooth"
}
if ($wired) {
    $wired | Select-Object Name, InterfaceDescription, Status, LinkSpeed | Format-Table -AutoSize
}
else {
    Write-Host "No active wired adapter detected."
}

foreach ($name in @("hust-network-login.out.log", "hust-network-login.err.log")) {
    $path = Join-Path $root $name
    Write-Host "`n== $name (last 20 lines) =="
    if (Test-Path -LiteralPath $path) {
        Get-Content -LiteralPath $path -Tail 20
    }
    else {
        Write-Host "No log yet."
    }
}
