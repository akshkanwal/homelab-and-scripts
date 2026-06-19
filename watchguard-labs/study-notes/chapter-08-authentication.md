# WatchGuard NSE Study Notes — Chapter 8
**Study Guide:** Network Security Essentials for Locally-Managed Fireboxes  
**Fireware Version:** v12.11.2  
**Date:** June 2026

---

## Chapter 8: Authentication

### Core Concept

By default the Firebox identifies traffic by IP address, not by user identity. Authentication binds a username to an IP address so that policies can target users/groups, logs show usernames instead of IPs, and access can be controlled per-identity rather than per-IP. Critical in DHCP environments where IPs change, and when users must be identified before accessing external or other internal networks.

---

### Three Authentication Server Types

#### 1. Firebox-DB (Local)
- Firebox maintains a local user database; acts as its own authentication server
- Best for organizations without third-party authentication infrastructure
- Admin must create/manage all accounts; no user self-service for password changes or resets
- WatchGuard recommends a third-party server for networks with many users
- Passwords stored as NT hash in config; AES key-wrapped if config exported to cleartext
- Passphrase length: configurable minimum 8–32 characters; maximum is 32 characters (hard limit, cannot be changed)

#### 2. AuthPoint
- WatchGuard's cloud-based MFA service
- Disabled by default on the Firebox
- Activated by adding a Firebox "resource" in AuthPoint (resources = applications/services users authenticate to)
- Once a Firebox resource is added in AuthPoint, AuthPoint is automatically enabled as an auth server on the Firebox
- Supports MFA for: Mobile VPN with SSL, Mobile VPN with IKEv2, Firebox Web UI, Firebox Authentication Portal

#### 3. Third-Party Servers
- Supported types: Active Directory, LDAP, RADIUS, SAML, SecurID
- **SecurID has no separate tab** — it is enabled as an option inside the RADIUS server configuration
- Multiple servers of the same type can be configured (e.g., multiple AD or RADIUS servers), each with an optional backup

---

### Authentication Portal

The Firebox runs a dedicated HTTPS authentication server accessible at:

```
https://[Firebox interface IP]:4100
```

Typically bound to a trusted or optional interface. Can be placed on an external interface (to require authentication for inbound connections like RDP/SSH), but WatchGuard recommends against exposing the login page to the internet — use a VPN instead.

**Authentication sequence:**
1. User navigates to the portal URL
2. Enters username and password
3. Credentials sent to the selected auth server using PAP (unencrypted transport; password is hashed)
4. Auth server approves → user granted access to permitted resources
5. Browser window can be closed after authentication

Session remains active until timeout expires or until the user clicks Logout. If the browser window was closed, the user must reopen it to log out early.

Automatic redirect to the portal (before internet access is granted) can be configured — applies to HTTP and HTTPS connections only.

---

### WatchGuard Authentication Policy (Auto-Generated)

The first time a user or group is added to the **From** field of any policy, the Firebox automatically creates a policy named **WatchGuard Authentication**:

| Field | Value |
|-------|-------|
| From | Any-Trusted, Any-Optional |
| To | Firebox |

This policy allows traffic to reach the Authentication Portal (port 4100). If users cannot reach the portal, verify this policy exists and is enabled.

**Gateway Firebox scenario:** when authentication requests are forwarded through a gateway Firebox to another Firebox, the WatchGuard Authentication policy on the gateway must be edited to also allow traffic to the destination Firebox's IP address.

---

### Authentication Timeouts

| Scope | Setting | Default |
|-------|---------|---------|
| Global | Session Timeout | 0 (unlimited) |
| Global | Idle Timeout | 2 hours |
| Per-user (Firebox-DB) | Session Timeout | 8 hours |
| Per-user (Firebox-DB) | Idle Timeout | 30 minutes |

- Per-user setting takes precedence over global if specified
- Third-party server timeout settings override Firebox global timeout settings

---

### Login Limits

Default: unlimited concurrent authenticated sessions per account.

When limits are enabled, options for a subsequent login attempt with the same credentials:
- Allow subsequent logins and log off the first session
- Reject subsequent login attempts

Configured at: Setup > Authentication > Users and Groups. Global login limits also configurable in Fireware Authentication settings.

---

### Multi-User Systems (Terminal Server / Citrix)

The Firebox maps one username to one IP address — this breaks on Terminal Server or Citrix where many users share a single IP.

**Fix:** install the **WatchGuard Terminal Services Agent** (also called the **TO Agent — Traffic Owner Agent**) on the Terminal Server/Citrix host. It monitors per-user traffic and reports the user session ID to the Firebox for each flow, enabling correct per-user/group policy enforcement despite the shared IP.

---

### Block Failed Logins

Protects against brute-force attacks on Firebox login pages.

| Version | Default State |
|---------|--------------|
| Fireware v12.10.4 | Disabled by default |
| Fireware v12.11+ | Enabled by default |

**Applies to:** Fireware Web UI, Mobile VPN with SSL client download page (removed in v12.11+), Access Portal, Authentication Portal.

When triggered: offending IP is temporarily added to the Blocked Sites list with Reason: `block failed logins`. The failed-attempt counter totals across all login pages, not per-page.

**Does NOT apply to:**
- Fireware Web UI logins where the username is not `admin` or `status`
- AuthPoint authentication

---

### AuthPoint MFA — Validation Path by User Type

| User Type | First Factor (Password) | Second Factor (MFA) |
|-----------|------------------------|---------------------|
| Local AuthPoint user | AuthPoint validates | AuthPoint validates |
| LDAP/AD user via AuthPoint | Active Directory validates | AuthPoint validates |

Flow: Firebox forwards authentication request to AuthPoint → AuthPoint coordinates per the rules above → Firebox prompts user for second factor (push notification or OTP).

**AuthPoint configuration requirements:**

In AuthPoint:
- Register and connect the Firebox to WatchGuard Cloud as a locally-managed device
- Add a Firebox resource in AuthPoint
- Add users and groups in AuthPoint
- Add authentication policies specifying which resources and auth methods are allowed

On the Firebox:
- Mobile VPN with SSL: set AuthPoint as the primary authentication server
- Mobile VPN with IKEv2: set AuthPoint as the primary authentication server
- Authentication Portal: specify AuthPoint as the auth server for users/groups
- Fireware Web UI: System > Users and Roles → add Device Management users with AuthPoint as the auth server

---

### Third-Party Server Configuration Requirements

| Server Type | Required Configuration |
|-------------|----------------------|
| Active Directory | Server IP + search base. Domain Name field is for Firebox log messages only |
| LDAP | Server IP + search base + group attribute + DN of a searching user (in most cases) |
| SAML | FQDN resolving to Firebox external interface + IdP metadata URL |
| RADIUS / SecurID | Server IP + shared secret |

Multiple AD and RADIUS servers can be configured, each with an optional backup.

---

### Backup Authentication Server Failover

1. Firebox attempts primary server for the Timeout duration (default: 10 seconds)
2. No response → primary marked inactive
3. Firebox attempts backup server for the Timeout duration
4. No response → backup marked inactive; log message generated
5. Firebox waits for the Dead Time value, then retries the primary
6. Process repeats indefinitely

**RADIUS-specific:** if a RADIUS server does not respond after the Timeout interval, the Firebox retries per the **Retries** value before marking it inactive. The Retries setting applies to RADIUS only.

---

### Users and Groups in Policies

- An authenticated user's traffic is only permitted if a Firebox policy allows it
- Adding a user/group to a policy's From field auto-creates the WatchGuard Authentication policy
- Authentication can be configured differently per policy (e.g., require auth for FTP but not general browsing)

**Critical:** User/group names must use **identical capitalization** on the Firebox and on the authentication server. A mismatch causes authentication to succeed (password valid) while policy matching fails — the group name returned by the auth server does not match the policy configuration.

Log message produced: `"Decrypted traffic does not match any policy"`  
First troubleshooting step: verify exact spelling and capitalization of group/user names on both systems.

**Authentication Server option when adding a user/group:**
- **Any** — works with any configured auth server; only use if any server is acceptable for that user/group
- **[Specific server name]** — restricts authentication to that server only

To allow authentication against multiple specific servers (but not all), add the same group multiple times — once per allowed server.

---

## Exam Fact Dump — Chapter 8

- Authentication Portal: `https://[interface IP]:4100`, uses PAP (unencrypted transport, hashed password)
- Firebox-DB passphrase: min 8 characters (configurable), max 32 characters (hard limit, cannot be changed)
- Firebox-DB passwords: NT hash in config; AES key-wrapped if exported to cleartext
- AuthPoint is disabled by default — requires a Firebox resource added in AuthPoint to activate
- SecurID has no separate tab — configured as an option inside the RADIUS configuration
- WatchGuard Authentication (WG-Auth) policy auto-creates on first user/group added to any policy's From field: From: Any-Trusted/Optional → To: Firebox
- AuthPoint local user: AuthPoint validates both password and second factor
- AuthPoint LDAP user: Active Directory validates password; AuthPoint validates second factor only
- "Decrypted traffic does not match any policy" → first check: capitalization/spelling mismatch of group/user names
- WatchGuard Terminal Services Agent (TO Agent) resolves the shared-IP problem on Terminal Server/Citrix
- Block Failed Logins: disabled by default in v12.10.4; enabled by default in v12.11+
- Block Failed Logins does NOT cover AuthPoint authentication
- Retries setting applies to RADIUS servers only (not AD, LDAP, or other types)
- Default auth server failover timeout: 10 seconds
- Global idle timeout default: 2 hours; per-user (Firebox-DB) idle timeout default: 30 minutes
- Per-user session timeout default: 8 hours; global session timeout default: 0 (unlimited)
- Third-party server timeout settings override Firebox global timeout settings
- Default login limit: unlimited concurrent sessions per account
- AD config requires only IP + search base; LDAP also requires group attribute + searching user DN
- SAML requires an FQDN resolving to the Firebox external interface + IdP metadata URL

---

## Check Yourself — Chapter 8

1. A user authenticates successfully but their traffic is still blocked with "Decrypted traffic does not match any policy." What is the most likely cause, and why does authentication still succeed?
2. What is the difference in how AuthPoint validates credentials for a local AuthPoint user versus an LDAP-sourced user?
3. Why does a Terminal Server environment break the Firebox's default authentication model, and what resolves it?
4. What two configuration steps in AuthPoint are required before it becomes an active authentication server on a Firebox?
5. What is the default failover timeout before the Firebox tries a backup authentication server, and what happens if the backup also fails to respond?

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
