# Lab 02 — WatchGuard Firebox Cloud: Full Network Lab Deployment on Azure

**Repo:** homelab-and-scripts
**Date Completed:** June 2026
**Certification Track:** AZ-104 Microsoft Azure Administrator + WatchGuard PCNSE

## Lab Overview

Deployed a complete enterprise-style firewall lab on Azure using WatchGuard Firebox Cloud. Built a proper network topology with WAN/LAN separation, deployed client VMs, configured firewall policies, SNAT port forwarding, and User Defined Routes (UDRs) to force all LAN traffic through the firewall. All resources were deployed and managed using Azure Portal, Azure CLI (Bash), and Azure PowerShell.

This lab simultaneously supports WatchGuard PCNSE certification study and hands-on Azure networking skill development — covering VNets, NSGs, route tables, virtual appliances, public IPs, and multi-tool deployment.

---

## Architecture Diagram

```
Internet
    │
    ▼
<PUBLIC-IP> (Azure Standard Static Public IP)
DNS: wg-firebox-lab.canadacentral.cloudapp.azure.com
    │
    ▼
Azure NSG: NSG-vmwgfireboxEth0Management
(Inbound: port 22 Allow, port 8080 Allow)
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  vnet-watchguard-lab  (10.10.0.0/16)                        │
│  rg-watchguard-lab  │  Canada Central                       │
│                                                             │
│  ┌────────────────────────────────────────────────────┐     │
│  │  subnet-wan  (10.10.1.0/24)                        │     │
│  │  Route Table: vmwgfirebox-subnet-wan-routes        │     │
│  │                                                    │     │
│  │  ┌──────────────────────────────────────────────┐  │     │
│  │  │  vmwgfirebox                                 │  │     │
│  │  │  WatchGuard Firebox Cloud PAYG               │  │     │
│  │  │  Standard_D2s_v3                             │  │     │
│  │  │  Eth0 (WAN) — subnet-wan                     │  │     │
│  │  │  Eth1 (LAN) — subnet-lan  <FIREBOX-LAN-IP>   │  │     │
│  │  └──────────────────────────────────────────────┘  │     │
│  └────────────────────────────────────────────────────┘     │
│                           │                                 │
│  ┌────────────────────────▼───────────────────────────┐     │
│  │  subnet-lan  (10.10.2.0/24)                        │     │
│  │  Route Table: rt-subnet-lan                        │     │
│  │  UDR: 0.0.0.0/0 → VirtualAppliance <FIREBOX-LAN-IP>│     │
│  │                                                    │     │
│  │  ┌──────────────────────┐  ┌──────────────────┐   │     │
│  │  │  vm-linux-client     │  │  vm-win-client   │   │     │
│  │  │  Ubuntu 22.04 LTS    │  │  WS 2022 DC Core │   │     │
│  │  │  Standard_D2s_v3     │  │  Standard_D2s_v3 │   │     │
│  │  │  10.10.2.4           │  │  (deallocated)   │   │     │
│  │  │  No public IP        │  │  No public IP    │   │     │
│  │  └──────────────────────┘  └──────────────────┘   │     │
│  └────────────────────────────────────────────────────┘     │
│                                                             │
│  Storage Account: stwgfireboxlab (Standard LRS)             │
└─────────────────────────────────────────────────────────────┘
```

---

## Resources Created

### Resource Groups

| Name | Contents |
|---|---|
| `rg-watchguard-lab` | VNet, subnets, storage account, route tables |
| `rg-wg-firebox` | All VMs, NICs, NSGs, disks, public IP |

### Networking

| Resource | Name | Details |
|---|---|---|
| Virtual Network | `vnet-watchguard-lab` | 10.10.0.0/16 |
| Subnet | `subnet-wan` | 10.10.1.0/24 — Firebox WAN/external |
| Subnet | `subnet-lan` | 10.10.2.0/24 — Firebox LAN/internal |
| NSG | `NSG-vmwgfireboxEth0Management` | Inbound: port 8080 (Web UI), port 22 (SSH) |
| Route Table | `vmwgfirebox-subnet-wan-routes` | Attached to subnet-wan (Firebox-managed) |
| Route Table | `rt-subnet-lan` | UDR: 0.0.0.0/0 → VirtualAppliance `<FIREBOX-LAN-IP>` |
| Public IP | `pip-wg-firebox` | Standard SKU, Static, DNS: wg-firebox-lab |
| Storage Account | `stwgfireboxlab` | Standard LRS — pre-created for Marketplace deploy |

### Virtual Machines

| Resource | Name | OS | Size | IP |
|---|---|---|---|---|
| Firewall | `vmwgfirebox` | WatchGuard Firebox Cloud PAYG | Standard_D2s_v3 | WAN: `<PUBLIC-IP>` / LAN: `<FIREBOX-LAN-IP>` |
| Linux Client | `vm-linux-client` | Ubuntu 22.04 LTS | Standard_D2s_v3 | 10.10.2.4 (private only) |
| Windows Client | `vm-win-client` | Windows Server 2022 Datacenter Core | Standard_D2s_v3 | Private only (deallocated when not in use) |

---

## WatchGuard Configuration

### Firewall Policies

| Policy Name | Direction | Source | Destination | Port/Protocol | Purpose |
|---|---|---|---|---|---|
| `WG-Fireware-XTM-WebUI` | Inbound | Any | Firebox | 8080 TCP | Web UI management access |
| `Ping` | Any | Any | Any | ICMP | ICMP/ping (default) |
| `WG-Firebox-Mgmt` | Inbound | Any | Firebox | 4105, 4117, 4118 TCP | Firebox management ports |
| `LAN-to-WAN` | Outbound | Any-Trusted | Any-External | Any | Allow LAN clients to reach internet |
| `SSH-to-Linux` | Inbound | Any-External | SNAT: Linux-Client | 22 TCP | Port-forward SSH to Linux VM |

### SNAT — Static NAT (Port Forwarding)

| Field | Value |
|---|---|
| Name | `SNAT Linux-Client` |
| Type | Static NAT |
| External IP | Firebox WAN IP (`<PUBLIC-IP>`) |
| Internal Target | Linux VM private IP (`10.10.2.4`) |
| Port | 22 (SSH) |
| Used By Policy | `SSH-to-Linux` |

SNAT intercepts inbound SSH connections arriving at the Firebox WAN IP on port 22 and translates the destination to the Linux VM's private IP. Combined with the UDR, return traffic is forced back through the Firebox rather than dropping directly.

### Alias

| Name | Type | Value |
|---|---|---|
| `Linux-Client` | Host IPv4 | 10.10.2.4 |

---

## Key Commands Used

### Session Startup — Create and Attach Public IP

```bash
# Create Standard Static public IP
az network public-ip create \
  --resource-group rg-wg-firebox \
  --name pip-wg-firebox \
  --sku Standard \
  --allocation-method Static \
  --dns-name wg-firebox-lab \
  --location canadacentral

# Attach to Firebox WAN NIC
az network nic ip-config update \
  --resource-group rg-wg-firebox \
  --nic-name vmwgfireboxEth0-NSG \
  --name ipconfig1 \
  --public-ip-address pip-wg-firebox

# Start VMs
az vm start --resource-group rg-wg-firebox --name vmwgfirebox
az vm start --resource-group rg-wg-firebox --name vm-linux-client
```

### Deploy Linux VM (Full Subnet Resource ID)

Cross-resource-group VNet references require the full subnet resource ID:

```bash
az vm create \
  --resource-group rg-wg-firebox \
  --name vm-linux-client \
  --image Ubuntu2204 \
  --subnet /subscriptions/<SUBSCRIPTION-ID>/resourceGroups/rg-watchguard-lab/providers/Microsoft.Network/virtualNetworks/vnet-watchguard-lab/subnets/subnet-lan \
  --admin-username azureuser \
  --generate-ssh-keys \
  --size Standard_D2s_v3
```

### Add SSH Inbound Rule to NSG

```bash
az network nsg rule create \
  --resource-group rg-wg-firebox \
  --nsg-name NSG-vmwgfireboxEth0Management \
  --name Allow-SSH \
  --priority 110 \
  --protocol TCP \
  --destination-port-ranges 22 \
  --access Allow \
  --direction Inbound
```

### Create User Defined Route Table (UDR)

```bash
# Create route table
az network route-table create \
  --resource-group rg-watchguard-lab \
  --name rt-subnet-lan \
  --location canadacentral

# Add default route via Firebox LAN interface (VirtualAppliance)
az network route-table route create \
  --resource-group rg-watchguard-lab \
  --route-table-name rt-subnet-lan \
  --name default-via-firebox \
  --address-prefix 0.0.0.0/0 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address <FIREBOX-LAN-IP>

# Attach route table to subnet-lan
az network vnet subnet update \
  --resource-group rg-watchguard-lab \
  --vnet-name vnet-watchguard-lab \
  --name subnet-lan \
  --route-table rt-subnet-lan
```

### Fix Subnet Address Prefixes (if null)

```bash
az network vnet subnet update \
  --resource-group rg-watchguard-lab \
  --vnet-name vnet-watchguard-lab \
  --name subnet-lan \
  --address-prefixes 10.10.2.0/24

az network vnet subnet update \
  --resource-group rg-watchguard-lab \
  --vnet-name vnet-watchguard-lab \
  --name subnet-wan \
  --address-prefixes 10.10.1.0/24
```

### Test Port Connectivity

```bash
nc -zv <PUBLIC-IP> 22      # Test SSH port
nc -zv <PUBLIC-IP> 8080    # Test Firebox Web UI port
```

### Verify Resource State

```bash
az resource list --resource-group rg-wg-firebox --output table
az vm list --resource-group rg-wg-firebox --show-details \
  --query "[].{Name:name, State:powerState}" --output table
az network public-ip list --resource-group rg-wg-firebox --output table
```

### Session Shutdown — Deallocate and Delete Public IP

```bash
# Deallocate VMs
az vm deallocate --resource-group rg-wg-firebox --name vmwgfirebox
az vm deallocate --resource-group rg-wg-firebox --name vm-linux-client

# Detach public IP from NIC
az network nic ip-config update \
  --resource-group rg-wg-firebox \
  --nic-name vmwgfireboxEth0-NSG \
  --name ipconfig1 \
  --remove publicIpAddress

# Delete public IP resource
az network public-ip delete \
  --resource-group rg-wg-firebox \
  --name pip-wg-firebox
```

### Deploy Windows Server VM (PowerShell)

Azure PowerShell does **not** auto-assign a public IP — unlike the CLI.

```powershell
New-AzVM `
  -ResourceGroupName "rg-wg-firebox" `
  -Name "vm-win-client" `
  -Location "canadacentral" `
  -Image "MicrosoftWindowsServer:WindowsServer:2022-datacenter-core:latest" `
  -VirtualNetworkName "vnet-watchguard-lab" `
  -SubnetName "subnet-lan" `
  -Size "Standard_D2s_v3"

# Deallocate when not in use
Stop-AzVM `
  -ResourceGroupName "rg-wg-firebox" `
  -Name "vm-win-client" `
  -Force
```

---

## Troubleshooting Encountered

| # | Problem | Root Cause | Resolution |
|---|---|---|---|
| 1 | WatchGuard Marketplace deploy failed | Firebox requires a completely empty resource group | Created dedicated `rg-wg-firebox`; kept VNet in `rg-watchguard-lab` |
| 2 | Basic SKU public IP unavailable | Being retired; not available in all Canada Central subscriptions | Switched to Standard SKU Static IP |
| 3 | B-series/A-series VM sizes unavailable | Quota not included in this subscription in Canada Central | Used Standard_D2s_v3 for all VMs |
| 4 | Subnet address prefixes null after VNet creation | UI deployment quirk — prefixes not saved correctly | Fixed via `az network vnet subnet update --address-prefixes` |
| 5 | Linux VM deployed into wrong VNet | VNet lived in `rg-watchguard-lab`, VM deployed to `rg-wg-firebox` — short name resolution failed | Used full subnet resource ID with `/subscriptions/<SUBSCRIPTION-ID>/...` |
| 6 | Port 8080 open but port 22 timing out | NSG was missing the Allow-SSH inbound rule | Added rule via `az network nsg rule create` |
| 7 | SSH policy configured on Firebox but Linux VM still not responding | Asymmetric routing — return packets left subnet-lan directly via Azure default route, bypassing the Firebox | Created UDR on subnet-lan with `0.0.0.0/0 → VirtualAppliance <FIREBOX-LAN-IP>` |
| 8 | Storage account inline creation failed during Marketplace deploy | Marketplace wizard could not create storage account mid-deployment | Pre-created `stwgfireboxlab` in `rg-watchguard-lab` before starting wizard |

---

## Concepts Learned

### Asymmetric Routing — The Core Problem This Lab Solved

Without a UDR, return traffic from the Linux VM took a shortcut:

```
Inbound:   Internet → Public IP → NSG → Firebox WAN → SNAT → vm-linux-client ✓
Return:    vm-linux-client → Azure default route → Internet (BYPASSES Firebox) ✗
```

The Firebox drops the return packets because it has no record of the session (it never saw the outbound side). The fix — a UDR forcing all LAN traffic through the Firebox LAN IP — ensures both directions traverse the firewall:

```
Return:    vm-linux-client → UDR → Firebox LAN → Firebox WAN → Internet ✓
```

### User Defined Routes (UDR) and VirtualAppliance Next Hop

Azure's system routes send subnet traffic directly to the internet by default. UDRs override this. The `VirtualAppliance` next hop type tells Azure to forward packets to a specific IP (the Firebox LAN interface) rather than following the default path. This is the standard mechanism for inserting any NVA (Network Virtual Appliance) — firewall, load balancer, IDS — into the traffic path.

### Double NAT

Traffic from the Linux VM reaching the internet passes through two NAT operations:
1. **Azure NAT** — Azure translates the VM's private IP to the public IP at the platform level
2. **Firebox SNAT** — WatchGuard performs its own outbound NAT via the LAN-to-WAN policy

Both must be correctly configured for end-to-end connectivity.

### SNAT vs DNAT (WatchGuard Context)

- **SNAT (Static NAT)** — used here for port forwarding inbound connections (WAN IP:22 → Linux VM:22). WatchGuard calls this "Static NAT" and it is configured as an SNAT action linked to a firewall policy.
- **Dynamic NAT** — used for outbound connections (many private IPs → one public IP). Applied automatically by the LAN-to-WAN policy.

### NSG Rule Priority

NSG rules are evaluated lowest number first. Priority 110 for the SSH rule means it is evaluated before the default deny rules (priority 65000+). Rules do not "fall through" — the first matching rule wins.

### Azure CLI vs Azure PowerShell — Default Behaviour

| Behaviour | Azure CLI | Azure PowerShell |
|---|---|---|
| Public IP on VM create | **Yes — assigned by default** | No — not assigned by default |
| Cross-RG VNet reference | Requires full resource ID | Accepts VNet name directly |
| Output | `--output table/json/tsv` | Object-based, pipe to `Format-Table` |

### WatchGuard Traffic Monitor

Real-time packet log inside the Firebox Web UI. Essential for verifying whether traffic is hitting the firewall, which policy is matching it, and whether the SNAT action is applying. Used extensively during troubleshooting to confirm packets were arriving but return traffic was being dropped.

### netcat (nc) for Port Testing

`nc -zv <HOST> <PORT>` tests TCP connectivity without initiating a full application handshake. Much faster than waiting for an SSH timeout to confirm a port is closed.

---

## Security Notes

| Item | Current State | Production Recommendation |
|---|---|---|
| SSH (port 22) | Open to any source | Restrict to known IPs only; close when not in use |
| Firebox Web UI (port 8080) | Open to any source | Restrict to known IPs only |
| SSH authentication | Key-based only (password disabled) | Keep key-based; rotate keys periodically |
| Public IP | Deleted after every session | Use Just-In-Time access or VPN for production |
| Windows VM | No public IP | Correct — access only via Firebox SNAT or VPN |
| Linux VM | No public IP | Correct — accessible only via Firebox SNAT rule |

---

## Cost Management

| Practice | Details |
|---|---|
| Deallocate VMs after every session | No compute charges while deallocated |
| Delete public IP after every session | Standard SKU static IPs charge ~$4–7 CAD/month even when unattached |
| Windows VM — delete when not in use | Redeploy via `deploy-win-vm.ps1` rather than leaving allocated |
| Budget alert | $50 CAD on subscription — email at 80% actual and forecasted |
| VM sizing | Standard_D2s_v3 only — only D_v3 series available in Canada Central for this subscription |

---

## Next Steps

- [ ] Restrict port 22 inbound NSG rule to `<YOUR-IP>/32` — close when not testing
- [ ] Configure RDP port forward (SNAT) for Windows VM access through Firebox
- [ ] Test traffic between Linux VM and Windows VM through Firebox (inter-LAN policy)
- [ ] Explore WatchGuard subscription services — IPS, web filtering, APT Blocker
- [ ] Set up WatchGuard Cloud (Dimension) for centralised logging and visibility
- [ ] Document Firebox policy export for repeatable lab rebuild
- [ ] Commit `deploy-linux-vm.sh` and `deploy-win-vm.ps1` scripts to this repo

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
