# WatchGuard NSE Study Notes — Chapter 9
**Study Guide:** Network Security Essentials for Locally-Managed Fireboxes  
**Fireware Version:** v12.11.2  
**Date:** June 2026

---

## Chapter 9: Mobile VPN

### Core Concept

Mobile VPN enables trusted remote users to connect and authenticate to internal network resources from an external network via an encrypted tunnel. Four benefits: data privacy/confidentiality (encryption), data integrity (data not altered in transit), data authentication (traffic verifiably originates from a real VPN endpoint), and direct communication between private addresses despite NAT.

---

### Four Mobile VPN Types

| Type | Notes |
|------|-------|
| Mobile VPN with IKEv2 | Recommended for most cases |
| Mobile VPN with SSL | Recommended when IPSec is blocked on the remote network |
| Mobile VPN with L2TP | Supported; no split tunnel configuration via Firebox |
| Mobile VPN with IPSec | Uses IKEv1 Aggressive Mode — known vulnerability; WatchGuard recommends alternatives |

All four types can be configured and used simultaneously on one Firebox. Clients can be configured to use one or more types.

---

### Selecting a Mobile VPN Type — Four Factors

#### 1. Encryption Support
AES is the most secure algorithm and is supported by all VPN types. Larger key size = more secure.

#### 2. Authentication Server Compatibility

| Mobile VPN | AuthPoint | Active Directory | LDAP | RADIUS | SecurID | SAML | Firebox-DB |
|------------|-----------|-----------------|------|--------|---------|------|------------|
| IKEv2 | Yes | Via RADIUS only | No | Yes | No | No | Yes |
| L2TP | Yes | Via RADIUS only | No | Yes | No | No | Yes |
| SSL | Yes | Yes (direct) | Yes | Yes | Yes | Yes | Yes |

**Key point:** Active Directory authentication for IKEv2 and L2TP is supported only through a RADIUS server — there is no direct AD integration for these two VPN types.

#### 3. VPN Tunnel Capacity

Maximum simultaneous mobile VPN connections is set by the device feature key.

| Feature Key Value | Shared Pool |
|-------------------|-------------|
| IPSec VPN Users | Mobile VPN with IKEv2 + Mobile VPN with IPSec (combined) |
| SSL VPN Users | Mobile VPN with SSL + BOVPN over TLS (combined) |

Example: a feature key allowing 250 total IPSec connections, with 200 IKEv2 users connected, leaves only 50 slots for IPSec — they draw from the same pool.

#### 4. Client OS Support

| VPN Type | Windows | macOS | Android | iOS |
|----------|---------|-------|---------|-----|
| L2TP | Native client (manual config) or RFC 2661-compliant client | Same | Manual native config | Manual native config |
| SSL | Auth to Firebox to download client/config; requires TLS 1.1+ | Same | Requires OpenVPN client; can download config from Firebox | OpenVPN client |
| IKEv2 | .bat script auto-configures native client (Windows 7: manual only); WatchGuard IPSec client via profile import | .mobileconfig profile auto-configures native client | strongSwan app + .sswan file | .mobileconfig profile auto-configures native client |

---

### Mobile VPN with IKEv2 (Recommended)

**Security:** Certificates only — no pre-shared key option. Authentication via EAP and MS-CHAPv2. Supports Firebox-DB, RADIUS, and AuthPoint.

**Performance:** Outperforms Mobile VPN with L2TP and Mobile VPN with SSL.

**MOBIKE:** Mobility protocol that maintains the VPN tunnel when the remote device changes networks (e.g., WiFi to cellular).

**Required ports:** ESP + UDP 500; UDP 500 and 4500 for NAT-T

**Encryption:**
- DES/3DES: 56-bit and 168-bit
- AES: 128/192/256-bit
- AES-GCM: 128/192/256-bit

**Authentication algorithms:** MD5, SHA-1, SHA2-256, SHA2-384, SHA2-512

---

### Mobile VPN with SSL

**Use when:** IKEv2/IPSec traffic is blocked on the remote network.

**Default port:** TCP 443 — portable to most environments allowing outbound HTTPS.

**Two configurable channels:**
- **Data channel:** carries tunnel traffic after connection is established. If changed from port 443, users must specify the port manually in the client (e.g., `203.0.113.2:444`)
- **Configuration channel:** where users download the SSL client software (e.g., `https://203.0.113.2/sslvpn.html`). If data channel is TCP, config channel auto-uses the same port/protocol. If data channel is UDP, config channel can use a different port.

**v12.11 change:** The Mobile VPN with SSL client download page is removed from the Firebox UI. The .ovpn configuration file is accessed via VPN > Mobile VPN on the Firebox, or by browsing to `https://[external IP]/sslvpn.html`.

**Failure scenarios (despite being the most portable type):**
- Network device performing HTTPS content inspection breaks the tunnel
- "Allow only TLS-compliant traffic" enabled on the Firebox breaks it
- Application Control blocking OpenVPN software breaks it (SSL VPN is built on OpenVPN)

**Security:** Less secure than IPSec-based types — does not support multi-layer encryption. An attacker needs only the Firebox IP and valid credentials to attempt a connection.

**Performance:** Slowest of the mobile VPN types. Improved by selecting UDP for the data channel and using AES-GCM ciphers.

**Authentication:** Compatible with all authentication server types (the only mobile VPN type with full compatibility).

**Encryption:**
- AES and AES-GCM (recommended): 128/192/256-bit
- 3DES: 168-bit

**Authentication algorithms:** SHA-1, SHA-256, SHA-512

---

### Setup — Wizard vs. Manual Configuration

WatchGuard recommends the Setup Wizard for each mobile VPN type. The wizard configures:
- Domain name or IP address (what users specify in their VPN client)
- IP address pool (assigned to connecting users; must not overlap with other networks)
- Authentication servers (from servers already configured on the Firebox)
- Users and groups

**Default group names:** IKEv2-Users, L2TP-Users, SSLVPN-Users

**Group requirements by auth server type:**
- RADIUS, LDAP, AD: group must be manually created on the authentication server, with VPN users added to it
- RADIUS/SecurID: the server must return a `Filter-Id` attribute whose value matches the group name on the Firebox

**Non-default groups:**
- Must exist on the auth server with exact spelling and capitalization (case-sensitive)
- Select the specific auth server the group exists on, or Any if it exists on multiple
- Non-default group names do not appear in the Firebox's group list, but mobile VPN policy still applies

---

### Full Tunnel vs. Split Tunnel

| Mode | Traffic Routing | Security | Performance |
|------|----------------|----------|-------------|
| Full tunnel (default route) | All traffic routes through VPN and Firebox | Higher — Firebox policies apply to all traffic | Lower |
| Split tunnel | Only traffic to specified resources routes through VPN | Lower — Firebox policies don't apply to bypassed traffic | Higher |

- **IKEv2 and SSL:** both support split tunnel configuration via Firebox UI
- **L2TP:** the Firebox does NOT support split tunnel configuration — must be manually configured on the client (manual route additions); WatchGuard does not provide support for L2TP split tunnel configurations

**Full tunnel note (Windows IKEv2):** manually configuring the native IKEv2 client in Windows 10 may require enabling "Use default gateway on remote network" in IPv4 adapter properties to achieve full tunnel behavior.

---

### Default Authentication and Encryption Settings

| Setting | Default |
|---------|---------|
| Authentication | SHA256 |
| Encryption | AES256 |
| Diffie-Hellman group | 14 (does not apply to Mobile VPN with SSL) |

Settings on the Firebox must match settings on the VPN client.

---

### DNS Configuration Options

| Option | Behavior |
|--------|---------|
| Assign Network (global) DNS/WINS settings | Uses global settings from Network > Interfaces > DNS/WINS. Default for new VPN configs |
| Do not assign DNS/WINS | Client configures its own DNS/WINS settings |
| Assign these settings | VPN-specific DNS/WINS configured directly in the mobile VPN config |

- **L2TP:** DNS servers only
- **IKEv2:** DNS servers, WINS servers, domain name suffix (Fireware v12.9.2+)
- **SSL:** DNS servers, WINS servers, domain name suffix

---

### Auto-Generated Policies

**IKEv2:**
| Policy | Purpose |
|--------|---------|
| Allow-IKE-to-Firebox | Hidden IPSec policy — allows VPN connections to terminate on the Firebox |
| Allow IKEv2 Users | Any policy granting configured IKEv2 users/groups access to network resources |

**SSL:**
| Policy | Purpose |
|--------|---------|
| WatchGuard SSLVPN | SSLVPN policy allowing connections from SSL VPN clients on the configured port/protocol |
| Allow SSLVPN Users | Any policy granting configured SSL users/groups access to network resources |

To restrict VPN user traffic by port/protocol, disable or delete the default "Allow ... Users Any" policy and replace with custom, more restrictive policies.

---

### Client Configuration Files — IKEv2

After configuration is saved to the Firebox, a .TGZ archive can be downloaded containing:
- `WG_IKEv2.mobileconfig` — macOS and iOS
- `WG_IKEv2.bat` — Windows (auto-configures native IKEv2 client)
- `WG_IKEv2.sswan` — Android (imported into strongSwan)
- `<profile>.ini` — WatchGuard IPSec Mobile VPN client
- `<profile>.crt` and `<profile>.pem` — certificates
- `README.txt` — per-OS instructions

**Windows deployment at scale:** Group Policy can push the .bat script at domain logon — zero-touch deployment, avoids user misconfiguration, auto-updates config at login. Windows 7: automatic script unsupported; manual native client configuration required.

---

### Client Configuration Files — SSL

The SSL client configuration file is automatically created and saved on the Firebox; clients retrieve it automatically on each connection. Users with the open-source OpenVPN client can also download a .ovpn profile.

**Download URL:** `https://[external interface IP]/sslvpn.html`

**Available downloads:** Windows SSL client, macOS SSL client, .ovpn profile (compatible with any SSL VPN client supporting .ovpn files).

---

### Virtual IP Address Pool

A pool of virtual IPs is defined when mobile VPN is configured. The Firebox assigns one address per connecting user. Addresses return to the pool when a session closes.

**Guidelines:**
- Use a private IP range not used elsewhere on the network
- Pool does not need to share a subnet with the trusted network
- **Exception:** if Mobile VPN with SSL is bridged to a bridge interface, virtual IPs must share the bridge interface subnet. In this bridge scenario with split tunneling, only the bridge subnet is reachable — other internal networks are not accessible. Recommended only for legacy software requiring single-subnet operation
- Pool size should match the maximum supported concurrent VPN connections; extra addresses beyond the Firebox maximum are unused

---

## Exam Fact Dump — Chapter 9

- Mobile VPN with IPSec (IKEv1 Aggressive Mode) has a known vulnerability — avoid; not covered in this guide
- AD authentication for IKEv2 and L2TP works only through RADIUS — no direct AD integration for these two types
- SSL VPN is the only mobile VPN type compatible with all authentication server types (including direct AD, LDAP, SAML)
- IPSec VPN Users feature key value = shared pool: IKEv2 + IPSec
- SSL VPN Users feature key value = shared pool: SSL VPN + BOVPN over TLS
- IKEv2 uses certificates only (no pre-shared key); EAP + MS-CHAPv2 for authentication
- IKEv2 supports MOBIKE — maintains tunnel across network changes (WiFi to cellular)
- IKEv2 required ports: ESP + UDP 500; UDP 500/4500 for NAT-T
- SSL VPN default port: TCP 443; built on OpenVPN — Application Control blocking OpenVPN breaks it
- SSL VPN client download page removed from Firebox UI in v12.11+; .ovpn accessed via VPN > Mobile VPN
- SSL VPN can fail due to: HTTPS content inspection, "Allow only TLS-compliant traffic," or App Control blocking OpenVPN
- Only IKEv2 and SSL support split tunnel via Firebox UI; L2TP split tunnel = manual client-side config, no WatchGuard support
- Full tunnel (default route) is the default for all mobile VPN types
- Default group names: IKEv2-Users, L2TP-Users, SSLVPN-Users
- Non-default group/user names must match exact spelling and capitalization on the auth server
- Auto-generated policies — IKEv2: Allow-IKE-to-Firebox (hidden) + Allow IKEv2 Users; SSL: WatchGuard SSLVPN + Allow SSLVPN Users
- Default settings: Authentication = SHA256, Encryption = AES256, DH group = 14 (DH group does not apply to SSL VPN)
- Virtual IP pool does not need to match the trusted subnet — exception: SSL VPN bridged to a bridge interface requires the same subnet
- Windows 7 + IKEv2: .bat auto-configuration script is unsupported — manual native client configuration required

---

## Check Yourself — Chapter 9

1. A remote user needs to connect from a network that blocks all non-standard ports and performs no HTTPS inspection. Which mobile VPN type is most likely to succeed, and why?
2. Why can't Active Directory be used as a direct authentication server for Mobile VPN with IKEv2, and what is the workaround?
3. What is the practical difference between the IPSec VPN Users and SSL VPN Users values in a Firebox feature key?
4. Why would Mobile VPN with SSL fail on a network that performs HTTPS content inspection, even though SSL VPN traffic looks like normal HTTPS?
5. Under what specific circumstance must the virtual IP address pool share a subnet with an internal network, and what limitation does that configuration introduce?

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
