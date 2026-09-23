# Chapter 1: AD DS Foundations

Windows Server study notes (AZ-802 content). Plain-language summary.

---

## Acronym Key

| Short | Full form | Meaning |
|---|---|---|
| AD DS | Active Directory Domain Services | The whole directory system |
| DC | Domain Controller | A server that holds the directory database |
| RODC | Read-Only Domain Controller | A DC that can't make changes |
| NTDS.dit | NT Directory Services, Directory Information Tree | The directory database file |
| SYSVOL | System Volume | Shared folder with Group Policy files and logon scripts |
| GPO | Group Policy Object | One Group Policy |
| GC | Global Catalog | Forest-wide quick-lookup index |
| DNS | Domain Name System | Turns names into IP addresses |
| FSMO | Flexible Single Master Operations | Jobs only one DC can do |
| SID | Security Identifier | Full unique ID of a user, group, or computer |
| RID | Relative Identifier | The unique last part of a SID |
| PDC | Primary Domain Controller | Legacy name, now used as "PDC Emulator" |
| PRP | Password Replication Policy | Controls which passwords an RODC may store |
| DSRM | Directory Services Restore Mode | AD's emergency repair mode and password |
| NIC | Network Interface Card | Network adapter (a VM's is set in Azure) |
| VNet | Virtual Network | Azure's private network |
| NSG | Network Security Group | Azure firewall rules |
| RDP | Remote Desktop Protocol | Remote Desktop |
| JIT | Just-In-Time | Azure feature that opens access only when needed |

---

## 1.1 What a Domain Controller Holds

- A DC holds the directory: every user, computer, group, and password.
- Most organizations run 2+ DCs. Each has a full copy.
- Any DC can accept a change. The change is then copied to the others (multi-master replication).
- The database file is `C:\\Windows\\NTDS\\ntds.dit`. It has four sections:
  - **Schema:** which fields an object can have. Copied to every DC in the forest.
  - **Configuration:** sites, subnets, and which DCs exist. Copied to every DC in the forest.
  - **Domain:** the actual users, computers, groups, and OUs. Copied only within the domain.
  - **DNS (application partitions):** AD-integrated DNS zones.
- When replication fails, the error names the section. That tells you the scope of the problem.
- **SYSVOL** (`C:\\Windows\\SYSVOL`) holds Group Policy files and logon scripts.
  - It's copied by DFSR, separately from the database.
- Each GPO is split in two:
  - Half lives in the database.
  - Half lives in SYSVOL.
  - If one half arrives late, a DC applies the old policy. GPMC shows an "AD vs SYSVOL version" mismatch.
- **Forest** = the real security boundary. **Domain** = not a security boundary.
  - Real isolation requires a separate forest.
- Two admins edit *different* fields on the same object → both changes are kept.
- Two admins edit the *same* field → the newer edit wins.
- **Global Catalog:** a lookup index for the whole forest.
  - Needed for email-style (UPN) logons and universal group checks.
  - In single-domain environments, make every DC a GC.

---

## 1.2 FSMO Roles

- Five jobs can't be shared. One DC does each.
- Two roles are forest-wide (one per forest). Three are domain-wide (one per domain).

| Role | Scope | Job | When you'll notice it |
|---|---|---|---|
| Schema Master | Forest | Changes the schema | Exchange install, LAPS schema update |
| Domain Naming Master | Forest | Adds or removes domains | Almost never |
| RID Master | Domain | Hands out ID numbers | New objects can't be created |
| PDC Emulator | Domain | Time, passwords, lockouts | Daily |
| Infrastructure Master | Domain | Tracks cross-domain references | Never in a single domain |

### RID Master
- A SID = domain part + RID. Example: `S-1-5-21-...-1105` → `1105` is the RID.
- The built-in Administrator account's RID is always `500`.
- The RID Master gives each DC a batch of 500 RIDs.
- If the RID Master dies:
  - Nothing breaks right away. DCs keep using their leftover batch.
  - The failure shows up later, when object creation fails.

### PDC Emulator
- Named after the Windows NT 4 "Primary Domain Controller," the only writable DC back then. Modern DCs all write, but one DC still plays the "primary" for its legacy duties.
- **Time source:** every machine syncs its clock from it.
  - A clock off by more than 5 minutes breaks Kerberos, so logins fail.
- **Passwords:** new passwords are sent to it urgently.
  - Other DCs check with it before rejecting a login. That's why a password reset works right away.
- **Lockouts:** processed here.
  - Start lockout investigations on the PDC. Event **4740** names the source computer.
- **GPO edits:** GPMC targets the PDC by default.
- Hyper-V DCs: disable the Hyper-V time sync integration service so the clock doesn't drift.

### Moving roles
- **Transfer:** both DCs are online. A clean handover.
- **Seize:** the old holder is dead. The new DC takes the role by force (`-Force`).
- After a seize, never reconnect the old DC. Wipe it and run metadata cleanup.
- Graceful demotion of a DC transfers its roles automatically.
- Small environments: keep all five roles on one well-backed-up DC.

### Commands
```powershell
netdom query fsmo
Get-ADDomain | Select-Object RIDMaster, PDCEmulator, InfrastructureMaster
Get-ADForest | Select-Object SchemaMaster, DomainNamingMaster

# Transfer
Move-ADDirectoryServerOperationMasterRole -Identity "DC02" -OperationMasterRole PDCEmulator
# Seize (old holder is dead)
Move-ADDirectoryServerOperationMasterRole -Identity "DC02" -OperationMasterRole PDCEmulator -Force
```

---

## 1.3 RODC (Read-Only Domain Controller)

- A DC holding a read-only copy of the directory.
- Built for sites with weak physical security: branch offices, clinics, unlocked closets.
- Changes are made on a writable DC and copied down to the RODC. Nothing copies back up.
- Stores no passwords by default. Logins are checked against a writable DC over the network.
- **PRP (Password Replication Policy)** decides whose passwords the RODC may store:
  - **Allowed RODC Password Replication Group:** add branch users here.
  - **Denied RODC Password Replication Group:** admins are in here by default.
- If the link to head office goes down, only users with stored passwords can log in.
- **Administrator Role Separation:** you can make a local admin on the RODC only. They get no domain admin rights.
- If an RODC is stolen:
  - Delete its computer account in AD.
  - Choose to reset the passwords of every account stored on it.

### Commands
```powershell
# Who is allowed to have passwords stored
Get-ADDomainControllerPasswordReplicationPolicy -Identity RODC01 -Allowed

# Whose passwords are actually stored right now
Get-ADDomainControllerPasswordReplicationPolicyUsage -Identity RODC01 -RevealedAccounts
```

---

## 1.4 Domain Controllers in Azure

- **Fixed IP:** set it on the NIC in Azure. Leave Windows on automatic (DHCP). A fixed IP typed inside Windows can cut off access to the VM.
- **Data disk:** put `ntds.dit` and SYSVOL on a separate data disk with host caching set to **None**. Write caching can corrupt the AD database.
- **Temporary disk:** drive D: in Azure is temporary and gets wiped. Never store data there.
- **DNS:** set the VNet's DNS server to the DC's IP.
  - Add Azure DNS (`168.63.129.16`) as a forwarder on the DC.
- **Remote access:** don't expose RDP to the internet.
  - Production: use Azure Bastion or JIT access.
  - Lab: allow RDP from your home IP only.

### Lab build: DC01

Environment: Canada Central, Standard_D2s_v3, Windows Server 2025, domain `lab.internal`.

**Mac terminal (Azure CLI)**
```bash
# 1. Resource group and network
az group create -n rg-winsrv-lab -l canadacentral

az network vnet create -g rg-winsrv-lab -n vnet-lab \
  --address-prefix 10.10.0.0/16 \
  --subnet-name snet-servers --subnet-prefix 10.10.1.0/24

# 2. DC01 with fixed IP and a data disk with caching off
az vm create -g rg-winsrv-lab -n DC01 \
  --image MicrosoftWindowsServer:WindowsServer:2025-datacenter-g2:latest \
  --size Standard_D2s_v3 \
  --vnet-name vnet-lab --subnet snet-servers \
  --private-ip-address 10.10.1.4 \
  --data-disk-sizes-gb 8 --data-disk-caching None \
  --admin-username labadmin \
  --nsg-rule NONE

# 3. RDP from home IP only
curl ifconfig.me
az network nsg rule create -g rg-winsrv-lab --nsg-name DC01NSG \
  -n allow-rdp-home --priority 1000 \
  --source-address-prefixes YOUR_IP/32 \
  --destination-port-ranges 3389 --protocol Tcp --access Allow
```

**PowerShell on DC01**
```powershell
# 4. Set up the data disk as F:
Get-Disk | Where-Object PartitionStyle -eq 'RAW' | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -DriveLetter F -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "ADData"

# 5. Install the AD role
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# 6. Promote to DC and create the forest (prompts for the DSRM password; reboots)
Install-ADDSForest -DomainName "lab.internal" -DomainNetbiosName "LAB" -DatabasePath "F:\\NTDS" -LogPath "F:\\NTDS" -SysvolPath "F:\\SYSVOL" -InstallDns
```

**Mac terminal**
```bash
# 7. Point the VNet's DNS at DC01
az network vnet update -g rg-winsrv-lab -n vnet-lab --dns-servers 10.10.1.4
az vm restart -g rg-winsrv-lab -n DC01
```

**PowerShell on DC01**
```powershell
# 8. Forward internet lookups to Azure DNS
Add-DnsServerForwarder -IPAddress 168.63.129.16

# 9. Verify
netdom query fsmo
Get-ADDomain | Select-Object PDCEmulator, RIDMaster, InfrastructureMaster
Get-ADForest | Select-Object SchemaMaster, DomainNamingMaster
dcdiag /q
```

**Mac terminal**
```bash
# 10. Stop billing when done
az vm deallocate -g rg-winsrv-lab -n DC01
```

Expected result: all five FSMO roles on DC01, and `dcdiag /q` returns no errors.

---

## Key Takeaways

1. A DC holds a full copy of the directory. Any writable DC accepts changes.
2. The directory has two parts: the database (`ntds.dit`) and SYSVOL (Group Policy files).
3. The forest is the security boundary. A domain isn't.
4. There are five FSMO roles, with one DC in charge of each.
5. The PDC Emulator handles time, passwords, and lockouts. Start lockout hunts there (event 4740).
6. A dead RID Master is a slow problem: object creation fails later.
7. Transfer a role when the old DC is alive. Seize it when the old DC is dead, and never reconnect the dead DC.
8. An RODC is a read-only DC for weak-security sites. It stores only the passwords the PRP allows.
9. DCs in Azure:
   - Set the fixed IP on the NIC.
   - Put AD on a data disk with caching set to None.
   - Point the VNet's DNS at the DC.
   - Never use drive D: for data.

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
