
# Lab 03 — Active Directory Users, OUs & Security Groups

## Objective

Create and organize Active Directory user accounts, Organizational Units (OUs), and security groups in a Windows Server 2025 domain environment.

Practice employee onboarding, group membership management, the AGDLP permission model, and PowerShell-based verification.

## Environment

| Component | Configuration |
|---|---|
| Domain Controller | DC01 |
| Operating System | Windows Server 2025 Standard Evaluation |
| Active Directory Domain | corp.example.test |
| NetBIOS Domain Name | CORP |
| Domain Controller IP | 192.168.100.10 |
| Management Tools | Active Directory Users and Computers (ADUC), PowerShell |

## 1. Organizational Unit Structure

Created the following OUs using Active Directory Users and Computers:

```text
corp.example.test
├── Departments
│   ├── IT
│   ├── HR
│   └── Sales
├── Groups
└── Workstations
```

Accidental deletion protection was enabled for the OUs.

### Purpose

- **Departments:** Organize employee accounts by department.
- **Groups:** Organize security groups used for access management.
- **Workstations:** Organize domain-joined client computers.

OUs provide organizational boundaries and support Group Policy targeting. They do not automatically grant resource permissions.

## 2. Domain User Accounts

Created three employee accounts in their respective department OUs.

| Name | Username | OU | Account Status |
|---|---|---|---|
| Marco Rossi | marco.rossi | IT | Enabled |
| Giulia Bianchi | giulia.bianchi | HR | Enabled |
| Alessandro Verdi | alessandro.verdi | Sales | Enabled |

Example login formats:

```text
CORP\marco.rossi
marco.rossi@corp.example.test
```

Temporary passwords were configured during account creation.

The initial onboarding configuration required password changes at first login. For lab convenience, this requirement was later disabled for Marco's account to support testing with an existing lab password.

Passwords are not stored in this repository.

## 3. Global Security Groups

Created three Global Security Groups inside the Groups OU.

| Group | Scope | Category | Member |
|---|---|---|---|
| SG_IT_Users | Global | Security | Marco Rossi |
| SG_HR_Users | Global | Security | Giulia Bianchi |
| SG_Sales_Users | Global | Security | Alessandro Verdi |

Global Security Groups represent departmental membership.

### Important distinction

- **OU membership:** Determines where an AD object is organized and which OU-linked policies may apply.
- **Security group membership:** Provides a basis for assigning access permissions.

Moving a user into a departmental OU does not automatically add that user to a corresponding security group.

## 4. Domain Local Security Group and AGDLP

Created:

```text
DL_IT_Share_RW
```

Configuration:

| Property | Value |
|---|---|
| Group category | Security |
| Group scope | Domain Local |
| Intended resource | IT shared folder |
| Intended access | Read/Write |

Added the Global Security Group `SG_IT_Users` as a member of `DL_IT_Share_RW`.

### AGDLP Model

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
    v
IT shared-folder permissions
(Not configured yet)
```

This approach separates employee roles from resource-specific permissions.

Actual NTFS and share permissions will be configured in a later lab.

## 5. PowerShell Verification

### Retrieve department users

```powershell
Get-ADUser -Filter * -SearchBase "OU=Departments,DC=corp,DC=example,DC=test" |
    Select-Object Name, SamAccountName, Enabled
```

Verified results:

```text
Name             SamAccountName   Enabled
----             --------------   -------
Marco Rossi      marco.rossi         True
Giulia Bianchi   giulia.bianchi      True
Alessandro Verdi alessandro.verdi    True
```

### Inspect a security group

```powershell
Get-ADGroup -Identity "SG_IT_Users"
```

Verified properties:

```text
GroupCategory : Security
GroupScope    : Global
Name          : SG_IT_Users
ObjectClass   : group
```

### Verify departmental memberships

```powershell
Get-ADGroupMember -Identity "SG_IT_Users"
Get-ADGroupMember -Identity "SG_HR_Users"
Get-ADGroupMember -Identity "SG_Sales_Users"
```

Verified that each group contained the correct employee account.

### Verify nested group membership

```powershell
Get-ADGroupMember -Identity "DL_IT_Share_RW" |
    Select-Object Name, ObjectClass, SamAccountName
```

Result:

```text
Name        ObjectClass SamAccountName
----        ----------- --------------
SG_IT_Users group       SG_IT_Users
```

### Verify recursive membership

```powershell
Get-ADGroupMember -Identity "DL_IT_Share_RW" -Recursive |
    Select-Object Name, ObjectClass
```

Result:

```text
Name        ObjectClass
----        -----------
Marco Rossi user
```

The recursive query demonstrated that Marco belongs to the Domain Local group indirectly through `SG_IT_Users`.

## 6. Troubleshooting

### Incorrect object type

**Issue:** Accidentally created an OU named `SG_IT_Users` instead of a Security Group.

**Resolution:**

1. Enabled Advanced Features in ADUC.
2. Removed accidental deletion protection from the incorrect OU.
3. Deleted the incorrect OU.
4. Created a new Group object with Global scope and Security category.

**Lesson:** Organizational Units and security groups are different Active Directory object types.

### Group membership not saved

**Issue:** `Get-ADGroupMember` initially returned no members for `SG_IT_Users`.

**Cause:** The membership change had not been applied in ADUC.

**Resolution:** Saved the group membership change and repeated the PowerShell query.

**Lesson:** Always verify administrative changes rather than assuming the GUI operation succeeded.

## 7. Validation Summary

| Test | Result |
|---|---|
| Department OUs created | PASS |
| Groups and Workstations OUs created | PASS |
| Three employee accounts created | PASS |
| All employee accounts enabled | PASS |
| Departmental security groups created | PASS |
| Group memberships verified | PASS |
| Domain Local group created | PASS |
| Global Group nested within Domain Local group | PASS |
| Recursive membership verified | PASS |

## 8. Key Takeaways

- Organizational Units organize AD objects and enable targeted Group Policy application.
- Security groups are used to manage resource access.
- Global Security Groups commonly represent organizational roles.
- Domain Local Security Groups commonly represent resource permissions.
- AGDLP separates accounts, roles, and permissions.
- PowerShell provides a reliable way to verify Active Directory configuration.
- Changes made through GUI tools should always be validated.

## Next Steps

- Join CLIENT01 to the Active Directory domain.
- Move CLIENT01 into the Workstations OU.
- Configure Group Policy Objects.
- Create shared folders and implement group-based permissions.
