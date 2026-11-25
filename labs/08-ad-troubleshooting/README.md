
# Lab 08 — Active Directory Troubleshooting & Recovery

## Objective

Develop practical troubleshooting skills by simulating, diagnosing, and resolving common Active Directory infrastructure problems.

Validate the health of the existing domain environment following controlled troubleshooting exercises.

This lab focuses on identifying root causes rather than applying unnecessary configuration changes or rebuilding infrastructure.

## Environment

| Component | Configuration |
|---|---|
| Domain Controller | DC01 |
| Server OS | Windows Server 2025 |
| Domain | corp.example.test |
| NetBIOS Name | CORP |
| Domain Controller IP | 192.168.100.10 |
| Client Workstation | CLIENT01 |
| Client OS | Windows 11 Enterprise Evaluation |
| Client IP | 192.168.100.20 |
| Default Gateway | 192.168.100.1 |
| Internal DNS Server | 192.168.100.10 |
| Network | AD-Lab-NAT |
| Virtualization | Oracle VirtualBox |

### Administrative Accounts

| Account | Purpose |
|---|---|
| CORP\Administrator | Domain administration |
| CLIENT01\LabAdmin | Local workstation administration |
| CORP\luca.ferrari | Employee authentication and authorization testing |

## 1. Troubleshooting Methodology

Each incident followed a structured troubleshooting workflow:

```text
Establish a healthy baseline
            |
            v
Introduce a controlled fault
            |
            v
Reproduce the problem
            |
            v
Collect diagnostic information
            |
            v
Identify the root cause
            |
            v
Implement a targeted solution
            |
            v
Verify restored functionality
            |
            v
Document the incident
```

All intentional faults were controlled and reversible.

The objective was to restore functionality without introducing unnecessary changes to the existing infrastructure.

---

## 2. Scenario 01 — Incorrect DNS Configuration

### Incident Description

A domain-joined workstation has IP connectivity but cannot resolve internal domain resources or discover Active Directory services.

### 2.1 Establish a Healthy Baseline

On CLIENT01, inspected the network configuration:

```powershell
Get-NetIPConfiguration
```

Result:

```text
InterfaceAlias       : Ethernet
InterfaceIndex       : 7
InterfaceDescription : Intel(R) PRO/1000 MT Desktop Adapter
NetProfile.Name      : corp.example.test
IPv4Address          : 192.168.100.20
IPv4DefaultGateway   : 192.168.100.1
DNSServer            : 192.168.100.10
```

Verified IP connectivity:

```powershell
ping 192.168.100.10
```

Result:

- Packets sent: 4
- Packets received: 4
- Packet loss: 0%

Verified internal hostname resolution:

```powershell
Resolve-DnsName dc01.corp.example.test
```

Result:

```text
Name                       Type IPAddress
----                       ---- ---------
dc01.corp.example.test     A    192.168.100.10
```

### 2.2 Verify Active Directory Service Discovery

Queried the LDAP service record used for Domain Controller discovery:

```powershell
Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.corp.example.test" -Type SRV
```

Result:

| Property | Value |
|---|---|
| Record Type | SRV |
| NameTarget | dc01.corp.example.test |
| Priority | 0 |
| Weight | 100 |
| TTL | 600 |
| Additional IPv4 Address | 192.168.100.10 |

### Understanding the SRV Record

```text
_ldap._tcp.dc._msdcs.corp.example.test
```

| Component | Meaning |
|---|---|
| _ldap | LDAP service |
| _tcp | TCP transport protocol |
| dc | Domain Controller |
| _msdcs | Microsoft-specific AD service discovery namespace |
| corp.example.test | Active Directory domain |

Unlike an A record, which maps a hostname to an IPv4 address, an SRV record identifies servers providing a particular service.

Active Directory clients rely on DNS service records to locate Domain Controllers and associated services.

### 2.3 Introduce the Fault

Changed CLIENT01's DNS server from the internal Domain Controller to a public DNS resolver:

```powershell
Set-DnsClientServerAddress -InterfaceIndex 7 -ServerAddresses "1.1.1.1"
```

Cleared the DNS client cache:

```powershell
Clear-DnsClientCache
```

The workstation's IP address, gateway, and domain membership remained unchanged.

### 2.4 Reproduce and Diagnose the Problem

Tested IP connectivity:

```powershell
ping 192.168.100.10
```

Result:

```text
Packets: Sent = 4, Received = 4, Lost = 0 (0% loss)
```

IP connectivity remained functional.

Tested internal DNS resolution:

```powershell
Resolve-DnsName dc01.corp.example.test
```

Result:

```text
Resolve-DnsName: dc01.corp.example.test : DNS name does not exist.
```

Tested public DNS resolution:

```powershell
Resolve-DnsName microsoft.com
```

The query successfully returned public A and AAAA records.

Tested Active Directory service discovery:

```powershell
Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.corp.example.test" -Type SRV
```

Result:

```text
DNS name does not exist.
```

Verified the configured DNS server:

```powershell
Get-DnsClientServerAddress -InterfaceIndex 7 -AddressFamily IPv4
```

Result:

```text
InterfaceAlias  InterfaceIndex  AddressFamily  ServerAddresses
--------------  --------------  -------------  ---------------
Ethernet        7               IPv4           {1.1.1.1}
```

### Diagnostic Findings

| Test | Result |
|---|---|
| IP connectivity to DC01 | PASS |
| Public DNS resolution | PASS |
| Internal DNS resolution | FAIL |
| Active Directory SRV resolution | FAIL |

### Root Cause

CLIENT01 was configured to use a public DNS resolver that could not resolve the private Active Directory DNS namespace.

The issue was related to DNS configuration rather than general network connectivity.

### 2.5 Resolution

Restored the internal DNS server:

```powershell
Set-DnsClientServerAddress -InterfaceIndex 7 -ServerAddresses "192.168.100.10"
```

Cleared the DNS cache:

```powershell
Clear-DnsClientCache
```

### 2.6 Verify Recovery

Repeated both internal DNS queries:

```powershell
Resolve-DnsName dc01.corp.example.test
```

```powershell
Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.corp.example.test" -Type SRV
```

Both queries succeeded.

The A record resolved to 192.168.100.10, and the SRV record identified dc01.corp.example.test.

### Incident Result

**RESOLVED**

### Key Takeaways

- Successful ping tests do not guarantee DNS functionality.
- Public DNS resolution does not guarantee internal domain resolution.
- Active Directory relies heavily on DNS service discovery.
- Domain-joined computers should use DNS servers capable of resolving their Active Directory namespace.
- Network connectivity and DNS resolution should be tested independently.

---

## 3. Scenario 02 — Domain Controller Connectivity Failure

### Incident Description

A domain-joined workstation cannot locate its Domain Controller.

The objective was to distinguish network connectivity problems from an actual failure of the computer's domain trust relationship.

### 3.1 Establish a Healthy Baseline

Verified the computer's secure channel:

```powershell
Test-ComputerSecureChannel
```

Result:

```text
True
```

Located the Domain Controller:

```powershell
nltest /dsgetdc:corp.example.test /force
```

Result:

```text
DC: \\DC01.corp.example.test
Address: \\192.168.100.10
Dom Name: corp.example.test
Forest Name: corp.example.test
Dc Site Name: Default-First-Site-Name
Our Site Name: Default-First-Site-Name

The command completed successfully
```

The Domain Controller advertised capabilities including LDAP, Kerberos KDC, Global Catalog, and writable directory services.

### Diagnostic Tools

| Command | Purpose |
|---|---|
| Resolve-DnsName | Verify DNS resolution |
| nltest /dsgetdc | Locate a Domain Controller |
| nltest /dsgetdc with /force | Force fresh Domain Controller discovery |
| Test-ComputerSecureChannel | Test the computer's domain secure channel |

### 3.2 Introduce the Fault

From the CLIENT01 VirtualBox console, disabled the Ethernet network adapter:

```powershell
Disable-NetAdapter -Name "Ethernet" -Confirm:$false
```

This simulated a network connectivity outage without modifying the workstation's domain membership or computer account password.

### 3.3 Reproduce the Problem

Attempted fresh Domain Controller discovery:

```powershell
nltest /dsgetdc:corp.example.test /force
```

Result:

```text
Getting DC name failed: Status = 1355 0x54b ERROR_NO_SUCH_DOMAIN
```

Error 1355 indicated that the workstation could not locate the requested domain or an available Domain Controller.

It did not establish that the domain had been deleted or that CLIENT01 was no longer domain-joined.

### 3.4 Investigate Network Connectivity

Inspected the network adapter:

```powershell
Get-NetAdapter -Name "Ethernet"
```

Result:

```text
Name      ifIndex Status
----      ------- ------
Ethernet  7       Disabled
```

Tested connectivity:

```powershell
ping 192.168.100.10
```

Result:

```text
PING: transmit failed. General failure.

Packets: Sent = 4, Received = 0, Lost = 4 (100% loss)
```

### 3.5 Unexpected Secure Channel Result

Repeated:

```powershell
Test-ComputerSecureChannel
```

Unexpected result:

```text
True
```

The command continued returning True while the network adapter was disabled and fresh Domain Controller discovery failed.

The exact reason for this behaviour was not conclusively established.

The result may have reflected existing Netlogon secure-channel state, but this explanation was not independently verified.

### Diagnostic Findings

| Test | Result |
|---|---|
| Network adapter | Disabled |
| IP connectivity | FAIL |
| Fresh DC discovery | FAIL |
| Secure channel test | True |

### Root Cause

The workstation's Ethernet adapter was disabled.

The evidence indicated a connectivity problem rather than a confirmed computer account trust failure.

### 3.6 Resolution

Re-enabled the network adapter:

```powershell
Enable-NetAdapter -Name "Ethernet" -Confirm:$false
```

### 3.7 Verify Recovery

Repeated the diagnostic tests:

```powershell
Get-NetAdapter -Name "Ethernet"
```

```powershell
ping 192.168.100.10
```

```powershell
nltest /dsgetdc:corp.example.test /force
```

```powershell
Test-ComputerSecureChannel
```

Results:

| Diagnostic Test | During Outage | After Recovery |
|---|---|---|
| Ethernet adapter | Disabled | Up |
| Ping | 100% packet loss | 0% packet loss |
| Domain Controller discovery | Error 1355 | Successful |
| Secure channel test | True | True |

Domain Controller connectivity was restored without:

- Repairing the secure channel.
- Resetting the computer account.
- Removing CLIENT01 from the domain.
- Rejoining the domain.

### Incident Result

**RESOLVED**

### Key Takeaways

- Network connectivity failures do not necessarily indicate broken domain trust.
- Error 1355 should be investigated in the context of network and DNS configuration.
- A successful diagnostic result does not guarantee that every related service is functional.
- Multiple diagnostic tools should be used to establish a reliable conclusion.
- Unnecessary domain rejoining should be avoided.

---

## 4. Scenario 03 — Security Group and Resource Access Troubleshooting

### Incident Description

An IT employee can authenticate to the domain but cannot access a departmental SMB share.

This scenario demonstrates the distinction between authentication and authorization.

### 4.1 Existing Authorization Model

The IT shared folder was configured in Lab 06 using AGDLP:

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

### 4.2 Establish a Healthy Baseline

On DC01, inspected Luca's group memberships:

```powershell
Get-ADPrincipalGroupMembership -Identity "luca.ferrari"
```

Confirmed membership in:

```text
Domain Users
SG_IT_Users
```

### 4.3 Introduce the Fault

Previewed removal of the departmental security group membership:

```powershell
Remove-ADGroupMember -Identity "SG_IT_Users" -Members "luca.ferrari" -WhatIf
```

Removed Luca from the group:

```powershell
Remove-ADGroupMember -Identity "SG_IT_Users" -Members "luca.ferrari"
```

Verified the updated membership:

```powershell
Get-ADPrincipalGroupMembership -Identity "luca.ferrari"
```

Result:

```text
Domain Users
```

The following configurations remained unchanged:

- Luca's account status.
- Luca's password.
- Luca's IT OU location.
- NTFS permissions.
- SMB share permissions.
- Group Policy configuration.
- Other IT employees' group memberships.

### 4.4 Reproduce the Access Problem

Signed in to CLIENT01 as Luca.

Verified the user identity:

```powershell
whoami
```

Result:

```text
corp\luca.ferrari
```

Attempted to list the contents of the IT share:

```powershell
Get-ChildItem "\\DC01\IT"
```

Result:

```text
Get-ChildItem : Access is denied
```

PowerShell also reported that the path could not be found.

The primary error was an UnauthorizedAccessException.

The secondary path error did not establish that the share had been deleted.

### Initial Findings

| Test | Result |
|---|---|
| Domain authentication | PASS |
| User identity verification | PASS |
| IT share authorization | FAIL |

Luca could authenticate successfully but was no longer authorized to access the resource.

### 4.5 Inspect the Local Security Token

Executed:

```powershell
whoami /groups
```

Unexpectedly, the current local token still contained:

```text
CORP\SG_IT_Users
CORP\DL_IT_Share_RW
```

This created a discrepancy between the group membership stored in Active Directory, the local security token, and the observed SMB access result.

### 4.6 Investigate the Authentication Context

Inspected the logon server:

```powershell
$env:LOGONSERVER
```

Result:

```text
\\DC01
```

Inspected cached Kerberos tickets:

```powershell
klist
```

The output contained five cached tickets, including:

| Ticket | Purpose |
|---|---|
| krbtgt/CORP.EXAMPLE.TEST | Ticket Granting Ticket |
| cifs/DC01 | SMB service authentication |
| ldap/dc01.corp.example.test | LDAP service authentication |

The tickets were issued by DC01.

### Kerberos and Authorization

A valid Kerberos ticket allows a client to authenticate to a service.

It does not independently grant permission to access every resource provided by that service.

SMB and NTFS access decisions still depend on the applicable security context and resource ACLs.

### 4.7 Refresh the User Session

Signed Luca out:

```powershell
shutdown /l
```

Signed back in and inspected the domain-related groups:

```powershell
whoami /groups | Select-String "CORP"
```

The command returned no matching output.

The previously displayed IT security groups were no longer present in the local token.

### Root Cause

Luca's membership in SG_IT_Users had been removed, interrupting the existing AGDLP authorization chain.

The resource's ACLs did not require modification.

### 4.8 Restore Authorization

On DC01, restored the departmental group membership:

```powershell
Add-ADGroupMember -Identity "SG_IT_Users" -Members "luca.ferrari"
```

Verified:

```powershell
Get-ADPrincipalGroupMembership -Identity "luca.ferrari" |
    Select-Object Name
```

Result:

```text
Name
----
Domain Users
SG_IT_Users
```

### 4.9 Verify Restored Resource Access

After refreshing Luca's login session, tested the shared folder:

```powershell
Get-ChildItem "\\DC01\IT"
```

Result:

```text
IT-Access-Test.txt
Luca-Access-Test.txt
```

Resource access was successfully restored.

No NTFS or SMB ACL modifications were required.

### 4.10 Investigate the Remaining Token Discrepancy

Despite restored resource access, the following command initially returned no matching domain groups:

```powershell
whoami /groups | Select-String "CORP"
```

Another complete sign-out and sign-in did not resolve the discrepancy.

The workstation was then restarted:

```powershell
shutdown /r /t 0
```

After signing in again, repeated:

```powershell
whoami /groups | Select-String "CORP"
```

Result:

```text
CORP\SG_IT_Users
CORP\DL_IT_Share_RW
```

Both expected IT security groups were present in the new local security token.

### Observed Behaviour

| Stage | AD Membership | Local IT Groups | SMB Access |
|---|---|---|---|
| Initial configuration | Present | Not inspected | Previously verified |
| After removal | Absent | Present | Denied |
| Additional login | Absent | Absent | Not retested |
| After restoration | Present | Absent | Allowed |
| After restart | Present | Present | Previously verified |

The workstation restart resolved the observed local-token discrepancy.

The exact reason why the previous sessions retained outdated group information was not conclusively determined.

### Incident Result

**RESOLVED**

### Key Takeaways

- Authentication establishes identity.
- Authorization determines permitted resource access.
- OU placement does not automatically grant file permissions.
- AD group memberships and local access tokens may temporarily differ.
- Local access tokens and remote service security contexts are distinct.
- Kerberos authentication does not guarantee resource authorization.
- AGDLP allows administrators to restore access without modifying resource ACLs.
- Unexpected diagnostic results should be documented rather than explained through unsupported assumptions.

---

## 5. Scenario 04 — Group Policy Troubleshooting

### Incident Description

An IT employee reports that an existing organizational restriction is no longer being enforced.

The affected Group Policy Object was:

```text
GPO_IT_User_Restrictions
```

This GPO was configured in Lab 05 to prevent IT users from changing their desktop background.

### 5.1 Establish a Healthy Baseline

On CLIENT01, signed in as Luca and executed:

```powershell
gpresult /scope user /r
```

Relevant output:

```text
USER SETTINGS
--------------
CN=Luca Ferrari,OU=IT,OU=Departments,DC=corp,DC=example,DC=test

Group Policy was applied from:
    DC01.corp.example.test

Applied Group Policy Objects
-----------------------------
    GPO_IT_User_Restrictions
```

The output also confirmed Luca's membership in:

```text
SG_IT_Users
DL_IT_Share_RW
```

### 5.2 Introduce the Fault

On DC01, opened Group Policy Management:

```powershell
gpmc.msc
```

Navigated to:

```text
Forest: corp.example.test
└── Domains
    └── corp.example.test
        └── Departments
            └── IT
                └── GPO_IT_User_Restrictions
```

Disabled the GPO link by unchecking Link Enabled.

The GPO itself was not deleted, and its configured settings were not modified.

### GPO Link vs GPO Configuration

| Action | Effect |
|---|---|
| Disable GPO link | Stops policy application through that link |
| Disable user or computer configuration | Stops processing of the corresponding GPO settings |
| Delete GPO | Removes the Group Policy Object |

Disabling the link provided a controlled and reversible fault.

### 5.3 Refresh and Diagnose Group Policy

On CLIENT01, refreshed Group Policy:

```powershell
gpupdate /force
```

Inspected the resulting user policies:

```powershell
gpresult /scope user /r
```

Relevant result:

```text
Applied Group Policy Objects
-----------------------------
    N/A

The following GPOs were not applied because they were filtered out
-------------------------------------------------------------------
    Local Group Policy
        Filtering: Not Applied (Empty)

    GPO_IT_User_Restrictions
        Filtering: Disabled (Link)
```

The diagnostic output explicitly identified the disabled GPO link.

Luca's OU location and security group memberships remained unchanged.

### 5.4 Functional Verification

Opened the desktop background settings:

```powershell
Start-Process "ms-settings:personalization-background"
```

Confirmed that the previous restriction was no longer enforced.

Luca could change his desktop background.

### Root Cause

The link between the IT OU and GPO_IT_User_Restrictions had been disabled.

The policy settings themselves were still configured correctly.

### 5.5 Resolution

On DC01, reopened Group Policy Management:

```powershell
gpmc.msc
```

Navigated to the IT OU and re-enabled the GPO link.

On CLIENT01, refreshed Group Policy:

```powershell
gpupdate /force
```

### 5.6 Verify Recovery

Executed:

```powershell
gpresult /scope user /r
```

Relevant result:

```text
Applied Group Policy Objects
-----------------------------
    GPO_IT_User_Restrictions
```

Opened the personalization settings again:

```powershell
Start-Process "ms-settings:personalization-background"
```

Confirmed that Luca could no longer change his desktop background.

### Validation

| Test | During Fault | After Recovery |
|---|---|---|
| GPO link | Disabled | Enabled |
| GPO application | Not applied | Applied |
| Background changes | Allowed | Restricted |
| OU location | Unchanged | Unchanged |
| Security group memberships | Unchanged | Unchanged |

### Incident Result

**RESOLVED**

### Key Takeaways

- A correctly configured GPO must also be linked and applicable to its intended targets.
- Disabling a GPO link does not delete the GPO.
- gpresult identifies applied policies and reasons why policies were filtered out.
- gpupdate refreshes Group Policy processing.
- Diagnostic output should be supported by functional testing.
- Administrators should investigate policy targeting and application before modifying policy settings.

---

## 6. Scenario 05 — Active Directory Infrastructure Health Audit

### Objective

Verify the health of the Domain Controller and essential Active Directory services following the troubleshooting exercises.

Unlike the previous scenarios, this exercise did not introduce an intentional fault.

### 6.1 Verify Essential Domain Controller Services

On DC01, executed:

```powershell
Get-Service -Name NTDS, DNS, Netlogon, KDC, DFSR |
    Select-Object Name, DisplayName, Status
```

Result:

```text
Name     DisplayName                       Status
----     -----------                       ------
DFSR     DFS Replication                   Running
DNS      DNS Server                        Running
KDC      Kerberos Key Distribution Center  Running
Netlogon Netlogon                          Running
NTDS     Active Directory Domain Services  Running
```

### Service Responsibilities

| Service | Purpose |
|---|---|
| NTDS | Active Directory Domain Services |
| DNS | DNS resolution and AD service discovery |
| Netlogon | Domain authentication and secure-channel support |
| KDC | Kerberos ticket issuance |
| DFSR | Distributed File System Replication, including SYSVOL replication |

All five essential services were running.

A running service is an initial health indicator, but it does not independently guarantee correct service functionality.

### 6.2 Run Domain Controller Diagnostics

Executed:

```powershell
dcdiag /q
```

Result:

```text
No output
```

No errors were reported by the diagnostic tests performed.

The historical DFS Replication and System event log issues observed during the initial Active Directory deployment in Lab 02 were no longer reported by this diagnostic run.

This result does not establish that every historical event was resolved or that every possible infrastructure test was performed.

### 6.3 Verify Essential SMB Shares

Executed:

```powershell
Get-SmbShare |
    Select-Object Name, Path
```

Result:

```text
Name     Path
----     ----
ADMIN$   C:\WINDOWS
C$       C:\
IPC$
IT       C:\Shares\IT
NETLOGON C:\WINDOWS\SYSVOL\sysvol\corp.example.test\SCRIPTS
SYSVOL   C:\WINDOWS\SYSVOL\sysvol
```

### Share Responsibilities

| Share | Purpose |
|---|---|
| ADMIN$ | Administrative access to the Windows directory |
| C$ | Administrative access to the C: drive |
| IPC$ | Inter-process communication |
| IT | Departmental file sharing |
| NETLOGON | Domain logon scripts |
| SYSVOL | Group Policy files and domain scripts |

All expected shares were present.

SYSVOL and NETLOGON are particularly important for Active Directory operations.

### 6.4 Health Audit Results

| Check | Result |
|---|---|
| NTDS running | PASS |
| DNS running | PASS |
| Netlogon running | PASS |
| KDC running | PASS |
| DFSR running | PASS |
| DCDiag quiet-mode diagnostics | No errors reported |
| SYSVOL share present | PASS |
| NETLOGON share present | PASS |
| IT share present | PASS |

The final health audit was successful within the scope of the tests performed.

### Audit Result

**PASS**

---

## 7. Final Incident Summary

| Incident | Root Cause | Resolution | Status |
|---|---|---|---|
| Incorrect DNS configuration | Public DNS resolver configured | Restored internal DNS | RESOLVED |
| Domain Controller connectivity failure | Disabled Ethernet adapter | Re-enabled network adapter | RESOLVED |
| Departmental resource access failure | Missing security group membership | Restored membership and refreshed session | RESOLVED |
| Group Policy application failure | Disabled GPO link | Re-enabled link and refreshed policy | RESOLVED |
| Infrastructure health audit | Preventive validation | No repairs required | PASS |

## 8. Troubleshooting Command Reference

### Network and DNS

| Command | Purpose |
|---|---|
| Get-NetIPConfiguration | Inspect network configuration |
| Get-NetAdapter | Inspect network adapter status |
| Get-DnsClientServerAddress | Retrieve configured DNS servers |
| Set-DnsClientServerAddress | Modify client DNS configuration |
| Clear-DnsClientCache | Clear cached DNS records |
| Resolve-DnsName | Perform DNS queries |
| ping | Test IP connectivity |
| Disable-NetAdapter | Disable a network adapter |
| Enable-NetAdapter | Enable a network adapter |

### Active Directory and Authentication

| Command | Purpose |
|---|---|
| Test-ComputerSecureChannel | Test the computer's domain secure channel |
| nltest /dsgetdc | Locate a Domain Controller |
| Get-ADPrincipalGroupMembership | Inspect AD group memberships |
| Add-ADGroupMember | Add a principal to a group |
| Remove-ADGroupMember | Remove a principal from a group |
| whoami | Identify the current user |
| whoami /groups | Inspect groups in the current access token |
| $env:LOGONSERVER | Display the logon server environment variable |
| klist | Inspect cached Kerberos tickets |

### Group Policy

| Command | Purpose |
|---|---|
| gpmc.msc | Open Group Policy Management |
| gpupdate /force | Refresh Group Policy |
| gpresult /scope user /r | Display user-side policy results |

### Infrastructure Health

| Command | Purpose |
|---|---|
| Get-Service | Inspect Windows service status |
| dcdiag /q | Report Domain Controller diagnostic errors |
| Get-SmbShare | Inspect SMB shares |

### Session Management

| Command | Purpose |
|---|---|
| shutdown /l | Sign out the current user |
| shutdown /r /t 0 | Restart the computer immediately |

## 9. Unexpected Diagnostic Observations

Two unexpected behaviours were encountered during this lab.

### Secure Channel Result During Network Outage

Test-ComputerSecureChannel returned True while:

- The workstation's network adapter was disabled.
- IP connectivity to DC01 failed.
- Fresh Domain Controller discovery failed.

The exact cause was not conclusively established.

The result demonstrates the importance of correlating multiple diagnostic tests.

### Local Access Token and AD Membership Discrepancy

The local access token temporarily retained outdated group membership information following changes in Active Directory.

SMB authorization reflected the removal and restoration of access before the local token consistently displayed the expected group membership.

A workstation restart resolved the observed discrepancy.

The exact underlying cause was not independently established.

These observations were retained in the documentation to accurately represent the actual troubleshooting process.

## 10. Final Validation

| Test | Result |
|---|---|
| Healthy network baseline established | PASS |
| Internal DNS failure reproduced | PASS |
| DNS root cause identified | PASS |
| Internal DNS restored | PASS |
| AD service discovery restored | PASS |
| Domain connectivity failure reproduced | PASS |
| Network root cause identified | PASS |
| Domain Controller connectivity restored | PASS |
| Missing security group membership reproduced | PASS |
| Unauthorized SMB access denied | PASS |
| Security group membership restored | PASS |
| SMB resource access restored | PASS |
| Expected local token groups restored | PASS |
| Disabled GPO link diagnosed | PASS |
| GPO restriction removed during fault | PASS |
| GPO link restored | PASS |
| GPO restriction restored | PASS |
| Essential DC services verified | PASS |
| DCDiag executed without reported errors | PASS |
| SYSVOL and NETLOGON shares verified | PASS |

## 11. Key Takeaways

- Troubleshooting should begin with a known healthy baseline.
- Network connectivity, DNS, authentication, and authorization represent different infrastructure concerns.
- Active Directory depends on functional internal DNS and service discovery.
- Domain Controller discovery failures do not automatically indicate broken domain trust.
- Administrators should avoid unnecessary domain rejoining or computer account resets.
- AD group memberships and access tokens represent different aspects of the security context.
- AGDLP simplifies both resource administration and permission troubleshooting.
- Kerberos tickets provide authentication rather than unrestricted resource authorization.
- Group Policy troubleshooting requires checking targeting, links, filtering, and actual policy application.
- Domain Controller health should be evaluated using multiple diagnostic tools.
- Successful configuration changes should always be followed by functional verification.
- Unexpected results should be investigated and documented without unsupported conclusions.

## Lab Conclusion

This lab successfully demonstrated the diagnosis and resolution of four controlled Active Directory infrastructure incidents, followed by a preventive Domain Controller health audit.

All intentional faults were reversed, and the tested infrastructure functionality was restored.

The lab concludes the planned practical exercises of the Windows Server & Active Directory project.

## Scope and Limitations

This environment contains a single Domain Controller and one domain-joined workstation.

Multi-DC replication troubleshooting, actual computer account trust repair, backup restoration, and disaster recovery were not performed.

Recovery in this lab refers to restoring functionality following controlled configuration and connectivity failures.
