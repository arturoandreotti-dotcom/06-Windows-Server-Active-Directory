param (
    [string]$ReportsDirectory = "C:\ADLab\reports"
)

$ErrorActionPreference = "Stop"

try {
    $DomainDN = (Get-ADDomain).DistinguishedName
    $SearchBase = "OU=Departments,$DomainDN"
    $ReportFilePath = Join-Path $ReportsDirectory "AD_UserAudit.csv"

    if (-not (Test-Path $ReportsDirectory)) {
        New-Item -ItemType Directory -Path $ReportsDirectory | Out-Null
    }

    $ADUsers = Get-ADUser -SearchBase $SearchBase -Filter * -Properties Department, Title |
        Select-Object Name, SamAccountName, Department, Title, Enabled

    $ADUsers | Export-Csv -Path $ReportFilePath

    Write-Host "Report successfully generated: $ReportFilePath" -ForegroundColor Green
    Write-Host "Total users exported: $($ADUsers.Count)"

}
catch {
    Write-Host "Report generation failed: $_" -ForegroundColor Red
    exit 1
}
