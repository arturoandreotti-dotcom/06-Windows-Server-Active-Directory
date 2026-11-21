
# Lab 00 — Environment Setup

## Objective

Prepare a virtualized Windows environment for deploying and administering an Active Directory domain.

## Lab Environment

| Component | Configuration |
|---|---|
| Hypervisor | Oracle VirtualBox |
| Host OS | Windows 11 Home |
| Host RAM | 16 GB |
| Domain client | Windows 11 Enterprise Evaluation |
| Client VM | CLIENT01 |
| Client RAM | 4 GB |
| Client vCPUs | 2 |
| Domain controller | DC01 (planned) |
| Server OS | Windows Server 2025 Evaluation (planned) |

## Network Configuration

A dedicated VirtualBox NAT Network was created to provide connectivity between the virtual machines and external networks.

| Setting | Value |
|---|---|
| Network name | AD-Lab-NAT |
| IPv4 subnet | 192.168.100.0/24 |
| NAT gateway | 192.168.100.1 |
| VirtualBox DHCP | Disabled |
| IPv6 | Disabled |

### CLIENT01

| Setting | Value |
|---|---|
| Hostname | CLIENT01 |
| IPv4 address | 192.168.100.20 |
| Subnet prefix | /24 |
| Default gateway | 192.168.100.1 |
| DNS server | 1.1.1.1 (temporary) |

The client will use the domain controller as its DNS server after Active Directory DNS is deployed.

## Configuration

### Client Preparation

1. Created a full clone of the existing Windows 11 administration VM.
2. Named the cloned VM CLIENT01.
3. Connected its network adapter to AD-Lab-NAT.
4. Changed the VirtualBox graphics controller to VMSVGA.
5. Renamed the Windows computer to CLIENT01.
6. Configured static IPv4 addressing.
7. Configured temporary public DNS.
8. Verified Windows activation.

### PowerShell Commands

```powershell
# Inspect network configuration
Get-NetIPConfiguration

# Configure static IPv4 addressing
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.100.20 -PrefixLength 24 -DefaultGateway 192.168.100.1

# Verify the assigned IPv4 address
Get-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4

# Configure temporary DNS
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 1.1.1.1

# Verify DNS resolution
Resolve-DnsName www.microsoft.com

# Check computer name
hostname

# Rename computer
Rename-Computer -NewName "CLIENT01" -Restart

# Check Windows activation
slmgr /xpr
```

## Verification

| Test | Result |
|---|---|
| Static IPv4 address | Preferred |
| Gateway ping | 4/4 replies, 0% loss |
| External IPv4 ping | 4/4 replies, 0% loss |
| DNS resolution | Successful after DNS configuration |
| Computer hostname | CLIENT01 |
| Windows activation | Activated until January 31, 2027 |

## Troubleshooting

### Black Screen During VM Startup

**Issue:** CLIENT01 displayed a black screen after cloning.

**Resolution:** Changed the VirtualBox graphics controller from VBoxSVGA to VMSVGA.

Disabling 3D acceleration alone did not resolve the issue.

### Missing IPv4 Configuration

**Issue:** Windows automatically assigned an APIPA address (`169.254.127.132`).

**Cause:** DHCP was disabled on the NAT Network, and the client did not yet have a static IPv4 address.

**Resolution:** Configured `192.168.100.20/24` manually.

### DNS Resolution Failure

**Issue:** DNS queries timed out despite successful external IPv4 connectivity.

**Resolution:** Configured `1.1.1.1` as a temporary DNS resolver.

### Windows Activation Failure

**Issue:** The cloned Windows evaluation installation entered Notification Mode.

**Findings:**
- Initial notification reason: 0xC004F00F
- Online activation initially failed with 0x80072EE7
- DNS resolution was failing

**Resolution:** Restored DNS resolution and successfully activated Windows.

## Results

CLIENT01 is prepared with a static IPv4 configuration, functional NAT networking, working DNS resolution, and valid Windows evaluation activation.

The domain controller installation and final Active Directory DNS configuration remain pending.

## Lessons Learned

- VirtualBox VM names and Windows computer names are separate.
- NAT Networks allow multiple VMs to communicate and access external networks.
- Disabling DHCP requires manual IP configuration or another DHCP service.
- Successful IP connectivity does not guarantee DNS resolution.
- VM cloning may require changes to graphics and licensing configuration.
- Troubleshooting should proceed through observation, hypothesis, testing, and verification.
