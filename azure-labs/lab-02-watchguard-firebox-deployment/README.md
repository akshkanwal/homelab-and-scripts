# Lab 02 — WatchGuard Firebox Cloud Deployment on Azure

**Repo:** homelab-and-scripts
**Date Completed:** June 2026
**Certification Track:** AZ-104 Microsoft Azure Administrator + WatchGuard PCNSE

## Lab Overview

Deployed a full WatchGuard Firebox Cloud lab environment on Azure including a virtual firewall, Linux client VM, and Windows Server client VM. All resources were deployed and managed using a combination of Azure Portal, Azure CLI (Bash), and Azure PowerShell — deliberately using all three methods to build familiarity with each toolset.

This lab was built to support WatchGuard certification (PCNSE) study and hands-on Azure networking practice simultaneously. The environment mirrors a real production deployment: a firewall sitting between the internet and an internal network, with client machines behind it that should have their traffic inspected and controlled by the Firebox.

---

## Architecture Diagram

```
Internet
    │
    ▼
Public IP (Dynamic — Standard SKU)
DNS: wg-firebox-lab.canadacentral.cloudapp.azure.com
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  vnet-watchguard-lab  (10.10.0.0/16)                    │
│  Resource Group: rg-watchguard-lab  │  Canada Central   │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │  subnet-wan  (10.10.1.0/24)                      │   │
│  │  WAN / External Interface                        │   │
│  │  Route Table: vmwgfirebox-subnet-wan-routes      │   │
│  │                                                  │   │
│  │  ┌────────────────────────────────────────────┐  │   │
│  │  │  vmwgfirebox                               │  │   │
│  │  │  WatchGuard Firebox Cloud PAYG             │  │   │
│  │  │  Standard_D2s_v3                           │  │   │
│  │  │  NSG: NSG-vmwgfireboxEth0Management        │  │   │
│  │  │  (Port 8080 inbound — Management UI)       │  │   │
│  │  └────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────┘   │
│                         │                               │
│  ┌──────────────────────▼───────────────────────────┐   │
│  │  subnet-lan  (10.10.2.0/24)                      │   │
│  │  LAN / Internal Interface                        │   │
│  │  Route Table: vmwgfirebox-subnet-lan-routes      │   │
│  │                                                  │   │
│  │  ┌──────────────────────┐  ┌──────────────────┐  │   │
│  │  │  vm-linux-client     │  │  vm-win-client   │  │   │
│  │  │  Ubuntu 22.04 LTS    │  │  WS 2022 DC Core │  │   │
│  │  │  Standard_D2s_v3     │  │  Standard_D2s_v3 │  │   │
│  │  │  No public IP        │  │  No public IP    │  │   │
│  │  └──────────────────────┘  └──────────────────┘  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
│  Storage Account: stwgfireboxlab (Standard LRS)         │
└─────────────────────────────────────────────────────────┘
```

---

## Resources Created

### Resource Groups

| Name | Purpose |
|---|---|
| `rg-watchguard-lab` | VNet, subnets, storage account |
| `rg-wg-firebox` | All VMs, NICs, NSGs, route tables, public IPs |

### Networking

| Resource | Name | Details |
|---|---|---|
| Virtual Network | `vnet-watchguard-lab` | Address space: 10.10.0.0/16 |
| Subnet | `subnet-wan` | 10.10.1.0/24 — WAN/external interface |
| Subnet | `subnet-lan` | 10.10.2.0/24 — LAN/internal interface |
| NSG | `NSG-vmwgfireboxEth0Management` | Inbound rule: port 8080 — Firebox management UI |
| Route Table | `vmwgfirebox-subnet-wan-routes` | Attached to subnet-wan |
| Route Table | `vmwgfirebox-subnet-lan-routes` | Attached to subnet-lan |

### Virtual Machines

| Resource | Name | Details |
|---|---|---|
| Firewall VM | `vmwgfirebox` | WatchGuard Firebox Cloud PAYG, Standard_D2s_v3 |
| Linux Client | `vm-linux-client` | Ubuntu 22.04 LTS, Standard_D2s_v3, no public IP |
| Windows Client | `vm-win-client` | Windows Server 2022 Datacenter Core, Standard_D2s_v3, no public IP |

### Other

| Resource | Name | Details |
|---|---|---|
| Public IP | Dynamic (Standard SKU) | DNS: wg-firebox-lab.canadacentral.cloudapp.azure.com |
| Storage Account | `stwgfireboxlab` | Standard LRS — pre-created for Firebox Marketplace deployment |

---

## Key Commands Used

### Azure CLI — Deploy Linux VM

```bash
az vm create \
  --resource-group rg-wg-firebox \
  --name vm-linux-client \
  --image Ubuntu2204 \
  --vnet-name vnet-watchguard-lab \
  --subnet subnet-lan \
  --admin-username azureuser \
  --generate-ssh-keys \
  --size Standard_D2s_v3 \
  --output table
```

### Azure CLI — Remove Public IP from Linux VM

Azure CLI assigns a public IP by default. These commands dissociate it from the NIC, then delete the resource:

```bash
az network nic ip-config update \
  --resource-group rg-wg-firebox \
  --nic-name vm-linux-clientVMNic \
  --name ipconfigvm-linux-client \
  --remove publicIpAddress

az network public-ip delete \
  --resource-group rg-wg-firebox \
  --name vm-linux-clientPublicIP
```

### Azure CLI — Verify Deployed Resources

```bash
# List all resources in the VM resource group
az resource list --resource-group rg-wg-firebox --output table

# Check VM power states
az vm list --resource-group rg-wg-firebox --show-details \
  --query "[].{Name:name, State:powerState}" --output table

# Confirm no public IPs remain attached
az network public-ip list --resource-group rg-wg-firebox --output table
```

### Azure PowerShell — Deploy Windows Server VM

Azure PowerShell does **not** assign a public IP by default — unlike the CLI. No removal step needed.

```powershell
New-AzVM `
  -ResourceGroupName "rg-wg-firebox" `
  -Name "vm-win-client" `
  -Location "canadacentral" `
  -Image "MicrosoftWindowsServer:WindowsServer:2022-datacenter-core:latest" `
  -VirtualNetworkName "vnet-watchguard-lab" `
  -SubnetName "subnet-lan" `
  -Size "Standard_D2s_v3"
```

### Azure PowerShell — Deallocate Windows VM (Cost Control)

```powershell
Stop-AzVM `
  -ResourceGroupName "rg-wg-firebox" `
  -Name "vm-win-client" `
  -Force
```

### Deployment Scripts

Reusable scripts saved to this repo for future redeployment:

| Script | Location | Purpose |
|---|---|---|
| `deploy-linux-vm.sh` | `/azure-labs/lab-02-watchguard-firebox-deployment/` | Bash script — deploy Linux client VM |
| `deploy-win-vm.ps1` | `/powershell/` | PowerShell script — deploy Windows Server VM |

---

## Troubleshooting Encountered

Real issues hit during this lab and how they were resolved:

| # | Problem | Root Cause | Resolution |
|---|---|---|---|
| 1 | WatchGuard Marketplace deployment failed | Firebox Cloud requires a **completely empty** resource group | Created separate `rg-wg-firebox` for the Firebox; kept VNet in `rg-watchguard-lab` |
| 2 | Basic SKU public IP not available | Basic SKU public IPs are being retired; not available in all subscriptions | Switched to **Standard SKU** with Dynamic allocation and DNS label |
| 3 | B-series and A-series VM sizes unavailable | Canada Central subscription quota does not include B/A series | Used **Standard_D2s_v3** for all VMs (Firebox, Linux client, Windows client) |
| 4 | Port 8080 blocked after Firebox deployment | Management Only NSG applied by default — port 8080 not included | Manually added inbound NSG rule: port 8080, source My IP |
| 5 | Linux VM got an unexpected public IP | Azure CLI assigns a public IP to VMs by default | Removed manually post-deployment using `nic ip-config update` + `public-ip delete` |
| 6 | Storage account creation failed during Marketplace deploy | Marketplace deployment could not create a storage account inline | Pre-created `stwgfireboxlab` in `rg-watchguard-lab` before deployment; referenced it during wizard |

---

## Concepts Learned

### VNet Architecture — Address Spaces vs Subnets

The VNet address space (10.10.0.0/16) is the outer boundary — like a city. Subnets (10.10.1.0/24, 10.10.2.0/24) are neighbourhoods within that city. Devices in different subnets can communicate via routing, but the separation allows traffic control at each boundary.

Azure reserves 5 IPs per subnet (network, gateway, two DNS, broadcast), so a /24 provides 251 usable addresses.

### Subnetting — /16 vs /24

| CIDR | Hosts Available | Typical Use |
|---|---|---|
| /16 | 65,534 | VNet address space — wide container |
| /24 | 251 (Azure) | Individual subnet — one network segment |
| /30 | 2 | Point-to-point links |

### SSH Key Pairs

`--generate-ssh-keys` creates an RSA key pair:
- **Private key** — stored locally at `~/.ssh/id_rsa` on the machine running the CLI command. Never shared.
- **Public key** — placed in `~/.ssh/authorized_keys` on the VM. Can be shared freely.

Authentication: the VM challenges with a value encrypted using the public key. Only the holder of the private key can decrypt it and prove identity. No password to brute-force or leak.

### Public IPs — Static vs Dynamic, SKU Differences

| | Basic SKU | Standard SKU |
|---|---|---|
| Allocation | Static or Dynamic | Static or Dynamic |
| Zone redundancy | No | Yes |
| Availability | Being retired | Current standard |
| Security | Open by default | Closed by default (NSG required) |

Dynamic IPs release on VM deallocation. The DNS label (`wg-firebox-lab.canadacentral.cloudapp.azure.com`) provides a stable hostname even as the underlying IP changes.

### NSGs — Inbound/Outbound Rules

NSGs are stateful packet filters. Key properties:
- Rules are evaluated by **priority** — lower number = higher priority
- Default rules allow VNet-internal traffic and block everything else inbound from internet
- The Management Only NSG on the Firebox restricts inbound to port 8080 — all other ports blocked until explicitly opened

### Route Tables

Azure creates system routes by default (VNet-to-VNet, internet). User Defined Routes (UDRs) override these — for example, forcing all LAN subnet traffic through the Firebox's internal NIC instead of routing directly to the internet. This is what makes the Firebox an actual gateway rather than just another VM on the network.

*Route table configuration is the next step in this lab.*

### Azure CLI vs Azure PowerShell — Behaviour Differences

| Behaviour | Azure CLI | Azure PowerShell |
|---|---|---|
| Public IP on VM create | **Assigned by default** — must remove manually if not wanted | **Not assigned by default** |
| Output format | `--output table/json/tsv` | Object-based — pipe to `Format-Table` |
| Script style | Bash — good for Linux/Mac environments | PowerShell — good for Windows and cross-platform |
| Best for | Quick commands, CI/CD pipelines | Complex automation, enterprise scripting |

### Git Workflow Practiced

```bash
# Write the script file
vim deploy-linux-vm.sh

# Stage changes
git add deploy-linux-vm.sh

# Commit with meaningful message
git commit -m "Add deploy-linux-vm.sh — Azure CLI script for vm-linux-client deployment"

# Push to GitHub
git push
```

---

## Cost Management

Keeping lab costs under control while maximising learning time:

| Practice | Details |
|---|---|
| Deallocate VMs after every session | Stopped VMs do not incur compute charges |
| Delete public IP after each session | Dynamic IPs are free when unattached; Standard SKU IPs have a small charge when attached |
| Windows VM — delete when not in use | Redeploy via `deploy-win-vm.ps1` script rather than leaving it allocated |
| Budget alert | $50 CAD set at subscription level — email notification at 80% actual and forecasted |
| VM sizing | Standard_D2s_v3 only — only D_v3 series available in Canada Central for this subscription |

---

## Next Steps

- [ ] Configure Route Table on `subnet-lan` — UDR to force all client traffic through Firebox LAN NIC
- [ ] Complete WatchGuard Firebox initial setup wizard via web UI (port 8080)
- [ ] Configure outbound firewall policy — allow Linux/Windows clients to reach internet through Firebox
- [ ] Test end-to-end traffic flow: client VM → Firebox → internet
- [ ] SSH into `vm-linux-client` from Mac Terminal via Firebox management access
- [ ] RDP into `vm-win-client` through Firebox
- [ ] Configure WatchGuard logging — review traffic logs in Firebox System Manager
- [ ] Practice NAT rules — Dynamic NAT for outbound, Static NAT for inbound services
- [ ] Commit `deploy-linux-vm.sh` and `deploy-win-vm.ps1` scripts to this repo

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
