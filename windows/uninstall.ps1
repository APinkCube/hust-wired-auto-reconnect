[CmdletBinding()]
param(
    [switch]$KeepCredentials
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$taskName = "HUST Wired Auto Reconnect"
$root = "C:\ProgramData\hust-network-login"
$expectedRoot = "C:\ProgramData\hust-network-login"

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this uninstaller from an Administrator PowerShell window."
}

Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Stop-Process -Name "hust-network-login" -Force -ErrorAction SilentlyContinue

if (Test-Path -LiteralPath $root) {
    $resolvedRoot = [IO.Path]::GetFullPath($root).TrimEnd("\")
    if (-not [string]::Equals($resolvedRoot, $expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected path: $resolvedRoot"
    }

    if ($KeepCredentials) {
        Get-ChildItem -LiteralPath $root -Force | Where-Object {
            $_.Name -notin @("hust-network-login.conf", "uninstall.ps1")
        } | Remove-Item -Force -Recurse
        Write-Host "Removed the task and program files. Credentials were kept in $root."
    }
    else {
        Remove-Item -LiteralPath $root -Force -Recurse
        Write-Host "Removed the task, program files, logs, and stored credentials."
    }
}
else {
    Write-Host "The scheduled task was removed. The program directory did not exist."
}
