# Chapter 2: Sites, Replication, and Trusts

Windows Server study notes (AZ-802 content). Plain-language summary.

---

## Acronym Key

| Short | Full form | Meaning |
|---|---|---|
| DC | Domain Controller | A server that holds the directory database |
| IP | Internet Protocol | Network addressing |
| WAN | Wide Area Network | The slower links between offices |
| KCC | Knowledge Consistency Checker | Automatically plans which DCs copy from which |
| ISTG | Inter-Site Topology Generator | Picks the bridgehead server for each site |
| DFS | Distributed File System | Sends users to the nearest file server |
| PDC | Primary Domain Controller | As in the "PDC Emulator" FSMO role |
| FSMO | Flexible Single Master Operations | Jobs only one DC can do |
| SID | Security Identifier | Full unique ID of a user, group, or computer |
| DNS | Domain Name System | Turns names into IP addresses |
| DSRM | Directory Services Restore Mode | AD's emergency repair mode and password |
| VNet | Virtual Network | Azure's private network |
| VM | Virtual Machine | A virtual server |
| vCPU | Virtual CPU | Processor cores assigned to a VM |

---

## 2.1 Sites and Subnets

- A **site** is a group of locations with fast connections between them. Think of it as one office.
- A **subnet** is an IP address range. Mapping a subnet to a site tells AD where a computer is.
  - Example: Surrey site → `10.10.1.0/24`, Kelowna site → `10.20.1.0/24`.
- Sites do three jobs:
  1. **Logins stay local.** Computers log in to a DC in their own site.
  2. **Replication is planned around sites.** Changes copy fast inside a site and on a schedule between sites.
  3. **Other services use sites.** For example, DFS sends users to the nearest file server.
- Every new forest starts with one site: **Default-First-Site-Name**.
- **Common miss:** a new office opens but its subnet is never added in AD. Its computers may log in to a DC in another city, so logins and Group Policy are slow.
- How to catch it:
  - On a client, `nltest /dsgetsite` shows which site it thinks it's in.
  - On the DC, `C:\\Windows\\debug\\netlogon.log` lists computers from IP ranges not mapped to any site.

### Commands
```powershell
New-ADReplicationSite -Name "Kelowna"
New-ADReplicationSubnet -Name "10.20.1.0/24" -Site "Kelowna"
```

---

## 2.2 Replication: How Changes Travel

### Inside a site (intra-site)
- Fast and automatic. A DC notifies its partners about 15 seconds after a change.
- Not compressed. The network inside a site is fast.
- The **KCC** automatically decides which DC copies from which.

### Between sites (inter-site)
- Runs on a schedule. The default is every **180 minutes**.
- Compressed, to save WAN bandwidth.
- Travels over a **site link**, which has three settings:
  - **Cost:** lower cost means the route is preferred.
  - **Interval:** how often replication runs. Default 180 minutes, minimum 15.
  - **Schedule:** which hours replication is allowed.
- Default site link: `DEFAULTIPSITELINK` (cost 100, interval 180 minutes).
- Each site has one **bridgehead server** that sends and receives changes for that site. The **ISTG** picks it automatically.

### Changes that skip the queue
- **Password changes** go straight to the PDC Emulator, no matter which site it's in.
- **Account lockouts** are pushed out right away inside a site.

### On the job
- A user created in one site may not appear at another site for up to 3 hours. Nothing is broken; it's waiting for the schedule.
- Force replication now:
```powershell
repadmin /syncall /AdeP
```
  - `A` = all partitions, `d` = show names instead of IDs, `e` = include other sites, `P` = push changes out from this DC.

### The 180-day rule
- A DC offline for more than **180 days** (the tombstone lifetime) must never be reconnected. It has missed deletions and can bring deleted objects back. Wipe it and rebuild it.

### Health checks
```powershell
repadmin /replsummary      # One-page health summary: look for fails and large "largest delta" times
repadmin /showrepl         # Detail per DC and per partition
```

---

## 2.3 Trusts

- A **trust** is an agreement that lets users from another domain or forest access your resources.
- **Direction:** the side that trusts is the side that lets people in. Access flows opposite to the trust arrow.
```
Company A  ──trusts──▶  Company B
Result: B's users can access A's resources
```
- **One-way:** only one side gets access. **Two-way:** both sides do.
- **Transitive:** friends of friends are trusted (A trusts B, B trusts C → A trusts C).
- **Non-transitive:** only the two sides that signed the agreement.

### Trust types

| Type | Between | Direction | Transitive? | When you'd see it |
|---|---|---|---|---|
| Parent-child / tree-root | Domains in the same forest | Two-way | Yes | Automatic, created for you |
| Forest | Two whole forests | One- or two-way | Yes, between those two forests only | Mergers and acquisitions |
| External | One domain in another forest | One- or two-way | No | Old domains, or when you need just one domain |
| Shortcut | Two domains in the same forest | One- or two-way | Yes | Speeds up logins in big multi-domain forests |
| Realm | A Windows domain and a non-Windows Kerberos system | One- or two-way | Either | Linux/Unix environments |

- Every domain in one forest trusts every other domain automatically. You only create trusts to reach outside the forest, or as a shortcut.
- Mergers often use a temporary forest trust during migration, then remove it once everyone has moved.

### Security controls
- **SID filtering:** on by default for forest and external trusts. Blocks the other forest from adding extra permissions to its users. Leave it on.
- **Selective authentication:** the other side's users can only log in to servers where you grant the **"Allowed to Authenticate"** permission. Tighter and safer, but more work.

### Requirements
- **DNS:** each side must be able to find the other's DCs, usually through conditional forwarders.
- **Firewall:** the ports AD needs must be open between the networks.
- When a new trust fails, check DNS first.

### Commands
```powershell
Get-ADTrust -Filter *
nltest /domain_trusts
netdom trust lab.internal /domain:other.internal /verify
```

---

## 2.4 Lab: DC02, a Second Site, Replication, and FSMO Transfer

**Result:** DC01 in the Surrey site, DC02 in the Kelowna site, and a site link with a 15-minute interval.

Note: both subnets are in the same Azure VNet, so the link between the "sites" is as fast as inside a site. The AD behavior is still real. A trust lab was skipped, because it needs a third VM running a second forest.

**Mac terminal**
```bash
# 0. Check quota: "Standard DSv3 Family" needs at least 4 vCPUs available
az vm list-usage -l canadacentral -o table

# 1. Start DC01 and add the Kelowna subnet
az vm start -g rg-winsrv-lab -n DC01
az network vnet subnet create -g rg-winsrv-lab --vnet-name vnet-lab \
  -n snet-kelowna --address-prefixes 10.10.2.0/24
```

**PowerShell on DC01**
```powershell
# 2. Set up sites BEFORE promoting DC02, so it lands in the right site
Rename-ADObject -Identity "CN=Default-First-Site-Name,CN=Sites,CN=Configuration,DC=lab,DC=internal" -NewName "Surrey"
New-ADReplicationSubnet -Name "10.10.1.0/24" -Site "Surrey"
New-ADReplicationSite -Name "Kelowna"
New-ADReplicationSubnet -Name "10.10.2.0/24" -Site "Kelowna"

# A site created in PowerShell isn't added to a site link automatically
New-ADReplicationSiteLink -Name "Surrey-Kelowna" -SitesIncluded Surrey,Kelowna -Cost 100 -ReplicationFrequencyInMinutes 15
```

**Mac terminal**
```bash
# 3. Create DC02 and allow RDP from home IP only
az vm create -g rg-winsrv-lab -n DC02 \
  --image MicrosoftWindowsServer:WindowsServer:2025-datacenter-g2:latest \
  --size Standard_D2s_v3 \
  --vnet-name vnet-lab --subnet snet-kelowna \
  --private-ip-address 10.10.2.4 \
  --data-disk-sizes-gb 8 --data-disk-caching None \
  --admin-username labadmin \
  --nsg-rule NONE

az network nsg rule create -g rg-winsrv-lab --nsg-name DC02NSG \
  -n allow-rdp-home --priority 1000 \
  --source-address-prefixes YOUR_IP/32 \
  --destination-port-ranges 3389 --protocol Tcp --access Allow
```

**PowerShell on DC02**
```powershell
# 4. Set up the data disk, install the role, promote into the Kelowna site
Get-Disk | Where-Object PartitionStyle -eq 'RAW' | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -DriveLetter F -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "ADData"

Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

Install-ADDSDomainController -DomainName "lab.internal" -SiteName "Kelowna" -Credential (Get-Credential LAB\labadmin) -DatabasePath "F:\NTDS" -LogPath "F:\NTDS" -SysvolPath "F:\SYSVOL" -InstallDns
```

**Mac terminal**
```bash
# 5. Point the VNet's DNS at both DCs
az network vnet update -g rg-winsrv-lab -n vnet-lab --dns-servers 10.10.1.4 10.10.2.4
```

**PowerShell on DC01**
```powershell
# 6. Check sites and replication health
Get-ADDomainController -Filter * | Select-Object Name, Site, IPv4Address
repadmin /replsummary

# 7. Watch replication: create on DC01, check DC02, force if missing
New-ADUser -Name "Test Kelowna" -SamAccountName tkelowna
Get-ADUser tkelowna -Server DC02
repadmin /syncall /AdeP
Get-ADUser tkelowna -Server DC02

# 8. Transfer the PDC Emulator role to DC02 and back
netdom query fsmo
Move-ADDirectoryServerOperationMasterRole -Identity DC02 -OperationMasterRole PDCEmulator
netdom query fsmo
Move-ADDirectoryServerOperationMasterRole -Identity DC01 -OperationMasterRole PDCEmulator
netdom query fsmo
```

**Mac terminal**
```bash
# 9. Stop billing
az vm deallocate -g rg-winsrv-lab -n DC01
az vm deallocate -g rg-winsrv-lab -n DC02
```

**Expected results**
- DC01 shows the Surrey site, and DC02 shows Kelowna.
- `repadmin /replsummary` shows 0 fails.
- The test user appears on DC02 after the forced sync.
- The PDC Emulator role moves to DC02 and back.

---

## Key Takeaways

1. A site is a group of well-connected locations. Subnets map IP ranges to sites.
2. Computers log in to a DC in their own site. Missing subnets cause slow logins at new offices.
3. Inside a site, replication happens in about 15 seconds, uncompressed. Between sites, it runs on a schedule (default 180 minutes), compressed, over site links.
4. A site link has a cost (lower is preferred), an interval, and a schedule.
5. `repadmin /syncall /AdeP` forces replication. `repadmin /replsummary` is the daily health check.
6. A DC offline for more than 180 days must be rebuilt, never reconnected.
7. For trusts, access flows opposite to the trust arrow.
8. Domains in the same forest trust each other automatically. Forest trusts are for mergers.
9. Keep SID filtering on. Use selective authentication to limit which servers the other side can reach.
10. Trust failures are usually DNS.
11. Create sites and subnets before promoting a new DC, and link every new site with a site link.

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
