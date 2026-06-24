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

### Gateway Configuration

A BOVPN gateway defines the two VPN endpoints and Phase 1 settings. Configuration is symmetric — Site B mirrors Site A with local/remote roles reversed.

**Gateway general settings:**
- **Address family** — IPv4 or IPv6; all addresses in gateway and tunnel settings must use the same family
- **Credential method** — pre-shared key or IPSec Firebox certificate

**Example topology:**

| | Site A | Site B |
|-|--------|--------|
| External IP | `203.0.113.10` | `192.0.2.20` |
| Trusted network | `10.0.10.0/24` | `10.0.20.0/24` |

**Gateway endpoint settings (Site A):**
- Local Gateway IP / ID: `203.0.113.10`
- Remote Gateway IP / ID: `192.0.2.20`

**Dynamic remote endpoints:** if the remote device uses a dynamic IP with dynamic DNS, specify the FQDN. If not using dynamic DNS, any non-resolvable domain string can be used if the remote device is the initiator. Dynamic endpoints require IKEv1 Aggressive Mode or IKEv2 (IKEv2 recommended).

**Recommended Phase 1 settings:**
- Version: IKEv2 (establishes and rebuilds tunnels faster than IKEv1)
- Transform: SHA2-256-AES (256-bit)

**Important:** Strong Phase 1 encryption does **not** affect BOVPN file transfer speed — Phase 1 encryption only protects the control channel, not the data path. There is no performance justification for weakening Phase 1.

**Phase 1 Settings tab includes:**
- IKE version
- NAT Traversal (keep-alive interval default: 20 seconds)
- Dead Peer Detection / RFC 3706 (type: Traffic-Based; idle timeout default: 20 seconds; max retries default: 5)
- Transform settings list — ordered by preference, high to low (e.g., SHA2-256-AES (256-bit), DH Group 14)

---

### Tunnel Configuration

After adding a gateway, configure one or more BOVPN tunnels against it.

**Tunnel settings:**
- **Gateway** — an already-configured BOVPN gateway on this Firebox
- **Tunnel Routes** — local and remote IP addresses (must match the gateway's address family)
- **Phase 2** — PFS, DH group, and IPSec proposals

Default Phase 2 values: PFS enabled, DH Group 14, proposal ESP-AES256-SHA256.

**Site A example tunnel route:** Local `10.0.10.0/24`, Remote `10.0.20.0/24`  
**Site B example tunnel route:** Local `10.0.20.0/24`, Remote `10.0.10.0/24`

The **"Add this tunnel to the BOVPN-Allow policies"** checkbox controls whether the Firebox auto-creates two Any policies for this tunnel (see Part 1).

**Zero Route:** All traffic (including internet-bound) can be forced through the BOVPN to the main location. Also simplifies tunnel switching in hub-and-spoke deployments.

---

### BOVPN Failover

BOVPN failover provides redundancy between two Fireboxes. **Not supported for third-party endpoints.**

**Failover triggers (two independent detection mechanisms):**
- **Link Monitor** — detects physical or logical link failure
- **Dead Peer Detection (DPD)** — detects inactive VPN peer

Keep DPD enabled. Without DPD, the Firebox cannot detect an inactive peer and continues sending traffic into a dead tunnel.

**Requirements:**
- Local Firebox must have at least two external interfaces
- Link Monitor targets must be configured on those external interfaces (use a target other than the default gateway)
- On the remote Firebox, a second gateway endpoint must be added for the backup local external interface

**Redundancy levels:**

| Type | Description |
|------|-------------|
| Partial | Only one Firebox has redundant external interfaces and gateway endpoints |
| Full | Both Fireboxes have redundant external interfaces and gateway endpoints |

**Full redundancy — gateway endpoint ordering:**  
With two external interfaces on each side, all combinations of local/remote interface pairs are configured as separate gateway endpoints (e.g., A-Ext1↔B-Ext1, A-Ext1↔B-Ext2, A-Ext2↔B-Ext1, A-Ext2↔B-Ext2). These endpoint pairs must be listed in **identical order** in the Gateway Endpoints list on both Fireboxes.

---

### BOVPN Virtual Interface Configuration

A BOVPN VIF can be configured between two Fireboxes or between a Firebox and a compatible third-party endpoint. If one side uses a BOVPN VIF, **the remote gateway must also be configured as a BOVPN VIF**. Failover is not supported for third-party endpoints.

Configuring a BOVPN VIF adds a logical (not physical) interface to the Firebox. It supports advanced routing: metric-based failover, dynamic routing, and routing of replies to Firebox-generated traffic (DNS, DHCP, Dimension, syslog, SNMP, NTP, authentication server queries) through the VPN tunnel.

**Key configuration difference vs. Manual BOVPN:**

| | Manual BOVPN | BOVPN VIF |
|-|-------------|-----------|
| Routing decision | Source/dest IP matches an explicit tunnel route | Routing table: packet goes through VIF if VIF has the lowest-distance route to the destination |
| Static routes | Separate IPSec routing table | Appear in the Firebox's normal static routes list |
| Route distance | Not applicable | 1–254; lower = higher priority |
| Dynamic routing | Not supported | Supported (OSPF, BGP) |

For each BOVPN VIF, static routes are configured on the **VPN Routes** tab specifying a destination and a metric (route distance).

---

### BOVPN VIF Use Cases

#### Metric-Based Failover

Routes with a lower distance have higher priority. To make a BOVPN VIF a secondary/backup path (e.g., behind an MPLS leased line), assign it a higher distance number than the primary route.

When the primary route (MPLS) becomes unavailable, its route is removed from the routing table or assigned a distance higher than the VIF route. The Firebox automatically switches to the VIF route. When the primary recovers, the Firebox automatically fails back because the primary route again has a lower distance.

#### Dynamic Routing (OSPF / BGP)

With a BOVPN VIF, dynamic routing protocols (OSPF or BGP) can be enabled between two sites over a secure VPN. This eliminates the need to manually maintain explicit static routes between all private networks at each site.

Virtual IP addresses are configured on the VPN Routes tab — these must not overlap with any other physical or BOVPN network. Dynamic routing configuration specifies these virtual IPs as peer addresses and defines which local networks each device propagates.

---

### BOVPN and NAT

NAT can be applied to BOVPN tunnel routes when sites have overlapping or conflicting private IP address ranges.

**WatchGuard recommendation:** Do **not** default to 1-to-1 NAT to resolve overlapping subnet issues. Preferred solution: re-address one site so ranges do not overlap (Secondary Networks can assist with this). 1-to-1 NAT introduces scalability and management challenges. Use 1-to-1 NAT only when you do not control the remote site and cannot change its addressing.

#### 1-to-1 NAT over BOVPN

Translates an entire address range to a different range, in both directions. Used to hide true subnet addresses from the remote peer, or to resolve overlapping subnets when re-addressing is not possible.

**Example — both sites use `10.0.200.0/24`:**

| Site | Local subnet | Remote (as seen in tunnel config) | 1:1 NAT address |
|------|-------------|----------------------------------|-----------------|
| Site A | `10.0.200.0/24` | `192.168.150.0/24` | `192.168.200.0/24` (rewrites Site A's subnet) |
| Site B | `10.0.200.0/24` | `192.168.200.0/24` | `192.168.150.0/24` (rewrites Site B's subnet) |

Direction: Bi-directional on both sides.

The Firebox rewrites only the octets covered by the subnet mask — for a `/24`, only the first three octets are rewritten; the host portion (last octet) is preserved. Example: `10.0.200.7` at Site B is rewritten to `192.168.150.7` before entering the tunnel.

#### Dynamic NAT (DNAT) over BOVPN

Masquerades an entire local subnet as a single host IP address. Only works on **uni-directional** tunnels.

**Typical use case:** connecting to a remote network you do not control, where the remote admin requires your traffic to appear as a single IP (e.g., they restrict multiple private subnets, or need single-IP usage tracking).

**Example:** local network `10.0.1.0/24`, remote network `10.0.200.0/24`, masquerade local as `5.5.5.5`.  
Tunnel route config: Local `10.0.1.0/24`, Remote `10.0.200.0/24`, Direction: Local to Remote, DNAT: `5.5.5.5`.

---

### BOVPN with Dynamic Public IP Addresses

When one or both BOVPN gateway endpoints have dynamic public IPs, the IP may change and break the tunnel. The static-IP side cannot proactively reconnect — the **dynamic-IP side must initiate the tunnel**.

**Two methods for identifying a dynamic endpoint:**

#### FQDN with Dynamic DNS
If the dynamic-IP site uses a dynamic DNS service, configure the FQDN as the remote gateway ID on the static side. The dynamic DNS service keeps the domain's IP record current.  
Config: Gateway ID type = Domain Name, value = `test.example.com`, "Attempt to Resolve" = checked.

#### Text String (no dynamic DNS)
If no dynamic DNS is available, use an arbitrary text string as the gateway ID. The string must be **identical** on both sides, and must not be a resolvable domain name.  
Config: Gateway ID type = By Domain Information, value = `testID`, "Attempt to Resolve" = **unchecked**.

The static-IP side specifies the dynamic side's current known IP as the remote gateway address. The dynamic-IP site must initiate all tunnel connections.

---

## Part 2 Exam Fact Dump

- Phase 1 encryption strength does **not** affect BOVPN file transfer speed — only Phase 2 settings impact throughput; no performance justification for weakening Phase 1
- Default Phase 1 transform example: SHA2-256-AES (256-bit); default Phase 2 proposal: ESP-AES256-SHA256, PFS enabled, DH Group 14
- Site B config must exactly mirror Site A with local/remote gateway IPs and tunnel addresses reversed
- BOVPN failover requires: 2+ external interfaces, Link Monitor on those interfaces, and a second gateway endpoint on the remote Firebox for the backup interface
- Keep DPD enabled — without it, the Firebox cannot detect an inactive peer and continues sending traffic into a dead tunnel
- Failover uses two distinct mechanisms: **Link Monitor** (link failure) and **DPD** (peer failure)
- Partial redundancy = one side has backup; full redundancy = both sides have backup
- Full redundancy: gateway endpoint pairs must be listed in the **identical order** on both Fireboxes
- BOVPN failover is **not** supported for third-party endpoints
- Manual BOVPN uses a separate IPSec routing table; BOVPN VIF static routes appear in the Firebox's normal static routes list
- VIF routing decision = route distance in the routing table (not explicit tunnel-route address matching); lower distance = higher priority
- VIF supports metric-based failover and dynamic routing (OSPF/BGP); Manual BOVPN supports neither
- If one side uses BOVPN VIF, the remote gateway must also be configured as a BOVPN VIF
- VIF virtual IP addresses (for dynamic routing) must not overlap with any physical or BOVPN network
- WatchGuard does **not** recommend 1-to-1 NAT as the default fix for overlapping subnets — re-addressing is preferred; NAT introduces scalability/management challenges
- 1-to-1 NAT over BOVPN is bidirectional; only rewrites octets covered by the subnet mask (e.g., /24 = first three octets, host portion unchanged)
- DNAT over BOVPN is uni-directional only; masquerades an entire subnet as a single host IP
- DNAT typical use case: connecting to a remote network you don't control where the admin requires single-IP visibility
- For dynamic public IPs: use FQDN + dynamic DNS if available; use a matching arbitrary text string (with "Attempt to Resolve" unchecked) if dynamic DNS is not available
- The dynamic-IP site must initiate the tunnel — the static-IP side cannot proactively reach a moving target

---

## Part 2 Check Yourself

1. Why doesn't strengthening Phase 1 encryption hurt BOVPN performance, while strengthening Phase 2 settings does?
2. A full-redundancy BOVPN failover setup is correctly configured on Site A but the Gateway Endpoints list is in a different order on Site B. What happens, and why?
3. What is the core mechanical difference in how a Manual BOVPN and a BOVPN Virtual Interface each decide whether a packet should be sent through the tunnel?
4. Two sites both use `10.0.200.0/24` internally and need a BOVPN, but you don't control the remote site. What is the recommended fix, and what is the fallback if re-addressing is not possible?
5. Site B has a dynamic public IP and no dynamic DNS service. What two configuration requirements must be met for the tunnel to work reliably, and which side must initiate the connection?

---

## Part 3: Topologies and Troubleshooting

*(Coming soon — to be added in a future session)*

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
