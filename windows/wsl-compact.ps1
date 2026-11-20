# wsl-compact.ps1 - compact the Ubuntu WSL disk file when it has grown well past what's in use,
# then restart WSL via the "Start WSL Ubuntu" task.
# Usage: wsl-compact.ps1 [-DryRun] [-Force] [-ThresholdGB 50]   (compacting needs an elevated shell)
param([switch]$DryRun, [switch]$Force, [int]$ThresholdGB = 50)
$ErrorActionPreference = 'Stop'
$Distro  = 'Ubuntu'
$Vhdx    = 'W:\Ubuntu\ext4.vhdx'
$Task    = 'Start WSL Ubuntu'
$Log     = Join-Path $PSScriptRoot 'wsl-compact.log'
function Log($m) { $l = "{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $m; Write-Output $l; Add-Content -Path $Log -Value $l }
function GB($b) { "{0:N1}GB" -f ($b / 1GB) }

$file = (Get-Item $Vhdx).Length
& wsl.exe -d $Distro -u root -- fstrim / 2>$null | Out-Null
$used = [int64]((& wsl.exe -d $Distro -u root -- df -B1 --output=used / | Select-Object -Last 1).Trim())
$slack = $file - $used
Log "vhdx $(GB $file), used $(GB $used), slack $(GB $slack), threshold ${ThresholdGB}GB"

if (-not $Force -and $slack -lt $ThresholdGB * 1GB) { Log "below threshold, skipping"; exit 0 }
if ($DryRun) { Log "dry run: would shut down WSL, compact, restart"; exit 0 }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Log "ERROR: needs an elevated shell"; exit 1 }

try {
    Log "shutting down WSL"
    & wsl.exe --shutdown
    Start-Sleep -Seconds 10
    $dp = New-TemporaryFile
    Set-Content -Path $dp -Encoding ASCII -Value @(
        "select vdisk file=`"$Vhdx`"", 'attach vdisk readonly', 'compact vdisk', 'detach vdisk')
    Log "compacting"
    $out = & diskpart.exe /s $dp 2>&1 | Out-String
    Remove-Item $dp
    if ($LASTEXITCODE -ne 0) { Log "diskpart failed ($LASTEXITCODE): $($out.Trim())" }
    $after = (Get-Item $Vhdx).Length
    Log "vhdx $(GB $file) -> $(GB $after) (freed $(GB ($file - $after)))"
}
catch { Log "ERROR: $_" }
finally {
    Log "restarting WSL"
    try { Start-ScheduledTask -TaskName $Task }
    catch { Start-Process wsl.exe -ArgumentList "-d $Distro --exec sleep infinity" -WindowStyle Hidden }
}
