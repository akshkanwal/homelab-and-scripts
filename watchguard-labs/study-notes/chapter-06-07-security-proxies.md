# WatchGuard NSE Study Notes — Chapters 6 & 7
**Study Guide:** Network Security Essentials for Locally-Managed Fireboxes  
**Fireware Version:** v12.11.2  
**Date:** June 2026

---

## Chapter 6: Security Services

### All 13 Services — One Line Each
| Service | What it does |
|---------|-------------|
| Gateway AntiVirus | Scans files in email, web, FTP for known viruses |
| IntelligentAV | AI/ML detection of known + unknown malware (no signatures) |
| APT Blocker | Cloud sandbox for zero-day/advanced malware detection |
| IPS | Signature-based detection of exploits in live traffic |
| Application Control | Identifies and controls 1000+ apps by traffic signature |
| WebBlocker | Blocks websites by content category |
| spamBlocker | Identifies and blocks spam and malicious email |
| Botnet Detection | Denies connections to/from known botnet C2 IPs |
| DNSWatch | Blocks DNS queries to known malicious domains |
| Geolocation | Blocks connections to/from specific countries |
| DLP | Prevents confidential data leaving the network |
| Tor Exit Node Blocking | Blocks known Tor exit node IPs (uses RED database) |
| Access Portal | Clientless browser-based VPN for internal/cloud resources |

- File exceptions: use **MD5 hash** — not filename or path
- IntelligentAV = AI model, not signatures; still needs occasional model updates

### Basic vs Total Security Suite
**Basic includes:** App Control, Botnet Detection, Gateway AV, Geolocation, IPS, spamBlocker, Tor Exit Node Blocking, WebBlocker  
**Total adds:** APT Blocker, DLP, DNSWatch, EDR Core, IntelligentAV, Access Portal

### Where Services Run
**Any policy (packet filter or proxy):** App Control, Geolocation, IPS, Tor Exit Node Blocking

**Proxy policies only:**
| Service | Proxy Policies |
|---------|---------------|
| APT Blocker | HTTP, HTTPS, SMTP, POP3, IMAP, FTP |
| DLP | HTTP, HTTPS, SMTP, FTP |
| Gateway AV / IntelligentAV | HTTP, HTTPS, SMTP, POP3, IMAP, FTP, TCP-UDP |
| WebBlocker | HTTP, HTTPS only |

- HTTPS inspection required for full content scanning
- Exceptions (no inspection needed): WebBlocker, Botnet Detection, Geolocation, DNSWatch

### IPS
- Configured **globally** — enabled on all policies by default; disable selectively
- Disable IPS on **WatchGuard Web UI management policy** (WatchGuard recommendation)
- **Full Scan** = most secure, catches evasion, performance hit (recommended)
- **Fast Scan** = better throughput, misses some evasion techniques
- Threat levels: Critical, High, Medium, Low, Information
- Default: drops Critical/High/Medium/Low; logs Information only
- Actions: Allow, Drop, Block (Block = drop + add to Blocked Sites list)
- HTTP blocks show deny page; non-HTTP blocks are silent

### Application Control
- 1800+ signatures identifying 1000+ applications by traffic pattern (not port)
- Can control specific behaviours (e.g. allow Skype voice, block Skype file transfer)
- **Do NOT modify the Global action** — clone it instead
- Creating an action does nothing until attached to a policy
- Needs HTTPS content inspection for encrypted app identification

---

## Chapter 7: Proxies and Proxy-Based Services

### Proxy Policy vs Proxy Action
- **Proxy policy** = traffic match (catches packets)
- **Proxy action** = content ruleset (defines what to do with content)
- Both required — policy does nothing without an action assigned

### Three Proxy Action Types
| Type | Name pattern | Editable | Services enabled |
|------|-------------|---------|-----------------|
| Predefined | `.Standard` suffix | No — clone first | No |
| Default | `Default-` prefix | Yes | Yes (if licensed) |
| Custom | Any name | Yes | As configured |

- For new outgoing HTTP/HTTPS/FTP policies: use **Default-HTTP-Client / Default-HTTPS-Client / Default-FTP-Client**
- Not `HTTP-Client` or `HTTP-Server` — these are obsolete

### AV Scan Pipeline (strict order)
1. **Gateway AntiVirus** — always scans first; AV Scan action must be selected
2. **IntelligentAV** — only if GAV completes clean AND IntelligentAV enabled
3. **APT Blocker** — only if GAV clean AND IntelligentAV (if enabled) clean/suspicious
4. **DLP** — runs after all AV scanning completes

- Gateway AV disabled = IntelligentAV and APT Blocker stop working entirely
- APT Blocker sends MD5 hash first; uploads full file only if unknown
- HTTP/FTP: file passes while waiting for result; IMAP: held; SMTP: configurable
- Results cached locally — same file not re-uploaded

### Gateway AV Actions by Proxy
| Action | Available in |
|--------|-------------|
| Allow | All proxies |
| Drop | All except IMAP, POP3 |
| Block | All except IMAP, POP3 |
| Deny | FTP, SMTP only |
| Lock | SMTP, IMAP, POP3 only |
| Quarantine | SMTP only |
| Remove | SMTP, IMAP, POP3 only |

- Compressed file scan depth: <2GB RAM = 8 levels; >=2GB RAM = 16 levels
- Password-protected archives = **not scannable**, pass through unscanned

### HTTP Proxy
- **HTTP-proxy** = transparent, clients unaware (default)
- **Explicit-proxy** = clients configured to use Firebox as proxy server
- **NEVER** configure Explicit-proxy From: Any-External — creates open proxy

**Proxy action selection:**
- **HTTP-Client.Standard / Default-HTTP-Client** = outbound (users to internet)
- **HTTP-Server.Standard** = inbound (internet to your web server) — blocks upload/delete by default

**HTTP content control categories:**
- URL Paths — match file names or path patterns
- Content Types — match MIME type in header
- Body Content Types — match actual file signature (magic number) — most reliable

### WebBlocker
- Works on HTTPS without content inspection (reads domain from TLS SNI)
- Without inspection: filters root domain only
- With inspection: filters full URL paths
- Actions: **Allow, Deny** (block page), **Warn** (user can continue)
- Uses WebBlocker Cloud by default; on-premises server available

### HTTPS Proxy
- Without content inspection: sees domain, applies WebBlocker, routing actions
- With content inspection (Inspect action): full AV, URL filtering, DLP — Firebox does SSL MITM

**Certificate handling:**
- **HTTPS-Client** proxy action = outbound -> uses **Proxy Authority CA certificate**
- **HTTPS-Server** proxy action = inbound -> uses **web server certificate**
- Getting these backwards causes certificate errors — common exam trap

**Content inspection setup:**
1. Push Firebox Proxy Authority CA cert to all clients (via GPO/MDM)
2. Or: use internal PKI cert as Proxy Authority (clients already trust it)
3. Test with limited clients first — performance impact on smaller Fireboxes

**Domain Name Rule actions:**
- Allow = pass through encrypted
- Inspect = decrypt and run HTTP proxy action
- Deny = block, keep TCP session
- Drop = kill connection
- Block = drop + add to temp Blocked Sites

- Domain rules match wildcard domains only (`*.example.com`)
- **Cannot match URL paths** in domain rules — URL is encrypted
- To match URL paths: use Inspect action + HTTP content action

**TLS Profile:**
- Minimum TLS version — set TLS 1.2 for PCI DSS compliance
- Allow only TLS-compliant traffic = more secure, can break some apps

### Content Actions and Routing Actions
- **Routing Actions** = route inbound HTTPS to specific servers by domain name — no inspection needed
- **Content Actions** = route by URL path — requires Inspect action first (paths are encrypted)
- Use cases: Host Header Redirect, SSL/TLS Offloading

---
*Notes generated from WatchGuard study sessions — Fireware v12.11.2 Study Guide*

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
