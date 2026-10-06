# Chapter 5: DNS and DHCP

Windows Server study notes (AZ-802 content). Plain-language summary.

---

## Acronym Key

| Short | Full form | Meaning |
|---|---|---|
| DNS | Domain Name System | Turns names into IP addresses |
| DHCP | Dynamic Host Configuration Protocol | Hands out IP addresses automatically |
| IP | Internet Protocol | Network addressing |
| DC | Domain Controller | A server that holds the directory database |
| FQDN | Fully Qualified Domain Name | A full name, e.g. `app01.lab.internal` |
| A | Address record | Name → IPv4 address |
| AAAA | IPv6 address record | Name → IPv6 address |
| CNAME | Canonical Name | Alias → real name |
| PTR | Pointer record | IP → name (reverse lookup) |
| SRV | Service record | Locates a service (how PCs find DCs) |
| MX | Mail Exchanger | Where email for a domain is delivered |
| TXT | Text record | Free text: SPF, domain verification |
| SOA | Start of Authority | The zone's ID card (serial number, timers) |
| NS | Name Server | Which servers hold the zone |
| DNSSEC | DNS Security Extensions | Digital signatures on DNS records |
| KSK | Key Signing Key | Signs the ZSK |
| ZSK | Zone Signing Key | Signs the zone's records |
| RRSIG | Resource Record Signature | The DNSSEC signature record |
| DS | Delegation Signer | Links a signed zone to its parent |
| NRPT | Name Resolution Policy Table | Tells clients to require signed answers |
| VPN | Virtual Private Network | Encrypted link between networks |
| VNet | Virtual Network | Azure's private network |
| NIC | Network Interface Card | A VM's network adapter |
| DORA | Discover, Offer, Request, Acknowledge | The 4 steps of getting a DHCP address |
| APIPA | Automatic Private IP Addressing | Self-assigned `169.254.x.x` when DHCP fails |
| MAC | Media Access Control | A network adapter's hardware address |
| MCLT | Maximum Client Lead Time | Safety timer in DHCP failover |

---

## 5.1 DNS with Active Directory

- PCs find DCs by querying DNS for **SRV records**, e.g. `_ldap._tcp.dc._msdcs.lab.internal`.
  - DCs register these records automatically.
  - Missing or wrong SRV records break logins, GPOs, and domain joins.
- **Domain PCs must use only internal DNS servers (the DCs).** Never set `8.8.8.8` or ISP DNS as a secondary.
  - Windows doesn't always query the first server. A public resolver doesn't know the AD zone, which causes slow logins, intermittent GPO failures, and "domain not found" errors.
  - Common cause: firewall DHCP handing out ISP DNS. Fix: have DHCP hand out the DCs, and let the DCs forward internet lookups.

### Zone types

| Zone type | Description | Use |
|---|---|---|
| AD-integrated | Stored in AD, replicated by AD replication | Default for domains |
| Primary (file-based) | Master copy, stored in a text file | Non-AD DNS servers |
| Secondary | Read-only copy pulled from a primary | Extra copies on non-AD servers |
| Stub | Holds only another zone's NS, SOA, and glue records | Tracking a partner domain's DNS servers |

### AD-integrated zones
- Multi-master: any DC running DNS can accept updates.
- Replicated automatically through AD, so no zone transfers need to be configured.
- **Secure dynamic updates:** only domain-joined computers can register or update their records.
- Replication scope options:
  - All DNS servers in the forest
  - All DNS servers in the domain (the default for domain zones)
  - All DCs in the domain (legacy compatibility option)

### DC DNS client settings
- Preferred DNS: another DC. Alternate: the DC itself.
- A DC pointing only at itself can have startup issues.

---

## 5.2 Records, Reverse Zones, and Scavenging

### Common records

| Record | Purpose | Example |
|---|---|---|
| A | Name → IPv4 | `app01` → `10.10.1.50` |
| AAAA | Name → IPv6 | `app01` → `fd00::50` |
| CNAME | Alias → real name | `intranet` → `app01.lab.internal` |
| PTR | IP → name | `10.10.1.50` → `app01.lab.internal` |
| SRV | Service location | How PCs find DCs |
| MX | Mail delivery | `mail.contoso.com` |
| TXT | Text data | SPF, Microsoft 365 verification |
| NS | Zone name servers | `dc01.lab.internal` |
| SOA | Zone authority | Serial number, refresh timers |

### Reverse zones
- Answer "what's the name for this IP?" using PTR records.
- Named in reverse: `10.10.x.x` → `10.10.in-addr.arpa`.
- Not required for AD, but they help logs, monitoring, and troubleshooting show names instead of IPs.

### Aging and scavenging
- Deletes dynamic records that haven't been refreshed within a set period. A common setting is 7 days no-refresh plus 7 days refresh.
- Without it, stale records point to old IPs and send users or tools to the wrong machine.
- Must be enabled in two places: on the server (the cleanup job) and on the zone (aging).
```powershell
Set-DnsServerScavenging -ScavengingState $true -ScavengingInterval 7.00:00:00
Set-DnsServerZoneAging -Name lab.internal -Aging $true
```
- Only dynamic records are scavenged. Manually created static records are never deleted.

---

## 5.3 Forwarding

### Resolution order on a DNS server
1. Its own zones
2. Its cache
3. Conditional forwarders
4. Forwarders
5. Root hints (only when no forwarders are configured)

### Forwarders vs conditional forwarders vs stub zones
- **Forwarder:** sends all unknown queries to an upstream server (e.g. Azure DNS, the ISP).
- **Conditional forwarder:** sends queries for one specific domain to a specific server.
  - Uses for: forest trusts, partner or acquired companies, hybrid Azure DNS.
  - Uses fixed IPs, so it must be updated manually if the target servers change.
- **Stub zone:** keeps its own list of another zone's DNS servers and updates it automatically.

---

## 5.4 Hybrid DNS (On-Prem and Azure)

- Azure-provided DNS is at **`168.63.129.16`**. It's reachable **only from inside Azure**, not from on-prem, even over a VPN.
- **Azure Private DNS zones** are visible only to linked VNets.
  - Private endpoints (e.g. Storage, SQL on a private IP) use zones like `privatelink.blob.core.windows.net`.
- **Classic problem:** a private endpoint works from Azure VMs, but on-prem clients resolve the public IP, because on-prem DCs can't see Azure's private zones or reach `168.63.129.16`.
- **Fix: Azure DNS Private Resolver**, a managed DNS bridge:
  - **Inbound endpoint:** a VNet IP that on-prem DNS can reach over the VPN.
  - **Outbound endpoint plus forwarding ruleset:** sends Azure-side queries for on-prem zones back to the on-prem DCs.
```
On-prem DCs:  Conditional forwarder  blob.core.windows.net  →  Resolver inbound IP
Azure:        Forwarding rule        lab.internal           →  On-prem DC IPs
```
- Forward the public service zone (`blob.core.windows.net`), not the `privatelink` zone. Azure handles the CNAME redirect to the private zone.
- Legacy alternative: a DNS forwarder VM in Azure that forwards to `168.63.129.16`. It still works, but Private Resolver is the current recommendation.

---

## 5.5 DNS Policies and DNSSEC

### DNS policies
- Return different answers based on conditions:
  - **Client location (subnet):** branch clients get the branch server's IP.
  - **Time of day:** route traffic to a backup server overnight.
  - **Split-brain:** internal and external clients get different answers.
  - **Blocking:** refuse queries for a domain.
- Actions:
  - **ALLOW:** answer normally.
  - **DENY:** respond with "refused."
  - **IGNORE:** drop the query with no response.
- Managed through PowerShell only. There's no GUI.

### DNSSEC
- Digitally signs zone records so resolvers can confirm an answer is genuine and unmodified. This protects against forged DNS responses.
- Components:
  - **ZSK:** signs the zone's records.
  - **KSK:** signs the ZSK.
  - **Records:** RRSIG (signatures), DNSKEY (public keys), DS (links the zone to its parent).
  - **Trust anchor:** the starting point a resolver trusts.
  - **NRPT:** deployed by GPO, it makes Windows clients require validated answers for specific zones.
- Rare on internal AD zones in MSP environments, but required knowledge for the exam.

---

## 5.6 DHCP

### DORA
1. **Discover:** the client broadcasts a request for a DHCP server.
2. **Offer:** the server offers an address.
3. **Request:** the client accepts the offer.
4. **Acknowledge:** the server confirms the lease.
- Discover and Offer are **broadcasts**, so they don't cross routers by themselves.

### DHCP relay (IP helper)
- When clients and the DHCP server are on different subnets, the router or firewall must relay DHCP broadcasts to the server.

### Building blocks
- **Scope:** the address range for one subnet.
- **Exclusion:** addresses inside the scope that are never handed out (fixed-IP devices).
- **Reservation:** a specific IP always given to a specific MAC address (printers, badge readers).
- **Lease duration:** 8 days by default. Use shorter leases for guest Wi-Fi.
- **Options:**
  - **003 Router:** the default gateway
  - **006 DNS Servers:** the DCs, never the ISP
  - **015 DNS Domain Name:** e.g. `lab.internal`

### Authorization
- A Windows DHCP server must be **authorized in AD** before it hands out leases.
- This prevents unauthorized *Windows* DHCP servers only. Non-Windows rogue devices (e.g. a home router) aren't blocked by AD.

### DHCP failover
- Two servers share one scope. IPv4 only, with a maximum of 2 servers per relationship.

| Mode | Behavior | Use when |
|---|---|---|
| Load balance | Both servers issue leases, 50/50 by default | Both servers are at the same site |
| Hot standby | The active server issues leases; the standby holds a reserve (5% by default) | The standby is at another site |

- **MCLT** (1 hour by default) limits how far a partner can extend leases while the other server is unreachable. It prevents duplicate address assignment.
- Legacy alternative: **split scope**, two servers each owning part of a range (often 80/20).

### Troubleshooting
- A **`169.254.x.x` (APIPA)** address means no DHCP server responded. Check the relay, the server, and whether the scope is active.
- **Scope exhausted:** `Get-DhcpServerv4ScopeStatistics`
- **Wrong gateway or DNS:** check the scope options.
- **Client renewal:** `ipconfig /release`, then `ipconfig /renew`.

### DHCP in Azure
- Customer DHCP servers can't serve Azure VMs. Azure assigns addresses based on NIC configuration.
- Windows DHCP is used for on-prem networks: offices, clinics, Wi-Fi.

---

## 5.7 Lab: DNS Records, Forwarding, Policies, DNSSEC, and DHCP Failover

Environment: DC01 (`10.10.1.4`), DC02 (`10.10.2.4`), SRV01 (`10.10.1.10`), domain `lab.internal`.

Note: the DHCP scope is for a simulated branch subnet (`192.168.50.0/24`) reached through a DHCP relay. No Azure VM will receive a lease from it.

**Mac terminal**
```bash
# 0. Start all three VMs
az vm start -g rg-winsrv-lab -n DC01
az vm start -g rg-winsrv-lab -n DC02
az vm start -g rg-winsrv-lab -n SRV01
```

**PowerShell on SRV01**
```powershell
# 1. SRV records that clients use to find DCs (expect DC01 and DC02)
Resolve-DnsName -Type SRV _ldap._tcp.dc._msdcs.lab.internal
```

**PowerShell on DC01**
```powershell
# 2. Reverse zone, A record with PTR, and CNAME
Add-DnsServerPrimaryZone -NetworkId "10.10.0.0/16" -ReplicationScope Domain
Add-DnsServerResourceRecordA -ZoneName lab.internal -Name app01 -IPv4Address 10.10.1.50 -CreatePtr
Add-DnsServerResourceRecordCName -ZoneName lab.internal -Name intranet -HostNameAlias app01.lab.internal
```

**PowerShell on SRV01**
```powershell
# Expect intranet → app01 → 10.10.1.50, and the reverse lookup → app01.lab.internal
Resolve-DnsName intranet.lab.internal
Resolve-DnsName 10.10.1.50
```

**PowerShell on DC02**
```powershell
# Confirm AD replication of the record (run repadmin /syncall /AdeP if it's missing)
Get-DnsServerResourceRecord -ZoneName lab.internal -Name app01

# 3. File-based partner zone on DC02 only (simulates a partner company's DNS)
Add-DnsServerPrimaryZone -Name partner.test -ZoneFile partner.test.dns
Add-DnsServerResourceRecordA -ZoneName partner.test -Name web -IPv4Address 10.10.2.50
```

**PowerShell on DC01**
```powershell
# 4. Conditional forwarder: before (expect failure)
Resolve-DnsName web.partner.test -Server 10.10.1.4

# After (expect 10.10.2.50)
Add-DnsServerConditionalForwarderZone -Name partner.test -MasterServers 10.10.2.4
Clear-DnsServerCache -Force
Resolve-DnsName web.partner.test -Server 10.10.1.4

# 5. DNS policy: block a domain, test, then remove
Resolve-DnsName example.com -Server 10.10.1.4
Add-DnsServerQueryResolutionPolicy -Name "BlockExample" -Action DENY -FQDN "EQ,example.com,*.example.com"
Clear-DnsServerCache -Force
Resolve-DnsName example.com -Server 10.10.1.4      # Expect refused or failure
Remove-DnsServerQueryResolutionPolicy -Name "BlockExample" -Force
```

**PowerShell on DC02**
```powershell
# 6. Sign the partner zone with DNSSEC and look for RRSIG records
Invoke-DnsServerZoneSign -ZoneName partner.test -SignWithDefault -Force
Resolve-DnsName web.partner.test -Server 10.10.2.4 -DnssecOk
```

**PowerShell on DC01**
```powershell
# 7a. Install and authorize DHCP on DC01
Install-WindowsFeature DHCP -IncludeManagementTools
Add-DhcpServerSecurityGroup
Restart-Service DHCPServer
Add-DhcpServerInDC -DnsName dc01.lab.internal -IPAddress 10.10.1.4
```

**PowerShell on SRV01 (signed in as LAB\\labadmin)**
```powershell
# 7b. Install and authorize DHCP on SRV01
Install-WindowsFeature DHCP -IncludeManagementTools
Add-DhcpServerSecurityGroup
Restart-Service DHCPServer
Add-DhcpServerInDC -DnsName srv01.lab.internal -IPAddress 10.10.1.10
```

**PowerShell on DC01**
```powershell
# 8. Branch clinic scope: range, exclusion, reservation, options
Add-DhcpServerv4Scope -Name "Branch-Clinic" -StartRange 192.168.50.100 -EndRange 192.168.50.200 -SubnetMask 255.255.255.0 -LeaseDuration 8.00:00:00
Add-DhcpServerv4ExclusionRange -ScopeId 192.168.50.0 -StartRange 192.168.50.100 -EndRange 192.168.50.110
Add-DhcpServerv4Reservation -ScopeId 192.168.50.0 -IPAddress 192.168.50.150 -ClientId "00-15-5D-01-02-03" -Name "Clinic-Printer"
Set-DhcpServerv4OptionValue -ScopeId 192.168.50.0 -Router 192.168.50.1 -DnsServer 10.10.1.4,10.10.2.4 -DnsDomain lab.internal

# 9. Failover with SRV01 (replace YOUR_SECRET with your own shared secret)
Add-DhcpServerv4Failover -ComputerName dc01.lab.internal -PartnerServer srv01.lab.internal -Name "DC01-SRV01" -ScopeId 192.168.50.0 -LoadBalancePercent 50 -SharedSecret "YOUR_SECRET"
```

**PowerShell on SRV01**
```powershell
# Expect the Branch-Clinic scope, and failover in Load Balance mode at 50%
Get-DhcpServerv4Scope
Get-DhcpServerv4Failover
```

**Mac terminal**
```bash
# 10. Stop billing
az vm deallocate -g rg-winsrv-lab -n DC01
az vm deallocate -g rg-winsrv-lab -n DC02
az vm deallocate -g rg-winsrv-lab -n SRV01
```

**Expected results**
- The SRV lookup lists DC01 and DC02.
- `intranet` resolves through `app01` to `10.10.1.50`, and the reverse lookup returns `app01.lab.internal`.
- `web.partner.test` fails on DC01 before the conditional forwarder, and resolves after it.
- `example.com` is refused while the policy is active.
- The DNSSEC query returns RRSIG records.
- SRV01 shows the replicated `Branch-Clinic` scope and a 50% load-balance failover.

---

## Key Takeaways

1. PCs find DCs through SRV records. When DNS breaks, AD breaks.
2. Domain PCs must use only internal DNS. Never use a public DNS server as a secondary.
3. Use AD-integrated zones: multi-master, replicated by AD, with secure dynamic updates.
4. Reverse zones hold PTR records (IP → name).
5. Scavenging removes stale dynamic records and must be enabled on both the server and the zone.
6. Resolution order: own zones → cache → conditional forwarders → forwarders → root hints.
7. Conditional forwarders handle one domain. Stub zones keep their own server list up to date.
8. `168.63.129.16` works only inside Azure. Bridge hybrid DNS with Azure DNS Private Resolver.
9. DNS policies change answers by location, time, or client, and can block domains. They're PowerShell only.
10. DNSSEC signs records: the ZSK signs the records, the KSK signs the ZSK, and RRSIG holds the signatures.
11. DORA: Discover and Offer are broadcasts, so remote subnets need a DHCP relay.
12. DHCP option 006 should hand out the DCs.
13. Authorize Windows DHCP servers in AD.
14. DHCP failover: load balance or hot standby, two servers max, IPv4 only.
15. A `169.254.x.x` address means no DHCP server responded.
16. Azure VMs can't use customer DHCP servers.

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
