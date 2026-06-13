# WatchGuard NSE Study Notes — Chapters 1, 2 & 3
**Study Guide:** Network Security Essentials for Locally-Managed Fireboxes  
**Fireware Version:** v12.11.2  
**Date:** June 2026

---

## Chapter 1: Introduction

### Firebox vs Fireware
- **Firebox** = the hardware or VM
- **Fireware** = the operating system running on it

### Management Models
- **Locally-managed** — config managed via WSM, Web UI, or CLI
- **Cloud-managed** — WatchGuard Cloud holds and pushes config; local tools are locked out
- A Firebox VM running in Azure is still **locally-managed** — "Firebox Cloud" is a product name, not a management model

### Management Tools
| Tool | Saves How | Notes |
|------|-----------|-------|
| WSM / Policy Manager | Offline — push when ready | Auto-saves local backup |
| Fireware Web UI | Live — immediate | No auto local backup |
| CLI | Immediate | SSH on port **4118** |

### NAT Types
- **Dynamic NAT (DNAT)** — outbound, many private IPs share one public IP
- **Static NAT (SNAT)** — inbound port forwarding to internal servers
- **1-to-1 NAT** — dedicated public IP per internal host; used when servers must initiate outbound on their public IP

### Key Concepts
- Unknown route = Firebox drops packet as **IP spoofing** (not "unknown destination")
- Secondary networks ≠ security isolation; VLANs = security isolation
- IKEv2 = default Mobile VPN recommendation; SSL VPN = fallback when IPSec blocked (TCP 443)
- Symmetric encryption = fast, used inside tunnels; Asymmetric = slow, used to set up tunnels

---

## Chapter 2: Firebox Setup and Management

### Factory Default Interfaces
| Interface | Role | Default IP | DHCP |
|-----------|------|-----------|------|
| Eth0 | External (WAN) | DHCP client | Client |
| Eth1 | Trusted (LAN) | 10.0.1.1/24 | Server |
| Eth2+ | Optional | 10.0.x.1/24 | Disabled |

- Web Setup Wizard URL: `https://10.0.1.1:8080`
- Web Setup Wizard = browser-based, can activate device
- Quick Setup Wizard = inside WSM, more options, cannot activate device

### Config File vs Backup Image
| | Config File (.xml) | Backup Image (.fxi) |
|-|--------------------|---------------------|
| Contains | Settings only | Everything |
| Portable? | Yes — any Firebox | No — same device only |
| Includes keys/users/certs? | No | Yes |

### Admin Roles
| Role | Permissions |
|------|-------------|
| Device Administrator | Read + write |
| Device Monitor | Read only |
| Guest Administrator | Hotspot accounts only |

- Default: `admin` / `readwrite` and `status` / `readonly`

### Feature Keys
- Without one: max 1 outbound device, no upgrades, no security services, no VPN
- **LiveSecurity** = required for Fireware OS upgrades
- Auto Feature Key Sync checks 7 days before expiry

### Upgrade Order
1. Read release notes
2. Save config file
3. Save backup image (.fxi)
4. Schedule maintenance window
- WSM version must be ≥ Fireware OS version

### Default Threat Protection (runs BEFORE policies)
- **Blocked Ports** — overrides all policies; inbound only
- **Blocked Sites** — permanent (manual) or temporary (auto-block, default 20 min, clears on reboot)
- **Blocked Sites Exceptions** — bypasses Default Packet Handling checks **except** IP Spoofing and IP Source Route attacks
- **Default Packet Handling** — drops DoS, SYN floods, port scans, spoofing

### Global Settings
- Web UI port default: **8080**
- NTP enabled by default — critical for certs, VPNs, log timestamps, feature key renewals

---

## Chapter 3: Logging, Monitoring and Reporting

### Log Destinations (can use all simultaneously)
- WatchGuard Cloud, Dimension, Syslog Server, WatchGuard Log Server
- **Log Server limitation:** doesn't support security services added after Fireware v11.8

### Five Log Types (TAEDS)
- **Traffic** — policy allow/deny decisions
- **Alarm** — notification-triggered events
- **Event** — admin activity, device state changes
- **Debug** — troubleshooting; adjustable verbosity
- **Statistic** — performance and bandwidth data

- Denied traffic = always logged
- Allowed traffic = only logged if enabled on the policy

### Reading a Traffic Log Message
```
2022-07-02 17:38:43 Member2 Allow 192.168.228.202 10.0.1.1 webcache/tcp 42973 8080 3-Trusted 1-WCI Allowed 60 63 (Outgoing-proxy-00) proc_id="firewall" rc="100" src_ip_nat="203.0.113.99"
```
Fields: timestamp → cluster member → disposition → source IP → dest IP → service/protocol → source port → dest port → source interface → dest interface → connection action → packet length → TTL → policy name → NAT address

- `src_ip_nat` = post-NAT public IP (confirms DNAT working)
- **Disposition** = packet filter decision (Allow/Deny)
- **Connection Action** = proxy content decision (Allowed/Dropped/Stripped)

### Monitoring Tools
- **FSM Traffic Monitor** — refreshes every 5 seconds; built-in ping, traceroute, DNS lookup, TCP dump
- **Fireware Web UI** — browser-based Traffic Monitor, no software install needed
- **Dimension** — on-prem VM (Hyper-V or VMware), richest local reporting
- **WatchGuard Cloud** — live status, logs, reports, remote system actions for locally-managed Fireboxes

---
*Notes generated from WatchGuard study sessions — Fireware v12.11.2 Study Guide*

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
