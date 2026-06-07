# Lab 02 — WatchGuard Firebox Cloud Deployment on Azure

**Repo:** homelab-and-scripts  
**Date Completed:** June 2026  
**Certification Track:** AZ-104 Microsoft Azure Administrator + WatchGuard PCNSE

## Lab Overview

This lab deploys a functional WatchGuard Firebox Cloud instance on Azure with a proper two-NIC architecture (WAN and LAN), a virtual network configured with correct subnet segmentation, and a Linux client VM on the internal network to simulate a protected workstation.

The objective was to build a realistic firewall lab environment in Azure that mirrors how WatchGuard is deployed in production — external interface exposed to the internet, internal interface protecting a private network — while also practicing core Azure networking concepts (VNets, subnets, NSGs, public IPs, and Azure CLI).

---

## Architecture Diagram

```
Internet
    │
    ▼
Public IP (Dynamic)
wg-firebox-lab.canadacentral.cloudapp.azure.com
    │
    ▼
┌─────────────────────────────────────────────┐
│  vnet-watchguard-lab  (10.10.0.0/16)        │
│  Resource Group: rg-watchguard-lab          │
│  Region: Canada Central                     │
│                                             │
│  ┌──────────────────────────────────────┐   │
│  │  subnet-wan  (10.10.1.0/24)          │   │
│  │  WAN / External Interface            │   │
│  │                                      │   │
│  │  ┌────────────────────────────────┐  │   │
│  │  │  vmwgfirebox                   │  │   │
│  │  │  WatchGuard Firebox Cloud PAYG │  │   │
│  │  │  Standard_D2s_v3               │  │   │
│  │  │  NSG: Management Only          │  │   │
│  │  └────────────────────────────────┘  │   │
│  └──────────────────────────────────────┘   │
│                │                            │
│  ┌─────────────▼────────────────────────┐   │
│  │  subnet-lan  (10.10.2.0/24)          │   │
│  │  LAN / Internal Interface            │   │
│  │                                      │   │
│  │  ┌────────────────────────────────┐  │   │
│  │  │  vm-linux-client               │  │   │
│  │  │  Ubuntu 22.04 LTS              │  │   │
│  │  │  Standard_D2s_v3               │  │   │
│  │  │  No public IP                  │  │   │
│  │  └────────────────────────────────┘  │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

---

## Resources Created

| Resource | Name | Resource Group | Details |
|---|---|---|---|
| Resource Group | `rg-watchguard-lab` | — | VNet and networking resources |
| Resource Group | `rg-wg-firebox` | — | Firebox VM and client VM |
| Virtual Network | `vnet-watchguard-lab` | rg-watchguard-lab | Address space: 10.10.0.0/16 |
| Subnet | `subnet-wan` | rg-watchguard-lab | 10.10.1.0/24 — WAN/external |
| Subnet | `subnet-lan` | rg-watchguard-lab | 10.10.2.0/24 — LAN/internal |
| Virtual Machine | `vmwgfirebox` | rg-wg-firebox | WatchGuard Firebox Cloud PAYG, Standard_D2s_v3 |
| Network Security Group | Management Only NSG | rg-wg-firebox | Attached to Firebox VM — management traffic only |
| Public IP | Dynamic | rg-wg-firebox | DNS: wg-firebox-lab.canadacentral.cloudapp.azure.com |
| Virtual Machine | `vm-linux-client` | rg-wg-firebox | Ubuntu 22.04 LTS, Standard_D2s_v3, no public IP |

---

## Key Commands Used

The Linux client VM was deployed via **Azure CLI** rather than the portal to practice CLI-based deployment.

**Login and set subscription context:**
```bash
az login
az account list --output table
az account set --subscription "<subscription-id>"
```

**Deploy the Linux client VM into subnet-lan:**
```bash
az vm create \
  --resource-group rg-wg-firebox \
  --name vm-linux-client \
  --image Ubuntu2204 \
  --size Standard_D2s_v3 \
  --vnet-name vnet-watchguard-lab \
  --subnet subnet-lan \
  --generate-ssh-keys \
  --admin-username azureuser
```

**Remove the auto-assigned public IP after deployment:**
```bash
# Dissociate the public IP from the NIC first
az network nic ip-config update \
  --resource-group rg-wg-firebox \
  --nic-name vm-linux-clientVMNic \
  --name ipconfig1 \
  --remove publicIpAddress

# Delete the public IP resource
az network public-ip delete \
  --resource-group rg-wg-firebox \
  --name vm-linux-clientPublicIP
```

**Verify the VM has no public IP:**
```bash
az vm list-ip-addresses --resource-group rg-wg-firebox --name vm-linux-client --output table
```

**Check VNet and subnet configuration:**
```bash
az network vnet show --resource-group rg-watchguard-lab --name vnet-watchguard-lab --output table
az network vnet subnet list --resource-group rg-watchguard-lab --vnet-name vnet-watchguard-lab --output table
```

---

## Concepts Learned

### Subnetting in Azure

Azure reserves 5 IP addresses in every subnet (first 4 and last 1), so a /24 subnet provides 251 usable addresses rather than 254.

Separating WAN and LAN into distinct subnets reflects real firewall architecture:
- The WAN subnet faces the internet and is locked down by NSG rules
- The LAN subnet is internal — traffic entering it passes through the Firebox first

```
10.10.1.0/24 (subnet-wan):
  10.10.1.0   — Network address (reserved)
  10.10.1.1   — Default gateway (reserved by Azure)
  10.10.1.2   — DNS (reserved by Azure)
  10.10.1.3   — Reserved by Azure
  10.10.1.255 — Broadcast (reserved)
  10.10.1.4–10.10.1.254 — Usable (251 addresses)
```

### SSH Keys

Azure generates an SSH key pair when `--generate-ssh-keys` is used. The private key is stored locally (`~/.ssh/id_rsa`) and the public key is placed in `~/.ssh/authorized_keys` on the VM. Key-based authentication is significantly stronger than password authentication — no password to brute-force or leak.

### Public IPs in Azure

- **Dynamic public IPs:** assigned at VM start, released at deallocation. The DNS label provides a stable hostname even when the IP changes.
- **Static public IPs:** fixed — cost more but required when the IP itself must not change (e.g. firewall rules on the remote side reference a specific IP).
- Removing a public IP from a VM (while keeping the VM running) requires dissociating it from the NIC's IP configuration before deleting the resource.

### Network Security Groups (NSGs)

NSGs are stateful packet filters attached to subnets or NICs. They define allow/deny rules for inbound and outbound traffic based on source, destination, port, and protocol.

For the Firebox VM, the Management Only NSG restricts inbound access to management protocols (HTTPS on port 8080/443 for the web UI, SSH for CLI) — preventing the management interface from being exposed to arbitrary internet traffic while the lab is running.

### Route Tables

Azure automatically creates system routes for traffic within the VNet and to the internet. Custom route tables (User Defined Routes) override these defaults — for example, forcing all traffic from `subnet-lan` to pass through the Firebox's internal NIC before reaching the internet. This is required for the Firebox to function as an actual gateway rather than just a VM sitting in the network.

*Route table configuration will be completed in the next lab session.*

### Azure CLI Basics

The Azure CLI (`az`) provides full control of Azure resources from the command line. Key patterns:
- `az [resource-type] [action]` — e.g. `az vm create`, `az network vnet show`
- `--output table` — human-readable output; `--output json` for scripting
- `--resource-group` — almost always required to scope the command to the right container
- Commands are idempotent where possible — running the same create command twice returns an error rather than creating a duplicate

---

## Next Steps

- Configure Route Table on `subnet-lan` to force all traffic through the Firebox internal NIC (UDR — User Defined Route)
- Complete initial WatchGuard Firebox setup wizard via web UI (port 8080)
- Configure WatchGuard outbound policy to allow the Linux client to reach the internet through the Firebox
- Test traffic flow: Linux client → Firebox → Internet
- Configure WatchGuard logging and review traffic logs
- Practice WatchGuard NAT rules (Dynamic NAT for outbound, Static NAT for inbound services)

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
