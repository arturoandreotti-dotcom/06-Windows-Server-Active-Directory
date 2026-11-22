
# Lab 05 — Group Policy Management

## Objective

Configure, deploy, and troubleshoot Group Policy Objects (GPOs) in a Windows Server 2025 Active Directory environment.

Demonstrate the differences between computer-based and user-based policies, verify policy application, and investigate Group Policy inheritance and precedence.

## Environment

| Component | Configuration |
|---|---|
| Domain Controller | DC01 |
| Server OS | Windows Server 2025 Standard Evaluation |
| Domain | corp.example.test |
| Domain NetBIOS Name | CORP |
| Domain Controller IP | 192.168.100.10 |
| Workstation | CLIENT01 |
| Client OS | Windows 11 Enterprise Evaluation |
| Client IP | 192.168.100.20 |
| Virtualization | Oracle VirtualBox |

### Active Directory Structure

```text
corp.example.test
├── Departments
│   ├── IT
│   │   └── Marco Rossi
│   ├── HR
│   │   └── Giulia Bianchi
│   └── Sales
│       └── Alessandro Verdi
├── Groups
│   ├── SG_IT_Users
│   ├── SG_HR_Users
│   ├── SG_Sales_Users
│   └── DL_IT_Share_RW
├── Workstations
│   └── CLIENT01
└── Domain Controllers
    └── DC01
```

## 1. Group Policy Fundamentals

Group Policy allows administrators to centrally manage configuration settings for domain users and computers.

A Group Policy Object contains settings that can be linked to Active Directory sites, domains, or Organizational Units.

### Computer vs User Configuration

| Computer Configuration | User Configuration |
|---|---|
| Targets computer accounts | Targets user accounts |
| Normally follows the computer | Normally follows the user |
| Can apply regardless of who signs in | Can apply across domain workstations |
| Example: Windows Firewall | Example: Wallpaper restrictions |

Policy application depends on GPO links, inheritance, security filtering, and other Group Policy processing rules.

### Administrative Tools

| Tool | Command | Purpose |
|---|---|---|
| Active Directory Users and Computers | `dsa.msc` | Manage AD objects and OUs |
| Group Policy Management | `gpmc.msc` | Create, link, and manage GPOs |
| Group Policy Management Editor | Right-click GPO → Edit | Configure policy settings |

GPMC manages GPO deployment and links. The Group Policy Management Editor configures the settings within a GPO.

## 2. Workstation Security GPO

### Create and Link the GPO

On DC01, opened Group Policy Management:

```text
gpmc.msc
```

Navigated to:

```text
Forest: corp.example.test
└── Domains
    └── corp.example.test
        └── Workstations
```

Right-clicked the Workstations OU and selected:

**Create a GPO in this domain, and Link it here...**

Created:

```text
GPO_Workstation_Baseline
```

The operation created the GPO and linked it directly to the Workstations OU.

### Configure the Firewall Policy

Opened the GPO using **Edit**.

Navigated to:

```text
Computer Configuration
└── Policies
    └── Windows Settings
        └── Security Settings
            └── Windows Defender Firewall with Advanced Security
```

Opened firewall properties and configured:

| Setting | Value |
|---|---|
| Profile | Domain Profile |
| Firewall state | On (recommended) |

The Private and Public profiles were not modified during this exercise.

### Purpose

This policy establishes a centrally configured firewall setting for domain workstations.

Since CLIENT01 belongs to the Workstations OU, it is within the scope of applicable computer settings from this GPO.

## 3. Refresh Computer Group Policy

On CLIENT01, executed:

```powershell
gpupdate /force
```

Observed:

```text
Computer Policy update has completed successfully.
User Policy update has completed successfully.
```

### Command Explanation

| Command | Purpose |
|---|---|
| `gpupdate` | Refresh changed user and computer policies |
| `gpupdate /force` | Reapply applicable user and computer policies |
| `gpupdate /target:user /force` | Reapply user policies only |
| `gpupdate /target:computer /force` | Reapply computer policies only |

`gpupdate` is a traditional Windows command-line utility and uses slash-prefixed options.

## 4. Verify Computer GPO Application

Opened an elevated PowerShell session on CLIENT01 and executed:

```powershell
gpresult /scope computer /r
```

The report identified:

```text
OS Configuration: Member Workstation
Group Policy was applied from: DC01.corp.example.test
Domain Name: CORP

Applied Group Policy Objects
-----------------------------
    GPO_Workstation_Baseline
    Default Domain Policy
```

### Verification

The report confirmed that:

- CLIENT01 was operating as a domain member workstation.
- Group Policy processing contacted DC01.
- `GPO_Workstation_Baseline` was applied.
- The Default Domain Policy was also applied.

### gpresult Commands

| Command | Purpose |
|---|---|
| `gpresult /r` | Display an available policy summary |
| `gpresult /scope user /r` | Display user policy results |
| `gpresult /scope computer /r` | Display computer policy results |

The `/scope` argument selects the target of the report.

The `/r` switch requests a summary report.

## 5. Verify Windows Firewall Configuration

On CLIENT01, executed:

```powershell
Get-NetFirewallProfile -Name Domain |
    Select-Object Name, Enabled
```

Result:

```text
Name   Enabled
----   -------
Domain    True
```

The Domain firewall profile was enabled.

### Inspect Effective Configuration

Executed:

```powershell
Get-NetFirewallProfile -PolicyStore ActiveStore -Name Domain |
    Select-Object Name, Enabled, AllowLocalFirewallRules
```

Result:

```text
Name   Enabled AllowLocalFirewallRules
----   ------- -----------------------
Domain    True                    True
```

This verified that:

- The effective Domain firewall profile was enabled.
- Local firewall rules were permitted to merge with centrally managed rules.

### Inspect Group Policy Results

Executed:

```powershell
Get-NetFirewallProfile -PolicyStore RSOP -Name Domain |
    Select-Object Name, Enabled
```

Result:

```text
Name   Enabled
----   -------
Domain    True
```

The RSOP policy store reported the Domain firewall profile as enabled.

### Validation Notes

`gpresult` confirmed that the custom workstation GPO applied to CLIENT01.

`ActiveStore` confirmed the effective firewall state.

`RSOP` confirmed that the enabled firewall state was represented in Group Policy results.

Together, these checks supported successful deployment of the workstation firewall configuration.

The firewall state alone does not identify which individual GPO supplied a setting when multiple policies or defaults could influence the result.

## 6. User-Based Group Policy

### Scenario

Configure a wallpaper restriction for members of the IT department without restricting employees in other departments.

### Create and Link the GPO

On DC01, opened Group Policy Management.

Navigated to:

```text
corp.example.test
└── Departments
    └── IT
```

Right-clicked the IT OU and selected:

**Create a GPO in this domain, and Link it here...**

Created:

```text
GPO_IT_User_Restrictions
```

The GPO was linked directly to the IT OU.

### Configure the Restriction

Opened the GPO editor and navigated to:

```text
User Configuration
└── Policies
    └── Administrative Templates
        └── Control Panel
            └── Personalization
```

Configured:

| Policy | State |
|---|---|
| Prevent changing desktop background | Enabled |

### Purpose

This user policy targets applicable user accounts within the IT OU.

Marco Rossi is currently located in that OU.

Other departments do not automatically receive this restriction simply because their employees sign in to CLIENT01.

## 7. Verify IT User Policy

Signed in to CLIENT01 using:

```text
CORP\marco.rossi
```

Refreshed user policies:

```powershell
gpupdate /target:user /force
```

Verified the current identity:

```powershell
whoami
```

Result:

```text
corp\marco.rossi
```

Queried Group Policy results:

```powershell
gpresult /scope user /r
```

The report identified:

```text
CN=Marco Rossi,OU=IT,OU=Departments,DC=corp,DC=example,DC=test

Group Policy was applied from: DC01.corp.example.test

Applied Group Policy Objects
-----------------------------
    GPO_IT_User_Restrictions
```

The report also included Marco's security groups:

```text
SG_IT_Users
DL_IT_Share_RW
```

This demonstrated that Windows recognized both his departmental group and his nested Domain Local group membership.

### Functional Test

On CLIENT01, while signed in as Marco:

1. Opened Settings.
2. Navigated to Personalization → Background.
3. Inspected the available wallpaper controls.

Observed:

- Windows displayed a message indicating that settings were managed by the organization.
- Background personalization controls were disabled.

**Result: PASS**

The wallpaper restriction applied as intended.

## 8. Verify Departmental Policy Separation

Signed out of Marco's session and signed in as:

```text
giulia.bianchi@corp.example.test
```

Giulia belongs to the HR OU rather than the IT OU.

### Functional Test

Opened:

```text
Settings → Personalization → Background
```

Observed that the wallpaper controls were available.

### PowerShell Verification

Executed:

```powershell
whoami
gpresult /scope user /r
```

Results included:

```text
corp\giulia.bianchi
```

And:

```text
CN=Giulia Bianchi,OU=HR,OU=Departments,DC=corp,DC=example,DC=test

Group Policy was applied from: DC01.corp.example.test

Applied Group Policy Objects
-----------------------------
    N/A
```

Her security group membership included:

```text
SG_HR_Users
```

### Comparison

| Test | Marco Rossi | Giulia Bianchi |
|---|---|---|
| Department | IT | HR |
| Workstation | CLIENT01 | CLIENT01 |
| IT GPO applied | Yes | No |
| Wallpaper controls | Disabled | Available |

**Result: PASS**

The same domain-joined workstation produced different user settings depending on the signed-in account.

## 9. Group Policy Inheritance

Inspected the Group Policy Inheritance tab in GPMC.

### IT OU

Observed:

| Precedence | GPO | Linked Location |
|---|---|---|
| 1 | GPO_IT_User_Restrictions | IT |
| 2 | Default Domain Policy | corp.example.test |

### HR OU

Observed only the inherited Default Domain Policy.

This explains why the IT user restriction did not apply to Giulia.

### Inheritance Concepts

GPO links can be configured at the:

- Site level
- Domain level
- Organizational Unit level

Under normal processing, child OUs inherit applicable GPOs linked at parent levels.

A GPO linked directly to a child OU can have higher precedence over conflicting inherited settings.

### Link Order vs Precedence

**Link Order** describes priority among GPO links at the same location.

**Precedence** describes the resulting priority across relevant GPO links after processing inheritance and other rules.

A lower precedence number represents higher priority.

For multiple GPOs linked to the same OU, link order 1 normally has the highest priority.

Advanced features such as enforced links, blocked inheritance, security filtering, WMI filtering, and loopback processing can affect policy application.

These advanced features were not modified during this lab.

## 10. Troubleshooting

### Issue 1 — Elevated PowerShell Credential Prompt

**Problem:** Attempting to launch PowerShell as Administrator from Marco's session caused the graphical credential prompt to become unresponsive.

**Investigation:**

- Confirmed CLIENT01 continued responding to the Windows security screen.
- Checked the difference between local and domain administrator accounts.
- Attempted alternate authentication methods.

**Resolution:**

Launched PowerShell under the local administrator account:

```powershell
runas /user:CLIENT01\LabAdmin powershell.exe
```

Authentication succeeded.

### Issue 2 — Access Denied With gpresult

**Problem:**

```powershell
gpresult /scope computer /r
```

Returned:

```text
ERROR: Access Denied.
```

**Cause:** The PowerShell session was running as `CLIENT01\LabAdmin` without an elevated administrator token.

**Resolution:**

Started an elevated PowerShell process:

```powershell
Start-Process powershell.exe -Verb RunAs
```

The elevated session successfully executed the computer policy report.

**Lesson:** Running a process under an administrator account is not necessarily the same as running it with elevated privileges.

### Issue 3 — Checking the Wrong User

**Problem:** The initial user policy report showed no applied domain user GPOs.

The report identified:

```text
RSOP data for CLIENT01\LabAdmin on CLIENT01
```

**Cause:** The command was being executed in a PowerShell session belonging to the local LabAdmin account rather than Marco.

**Resolution:**

Opened a normal PowerShell session under Marco Rossi and verified:

```powershell
whoami
```

Result:

```text
corp\marco.rossi
```

Repeated:

```powershell
gpresult /scope user /r
```

Confirmed that `GPO_IT_User_Restrictions` was applied.

**Lesson:** Always verify the current account when investigating user-specific policies.

## 11. Validation Summary

| Test | Result |
|---|---|
| Workstation GPO created and linked | PASS |
| Domain firewall setting configured | PASS |
| Computer Group Policy refreshed | PASS |
| Workstation GPO application verified | PASS |
| Effective Domain firewall enabled | PASS |
| Firewall RSOP state verified | PASS |
| IT user GPO created and linked | PASS |
| User Group Policy refreshed | PASS |
| Marco's IT GPO application verified | PASS |
| Marco's wallpaper restriction tested | PASS |
| Giulia's wallpaper settings remained available | PASS |
| Giulia's user GPO results verified | PASS |
| GPO inheritance inspected | PASS |
| PowerShell elevation issue resolved | PASS |

## 12. Key Takeaways

- Group Policy centrally manages Windows configuration settings.
- GPMC creates and manages GPOs and their links.
- Group Policy Management Editor configures settings inside a GPO.
- Computer Configuration normally follows computer accounts.
- User Configuration normally follows user accounts.
- GPOs can be created without immediately linking them.
- `gpupdate` refreshes Group Policy.
- `gpresult` reports applied Group Policy Objects.
- Firewall PowerShell commands can inspect effective and policy-derived settings.
- Group Policy inheritance and link order influence policy precedence.
- A successful policy refresh is not sufficient proof that a specific setting applied.
- Administrators should verify both the applicable GPO and the resulting system behavior.

## Next Steps

- Configure shared folders on the Windows Server.
- Implement NTFS and share permissions.
- Apply the AGDLP model created in Lab 03.
- Test resource access using IT, HR, and Sales domain accounts.
- Troubleshoot incorrect or missing permissions.
