
# Lab 07 — Active Directory PowerShell Administration

## Objective

Perform common Active Directory administration tasks using PowerShell and develop a reusable employee account auditing script.

This lab builds upon the infrastructure established in previous labs, combining Active Directory administration, AGDLP authorization, and PowerShell automation.

## Environment

| Component | Configuration |
|---|---|
| Domain Controller | DC01 |
| Operating System | Windows Server 2025 |
| Domain | corp.example.test |
| NetBIOS Name | CORP |
| Client Workstation | CLIENT01 |
| Client OS | Windows 11 Enterprise Evaluation |
| Administrative Account | CORP\Administrator |
| PowerShell | Windows PowerShell 5.1 / PowerShell 7.7.0 |
| Virtualization | Oracle VirtualBox |
| Development Environment | VS Code on host computer |

## 1. PowerShell Module Discovery

Verified the availability of the Active Directory module:

```powershell
Get-Module -ListAvailable ActiveDirectory
```

The ActiveDirectory module was available with version 1.0.1.0.

Listed the commands provided by the module:

```powershell
Get-Command -Module ActiveDirectory
```

### Module Management Concepts

| Command | Purpose |
|---|---|
| Get-Module | List currently loaded modules |
| Get-Module -ListAvailable | List available modules |
| Get-Command -Module ActiveDirectory | Discover AD commands |

## 2. Retrieve Active Directory Users

Retrieved all domain user accounts:

```powershell
Get-ADUser -Filter *
```

The query returned six accounts:

- Administrator
- Guest
- krbtgt
- Marco Rossi
- Giulia Bianchi
- Alessandro Verdi

Selected specific properties for improved readability:

```powershell
Get-ADUser -Filter * |
    Select-Object Name, SamAccountName, Enabled
```

### Important Account Properties

| Property | Purpose |
|---|---|
| Name | Object name |
| SamAccountName | Traditional Windows login name |
| UserPrincipalName | UPN login name |
| Enabled | Account status |
| DistinguishedName | Unique directory name and hierarchical location |
| SID | Security identifier |
| ObjectGUID | Unique directory object identifier |

### Distinguished Name Components

Example:

```text
CN=Marco Rossi,OU=IT,OU=Departments,DC=corp,DC=example,DC=test
```

- CN: Common Name
- OU: Organizational Unit
- DC: Domain Component

A Distinguished Name describes an object's position within the Active Directory hierarchy.

## 3. Filter User Accounts

Retrieved disabled accounts:

```powershell
Get-ADUser -Filter 'Enabled -eq $false' |
    Select-Object Name, SamAccountName, Enabled
```

Result:

```text
Name   SamAccountName Enabled
----   -------------- -------
Guest  Guest            False
krbtgt krbtgt           False
```

Both accounts were already disabled.

### Filtering vs Property Selection

- `-Filter` determines which objects are retrieved.
- `Select-Object` determines which properties are included in the resulting objects.

## 4. Retrieve Individual Accounts

Queried Marco Rossi using his SamAccountName:

```powershell
Get-ADUser -Identity "marco.rossi"
```

The Identity parameter supports identifiers such as:

- SamAccountName
- Distinguished Name
- SID
- GUID

Retrieved additional account properties:

```powershell
Get-ADUser -Identity "marco.rossi" -Properties Department, Title, EmailAddress, LastLogonDate |
    Select-Object Name, Department, Title, EmailAddress, LastLogonDate
```

Initial findings:

- Department was not configured.
- Title was not configured.
- EmailAddress was not configured.
- LastLogonDate contained a timestamp.

LastLogonDate is derived from the replicated lastLogonTimestamp attribute and should not be treated as an exact record of the latest authentication.

## 5. Modify Existing User Attributes

Updated Marco's account:

```powershell
Set-ADUser -Identity "marco.rossi" -Department "IT" -Title "IT Support Technician"
```

Verified the modification:

```powershell
Get-ADUser "marco.rossi" -Properties Department, Title |
    Select-Object Name, Department, Title
```

Result:

| Property | Value |
|---|---|
| Name | Marco Rossi |
| Department | IT |
| Title | IT Support Technician |

### Organizational Units vs Attributes

An account's OU location does not automatically populate its Department attribute.

These are independent Active Directory configurations.

## 6. Preview Administrative Changes

Tested the WhatIf safety mechanism:

```powershell
Set-ADUser -Identity "marco.rossi" -Title "IT Administrator" -WhatIf
```

Result:

```text
What if: Performing the operation "Set" on target "CN=Marco Rossi,OU=IT,OU=Departments,DC=corp,DC=example,DC=test".
```

Verified that the actual title remained unchanged:

```powershell
Get-ADUser -Identity "marco.rossi" -Properties Title |
    Select-Object Name, Title
```

Result:

```text
Name        Title
----        -----
Marco Rossi IT Support Technician
```

### WhatIf Limitations

WhatIf previews supported operations without applying the requested modification.

The output may identify the operation and target without describing every attribute-level change.

It does not guarantee that the actual operation will succeed.

WhatIf is especially useful when validating the scope of bulk administrative operations.

## 7. Discover Cmdlet Documentation

Attempted to retrieve New-ADUser examples:

```powershell
Get-Help New-ADUser -Examples
```

PowerShell reported that the local help files were unavailable.

Updated the Active Directory module's help documentation:

```powershell
Update-Help -Module ActiveDirectory -Force
```

Repeated the original command successfully:

```powershell
Get-Help New-ADUser -Examples
```

The documentation provided practical examples, including account creation using splatting and secure password input.

## 8. Employee Onboarding

Simulated onboarding a new IT employee.

| Property | Value |
|---|---|
| Name | Luca Ferrari |
| Username | luca.ferrari |
| UPN | luca.ferrari@corp.example.test |
| Department | IT |
| Title | Junior IT Technician |
| OU | Departments/IT |

### Prepare Account Parameters

Used a PowerShell hashtable to organize the account creation parameters:

```powershell
$UserParameters = @{
    Name                  = "Luca Ferrari"
    GivenName             = "Luca"
    Surname               = "Ferrari"
    SamAccountName        = "luca.ferrari"
    UserPrincipalName     = "luca.ferrari@corp.example.test"
    Department            = "IT"
    Title                 = "Junior IT Technician"
    Path                  = "OU=IT,OU=Departments,DC=corp,DC=example,DC=test"
    AccountPassword       = (Read-Host "Enter password" -AsSecureString)
    Enabled               = $true
    ChangePasswordAtLogon = $false
}
```

The initial password was entered interactively and is not included in the repository.

ChangePasswordAtLogon was set to false for convenience in this isolated lab. Production onboarding would generally require employees to change their temporary passwords.

### Splatting

Splatting passes the contents of a hashtable as named command parameters.

- `$UserParameters` references the hashtable.
- `@UserParameters` expands its contents into command parameters.

### Preview Account Creation

```powershell
New-ADUser @UserParameters -WhatIf
```

Result:

```text
What if: Performing the operation "New" on target "CN=Luca Ferrari,OU=IT,OU=Departments,DC=corp,DC=example,DC=test".
```

### Create the Account

```powershell
New-ADUser @UserParameters
```

### Verify the Account

```powershell
Get-ADUser "luca.ferrari" -Properties Department, Title |
    Select-Object Name, SamAccountName, Department, Title, Enabled
```

Result:

```text
Name           : Luca Ferrari
SamAccountName : luca.ferrari
Department     : IT
Title          : Junior IT Technician
Enabled        : True
```

The new account was successfully created and enabled.

## 9. Security Group Administration

Inspected Luca's initial group memberships:

```powershell
Get-ADPrincipalGroupMembership -Identity "luca.ferrari" |
    Select-Object Name, GroupScope, GroupCategory
```

Result:

```text
Name         GroupScope GroupCategory
----         ---------- -------------
Domain Users     Global      Security
```

Although Luca was located in the IT OU, he was not automatically a member of the IT security group.

### Assign Departmental Group Membership

```powershell
Add-ADGroupMember -Identity "SG_IT_Users" -Members "luca.ferrari"
```

Verified the change:

```powershell
Get-ADPrincipalGroupMembership -Identity "luca.ferrari" |
    Select-Object Name, GroupScope, GroupCategory
```

Result:

```text
Name         GroupScope GroupCategory
----         ---------- -------------
Domain Users     Global      Security
SG_IT_Users      Global      Security
```

### Inspect Nested Group Membership

Queried the global security group:

```powershell
Get-ADPrincipalGroupMembership -Identity "SG_IT_Users" |
    Select-Object Name, GroupScope, GroupCategory
```

Result:

```text
Name            GroupScope GroupCategory
----            ---------- -------------
DL_IT_Share_RW DomainLocal      Security
```

Inspected the resource group:

```powershell
Get-ADGroup -Identity "DL_IT_Share_RW"
```

Retrieved its direct members:

```powershell
Get-ADGroupMember -Identity "DL_IT_Share_RW"
```

The direct member was SG_IT_Users.

Expanded the nested group membership:

```powershell
Get-ADGroupMember -Identity "DL_IT_Share_RW" -Recursive |
    Select-Object Name, SamAccountName, ObjectClass
```

Result:

```text
Name         SamAccountName ObjectClass
----         -------------- -----------
Luca Ferrari luca.ferrari   user
Marco Rossi  marco.rossi    user
```

### Group Administration Commands

| Command | Purpose |
|---|---|
| Get-ADGroup | Retrieve group information |
| Get-ADGroupMember | Retrieve direct group members |
| Get-ADGroupMember -Recursive | Expand nested group membership |
| Get-ADPrincipalGroupMembership | Retrieve groups a principal belongs to |
| Add-ADGroupMember | Add members to a group |

## 10. Validate AGDLP Resource Access

The existing authorization model from Lab 06 was reused:

```text
Luca Ferrari
    |
    v
SG_IT_Users
    |
    v
DL_IT_Share_RW
    |
    +-- NTFS Modify
    +-- SMB Change
    |
    v
\\DC01\IT
```

Signed in to CLIENT01 using Luca's domain account.

Verified the identity:

```powershell
whoami
```

Result:

```text
corp\luca.ferrari
```

Created a test file on the network share:

```powershell
New-Item -ItemType File "\\DC01\IT\Luca-Access-Test.txt"
```

Listed the share contents:

```powershell
Get-ChildItem "\\DC01\IT"
```

Result:

```text
IT-Access-Test.txt
Luca-Access-Test.txt
```

### Validation

| Test | Result |
|---|---|
| Domain login | PASS |
| Identity verification | PASS |
| Network share access | PASS |
| File creation | PASS |
| Directory listing | PASS |

No additional NTFS or SMB ACL changes were required.

This demonstrates the benefits of group-based resource authorization during employee onboarding.

## 11. Account Lifecycle Management

Simulated temporarily disabling an employee account.

Signed Luca out of CLIENT01:

```powershell
shutdown /l
```

### Disable the Account

Previewed the operation:

```powershell
Disable-ADAccount -Identity "luca.ferrari" -WhatIf
```

Executed:

```powershell
Disable-ADAccount -Identity "luca.ferrari"
```

Verified:

```powershell
Get-ADUser "luca.ferrari" |
    Select-Object Name, Enabled
```

Result:

```text
Name         Enabled
----         -------
Luca Ferrari   False
```

Attempted to authenticate as Luca on CLIENT01.

Windows rejected the login because the account was disabled.

### Re-enable the Account

```powershell
Enable-ADAccount -Identity "luca.ferrari" -WhatIf
Enable-ADAccount -Identity "luca.ferrari"
```

Verified:

```powershell
Get-ADUser "luca.ferrari" |
    Select-Object Name, Enabled
```

Result:

```text
Name         Enabled
----         -------
Luca Ferrari    True
```

### Validate Restored Access

Signed back in as Luca on CLIENT01.

```powershell
Get-ChildItem "\\DC01\IT"
Get-Content "\\DC01\IT\IT-Access-Test.txt"
```

Successfully listed the shared files and read Marco's test file:

```text
Created by Marco Rossi.
Testing SMB Change and NTFS Modify permissions.
```

Disabling and re-enabling the account preserved its identity, password, and group-based access configuration.

### Account Lifecycle Results

| Operation | Result |
|---|---|
| Account creation | PASS |
| Group assignment | PASS |
| Resource access | PASS |
| Account disablement | PASS |
| Authentication rejection | PASS |
| Account re-enablement | PASS |
| Restored resource access | PASS |

## 12. Active Directory User Auditing

Created an employee-focused query using SearchBase:

```powershell
Get-ADUser -Filter * -SearchBase "OU=Departments,DC=corp,DC=example,DC=test" -Properties Department, Title |
    Select-Object Name, SamAccountName, Department, Title, Enabled
```

The query excluded built-in accounts outside the Departments OU.

Retrieved four employee accounts.

### Audit Findings

| Employee | Department | Title | Enabled |
|---|---|---|---|
| Marco Rossi | IT | IT Support Technician | True |
| Giulia Bianchi | Not configured | Not configured | True |
| Alessandro Verdi | Not configured | Not configured | True |
| Luca Ferrari | IT | Junior IT Technician | True |

The missing employee attributes were identified but intentionally left unchanged.

### Search Parameters

| Parameter | Purpose |
|---|---|
| Filter | Select matching objects |
| SearchBase | Specify the directory search location |
| Properties | Retrieve additional object attributes |
| Select-Object | Select output properties |

## 13. Manual CSV Report Generation

Created a local reports directory on DC01:

```powershell
New-Item -ItemType Directory -Path "C:\ADLab\reports" -Force
```

Exported the employee accounts:

```powershell
Get-ADUser -Filter * -SearchBase "OU=Departments,DC=corp,DC=example,DC=test" -Properties Department, Title |
    Select-Object Name, SamAccountName, Department, Title, Enabled |
    Export-Csv -Path "C:\ADLab\reports\AD_UserAudit.csv"
```

Verified the generated CSV:

```powershell
Get-Content "C:\ADLab\reports\AD_UserAudit.csv"
```

Confirmed that the report contained five columns and four employee records.

## 14. Dynamic Configuration

Replaced the hardcoded domain Distinguished Name with dynamic discovery:

```powershell
$DomainDN = (Get-ADDomain).DistinguishedName
$SearchBase = "OU=Departments,$DomainDN"
```

Result:

```text
OU=Departments,DC=corp,DC=example,DC=test
```

Constructed the report path dynamically:

```powershell
$ReportsDirectory = "C:\ADLab\reports"
$ReportFilePath = Join-Path $ReportsDirectory "AD_UserAudit.csv"
```

Result:

```text
C:\ADLab\reports\AD_UserAudit.csv
```

This reduced hardcoded configuration values and improved script maintainability.

The script still assumes that a top-level Departments OU exists in the target domain.

## 15. Host-to-VM Development Workflow

Configured a VirtualBox shared folder to allow script development on the host computer and execution on DC01.

### Shared Folder Configuration

| Setting | Value |
|---|---|
| Host Directory | labs/07-ad-powershell/scripts |
| Shared Folder Name | ADScripts |
| Access | Read-only |
| Auto-mount | Enabled |
| Guest Path | \\VBOXSVR\ADScripts |

Verified access from DC01:

```powershell
Get-ChildItem "\\VBOXSVR\ADScripts"
```

Navigated to the shared directory:

```powershell
Set-Location "\\VBOXSVR\ADScripts"
```

### Development Workflow

```text
Host PC
    |
    +-- VS Code
    +-- Git repository
    |
    v
VirtualBox read-only shared folder
    |
    v
DC01
    |
    +-- PowerShell 7
    +-- ActiveDirectory module
    +-- Local report generation
```

Only the scripts directory was shared with the virtual machine.

Generated reports remained on DC01.

### IntelliSense Limitation

The ActiveDirectory module was unavailable on the Windows 11 Home host.

Consequently, AD-specific PowerShell commands were not available through local IntelliSense.

This did not prevent script development on the host or execution on DC01, where the required module was installed.

## 16. Reusable Active Directory Audit Script

Developed:

[Get-ADUserAuditReport.ps1](scripts/Get-ADUserAuditReport.ps1)

### Script Features

- Configurable report destination.
- Dynamic domain discovery.
- OU-scoped employee account retrieval.
- Automatic report directory creation.
- CSV export.
- User count reporting.
- Structured error handling.
- Failure exit code.

### Requirements

- Windows PowerShell or PowerShell 7 with a compatible ActiveDirectory module.
- Connectivity to Active Directory Domain Services.
- Permission to read the requested directory objects.
- Write access to the report destination.
- A top-level Departments OU.

The script was tested on DC01 using PowerShell 7.7.0.

### Usage

Run with the default report directory:

```powershell
.\Get-ADUserAuditReport.ps1
```

Specify a custom output directory:

```powershell
.\Get-ADUserAuditReport.ps1 -ReportsDirectory "C:\ADLab\reports-test"
```

Run directly from the VirtualBox shared folder:

```powershell
& "\\VBOXSVR\ADScripts\Get-ADUserAuditReport.ps1"
```

### Error Handling

The script uses:

```powershell
$ErrorActionPreference = "Stop"
```

Combined with a try/catch structure, this allows non-terminating PowerShell errors to be treated as terminating errors.

The catch block displays a failure message and returns exit code 1.

## 17. Script Validation

### Test 1 — Default Execution

Executed:

```powershell
.\Get-ADUserAuditReport.ps1
```

Result:

```text
Report successfully generated: C:\ADLab\reports\AD_UserAudit.csv
Total users exported: 4
```

**Result: PASS**

### Test 2 — Custom Report Directory

Executed:

```powershell
\\VBOXSVR\ADScripts\Get-ADUserAuditReport.ps1 -ReportsDirectory "C:\ADLab\reports-test"
```

Result:

```text
Report successfully generated: C:\ADLab\reports-test\AD_UserAudit.csv
Total users exported: 4
```

Verified the report:

```powershell
Get-Content "C:\ADLab\reports-test\AD_UserAudit.csv"
```

Confirmed that the generated CSV contained all four employee accounts and their expected attributes.

**Result: PASS**

### Test 3 — Write-Protected Destination

Intentionally selected the read-only VirtualBox shared folder as the output directory:

```powershell
\\VBOXSVR\ADScripts\Get-ADUserAuditReport.ps1 -ReportsDirectory "\\VBOXSVR\ADScripts"
```

Result:

```text
Report generation failed: The media is write protected. : '\\VBOXSVR\ADScripts\AD_UserAudit.csv'.
```

Verified the exit code:

```powershell
$LASTEXITCODE
```

Result:

```text
1
```

The failure was handled correctly, and no misleading success message appeared.

**Result: PASS**

## 18. Troubleshooting Summary

### Problem 1 — Missing PowerShell Help Files

**Issue:** Get-Help did not provide New-ADUser examples.

**Resolution:** Updated the module help using Update-Help.

### Problem 2 — Incorrect Property Name

**Issue:** Selected Enable instead of Enabled.

**Resolution:** Corrected the requested property name.

### Problem 3 — Missing Additional Properties

**Issue:** Department and Title appeared empty even for accounts with configured attributes.

**Resolution:** Added the Properties parameter to Get-ADUser.

**Lesson:** Select-Object cannot retrieve attributes that were not requested from Active Directory.

### Problem 4 — Invalid SearchBase

**Issue:** The SearchBase omitted the DC=corp domain component.

**Resolution:** Corrected the Distinguished Name and subsequently implemented dynamic domain discovery.

### Problem 5 — Incorrect Test-Path Condition

**Issue:** The directory existence check did not pass the directory path to Test-Path within the conditional expression.

**Resolution:**

```powershell
if (-not (Test-Path $ReportsDirectory)) {
    New-Item -ItemType Directory -Path $ReportsDirectory | Out-Null
}
```

### Problem 6 — Error Handling Syntax

**Issue:** ErrorAction Stop was initially attached to the try statement instead of individual cmdlets.

**Resolution:** Used ErrorActionPreference to configure script-wide error behavior.

### Problem 7 — Missing AD IntelliSense

**Issue:** AD-specific commands did not autocomplete on the host.

**Resolution:** Continued developing on the host and executing scripts on DC01, where the ActiveDirectory module was available.

### Problem 8 — Write-Protected Report Destination

**Issue:** Intentional CSV export failure during validation.

**Result:** The script caught the error and returned exit code 1.

## 19. Repository and Data Management

Version-controlled content includes:

- PowerShell source code.
- Lab documentation.
- Git ignore configuration.

Generated reports and temporary report directories are excluded from version control.

This separates reusable automation code from generated operational data and reduces the risk of publishing sensitive employee information.

Passwords are never included in the repository.

## 20. Final Validation

| Test | Result |
|---|---|
| ActiveDirectory module discovery | PASS |
| User account retrieval | PASS |
| Account filtering | PASS |
| Additional property retrieval | PASS |
| Account modification | PASS |
| WhatIf verification | PASS |
| PowerShell help update | PASS |
| New employee creation | PASS |
| Security group assignment | PASS |
| Nested group verification | PASS |
| AGDLP resource access | PASS |
| Account disablement | PASS |
| Authentication rejection | PASS |
| Account re-enablement | PASS |
| Resource access restoration | PASS |
| OU-scoped auditing | PASS |
| Manual CSV export | PASS |
| Dynamic domain discovery | PASS |
| Shared folder script execution | PASS |
| Default script execution | PASS |
| Custom directory execution | PASS |
| Error handling | PASS |
| Failure exit code | PASS |

## 21. Key Takeaways

- PowerShell enables repeatable Active Directory administration.
- Module discovery and documentation reduce the need to memorize command syntax.
- Organizational Units and security groups serve different purposes.
- AGDLP simplifies employee onboarding and resource access management.
- Account disablement preserves the account and its existing configuration.
- SearchBase limits administrative queries to the intended directory scope.
- Additional AD properties must be explicitly requested when required.
- Splatting improves the readability of commands with multiple parameters.
- Dynamic configuration improves automation maintainability.
- WhatIf helps validate the targets of supported administrative operations.
- Error handling prevents misleading success messages.
- Automation should be validated using both successful and failing scenarios.
- Generated operational data should be separated from version-controlled source code.

## Next Steps

- Practice Active Directory troubleshooting and recovery.
- Investigate common domain authentication and DNS issues.
- Complete the remaining Windows Server infrastructure documentation.
