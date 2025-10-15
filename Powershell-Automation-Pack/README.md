# Active Directory Scripts

This folder contains PowerShell scripts focused on Active Directory administration and auditing.

## Scripts
- **Audit-LocalAdmins.ps1** – Exports a list of local admin accounts across endpoints.
- **Disable-StaleADAccounts.ps1** – Disables AD users inactive for more than 90 days.

## Example Usage
```powershell
.\Audit-LocalAdmins.ps1 -ExportPath "C:\Reports\Admins.csv"
