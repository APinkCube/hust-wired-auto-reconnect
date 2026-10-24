[CmdletBinding()]
param(
    [string]$BinaryPath = "",
    [switch]$UpdateCredentials
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TaskName = "HUST Wired Auto Reconnect"
$InstallRoot = "C:\ProgramData\hust-network-login"
$TargetExe = Join-Path $InstallRoot "hust-network-login.exe"
$ConfigPath = Join-Path $InstallRoot "hust-network-login.conf"
$RunnerPath = Join-Path $InstallRoot "run.ps1"

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Run this installer from an Administrator PowerShell window."
    }
}

function Copy-IfDifferent {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $sourceFull = [IO.Path]::GetFullPath($Source)
    $destinationFull = [IO.Path]::GetFullPath($Destination)
    if (-not [string]::Equals($sourceFull, $destinationFull, [StringComparison]::OrdinalIgnoreCase)) {
        Copy-Item -LiteralPath $sourceFull -Destination $destinationFull -Force
    }
}

function Save-Credentials {
    $studentId = Read-Host "HUST student ID"
    $securePassword = Read-Host "Campus network password" -AsSecureString

    if ([string]::IsNullOrWhiteSpace($studentId)) {
        throw "Student ID must not be empty."
    }

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    try {
        $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        if ([string]::IsNullOrEmpty($password)) {
            throw "Password must not be empty."
        }
        $utf8NoBom = New-Object Text.UTF8Encoding($false)
        [IO.File]::WriteAllText($ConfigPath, "$studentId`n$password`n", $utf8NoBom)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        Remove-Variable password -ErrorAction SilentlyContinue
    }
}

Assert-Administrator

if ([string]::IsNullOrWhiteSpace($BinaryPath)) {
    $BinaryPath = Join-Path $PSScriptRoot "hust-network-login.exe"
}

if (-not (Test-Path -LiteralPath $BinaryPath -PathType Leaf)) {
    throw "Executable not found: $BinaryPath"
}
$BinaryPath = (Resolve-Path -LiteralPath $BinaryPath).Path

$requiredScripts = @("install.ps1", "run.ps1", "check.ps1", "uninstall.ps1")
foreach ($name in $requiredScripts) {
    $source = Join-Path $PSScriptRoot $name
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required file not found: $source"
    }
}

New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null

$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
}
Stop-Process -Name "hust-network-login" -Force -ErrorAction SilentlyContinue

Copy-IfDifferent -Source $BinaryPath -Destination $TargetExe
foreach ($name in $requiredScripts) {
    Copy-IfDifferent -Source (Join-Path $PSScriptRoot $name) -Destination (Join-Path $InstallRoot $name)
}

if ($UpdateCredentials -or -not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    Save-Credentials
}
else {
    Write-Host "Keeping the existing credential file. Use -UpdateCredentials to replace it."
}

$currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $InstallRoot /inheritance:r /grant:r "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" "*${currentSid}:(OI)(CI)F" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to restrict permissions on $InstallRoot"
}

$actionArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RunnerPath`""
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $actionArgs
$triggers = @(
    New-ScheduledTaskTrigger -AtStartup
    New-ScheduledTaskTrigger -AtLogOn
)
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -RestartCount 999 `
    -ExecutionTimeLimit ([TimeSpan]::Zero)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $triggers -Settings $settings -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName

$wired = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object {
    $_.Status -eq "Up" -and
    $_.Name -notmatch "WLAN|Wi-?Fi|Wireless|Bluetooth" -and
    $_.InterfaceDescription -notmatch "WLAN|Wi-?Fi|Wireless|802\.11|Bluetooth"
}

Write-Host "Installed and started scheduled task: $TaskName"
Write-Host "Credentials are stored in $ConfigPath with restricted permissions."
if (-not $wired) {
    Write-Warning "No active wired adapter was detected. Connect the campus Ethernet cable before checking the service."
}
Write-Host "Check status with: powershell -ExecutionPolicy Bypass -File `"$InstallRoot\check.ps1`""
