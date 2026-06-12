

---

## Session 3 — VPN Configuration (Lab Complete)

### Overview

Configured and tested both SSL VPN and IKEv2 Mobile VPN on WatchGuard Firebox Cloud. Successfully established IKEv2 VPN tunnel from Mac to Azure lab environment, achieving full LAN access through the Firebox. This completes the WatchGuard Firebox Cloud lab.

---

### SSL VPN — Attempted and Abandoned

**Configuration completed:**
- Enabled Mobile VPN with SSL on Firebox
- Configured primary address with DNS name
- Set virtual IP pool: `192.168.200.0/24`
- Authentication: Firebox-DB
- Created VPN user in Firebox-DB
- Added port 443 inbound NSG rule

**Why SSL VPN was abandoned:**

**1. Apple Silicon Incompatibility**

The WatchGuard Mobile VPN with SSL client downloaded from the Firebox portal is compiled for Intel (x86_64) architecture only. It is not compatible with Apple Silicon (ARM/M-series) processors. Confirmed via:

```bash
file "/Applications/WatchGuard/WatchGuard Mobile VPN with SSL.app/Contents/MacOS/"*
# Returns: x86_64
```

The client fails silently with "check your server IP or network" error — no traffic reaches the Firebox at all. Port 443 connectivity was confirmed working via netcat, ruling out network issues.

**2. Known Security Concerns**

SSL VPN has well-documented security vulnerabilities:
- Multiple critical CVEs across major vendors (Ivanti, Fortinet, Pulse Secure, SonicWall)
- Cyber insurance providers are increasingly flagging SSL VPN usage
- Industry is actively moving away from SSL VPN toward IKEv2/IPSec and ZTNA
- SonicWall is actively pushing customers off SSL VPN toward more secure alternatives
- WatchGuard's own ZTNA solution is the modern replacement

**Decision:** SSL VPN disabled and port 443 NSG rule removed. Pivoted to IKEv2 — more secure, natively supported on all modern operating systems, and industry standard.

---

### IKEv2 Mobile VPN — Successfully Configured and Tested

**Configuration:**
- Enabled Mobile VPN with IKEv2 on Firebox
- Primary address: DNS name of Firebox
- Virtual IP pool: `192.168.114.0/24`
- Authentication: Firebox-DB
- Certificate: Firebox-Generated Certificate
- Perfect Forward Secrecy: Enabled
- Phase 2 Proposals: ESP-AES256-SHA256 (removed insecure ESP-AES-SHA1)
- Created `ikev2user` in Firebox-DB → added to IKEv2-Users group
- DNS: 8.8.8.8 assigned to mobile clients

**NSG rule added:**

```bash
az network nsg rule create \
  --resource-group rg-wg-firebox \
  --nsg-name NSG-vmwgfireboxEth0Management \
  --name Allow-IKEv2 \
  --priority 130 \
  --protocol Udp \
  --destination-port-ranges 500 4500 \
  --access Allow \
  --direction Inbound
```

**Why two ports:**
- UDP 500 — IKE negotiation (initial handshake between client and Firebox)
- UDP 4500 — NAT Traversal (actual tunnel data; handles NAT in the path)

**Mac built-in VPN client configuration:**
- System Settings → VPN → Add VPN Configuration → IKEv2
- Server Address: Firebox DNS name
- Remote ID: Firebox DNS name
- Authentication: Username
- No third-party software required — works natively on Apple Silicon

**Verified working:**

| Test | Result |
|---|---|
| IKEv2 VPN connected | ✅ |
| VPN IP assigned from `192.168.114.0/24` pool | ✅ |
| Ping to Linux VM (`<LINUX-VM-IP>`) through tunnel | ✅ |
| Full LAN access through Firebox | ✅ |

---

### IKEv2 vs SSL VPN — Key Differences

| Feature | SSL VPN | IKEv2 |
|---|---|---|
| Protocol | TCP 443 | UDP 500/4500 |
| Client | Third party required | Built into OS |
| Security | Known CVEs, being phased out | Industry standard, recommended |
| NAT handling | Single port | Dedicated NAT-T port (4500) |
| Apple Silicon | Not supported (Intel only) | Natively supported |
| Performance | Slower (TCP overhead) | Faster (UDP) |
| Cyber insurance | Flagged as risk | Accepted |

---

### Additional Concepts Learned (Session 3)

- **IKEv2/IPSec VPN** — Phase 1 and Phase 2 negotiation
- **Perfect Forward Secrecy** — each session uses unique keys; past sessions cannot be decrypted if a key is compromised
- **NAT Traversal** — how IKEv2 handles multiple NAT layers using port 4500
- **SSL VPN CVEs** — why the industry is actively migrating away
- **Apple Silicon architecture detection** — `file` command to identify x86_64 vs ARM binaries
- **UDP vs TCP for VPN tunnels** — UDP avoids TCP-over-TCP performance problems; better for real-time traffic
- **WatchGuard ZTNA** — modern Zero Trust replacement for traditional VPN
- **Firebox-DB** — WatchGuard's local user database for authentication
- **IKEv2-Users group** — WatchGuard's built-in group for IKEv2 VPN access
- **ESP proposals** — encryption (AES-256) and hashing (SHA-256) algorithm selection for Phase 2

---

### Security Cleanup Performed

| Item | Action |
|---|---|
| SSL VPN | Disabled on Firebox |
| Port 443 NSG rule | Deleted |
| Port 3389 NSG rule | Deleted — Windows VM no longer exists |
| Remaining open ports | 8080 (Web UI), 22 (SSH SNAT), 500/4500 UDP (IKEv2) |

---

### Scripts Added to Repository

- `session-startup.sh` — automates Public IP creation, NIC attachment, and VM startup
- `session-shutdown.sh` — automates VM deallocation and Public IP deletion

---

### Lab Status: COMPLETE ✅

**Full topology working:**

```
Internet
    ↓
<PUBLIC-IP> (Azure Standard Static Public IP)
DNS: wg-firebox-lab.canadacentral.cloudapp.azure.com
    ↓
Azure NSG (inbound: 8080, 22, 500/4500 UDP)
    ↓
WatchGuard Firebox Cloud (vmwgfirebox)
    ├── SSH SNAT → vm-linux-client (<LINUX-VM-IP>)
    ├── IKEv2 VPN → pool 192.168.114.0/24 → full LAN access
    └── LAN-to-WAN → outbound internet for all LAN clients
subnet-lan (10.10.2.0/24)
    └── vm-linux-client (Ubuntu 22.04) ✅
UDR rt-subnet-lan: 0.0.0.0/0 → VirtualAppliance <FIREBOX-LAN-IP>
```

**Everything verified working:**

| Feature | Status |
|---|---|
| Firewall policies (inbound/outbound) | ✅ |
| SNAT port forwarding — SSH (port 22) | ✅ |
| SSH from Mac through Firebox to Linux VM | ✅ |
| RDP through Firebox to Windows VM (tested, VM since deleted) | ✅ |
| IKEv2 Mobile VPN from Mac to LAN | ✅ |
| VM-to-VM internal communication | ✅ |
| Outbound internet through Firebox | ✅ |
| Asymmetric routing fixed via UDR | ✅ |
| Traffic Monitor troubleshooting | ✅ |
| Botnet reputation blocking observed | ✅ |

---

### Next Steps (Post-Lab)

- [ ] Complete WatchGuard Learning Center free training modules
- [ ] Review exam topics: authentication methods, subscription services, WatchGuard Cloud
- [ ] Sit WatchGuard Essentials exam (WGU-Essentials) — 70 questions, 75% pass mark
- [ ] Move on to AZ-104 certification study

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
