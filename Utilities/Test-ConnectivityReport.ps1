<#
.SYNOPSIS
  Test ICMP and TCP connectivity to targets and export a report.
#>
[CmdletBinding()]
param(
  [string[]]$Target,
  [string]$TargetList,
  [string]$ExportPath
)

# Build target list
if ($TargetList) {
  $Target = Get-Content -Path $TargetList | Where-Object { $_ -and $_.Trim() -ne '' }
}
if (-not $Target) { throw "Provide -Target or -TargetList." }

Write-Verbose ("Targets: {0}" -f ($Target -join ', '))

$rows = foreach ($t in $Target) {
  # DO NOT use $host (reserved); use $TargetHost / $TargetPort
  $TargetHost,$TargetPort = if ($t -match '^(.*?):(\d+)$') { $matches[1], [int]$matches[2] } else { $t, $null }

  Write-Verbose "Testing $t ..."
  $ping = $false
  try { $ping = Test-NetConnection -ComputerName $TargetHost -InformationLevel Quiet } catch { $ping = $false }

  $tcp = $null
  if ($TargetPort) {
    try { $tcp = Test-NetConnection -ComputerName $TargetHost -Port $TargetPort -InformationLevel Quiet } catch { $tcp = $false }
  }

  [pscustomobject]@{
    Target  = $t
    Host    = $TargetHost
    Port    = if ($TargetPort){$TargetPort}else{$null}
    PingOK  = [bool]$ping
    TcpOK   = if ($TargetPort -ne $null){ [bool]$tcp } else { $null }
    Checked = (Get-Date)
  }
}

# Always show a table in the console
Write-Host ("Results (rows: {0})" -f $rows.Count) -ForegroundColor Cyan
$rows | Sort-Object Host,Port | Format-Table -AutoSize | Out-String | Write-Host

# CSV export (auto-create folder)
if ($ExportPath) {
  try {
    $dir = Split-Path -Parent $ExportPath
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $rows | Export-Csv -NoTypeInformation -Path $ExportPath -Force
    Write-Host "Saved report to $ExportPath"
  } catch {
    Write-Host "Failed to write CSV: $($_.Exception.Message)" -ForegroundColor Red
  }
}
