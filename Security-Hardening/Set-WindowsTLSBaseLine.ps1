<#
.SYNOPSIS
    Apply a safe TLS/SChannel baseline: disable TLS 1.0/1.1, ensure TLS 1.2 on.
.DESCRIPTION
    Writes registry keys for Client/Server under SCHANNEL. Supports -WhatIf.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param()

function Set-Proto {
    param([string]$Proto,[int]$Enabled,[int]$DisabledByDefault)
    foreach ($role in 'Client','Server') {
        $base = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$Proto\$role"
        if (-not (Test-Path $base)) { New-Item -Path $base -Force | Out-Null }
        if ($PSCmdlet.ShouldProcess($base,"Enabled=$Enabled; DisabledByDefault=$DisabledByDefault")) {
            New-ItemProperty -Path $base -Name 'Enabled' -PropertyType DWord -Value $Enabled -Force | Out-Null
            New-ItemProperty -Path $base -Name 'DisabledByDefault' -PropertyType DWord -Value $DisabledByDefault -Force | Out-Null
        }
    }
}

Set-Proto -Proto 'TLS 1.0' -Enabled 0 -DisabledByDefault 1
Set-Proto -Proto 'TLS 1.1' -Enabled 0 -DisabledByDefault 1
Set-Proto -Proto 'TLS 1.2' -Enabled 1 -DisabledByDefault 0
Write-Host "Baseline applied. A reboot may be required."
