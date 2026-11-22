
# Lab 04 — Active Directory Domain Join

## Objective

Join a Windows 11 workstation to an Active Directory domain, configure internal DNS, authenticate using a domain account, and organize the workstation within Active Directory.

Practice a common enterprise workstation onboarding procedure and verify the results using PowerShell.

## Environment

| Component | Configuration |
|---|---|
| Domain Controller | DC01 |
| Server Operating System | Windows Server 2025 Standard Evaluation |
| Domain | corp.example.test |
| NetBIOS Name | CORP |
| Domain Controller IP | 192.168.100.10 |
| Client Computer | CLIENT01 |
| Client Operating System | Windows 11 Enterprise Evaluation |
| Client IP | 192.168.100.20 |
| Subnet Mask | 255.255.255.0 |
| Default Gateway | 192.168.100.1 |
| Virtualization | Oracle VirtualBox |
| Virtual Network | AD-Lab-NAT |

Both VMs were configured on the same VirtualBox NAT Network.

The client was initially configured using the local administrator account `CLIENT01\LabAdmin`.

## 1. DNS Configuration

### Initial configuration

CLIENT01 initially used Cloudflare's public DNS server:

```text
DNS Server: 1.1.1.1
```

This was sufficient for testing external name resolution, but it was not suitable for Active Directory service discovery.

Active Directory clients must be able to resolve the domain's internal DNS records.

### Inspect DNS settings

On CLIENT01:

```powershell
Get-DnsClientServerAddress -AddressFamily IPv4
```

Initial result:

```text
InterfaceAlias  InterfaceIndex  AddressFamily  ServerAddresses
--------------  --------------  -------------  ---------------
Ethernet        7               IPv4           {1.1.1.1}
```

### Configure internal DNS

Updated the Ethernet interface to use DC01:

```powershell
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses "192.168.100.10"
```

Verified the change:

```powershell
Get-DnsClientServerAddress -AddressFamily IPv4
```

Result:

```text
InterfaceAlias  InterfaceIndex  AddressFamily  ServerAddresses
--------------  --------------  -------------  ---------------
Ethernet        7               IPv4           {192.168.100.10}
```

### Key concept

Domain-joined workstations should use DNS servers capable of resolving the internal Active Directory domain.

External DNS resolution can be handled by DNS forwarders configured on the internal DNS server.

Using an external DNS server directly on a domain client can prevent reliable domain controller discovery.

## 2. Domain Controller Discovery

Before joining the domain, tested whether CLIENT01 could locate an Active Directory Domain Controller.

Executed on CLIENT01:

```powershell
Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.corp.example.test" -Type SRV
```

Verified results:

```text
SRV Target: dc01.corp.example.test
A Record:   192.168.100.10
```

### Explanation

Active Directory uses DNS SRV records to advertise available directory services.

The queried record identifies a Domain Controller providing LDAP services for the domain.

Relevant technologies:

| Technology | Purpose |
|---|---|
| DNS | Locates domain controllers and network services |
| LDAP | Accesses directory information |
| Kerberos | Provides domain authentication |

Successful DNS resolution confirmed that CLIENT01 could discover DC01 before the domain join.

## 3. Join CLIENT01 to Active Directory

### Local administrator session

The operation was performed from CLIENT01 using the local administrator account:

```text
CLIENT01\LabAdmin
```

A local administrator can initiate the domain join, provided appropriate domain credentials are supplied.

### Domain join command

Executed in an elevated PowerShell session:

```powershell
Add-Computer -DomainName "corp.example.test" -Credential "CORP\Administrator"
```

The command requests credentials authorized to join a computer to the domain.

### Result

PowerShell returned:

```text
WARNING: The changes will take effect after you restart the computer CLIENT01.
```

This confirmed that the join operation had been accepted and a restart was required.

### Restart

Executed:

```powershell
Restart-Computer
```

Following the restart, CLIENT01 was ready for domain authentication.

## 4. First Domain User Login

After restarting CLIENT01, selected **Other user** at the Windows sign-in screen.

Authenticated using the Active Directory account created in Lab 03:

```text
marco.rossi@corp.example.test
```

The equivalent down-level domain logon format is:

```text
CORP\marco.rossi
```

### Account types

| Account | Type | Purpose |
|---|---|---|
| CLIENT01\LabAdmin | Local Administrator | Local workstation administration |
| CORP\Administrator | Domain Administrator | Domain administration |
| CORP\marco.rossi | Domain User | Employee workstation authentication |

Joining the domain did not remove the existing local administrator account.

### Password configuration

The original employee onboarding configuration required a password change at first login.

During testing, a password change was rejected when attempting to reuse the existing lab password.

The mandatory first-login password change was disabled for Marco to simplify testing in the isolated lab.

The domain-wide password history policy was inspected but did not need to be disabled.

Passwords are not included in this repository.

**Security note:** Predictable passwords and relaxed onboarding practices are acceptable only as deliberate exceptions in an isolated training environment. They should not be reused in production.

## 5. Verify Domain Authentication

After successfully signing in as Marco Rossi, opened PowerShell on CLIENT01.

Executed:

```powershell
whoami
```

Result:

```text
corp\marco.rossi
```

This verified that the active Windows session belonged to the Active Directory domain account rather than the local `LabAdmin` account.

The domain sign-in test passed.

## 6. Verify the Computer Account in Active Directory

On DC01, opened Active Directory Users and Computers (ADUC).

Navigated to:

```text
corp.example.test
└── Computers
    └── CLIENT01
```

Confirmed that CLIENT01 appeared in the default `Computers` container following the domain join.

### Important distinction

The default `Computers` location is a container rather than an Organizational Unit.

Unlike an OU, the default Computers container cannot be used as a direct Group Policy linking target.

A dedicated OU is useful for organizing workstations and targeting computer-specific policies.

## 7. Move CLIENT01 to the Workstations OU

Using Active Directory Users and Computers:

1. Opened the `Computers` container.
2. Right-clicked `CLIENT01`.
3. Selected **Move**.
4. Selected the `Workstations` OU.
5. Confirmed the operation.

Resulting structure:

```text
corp.example.test
├── Departments
│   ├── IT
│   ├── HR
│   └── Sales
├── Groups
├── Workstations
│   └── CLIENT01
└── Domain Controllers
    └── DC01
```

Moving the computer object did not change its hostname or domain membership.

The new OU location allows workstation-specific Group Policy configuration.

## 8. PowerShell Computer Account Verification

On DC01, executed:

```powershell
Get-ADComputer -Identity "CLIENT01" |
    Select-Object Name, DNSHostName, Enabled, DistinguishedName
```

Verified properties:

```text
Name:              CLIENT01
DNSHostName:       CLIENT01.corp.example.test
Enabled:           True
DistinguishedName: CN=CLIENT01,OU=Workstations,DC=corp,DC=example,DC=test
```

The PowerShell output confirmed:

- The computer account exists.
- The account is enabled.
- Its DNS hostname matches the Active Directory domain.
- Its location is the Workstations OU.

## 9. Troubleshooting

### Incorrect PowerShell parameter syntax

**Issue:** The initial `Add-Computer` attempt failed with a parameter binding error.

Example of the incorrect syntax:

```powershell
Add-Computer -DomainName "corp.example.test" -Credential"CORP/Administrator"
```

**Cause:** Missing space between the `-Credential` parameter and its argument.

**Resolution:** Added the missing space and supplied the domain credentials through the PowerShell credential dialog.

**Lesson:** PowerShell parameters and their arguments must be separated correctly.

### Mandatory password change

**Issue:** The initial domain login required a password change, but attempting to reuse the existing password was unsuccessful.

**Investigation:** Inspected the default domain password policy:

```powershell
Get-ADDefaultDomainPasswordPolicy |
    Select-Object MinPasswordLength, ComplexityEnabled, PasswordHistoryCount, MinPasswordAge
```

Observed:

```text
MinPasswordLength:   7
ComplexityEnabled:   True
PasswordHistoryCount: 24
MinPasswordAge:      1 day
```

**Resolution:** Disabled the mandatory first-login password change for the lab account.

**Lesson:** User account password-change requirements and domain password policies are separate configuration concerns.

### Guest Additions clipboard behavior

**Issue:** Copy and paste between the VirtualBox guest and host was initially unavailable during testing under the new domain user profile.

**Action:** Reviewed VirtualBox shared clipboard configuration.

**Result:** Clipboard functionality was available again without reinstalling Guest Additions.

**Lesson:** Guest Additions is installed at the operating-system level, but some integration features may behave differently between user sessions.

## 10. Validation Summary

| Test | Result |
|---|---|
| CLIENT01 DNS changed to DC01 | PASS |
| Active Directory SRV record resolved | PASS |
| DC01 hostname resolved to 192.168.100.10 | PASS |
| Domain join accepted | PASS |
| CLIENT01 restarted successfully | PASS |
| Domain user login successful | PASS |
| `whoami` returned CORP domain account | PASS |
| CLIENT01 computer account found in ADUC | PASS |
| CLIENT01 moved to Workstations OU | PASS |
| Computer account verified using PowerShell | PASS |

## 11. Key Takeaways

- Active Directory depends on DNS for domain controller discovery.
- SRV records advertise available domain services.
- A local administrator can initiate a domain join using authorized domain credentials.
- Domain users can authenticate to domain-joined workstations.
- Local accounts continue to exist after a domain join.
- Computer accounts are created in Active Directory when workstations join the domain.
- Dedicated OUs provide organizational structure and Group Policy targeting.
- PowerShell can verify both the signed-in account and the computer's directory configuration.
- Administrative operations should always be followed by verification.

## Next Steps

- Create and link Group Policy Objects.
- Configure workstation policies using the Workstations OU.
- Configure user policies using departmental OUs.
- Verify policy application from CLIENT01.
- Implement shared-folder permissions using the AGDLP model.
