# WatchGuard NSE Study Notes — Chapters 4 & 5
**Study Guide:** Network Security Essentials for Locally-Managed Fireboxes  
**Fireware Version:** v12.11.2  
**Date:** June 2026

---

## Chapter 4: Network Settings

### Three Routing Modes
| Mode | All Interfaces | NAT | VLANs | VPN | Use When |
|------|---------------|-----|-------|-----|---------|
| Mixed Routing (default) | Different IPs | Yes | Yes | Yes | Always, unless specific reason not to |
| Drop-In | Same IP | Not required | Limited | Limited | Adding firewall without re-addressing |
| Bridge | Same network | No | No | No | Transparent L2 inspection only |

- VPN requires **Mixed Routing Mode** — not available in Bridge Mode
- Web Setup Wizard always creates Mixed Routing Mode

### Interface Types and Aliases
| Type | Alias | Use |
|------|-------|-----|
| External | Any-External | WAN/ISP; always has default route 0.0.0.0/0 |
| Trusted | Any-Trusted | Internal LAN |
| Optional | Any-Optional | DMZ, guest |
| Custom | Any only | Explicit policies required — nothing allowed by default |

- Internal interface IPs must always be **static**
- External can be DHCP, PPPoE, or static

### Secondary Networks vs Bridges vs VLANs
| | Secondary Network | Bridge | VLAN |
|-|------------------|--------|------|
| Security isolation | None | None | Yes |
| Use case | Migration/consolidation | Act as switch | Segment traffic securely |
| Requires managed switch | No | No | Yes (802.1Q) |

- VLAN IDs: 1-4094
- Secondary networks: no filtering between primary and secondary on same interface

### Multi-WAN
- Activates automatically with 2+ external interfaces
- Only affects **outbound traffic** — no impact on BOVPNs or inbound

| Method | Distributes by | Use when |
|--------|---------------|---------|
| Failover (default) | Primary -> backup only | Simple redundancy |
| Round-Robin | Number of connections | Roughly equal ISP bandwidth |
| Routing Table (ECMP) | src/dst IP pairs | Smarter load balancing |
| Interface Overflow | Bandwidth cap per interface | Expensive backup ISP |

- **Failover** = primary fails, traffic moves to secondary
- **Failback** = primary recovers, traffic returns (configurable: auto or manual)

### Link Monitor
- Probe interval: **5 seconds**
- Deactivate after: **3 consecutive failures**
- Reactivate after: **3 consecutive successes**
- Physical link state = cable up/down (fast but limited)
- Logical link state = active Ping/TCP/DNS probes (catches "up but no internet")

### NAT Deep Dive
| Type | Direction | How it works | Use when |
|------|-----------|-------------|---------|
| Dynamic NAT | Outbound | RFC1918 -> Firebox external IP | Default, always on |
| Static NAT (SNAT) | Inbound | Rewrites destination IP by port | Publishing internal servers |
| 1-to-1 NAT | Both | Dedicated public IP per host | Many public IPs available |

- SNAT recommended over 1-to-1 NAT for most deployments
- 1-to-1 NAT IPs cannot be shared with VPNs, management, or other services
- Enabling 1-to-1 NAT with only one public IP locks out all inbound Firebox functions

### NAT Loopback
Internal users reaching internal servers via public domain name/IP.
Configure: SNAT action (public -> private IP) + policy (From: Any-Trusted, To: public IP, SNAT action applied)

---

## Chapter 5: Firewall Policies

### Policy Matching
- Traffic must match **both** From AND To for a policy to apply
- No matching policy = denied by hidden Unhandled Packet policies (fails closed)

### Key Aliases
| Alias | Covers |
|-------|--------|
| Any-Trusted | All trusted interfaces |
| Any-Optional | All optional interfaces |
| Any-External | All external interfaces |
| Any-BOVPN | All BOVPN IPSec tunnels |
| Firebox | All IPs assigned to Firebox interfaces |
| Any | Everything |
| Microsoft365 | M365 IPs/domains (auto-updated) |

- Custom interfaces: **no built-in alias** — all traffic blocked unless explicit policy written

### Management Policies — Never Delete These
| Policy | Port | Allows |
|--------|------|--------|
| WatchGuard Web UI | TCP 8080 | Web browser management |
| WatchGuard | TCP 4117 (WSM), TCP 4118 (CLI) | WSM and CLI management |

- Default From: Any-Trusted, Any-Optional
- FireboxV and Firebox Cloud also allow Any-External by default — **remove after setup**
- Secure remote management: use VPN to connect to trusted network first, then manage

### Policy Precedence
- Only **one policy** applies per connection — highest precedence match wins
- Auto-Order mode: Firebox sorts automatically, most specific -> most general
- Tiebreaker: **proxy policy beats packet filter** when equally specific
- Manual ordering possible by disabling Auto-Order mode

### Hidden Policies (not visible in policy list, visible in FSM Service Watch)
| Hidden Policy | Priority | What it does |
|--------------|---------|-------------|
| Any From Firebox | Highest | Allows all Firebox-generated traffic (updates, logs, licensing) |
| Unhandled Internal Packet | Lowest | Denies unmatched outgoing connections |
| Unhandled External Packet | Lowest | Denies unmatched incoming connections |
| IPSec | Auto | Allows BOVPN tunnel establishment |

### Policy Checker
- Web UI only (not WSM or CLI)
- Simulates a packet: specify interface, protocol, src/dst IP, src/dst port
- Shows which policy matches and NAT translations applied
- Use for troubleshooting unexpected allow/deny behaviour

### Policy Logging — Two Independent Settings
| Setting | Logs to | When | Use for |
|---------|---------|------|---------|
| Send a log message | Traffic Monitor | Start of connection | Real-time troubleshooting |
| Send a log message for reports | Dimension / WatchGuard Cloud | End of connection | Historical reports, includes duration/bandwidth |

- Denied connections always log regardless
- Allowed connections only log if explicitly enabled
- High-volume allow policies: consider disabling "Send a log message" to reduce CPU/storage load

### Policy Schedules
- Default: Always On
- Custom schedules: select days + hours
- Schedule tiebreaker: **more limited schedule = higher precedence** when policies otherwise identical

### Packet Filter vs Proxy Policy
| | Packet Filter | Proxy / ALG |
|-|--------------|-------------|
| OSI Layer | 3/4 (header only) | 7 (full content) |
| Inspects | src/dst IP, port, protocol | Header + body, attachments, commands, RFC compliance |
| Speed | Fast | Slower |
| Can scan for viruses | No | Yes |
| Can strip attachments | No | Yes |
| Can enforce protocol compliance | No | Yes |

**Use packet filter:** Speed matters, non-HTTP protocols, no content inspection needed  
**Use proxy:** AV scanning, content filtering, HTTPS inspection, protocol compliance

**Supported proxy policies:** DNS, FTP, HTTP, HTTPS, SMTP, POP3, IMAP, SIP (ALG), H323 (ALG), Explicit Proxy, TCP-UDP

**FTP note:** Proxy configured for TCP 21 (control channel); dynamically opens data port automatically — no manual port config needed.

---
*Notes generated from WatchGuard study sessions — Fireware v12.11.2 Study Guide*

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
