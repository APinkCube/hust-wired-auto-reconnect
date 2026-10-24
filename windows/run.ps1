Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$exe = Join-Path $root "hust-network-login.exe"
$config = Join-Path $root "hust-network-login.conf"
$stdoutLog = Join-Path $root "hust-network-login.out.log"
$stderrLog = Join-Path $root "hust-network-login.err.log"

if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw "Executable not found: $exe"
}
if (-not (Test-Path -LiteralPath $config -PathType Leaf)) {
    throw "Configuration not found: $config"
}

foreach ($log in @($stdoutLog, $stderrLog)) {
    if ((Test-Path -LiteralPath $log) -and (Get-Item -LiteralPath $log).Length -gt 5MB) {
        Move-Item -LiteralPath $log -Destination "$log.old" -Force
    }
}

$process = Start-Process `
    -FilePath $exe `
    -ArgumentList "`"$config`"" `
    -WindowStyle Hidden `
    -RedirectStandardOutput $stdoutLog `
    -RedirectStandardError $stderrLog `
    -Wait `
    -PassThru

exit $process.ExitCode
