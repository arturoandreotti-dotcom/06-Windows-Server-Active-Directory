
# Lab 02 — Active Directory Domain Services Deployment

## Objective

Deploy the first Active Directory domain controller for a fictional small-business environment using Windows Server 2025.

Configure a new forest, integrate DNS, verify domain services, and investigate initial domain controller diagnostic warnings.

## Lab Environment

| Component | Configuration |
|---|---|
| Hypervisor | Oracle VirtualBox |
| Server | DC01 |
| Operating system | Windows Server 2025 Standard Evaluation (Desktop Experience) |
| Domain | corp.example.test |
| NetBIOS name | CORP |
| IPv4 address | 192.168.100.10/24 |
| Default gateway | 192.168.100.1 |
| Virtual network | AD-Lab-NAT |
| Forest functional level | Windows Server 2025 |
| Domain functional level | Windows Server 2025 |

## Deployment

### 1. Install Active Directory Domain Services

Used Server Manager:

1. Opened Manage > Add Roles and Features.
2. Selected Role-based or feature-based installation.
3. Selected DC01 as the destination server.
4. Selected Active Directory Domain Services.
5. Accepted the required management tools and features.
6. Completed the role installation.

### 2. Promote DC01 to a Domain Controller

Selected **Promote this server to a domain controller**.

Deployment configuration:

- Deployment type: Add a new forest
- Root domain: `corp.example.test`
- Forest and domain functional levels: Windows Server 2025
- DNS Server: Enabled
- Global Catalog: Enabled
- Read-only Domain Controller: Disabled
- DNS delegation: Not configured
- NetBIOS domain name: `CORP`

Configured a separate Directory Services Restore Mode (DSRM) password, stored privately in KeePassXC.

### 3. Active Directory Storage

Retained the default storage paths:

| Component | Path |
|---|---|
| Database | C:\Windows\NTDS |
| Transaction logs | C:\Windows\NTDS |
| SYSVOL | C:\Windows\SYSVOL |

The prerequisite checks passed successfully.

A DNS delegation warning appeared because the authoritative parent zone was unavailable. No delegation was required for this standalone lab forest.

Completed domain controller promotion and restarted DC01.

## Verification

### 1. Verify Domain Configuration

```powershell
Get-ADDomain
```

Verified:

- DNSRoot: `corp.example.test`
- NetBIOSName: `CORP`
- DomainMode: `Windows2025Domain`
- PDCEmulator: `DC01.corp.example.test`
- RIDMaster: `DC01.corp.example.test`

### 2. Verify Active Directory DNS

```powershell
Resolve-DnsName _ldap._tcp.dc._msdcs.corp.example.test -Type SRV
```

Results:

- SRV target: `dc01.corp.example.test`
- IPv4 address: `192.168.100.10`

### 3. Check Domain Controller Diagnostics

```powershell
dcdiag /q
```

The initial diagnostic reported failures in:

- DFSREvent
- SystemLog

These findings were investigated rather than ignored.

### 4. Verify SYSVOL and NETLOGON

```powershell
Get-SmbShare -Name SYSVOL, NETLOGON
```

Both shares were present.

### 5. Investigate DFS Replication Events

```powershell
Get-WinEvent -LogName "DFS Replication" -MaxEvents 10 |
    Select-Object TimeCreated, Id, LevelDisplayName, Message
```

Investigated warning Event ID 6016 using:

```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'DFS Replication'
    Id = 6016
} -MaxEvents 1 |
    Format-List TimeCreated, Id, LevelDisplayName, Message
```

Event 6016 reported error 1355, indicating that DFS Replication could not contact the domain during initial configuration.

Later events included:

- Event 4602: SYSVOL initialization succeeded.
- Event 6018: A subsequent DFS Replication operation succeeded.

### 6. Verify SYSVOL Readiness

```powershell
dcdiag /test:SysVolCheck /test:NetLogons
```

Results:

- Connectivity: Passed
- SysVolCheck: Passed
- NetLogons: Passed

These results support the interpretation that the initial DFS Replication warning was transient. A complete clean diagnostic run has not yet been established.

### 7. Graphical Verification

Opened Active Directory Users and Computers (ADUC).

Verified:

- Domain `corp.example.test` exists.
- DC01 appears in the Domain Controllers OU.
- Built-in Administrator account exists.
- Domain Admins contains Administrator as a direct member.
- Default Active Directory containers and security groups are present.

## Troubleshooting

### DFS Replication Warning — Event 6016

**Issue:** DFS Replication reported that it could not update its configuration in Active Directory.

**Error:** 1355 — The specified domain either does not exist or could not be contacted.

**Investigation:** Examined DFS Replication events, verified SYSVOL and NETLOGON shares, and ran targeted domain controller health checks.

**Finding:** SYSVOL initialization and targeted health checks succeeded. The earlier warning was likely associated with initial service startup.

**Action:** No configuration changes were required based on the available evidence.

### System Log Warnings

The initial diagnostic also reported:

- A Security Account Manager/KDC event involving lookup type 0x108.
- Secure Boot DBX and SBAT update errors because Secure Boot was not enabled.

These events were recorded separately from the SYSVOL investigation. No changes were made to Secure Boot settings.

## Results

Successfully deployed the first Active Directory domain controller for `corp.example.test`.

Verified domain configuration, DNS service discovery, SYSVOL and NETLOGON availability, and targeted domain controller diagnostics.

The environment is ready for further Active Directory administration, including Organizational Units, users, security groups, and domain-joined clients.

## Lessons Learned

- Installing AD DS and promoting a domain controller are separate operations.
- A forest can contain one or more domains.
- DNS SRV records help clients locate Active Directory services.
- Domain controllers store directory information and provide authentication services.
- SYSVOL contains Group Policy files and logon-related resources.
- Security groups simplify permissions management.
- Diagnostic warnings must be investigated using supporting evidence rather than assumed to indicate an active failure.
