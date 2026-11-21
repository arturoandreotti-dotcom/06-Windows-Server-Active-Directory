
# Lab 01 — Windows Server Installation and Initial Configuration

## Objective

Install Windows Server 2025 in Oracle VirtualBox and prepare it for deployment as an Active Directory domain controller.

Configure the server hostname, static IPv4 networking, DNS resolution, and VirtualBox Guest Additions. Verify connectivity before installing Active Directory Domain Services.

## Lab Environment

| Component | Configuration |
|---|---|
| Hypervisor | Oracle VirtualBox |
| Host operating system | Windows 11 Home |
| Host RAM | 16 GB |
| Virtual machine | DC01 |
| Guest operating system | Windows Server 2025 Standard Evaluation (Desktop Experience) |
| Virtual CPUs | 2 |
| VM RAM | 4 GB |
| Virtual disk | 60 GB, dynamically allocated |
| Firmware | EFI |
| Network | AD-Lab-NAT |
| IPv4 subnet | 192.168.100.0/24 |

## Installation

### 1. Create the Virtual Machine

Created a new virtual machine named `DC01` in Oracle VirtualBox.

Configured:

- 4 GB RAM and 2 virtual CPUs
- 60 GB dynamically allocated VDI disk
- EFI firmware
- Windows Server 2025 Evaluation ISO
- Unattended installation disabled

Connected Adapter 1 to the existing `AD-Lab-NAT` NAT Network.

### 2. Install Windows Server

Booted from the installation ISO and selected:

**Windows Server 2025 Standard Evaluation (Desktop Experience)**

Selected the 60 GB unallocated virtual disk and allowed Windows Setup to create the required partitions.

Completed installation and configured the built-in Administrator account.

The Administrator password was stored privately in KeePassXC.

### 3. Initial Server Configuration

Opened Server Manager and inspected the Local Server properties.

Initial findings:

- Automatically generated computer name
- Workgroup membership
- Windows Firewall enabled
- Remote management enabled
- Remote Desktop disabled
- Ethernet configured for DHCP

Renamed the server:

```powershell
Rename-Computer -NewName "DC01" -Restart
```

Verified the hostname:

```powershell
hostname
```

Result:

```text
DC01
```

### 4. Install VirtualBox Guest Additions

Mounted the VirtualBox Guest Additions CD and installed the Windows guest utilities.

Verified the Guest Additions service:

```powershell
Get-Service VBoxService
```

Result: `Running`.

Enabled bidirectional shared clipboard functionality and verified that copying text between the VM and host worked.

## Network Configuration

### 1. Inspect the Network Adapter

```powershell
Get-NetIPConfiguration
```

Initial results:

| Property | Value |
|---|---|
| Interface alias | Ethernet |
| Interface index | 5 |
| IPv4 address | 169.254.94.112 |
| Default gateway | Not configured |

Windows assigned an APIPA address because DHCP was disabled on the NAT Network.

### 2. Configure Static IPv4 Addressing

```powershell
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.100.10 -PrefixLength 24 -DefaultGateway 192.168.100.1
```

Verified the resulting configuration:

```powershell
Get-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4
```

Results:

- IPv4 address: `192.168.100.10`
- Prefix length: `/24`
- Prefix origin: Manual
- Address state: Preferred

### 3. Configure Temporary DNS

Configured Cloudflare DNS for initial internet name resolution:

```powershell
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 1.1.1.1
```

Verified DNS resolution:

```powershell
Resolve-DnsName microsoft.com
```

Result: Successful resolution of IPv4 and IPv6 DNS records.

The temporary public DNS configuration was intended to be replaced during Active Directory DNS deployment.

## Connectivity Verification

### Default Gateway

```powershell
ping 192.168.100.1
```

Results:

- Packets sent: 4
- Packets received: 4
- Packet loss: 0%
- Average latency: Less than 1 ms

### External Connectivity

```powershell
ping 1.1.1.1
```

Results:

- Packets sent: 4
- Packets received: 4
- Packet loss: 0%
- Average latency: 324 ms

External connectivity was successful despite relatively high latency.

## Troubleshooting

### Initial Installation Boot Failure

**Issue:** VirtualBox displayed a message indicating that no bootable device was found.

**Cause:** The prompt to boot from the installation ISO timed out.

**Resolution:** Reset the VM and pressed a key when prompted to boot from CD/DVD.

### Guest Clipboard Integration

**Issue:** Copying and dragging content between DC01 and the host initially failed.

**Cause:** Guest Additions had not been installed and configured.

**Resolution:** Installed VirtualBox Guest Additions, verified the VBoxService service, and enabled bidirectional clipboard sharing.

### APIPA Address

**Issue:** Windows Server automatically assigned `169.254.94.112`.

**Cause:** DHCP was disabled on the NAT Network, and the server did not yet have a static address.

**Resolution:** Manually configured `192.168.100.10/24` with gateway `192.168.100.1`.

### IPv4 Address State

Immediately after configuring the static address, Windows temporarily displayed `Tentative` and `Invalid` address states.

A subsequent verification confirmed that the address state changed to `Preferred`.

## Snapshot

Created a VirtualBox snapshot named:

`Baseline - Windows Server 2025 Configured`

The snapshot preserves the configured Windows Server environment before Active Directory Domain Services deployment.

## Results

Successfully installed and configured Windows Server 2025.

Verified:

- Computer hostname: DC01
- Static IPv4 addressing
- NAT gateway connectivity
- External IPv4 connectivity
- DNS resolution
- VirtualBox Guest Additions integration

The server was ready for Active Directory Domain Services deployment.

## Lessons Learned

- Windows Server roles should be installed after initial server configuration.
- A server hostname and virtual machine name are separate identifiers.
- Domain controllers require predictable network addressing.
- APIPA commonly indicates that a DHCP-configured interface could not obtain a lease.
- Windows networking can be configured and verified using PowerShell.
- DNS resolution and IP connectivity should be tested separately.
- VirtualBox snapshots provide useful recovery points for isolated lab environments.
