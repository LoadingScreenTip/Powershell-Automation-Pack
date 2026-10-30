# Windows troubleshooting — quick reference

Sanitized draft · 30 October 2026 · not executed or runtime-tested here.

## Where to run commands

**ADMIN PC** means your elevated PowerShell terminal, using an account authorized to administer the target. **REMOTE PC** means PowerShell already running on the affected PC (including the PsExec shell below). **USER SESSION** means the affected user's own session, not SYSTEM. Never paste a `PS C:\...>` prompt or command output back into the terminal.

Replace all placeholders. Set the target afresh for each machine; do not permanently save `$PC` in your profile.

### 1. Start the PsExec remote shell — ADMIN PC

```powershell
$PC = 'TARGET-PC'
$PsExec = 'C:\Tools\PSTools\PsExec.exe'
& $PsExec "\\$PC" -s -nobanner powershell.exe -NoProfile
```

Then verify context before doing anything else:

```powershell
hostname.exe
whoami.exe
```

`exit` returns to your admin PC. `-s` means **SYSTEM on the target**, not the signed-in user. This requires remote administrative access and approved PsExec connectivity; PsExec starts a helper service even when the diagnostic command itself only reads data. Do not disable security controls to make it connect. No plaintext password is needed in these examples. [Microsoft PsExec documentation](https://learn.microsoft.com/en-us/sysinternals/downloads/psexec).

### 2. Inspect network adapters — REMOTE PC

```powershell
Get-NetAdapter | Format-Table Name,InterfaceDescription,Status,LinkSpeed -AutoSize
```

Read-only; ordinary local access normally suffices. Distinguishes a disconnected dock NIC from a working onboard adapter. Select the actual adapter name from the result, not a remembered name.

### 3. Inspect one adapter's IP configuration — REMOTE PC

```powershell
$Adapter = 'Ethernet'
Get-NetIPConfiguration -InterfaceAlias $Adapter | Format-List
```

Read-only. Use **one alias at a time**; the earlier comma-separated alias attempt failed. A disconnected adapter is not automatically a DHCP problem.

### 4. Test a printer or service port — affected PC

```powershell
$Destination = 'DESTINATION-HOST-OR-IP'
$Port = 9100
Test-NetConnection -ComputerName $Destination -Port $Port -InformationLevel Detailed
```

Use `9100` only for a printer that supports RAW printing; use `445` for an authorized SMB connectivity test. Low-impact network probe, usually no elevation required. Review `TcpTestSucceeded`, `InterfaceAlias`, `SourceAddress`, and selected remote address. Test from the affected PC, not just your admin PC. A successful TCP connection is not a successful print or authenticated SMB session; IPv6 printing success does not establish an IPv4/VPN root cause. [Microsoft Test-NetConnection documentation](https://learn.microsoft.com/en-us/powershell/module/nettcpip/test-netconnection).

### 5. View mapped connections — USER SESSION

```powershell
net.exe use
```

Read-only supplemental command. Lists connections in the current logon context. SYSTEM or a different/elevated account will not reliably show the affected user's mappings. Do not add `/delete`, credentials, or a mapping command as a diagnostic default.

### 6. Inspect Search and Update services — REMOTE PC

```powershell
Get-Service -Name WSearch,wuauserv,BITS | Select-Object Name,Status,StartType
```

Read-only; service-query rights required. A stopped demand-start update service is not by itself a failure. Check evidence before starting or restarting anything.

### 7. Inspect Search processes — REMOTE PC

```powershell
Get-Process -Name SearchHost,SearchIndexer -ErrorAction SilentlyContinue |
    Select-Object ProcessName,Id,Responding,CPU
```

Read-only; elevated rights may be needed for full process details. `CPU` is cumulative CPU time, not current utilization. `Responding=True` does not prove Windows Search works. No rows can simply mean these processes are not running or visible in this context.

### 8. Read recent Search/Office errors — REMOTE PC

```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'Application'
    StartTime = (Get-Date).AddDays(-2)
    Level = 2,3
} | Where-Object { $_.ProviderName -match 'Search|Outlook|Office' } |
    Select-Object TimeCreated,ProviderName,Id,Message -First 15 |
    Format-List
```

Read-only; event-log read rights required. Keep errors visible: an inaccessible log is not the same as no matching events. Messages can contain private paths and identifiers—sanitize before sharing.

### 9. Read application crash/hang events — REMOTE PC

```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'Application'
    StartTime = (Get-Date).AddDays(-2)
    Id = 1000,1002
} | Where-Object { $_.Message -match 'OUTLOOK\.EXE|SearchFilterHost\.exe|SearchProtocolHost\.exe' } |
    Select-Object TimeCreated,Id,ProviderName,Message -First 15 |
    Format-List
```

Read-only; event-log read rights required. Evidence of a hang is not proof of its underlying cause.

### 10. Inspect Windows Update policy registry values — ADMIN PC

Run only after exiting the remote shell and setting `$PC`/`$PsExec` locally:

```powershell
& $PsExec "\\$PC" -s -nobanner reg.exe query 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /s
$LASTEXITCODE
```

Read-only query with PsExec's administrative helper-service side effects. An absent key can return exit code 1: it does not mean PsExec failed to connect or that no update-management policy exists anywhere. Do not disable Windows Update or change reboot policy from this result alone.

### 11. Inspect installed printer driver and port — USER SESSION

```powershell
Get-Printer | Format-List Name,DriverName,PortName,PrinterStatus
```

Read-only; PrintManagement module required. Run on the affected PC in the affected user's context to include their connections. No matching printer after removal is expected, not proof of a network fault. Inventory first; port changes, adding drivers, spooler restarts and queue deletion are separate approved changes.

### 12. Check local fixed-disk free space — REMOTE PC

```powershell
Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' |
    Select-Object DeviceID,
        @{N='TotalGB';E={[math]::Round($_.Size/1GB,2)}},
        @{N='FreeGB';E={[math]::Round($_.FreeSpace/1GB,2)}}
```

Read-only; CIM namespace access required. Values labelled GB use PowerShell's binary `1GB` unit (GiB). This is a fast capacity check, not a folder inventory and not permission to delete files.

## Longer script candidates — design proposals, not ready-to-run fixes

1. **Get-WorkstationTriage.ps1:** combine services, processes, bounded event windows, and disk capacity into one timestamped report. Parameters: computer, lookback days, selected categories, output path. Require explicit target; preserve permission/query errors; redact exported identifiers; no automatic service restarts or remediation.
2. **Get-FolderUsageReport.ps1:** replace fragile multiline pastes with a reviewed script file. Parameters: explicit root, maximum depth, exclusions, output path. Exclude reparse points; report access-denied/skipped counts; account for potentially expensive disk I/O and imperfect totals; never delete. The earlier pasted folder scan had parser errors, so do not label it a proven working script.
3. **Get-PrinterPathReport.ps1:** record installed driver/port, local adapter configuration, and explicit IPv4/IPv6 TCP test results from the affected machine. Parameters: printer name/address, port, output path. Preserve user-session context; no VPN, route, driver, port or spooler changes. Extend/reuse the repository's connectivity report rather than duplicate it after its existing implementation is reviewed.

## Copy/paste safety

Remote-shell examples intentionally avoid nesting complex PowerShell inside `-Command`. `$variables` and `$_.Property` must be interpreted on the intended machine; a double-quoted local command string may expand them too early. For longer commands, use a reviewed `.ps1` file and `-File`, or a deliberately UTF-16LE encoded command after review. Encoding is quoting hygiene, not secrecy or a reason to bypass organizational policy.

No destructive cleanup, blanket queue clearing, account changes, reboot commands, update installation or security-policy changes are defaults in this reference. These templates still require authorization for the specific target. Historical evidence and private source links belong in a separate non-public evidence note, not this publishable draft.
