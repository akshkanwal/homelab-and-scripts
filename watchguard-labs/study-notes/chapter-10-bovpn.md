# WatchGuard NSE Study Notes — Chapter 10
**Study Guide:** Network Security Essentials for Locally-Managed Fireboxes  
**Fireware Version:** v12.11.2  
**Date:** June 2026

---

## Chapter 10: Branch Office VPN

Branch Office VPN (BOVPN) creates an encrypted, authenticated site-to-site tunnel between two networks. The Firebox can establish an IPSec VPN tunnel to another Firebox or to any third-party IPSec-compliant VPN endpoint. The two tunnel endpoints authenticate each other before exchanging encrypted data. BOVPNs are built on top of the IPSec protocol suite and negotiate security parameters across two distinct phases before traffic can flow.

---

## Part 1: BOVPN Fundamentals, IPSec Algorithms, and VPN Negotiations

### Core Benefits

A BOVPN provides four benefits:
- **Data confidentiality** — traffic is encrypted; only sender and recipient can read it
- **Data integrity** — data cannot be altered in transit
- **Data authentication** — traffic verifiably originates from one of the two VPN endpoints, not an attacker
- **NAT transparency** — computers at both sites communicate using private IPs as if NAT devices were not present

The Firebox examines traffic to/from the networks it protects and uses source/destination IP address plus VPN settings to decide what to encrypt and forward to the remote VPN gateway.

---

### Four BOVPN Types

#### 1. Manual BOVPN
- Manually configured gateway and tunnel routes
- Remote endpoint can be a second Firebox or any third-party device supporting IKEv1 or IKEv2
- Traffic routes through the tunnel when source/destination IP matches a configured tunnel route
- Works with all Fireboxes and most third-party devices (except cloud services)
- Does **not** support dynamic routing or static routes with metrics

#### 2. BOVPN Virtual Interface (VIF)
- Traffic routing decision is based on the outgoing interface, not static tunnel routes
- Can be specified as the gateway endpoint for static routes, dynamic routing, and SD-WAN
- Any internal or external interface can serve as the gateway endpoint
- Works with any third-party device supporting Cisco VTI or GRE over IPSec
- Supports connections to cloud-based endpoints (Microsoft Azure, Amazon AWS)
- Route distance 1–254 assigned per VIF route; lower = higher priority

#### 3. Managed VPN Tunnel
- Created between two Fireboxes centrally managed by a WatchGuard Management Server
- Configured via drag-and-drop in the Management Server UI, using Security Templates and VPN Firewall Policy Templates
- Hub-and-spoke method available for Dimension-managed Fireboxes
- **Cannot** configure a BOVPN Virtual Interface via the Management Server
- Uses the same IKEv1 protocols and Phase 1/Phase 2 negotiation as manual BOVPN

#### 4. BOVPN over TLS
- Sends tunnel traffic over TCP port 443
- Third-party endpoints **not** supported — Firebox-to-Firebox only
- Recommended **only** when the network cannot pass IPSec traffic
- Slowest BOVPN type; not suitable for high-performance or full/partial mesh VPN

Manual BOVPN, BOVPN VIF, and Managed BOVPN tunnels share the same IKEv1 tunnel negotiation procedure. Manual BOVPN and BOVPN VIF also support IKEv2.

---

### Selecting a BOVPN Type

| Scenario | Recommended Type |
|----------|-----------------|
| Firebox to third-party device (no GRE/VTI support) | Manual BOVPN |
| Two Fireboxes, any configuration | Manual BOVPN or BOVPN VIF |
| SD-WAN, dynamic routing, metric-based failover | BOVPN VIF |
| Firebox to cloud (Azure, AWS) | BOVPN VIF |
| Large number of Firebox-to-Firebox tunnels via Management Server | Managed VPN |
| Network blocks IPSec traffic | BOVPN over TLS |

Use BOVPN VIF when you want to **separate routing decisions from the VPN security association** — the Firebox routes by outgoing interface rather than by matching tunnel routes.

---

### VPN Tunnel Capacity

Maximum active tunnels is determined by the device feature key (Setup > Feature Keys).

| Unit | SA Consumption |
|------|---------------|
| One manual BOVPN tunnel route | 1 SA |
| One BOVPN Virtual Interface | 1 SA (regardless of number of tunnel routes inside it) |

The feature key limits the number of active SAs — it does **not** limit the number of tunnel routes that can be configured.

---

### IPSec: Phases and Negotiations

IPSec protects communication between devices over an untrusted network via cryptography-based services and security protocols. Establishing a BOVPN requires two phases:

**Phase 1** — Sets up a secure, authenticated channel between the two VPN gateway devices (between their external interfaces). If Phase 1 fails, Phase 2 cannot begin.

**Phase 2** — Both gateways agree on parameters defining which traffic goes through the tunnel and how to encrypt and authenticate it. This agreement is the **Security Association (SA)**.

Both VPN gateways must use identical Phase 1 and Phase 2 settings. A mismatch on either side causes negotiation to fail.

---

### IKEv1

IKE negotiates security associations for IPSec. IKEv1 operates in two modes for Phase 1:

**Main Mode:**
- Six messages total (three exchanges)
- More secure — validates the IP address and gateway ID of both peers
- Requires both VPN gateways to have **static IP addresses**
- Use when both peers have static IPs

**Aggressive Mode:**
- Three messages
- Faster but less secure — relies on ID types, does not ensure VPN gateway identity
- Known vulnerability: CVE-2002-1623 (makes Aggressive Mode less secure than Main Mode unless certificates are used)
- Required when one peer has a **dynamic IP address**

**Main Fallback to Aggressive:** Firebox attempts Main Mode first; if negotiation fails, falls back to Aggressive Mode.

**IKEv1 message count:** Phase 1 = 6–9 messages (mode-dependent); Phase 2 = 3 messages.

---

### IKEv2

IKEv2 has a single mode and improves upon IKEv1 in several ways:

- Requires only **4 messages** to establish a tunnel
- Better logging when a settings mismatch occurs
- Cryptographic and payload enhancements
- Interoperates with third-party gateways using IKEv2
- **NAT Traversal is always enabled**
- **Dead Peer Detection (DPD) is always enabled**
- DPD can be Traffic-Based or Timer-Based
- Does **not** support IKE Keep-Alive (obsolete)
- Shares Phase 1 transform settings across all BOVPN gateways that have a peer with a dynamic IP

Fireware supports IKEv2 for BOVPN and BOVPN VIF configurations. Fireware does **not** support IKEv2 for Managed BOVPNs.

**Recommendation:** Use IKEv2 — it is the most secure option, supports both static and dynamic endpoints, and requires fewer negotiation messages.

---

### Encryption Algorithms

| Algorithm | Key Length | Security | Notes |
|-----------|-----------|---------|-------|
| AES | 128, 192, 256-bit | Strongest | Recommended |
| AES-GCM | 128, 192, 256-bit | Strongest + best performance | Phase 2 only; combines authentication + encryption |
| 3DES | 168-bit | Moderate | Affected by Sweet32 vulnerability |
| DES | 56-bit | Insecure | Not recommended |

**AES-GCM:** An authenticated encryption algorithm; authentication and encryption occur simultaneously, eliminating a separate hashing step. Recommended for performance-sensitive tunnels.

---

### Authentication Algorithms

| Algorithm | Hash Length | Security |
|-----------|------------|---------|
| SHA2-256 | 256-bit (32 bytes) | Secure |
| SHA2-384 | 384-bit (48 bytes) | Secure |
| SHA2-512 | 512-bit (64 bytes) | Secure |
| SHA-1 | 160-bit (20 bytes) | Mostly insecure |
| MD5 | 128-bit (16 bytes) | Insecure |

SHA-2 is the only secure option. SHA-2 is **not** supported on most XTM series devices (hardware cryptographic acceleration limitation). All T Series and M Series Fireboxes support SHA-2.

---

### Diffie-Hellman Key Exchange

DH allows two VPN gateways to establish a shared encryption key without transmitting the key in plaintext.

| Group Type | Groups | Notes |
|-----------|--------|-------|
| MODP | 1, 2, 5, 14, 15 | Group 14 = minimum considered secure |
| ECC | 19, 20, 21 | Faster AND more secure than MODP |

- Fireware v12.10+ supports DH Group 21
- Higher group number = more secure but more compute-intensive (for MODP)
- ECC groups outperform MODP groups at equivalent security levels

**Recommendation:** Group 14 minimum; Groups 19, 20, or 21 preferred for better security and performance.

**Cited optimal combination:** AES-GCM (128-bit) + DH Group 19

---

### AH vs. ESP

| Protocol | RFC | Authentication | Encryption | Recommended |
|----------|-----|---------------|-----------|------------|
| AH (Authentication Header) | 2402 | Yes | No | No |
| ESP (Encapsulating Security Payload) | 2406 | Yes | Yes | Yes |

ESP replaces the original packet payload with encrypted data and adds integrity checks. AH only adds authentication — it does not encrypt. WatchGuard recommends ESP in nearly all cases.

Managed BOVPNs, Mobile VPN with IKEv2, Mobile VPN with IPSec, and Mobile VPN with L2TP always use ESP — the Type setting is not selectable for these configurations.

---

### Phase 1 Negotiation Steps

1. Devices agree on the IKE version (must match on both endpoints)
2. Devices exchange credentials — certificate or pre-shared key (must match and use the same credential method)
3. Devices identify each other using Phase 1 identifiers (IP address, domain name, domain information, or X500 name); both sides must have matching configurations
4. *(IKEv1 only)* Gateways agree on Main Mode or Aggressive Mode; initiating gateway sends a proposal; the other can reject if not configured for that mode
5. Gateways agree on Phase 1 settings: NAT Traversal, IKE Keep-Alive *(IKEv1 only — obsolete, DPD preferred)*, Dead Peer Detection
6. Gateways agree on **Phase 1 Transform settings** — must exactly match on both peers:
   - Authentication algorithm
   - Encryption algorithm
   - SA Life (expiry time for the Phase 1 SA)
   - Diffie-Hellman Key Group

If the Phase 1 SA expires before Phase 2 negotiations complete, Phase 1 must restart.

---

### Phase 2 Negotiation Steps

1. Gateways use the Phase 1 SA to secure Phase 2, and agree on whether to use **Perfect Forward Secrecy (PFS)**:
   - PFS forces an independent DH calculation so Phase 2 keys are mathematically unrelated to Phase 1 keys
   - Must be enabled on both gateways, using the same DH group
   - Effectiveness is weakened if DH group < 14

2. Gateways agree on a **Phase 2 Proposal**:

   | Setting | Options | Notes |
   |---------|---------|-------|
   | Type | AH or ESP | Manual BOVPN only; Managed/Mobile VPN always use ESP |
   | Authentication | SHA-1, SHA-2, MD5 | SHA-2 only secure option |
   | Encryption | DES, 3DES, AES, AES-GCM | AES/AES-GCM only secure options; AES-GCM Phase 2 only |
   | Force Key Expiration | Time interval | Default: 8 hours; avoid "Traffic" option |

   **Force Key Expiration — avoid the Traffic option:** causes high Firebox load, throughput issues, packet loss, and frequent outages; incompatible with most third-party devices.

3. Gateways exchange **Phase 2 traffic selectors (tunnel routes)** — always sent as matched local/remote pairs specifying which IP addresses (host, network, or range) can send traffic over the VPN.

---

### IKEv1 vs. IKEv2 Comparison

| Phase 1 Setting | IKEv1 | IKEv2 |
|----------------|-------|-------|
| Modes | Main or Aggressive | Single mode |
| Message count (tunnel setup) | 6–9 | 4 |
| NAT Traversal | Configurable | Always enabled |
| IKE Keep-Alive | Supported (obsolete) | Not supported |
| Dead Peer Detection (DPD) | Configurable; always traffic-based | Always enabled; traffic-based or timer-based |
| Shared Phase 1 settings for dynamic peers | No | Yes |

**DPD modes:**
- **Traffic-Based** (default, recommended) — sends a DPD probe only if no traffic has been received from the remote peer for a specified interval AND a packet is queued to send. More efficient and scales better.
- **Timer-Based** — sends a DPD probe at a fixed interval regardless of traffic activity.

---

### Policies and VPN Traffic

Fireware allows traffic through a BOVPN only if a matching policy permits it.

**Auto-generated policies:** When a BOVPN tunnel is added, Policy Manager automatically creates two "Any" policies allowing all traffic through the tunnel. To prevent this, uncheck **"Add this tunnel to the BOVPN-Allow policies"** in the tunnel configuration.

**BOVPN Policy Wizard:** Available in **Policy Manager only** (not Fireware Web UI). Creates a matched pair of VPN policies (inbound + outbound) for the selected traffic type. Can also create aliases identifying selected BOVPNs. Run via VPN > Create BOVPN Policy.

**Manual policy creation:** Policies can be written targeting BOVPN traffic using:
- Remote VPN network addresses as From/To values
- BOVPN virtual interface names
- Tunnel addresses (Add > Add Other > Choose Type > Tunnel Address → select tunnel name from dropdown)

---

## Part 1 Exam Fact Dump

- BOVPN = site-to-site tunnel; fourth unique benefit vs. Mobile VPN = NAT-transparent private-to-private IP communication
- Four BOVPN types: Manual BOVPN, BOVPN VIF, Managed VPN Tunnel, BOVPN over TLS
- Manual BOVPN does **not** support dynamic routing or static routes with metrics
- BOVPN VIF supports: Cisco VTI, GRE over IPSec, cloud endpoints (Azure/AWS), dynamic routing, SD-WAN, metric-based failover
- Management Server **cannot** configure a BOVPN Virtual Interface
- BOVPN over TLS: port 443, Firebox-to-Firebox only, slowest type — use only when IPSec is blocked and full mesh is not required
- Feature key limits active SAs: 1 tunnel route = 1 SA; 1 BOVPN VIF = 1 SA regardless of how many tunnel routes are inside it
- Feature key does **not** limit number of configured tunnel routes
- IKEv1 Main Mode: 6 messages, static IP required on both sides, validates IP + gateway ID of both peers
- IKEv1 Aggressive Mode: 3 messages, works with dynamic IPs, vulnerable per CVE-2002-1623 unless certificate-based
- Default: Firebox attempts Main Mode first, falls back to Aggressive Mode on failure
- IKEv2: single mode, 4 messages, NAT-T and DPD always on, no Keep-Alive support, shared Phase 1 settings for dynamic-IP gateways
- Fireware supports IKEv2 for BOVPN and BOVPN VIF — **not** for Managed BOVPNs
- Encryption: AES/AES-GCM (secure) > 3DES (Sweet32 vulnerability) > DES (insecure)
- AES-GCM = Phase 2 only; combines encryption + authentication in one operation = best performance
- Authentication: SHA-2 only secure option; SHA-1 = mostly insecure; MD5 = insecure
- SHA-2 not supported on most XTM series (hardware limitation); fully supported on T Series and M Series
- DH Group 14 = minimum considered secure (MODP); Groups 19/20/21 (ECC) = faster AND more secure than MODP
- Fireware v12.10+ supports DH Group 21
- AH = authentication only, no encryption; ESP = authentication + encryption; WatchGuard recommends ESP
- Cited optimal combination: AES-GCM (128-bit) + DH Group 19
- Auto-generated "Any" policies created per tunnel by default — disable via checkbox if unwanted
- BOVPN Policy Wizard: Policy Manager only (not available in Fireware Web UI)
- Phase 1 SA must complete before Phase 2 starts; if Phase 1 SA expires mid-negotiation, Phase 1 restarts
- Phase 1 Transform settings (Authentication, Encryption, SA Life, Key Group) must match exactly on both peers
- PFS forces an independent DH calculation for Phase 2 — Phase 2 keys mathematically unrelated to Phase 1 keys
- PFS effectiveness weakened if DH group < 14
- Force Key Expiration default = 8 hours; avoid "Traffic" option — causes load spikes, packet loss, outages, and incompatibility with most third-party devices
- Phase 2 traffic selectors = tunnel routes — always exchanged as matched local/remote pairs
- Managed BOVPNs and all Mobile VPN types always use ESP (Type field not configurable for these)

---

## Part 1 Check Yourself

1. Why can't Main Mode be used when one VPN peer has a dynamic IP address, and what is the alternative?
2. What specifically does Perfect Forward Secrecy protect against, and what weakens its effectiveness even when it is enabled?
3. A BOVPN Virtual Interface has 12 tunnel routes configured inside it. How many SAs does this consume against the feature key limit, and how does this differ from a Manual BOVPN with 12 tunnel routes?
4. Why does WatchGuard recommend against the "Traffic" option for Force Key Expiration, despite it appearing to be an adaptive setting?
5. What is the practical difference between what AH and ESP each protect, and why does WatchGuard recommend ESP in nearly all cases?

---

## Part 2: Configuration, NAT, and Dynamic IP Handling

*(Coming soon — to be added in a future session)*

---

## Part 3: Topologies and Troubleshooting

*(Coming soon — to be added in a future session)*

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
