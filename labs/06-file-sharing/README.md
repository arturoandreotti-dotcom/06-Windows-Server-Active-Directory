
# Lab 06 — SMB File Sharing, NTFS Permissions & AGDLP

## Objective

Configure a secure departmental network share using Windows Server 2025, Active Directory security groups, NTFS permissions, and SMB share permissions.

Implement the AGDLP authorization model and validate access using authorized and unauthorized domain accounts.

## Environment

| Component | Configuration |
|---|---|
| File Server | DC01 |
| Operating System | Windows Server 2025 Standard Evaluation |
| Domain | corp.example.test |
| Domain NetBIOS Name | CORP |
| Server IP | 192.168.100.10 |
| Client | CLIENT01 |
| Client OS | Windows 11 Enterprise Evaluation |
| Client IP | 192.168.100.20 |
| Virtualization | Oracle VirtualBox |
| Network | AD-Lab-NAT |

For this isolated lab, DC01 also acts as the file server. In a production environment, file-serving workloads are generally hosted on dedicated member servers rather than Domain Controllers.

## 1. File Sharing Fundamentals

Windows file sharing uses two independent permission layers:

### NTFS Permissions

NTFS permissions control access to files and folders on the filesystem.

Common permissions include:

- Read
- Read & Execute
- Write
- Modify
- Full Control

NTFS permissions are stored in Access Control Lists (ACLs).

An ACL contains Access Control Entries (ACEs), specifying which users or groups receive particular permissions.

### SMB Share Permissions

Server Message Block (SMB) enables clients to access shared folders across a network.

Common share permissions include:

- Read
- Change
- Full Control

When accessing files through an SMB share, both share and NTFS permissions must allow the requested operation.

The effective access is constrained by both permission layers.

## 2. AGDLP Authorization Model

The project previously created the following Active Directory groups:

| Group | Scope | Purpose |
|---|---|---|
| SG_IT_Users | Global | IT department membership |
| SG_HR_Users | Global | HR department membership |
| SG_Sales_Users | Global | Sales department membership |
| DL_IT_Share_RW | Domain Local | IT shared-folder access |

### AGDLP

AGDLP stands for:

```text
Accounts → Global Groups → Domain Local Groups → Permissions
```

Our implementation:

```text
Marco Rossi
    |
    v
SG_IT_Users
    |
    v
DL_IT_Share_RW
    |
    +-- NTFS Modify
    |
    +-- SMB Change
    |
    v
\\DC01\IT
```

This design separates employee roles from resource-specific permissions.

The Domain Local group identifies the security principals receiving access. The actual permissions are defined by the NTFS and SMB ACLs.

## 3. Create the Folder Structure

On DC01, opened PowerShell and created the root directory:

```powershell
New-Item -ItemType Directory -Path "C:\Shares"
```

Verified its existence:

```powershell
Test-Path "C:\Shares"
```

Result:

```text
True
```

Created the IT departmental folder:

```powershell
New-Item -ItemType Directory -Path "C:\Shares\IT"
```

Verified:

```powershell
Get-ChildItem "C:\Shares"
```

Confirmed that the IT directory existed.

### Folder Structure

```text
C:\
└── Shares\
    └── IT\
```

## 4. Inspect Initial NTFS Permissions

Before changing permissions, inspected the folder's ACL:

```powershell
(Get-Acl -Path "C:\Shares\IT").Access |
    Select-Object IdentityReference, FileSystemRights, AccessControlType, IsInherited
```

The initial permissions included:

| Identity | Rights | Inherited |
|---|---|---|
| BUILTIN\Administrators | FullControl | No |
| NT AUTHORITY\SYSTEM | FullControl | Yes |
| BUILTIN\Administrators | FullControl | Yes |
| BUILTIN\Users | ReadAndExecute | Yes |
| BUILTIN\Users | CreateDirectories | Yes |
| BUILTIN\Users | CreateFiles | Yes |
| CREATOR OWNER | Special | Yes |

### ACL Terminology

- **ACL:** Access Control List
- **ACE:** Access Control Entry
- **IdentityReference:** User or group receiving permissions
- **FileSystemRights:** Allowed filesystem operations
- **AccessControlType:** Allow or Deny
- **IsInherited:** Whether an individual ACE was inherited

An entry with `IsInherited = False` is explicit.

This does not necessarily mean that inheritance is disabled for the entire folder.

### Inspect Inheritance

Executed:

```powershell
(Get-Acl "C:\Shares\IT").AreAccessRulesProtected
```

Result:

```text
False
```

This confirmed that the folder initially accepted inherited access rules.

## 5. Investigate Parent Folder Permissions

Compared the ACLs on:

```text
C:\
C:\Shares
C:\Shares\IT
```

Commands included:

```powershell
(Get-Acl "C:\Shares").Access |
    Select-Object IdentityReference, FileSystemRights, IsInherited
```

```powershell
(Get-Acl "C:\").Access |
    Select-Object IdentityReference, FileSystemRights, IsInherited |
    Format-List
```

### Findings

- The root of the C: drive contained explicit permission entries.
- The Shares and IT folders contained inherited permissions.
- Both Shares and IT also contained an explicit Administrators entry.
- The ACL output showed which entries were inherited but did not establish who originally created the explicit entries.

### Display Troubleshooting

`Format-Table` did not display every requested column because one security identity had a very long SID.

Used `Format-List` to display the permission properties vertically.

This made the inheritance status readable.

## 6. Configure Secure NTFS Permissions

Opened:

```text
C:\Shares\IT
```

Then selected:

**Properties → Security → Advanced**

### Disable Inheritance

Clicked **Disable inheritance** and selected:

**Convert inherited permissions into explicit permissions on this object**

This preserved existing access entries for review rather than immediately removing them.

### Remove Broad User Access

Removed the general Users permission entries that had been converted from inherited permissions.

Preserved administrative and system access.

### Add the Resource Security Group

Added the following permission entry:

| Property | Configuration |
|---|---|
| Principal | CORP\DL_IT_Share_RW |
| Type | Allow |
| Permission | Modify |
| Applies to | This folder, subfolders and files |

Modify permits users to read, create, edit, and delete files, without granting full permission-management rights.

### Final NTFS Verification

Executed:

```powershell
(Get-Acl "C:\Shares\IT").Access |
    Select-Object IdentityReference, FileSystemRights, IsInherited
```

Verified result:

```text
IdentityReference         FileSystemRights IsInherited
-----------------         ---------------- -----------
CREATOR OWNER                  FullControl       False
NT AUTHORITY\SYSTEM            FullControl       False
BUILTIN\Administrators         FullControl       False
CORP\DL_IT_Share_RW    Modify, Synchronize       False
```

All displayed ACEs were explicit.

The resource group received Modify permissions, while SYSTEM and Administrators retained Full Control.

## 7. Create the SMB Network Share

Created an SMB share using PowerShell.

### Initial Attempt

```powershell
New-SmbShare -Name "IT" -Path "C:\Shares\IT" -ChangeAccess "CORP\DL_IT_Share_RW" -FullAccess "CORP\Administrators"
```

Result:

```text
New-SmbShare: No mapping between account names and security IDs was done.
```

The error indicated that at least one supplied account name could not be translated into a security identifier.

### Investigate the Security Principals

Verified the Domain Local group:

```powershell
Get-ADGroup -Identity "DL_IT_Share_RW" |
    Select-Object Name, SID
```

Confirmed that the group existed and had a valid SID.

Also attempted:

```powershell
Get-LocalGroup -Name "Administrators" |
    Select-Object Name, SID
```

The command returned:

```text
Get-LocalGroup: Group Administrators was not found.
```

DC01 is a Domain Controller, so it does not use ordinary local SAM accounts and groups in the same way as a member workstation.

The built-in Administrators group is available through the BUILTIN security namespace.

Its well-known SID is:

```text
S-1-5-32-544
```

### Corrected Command

```powershell
New-SmbShare -Name "IT" -Path "C:\Shares\IT" -ChangeAccess "CORP\DL_IT_Share_RW" -FullAccess "BUILTIN\Administrators"
```

Result:

```text
Name ScopeName Path
---- --------- ----
IT   *         C:\Shares\IT
```

**Result: PASS**

The SMB share was successfully created.

## 8. Verify SMB Configuration

### Inspect the Share

Executed:

```powershell
Get-SmbShare -Name "IT"
```

Result:

```text
Name ScopeName Path
---- --------- ----
IT   *         C:\Shares\IT
```

### Inspect Share Permissions

Executed:

```powershell
Get-SmbShareAccess -Name "IT"
```

Result:

```text
Name ScopeName AccountName            AccessControlType AccessRight
---- --------- -----------            ----------------- -----------
IT   *         BUILTIN\Administrators Allow             Full
IT   *         CORP\DL_IT_Share_RW    Allow             Change
```

### Permission Comparison

| Security layer | Principal | Permission |
|---|---|---|
| NTFS | CORP\DL_IT_Share_RW | Modify |
| SMB | CORP\DL_IT_Share_RW | Change |
| NTFS | BUILTIN\Administrators | Full Control |
| SMB | BUILTIN\Administrators | Full |

The share was available using:

```text
\\DC01\IT
```

### Important Distinction

`Get-Acl` retrieves filesystem permissions.

`Get-SmbShare` retrieves registered SMB share information.

`Get-SmbShareAccess` retrieves share-level permissions.

SMB share names are registered with the Windows SMB server. They do not depend on PowerShell's current working directory.

## 9. Positive Access Test — IT Employee

On CLIENT01, signed in as:

```text
CORP\marco.rossi
```

Opened File Explorer and navigated to:

```text
\\DC01\IT
```

### Results

The folder opened successfully without requesting alternative credentials.

Created:

```text
IT-Access-Test.txt
```

Added the following content:

```text
Created by Marco Rossi.
Testing SMB Change and NTFS Modify permissions.
```

Saved and closed the file.

### Validation

| Test | Result |
|---|---|
| Open IT share | PASS |
| Create file | PASS |
| Edit file | PASS |
| Save file | PASS |

The test confirmed that Marco received access through the nested Active Directory groups and the configured NTFS and SMB permissions.

## 10. Negative Access Test — HR Employee

Signed out of Marco's session and signed in as:

```text
giulia.bianchi@corp.example.test
```

Attempted to open:

```text
\\DC01\IT
```

Windows denied access to the location.

Verified the signed-in account:

```powershell
whoami
```

Result:

```text
corp\giulia.bianchi
```

### Validation

| Test | Result |
|---|---|
| HR identity verified | PASS |
| Access to IT share denied | PASS |

Giulia belonged to `SG_HR_Users` and had not been granted access through `DL_IT_Share_RW`.

## 11. Negative Access Test — Sales Employee

Signed in as:

```text
alessandro.verdi@corp.example.test
```

Attempted to access:

```text
\\DC01\IT
```

Windows denied access.

Verified identity:

```powershell
whoami
```

Result:

```text
corp\alessandro.verdi
```

### Validation

| Test | Result |
|---|---|
| Sales identity verified | PASS |
| Access to IT share denied | PASS |

This confirmed that the share restrictions worked for another unauthorized departmental account.

## 12. Final Permissions Audit

Following the client access tests, verified the server configuration again.

### NTFS

```powershell
(Get-Acl "C:\Shares\IT").Access |
    Select-Object IdentityReference, FileSystemRights, IsInherited
```

Confirmed:

- SYSTEM — Full Control
- Administrators — Full Control
- CREATOR OWNER — Full Control for applicable child objects
- DL_IT_Share_RW — Modify
- All displayed entries explicit

### SMB

```powershell
Get-SmbShareAccess -Name "IT"
```

Confirmed:

- BUILTIN\Administrators — Full
- CORP\DL_IT_Share_RW — Change

No unintended permission changes were observed during testing.

## 13. Troubleshooting Summary

### Problem 1 — Understanding Explicit and Inherited ACEs

**Issue:** Administrators appeared with both explicit and inherited permissions.

**Investigation:** Compared ACLs across the root directory, Shares folder, and IT folder.

**Lesson:** The `IsInherited` property describes an individual ACE, not the folder's overall inheritance status.

### Problem 2 — SMB Account Name Resolution

**Issue:** `New-SmbShare` returned an account-name-to-SID mapping error.

**Resolution:** Used `BUILTIN\Administrators` instead of `CORP\Administrators`.

**Lesson:** Security principals must be specified using names that Windows can resolve.

### Problem 3 — Incorrect User Session During Testing

**Issue:** Initial testing suggested that an HR user could access the IT share.

**Investigation:** Discovered that the workstation was still using Marco's session.

**Resolution:** Signed out, signed in using Giulia's domain account, verified the identity with `whoami`, and repeated the test.

**Lesson:** Always verify the effective user identity before drawing conclusions from access-control tests.

## 14. Validation Summary

| Test | Result |
|---|---|
| Root Shares folder created | PASS |
| IT directory created | PASS |
| Initial NTFS ACL inspected | PASS |
| Inheritance status verified | PASS |
| NTFS permissions restricted | PASS |
| DL_IT_Share_RW granted NTFS Modify | PASS |
| SMB share created | PASS |
| SMB permissions verified | PASS |
| Marco accessed the share | PASS |
| Marco created and modified a file | PASS |
| Giulia denied access | PASS |
| Alessandro denied access | PASS |
| Final NTFS audit | PASS |
| Final SMB audit | PASS |

## 15. Key Takeaways

- SMB provides network file-sharing functionality.
- NTFS permissions control filesystem access.
- SMB share permissions control access through the network.
- Both permission layers are evaluated during network access.
- ACLs contain ACEs defining permissions for users and groups.
- Explicit and inherited ACEs can coexist.
- Active Directory security groups can be used as reusable access principals.
- AGDLP separates accounts, departmental roles, resource groups, and permissions.
- Administrators should avoid granting individual users direct resource permissions when group-based management is appropriate.
- Security testing should include both authorized and unauthorized accounts.
- Identity verification is essential when investigating permissions.
- PowerShell provides tools for inspecting and validating Windows file-sharing configuration.

## Next Steps

- Expand the lab with additional departmental resources where appropriate.
- Practice permission troubleshooting and auditing.
- Automate selected Active Directory and file-server administration tasks.
- Continue documenting the Windows Server infrastructure project.
