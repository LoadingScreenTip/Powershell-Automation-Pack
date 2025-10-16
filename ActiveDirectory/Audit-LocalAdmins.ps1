<#
.SYNOPSIS
    Export local Administrators group members from one or more Windows endpoints.
.DESCRIPTION
    Uses PowerShell remoting when possible; falls back to local query.
.PARAMETER ComputerName
    One or more computer names (defaults to localhost).
.PARAMETER ComputerList
    Path to a text file (one hostname per line).
.PARAMETER ExportPath
    Optional CSV path to save results.
.EXAMPLE
    .\Audit-LocalAdmins.ps1 -ComputerList .\endpoints.txt -ExportPath .\Admins.csv
.NOTES
    Demo only; identifiers should be sanitized before public posting.
#>
[CmdletBinding()]
param(
    [string[]]$ComputerName = $env:COMPUTERNAME,
    [string]$ComputerList,
    [string]$ExportPath
)

if ($ComputerList) {
    $ComputerName = Get-Content -Path $ComputerList | Where-Object { $_ -and $_.Trim() -ne '' }
}

$results = foreach ($comp in $ComputerName) {
    try {
        $sb = {
            try {
                Get-LocalGroupMember -Group 'Administrators' |
                Select-Object @{n='Computer';e={$env:COMPUTERNAME}},
                              @{n='Name';e={$_.Name}},
                              @{n='Class';e={$_.ObjectClass}},
                              @{n='Source';e={$_.PrincipalSource}}
            } catch {
                [pscustomobject]@{ Computer=$env:COMPUTERNAME; Name='(Failed to enumerate)'; Class=''; Source='' }
            }
        }
        if ($comp -ne $env:COMPUTERNAME) {
            Invoke-Command -ComputerName $comp -ScriptBlock $sb -ErrorAction Stop
        } else {
            & $sb
        }
    } catch {
        [pscustomobject]@{ Computer=$comp; Name='(Unreachable)'; Class=''; Source='' }
    }
}

if ($ExportPath) {
    $results | Sort-Object Computer,Name | Export-Csv -NoTypeInformation -Path $ExportPath
    Write-Host "Saved report to $ExportPath"
} else {
    $results | Sort-Object Computer,Name | Format-Table -AutoSize
}
