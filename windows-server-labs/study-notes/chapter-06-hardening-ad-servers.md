# Chapter 6: Hardening AD and Servers

Windows Server study notes (AZ-802 content). Plain-language summary.

---

## Acronym Key

| Short | Full form | Meaning |
|---|---|---|
| DC | Domain Controller | A server that holds the directory database |
| GPO | Group Policy Object | One Group Policy |
| OU | Organizational Unit | A folder in AD |
| ADUC | Active Directory Users and Computers | The classic AD console (`dsa.msc`) |
| LAPS | Local Administrator Password Solution | Auto-rotates each machine's local admin password |
| PSO | Password Settings Object | A fine-grained password policy |
| FGPP | Fine-Grained Password Policy | Different password rules for different groups |
| NTLM | NT LAN Manager | The legacy authentication protocol |
| TGT | Ticket Granting Ticket | Kerberos's initial "day pass" ticket |
| AES | Advanced Encryption Standard | Strong, modern encryption |
| RC4 / DES | Rivest Cipher 4 / Data Encryption Standard | Legacy, weak encryption |
| AS-REP | Authentication Service Reply | The Kerberos reply abused in "AS-REP roasting" |
| LSASS | Local Security Authority Subsystem Service | The process that holds login secrets in memory |
| VBS | Virtualization-Based Security | Hyper-V-isolated memory region |
| UEFI | Unified Extensible Firmware Interface | Modern firmware (replaces BIOS) |
| TPM | Trusted Platform Module | Hardware security chip |
| PAW | Privileged Access Workstation | A locked-down PC used only for admin work |
| PKI | Public Key Infrastructure | Certificate services |
| DEP | Data Execution Prevention | Memory protection against exploits |
| ASLR | Address Space Layout Randomization | Memory protection against exploits |
| WDAC | Windows Defender Application Control | Former name of App Control for Business |
| EDR | Endpoint Detection and Response | Detects and responds to attacks on endpoints |
| JIT | Just-In-Time | Opens access only when needed |
| IPsec | Internet Protocol Security | Authenticates and encrypts traffic between machines |
| ICMP | Internet Control Message Protocol | Used by `ping` |
| SMB | Server Message Block | Windows file sharing |
| DSRM | Directory Services Restore Mode | AD's emergency repair mode |
| RODC | Read-Only Domain Controller | A DC that can't make changes |
| gMSA | Group Managed Service Account | Service account with an AD-managed password |

---

## 6.1 Password Policies

### Domain password policy
- Set by a GPO linked at the **domain level**, normally the **Default Domain Policy**.
- Only **one** per domain.
- Password settings in an OU-linked GPO don't affect domain accounts. They only apply to *local* accounts on computers in that OU.

### Fine-grained password policies (PSOs)
- Give users or **global groups** their own password and lockout rules.
- Can't be applied to OUs.
- If a user is covered by multiple PSOs, the **lowest precedence number wins** (10 beats 20).
- A PSO overrides the domain policy for anyone it covers.
- Created in the AD Administrative Center or with PowerShell. Group Policy doesn't create PSOs.

### Microsoft Entra Password Protection for AD DS
- Blocks weak and common passwords that still pass complexity rules.
  - **Global banned list:** maintained by Microsoft.
  - **Custom banned list:** organization-specific terms (company name, products, city).
- Deployment:
  - **Proxy service** on a member server (communicates with Entra ID).
  - **DC agent** on every DC.
- Run in **Audit** mode first, then switch to **Enforce**.
- Requires Entra ID P1 licensing.

---

## 6.2 Account and Group Hardening

### User account options

| Setting | Recommendation | Reason |
|---|---|---|
| Account is sensitive and cannot be delegated | Enable for admins | Prevents servers from impersonating the account |
| Smart card is required for interactive logon | Strong option for admins | Blocks password-only logins |
| Do not require Kerberos preauthentication | Never use | Exposes a crackable hash (AS-REP roasting) |
| Store password using reversible encryption | Never use | Password can be recovered as plain text |
| Password never expires | Avoid | Use gMSAs for services |

### Built-in privileged groups
- **Domain Admins:** a small number of named admin accounts only.
- **Enterprise Admins, Schema Admins:** empty. Add an account only for a planned change, then remove it.
- **Account Operators, Server Operators, Print Operators, Backup Operators:** empty.
  - Backup Operators can copy `ntds.dit` from a DC, which exposes every password hash.

### Protected Users group
- Members automatically get:
  - **No NTLM:** Kerberos only.
  - **No DES or RC4** in Kerberos.
  - **No cached credentials:** no offline logon.
  - **No delegation.**
  - **4-hour TGT lifetime** (instead of 10).
- Don't add service accounts or computer accounts.
- Side effect: connecting **by IP address** (which falls back to NTLM) fails for members, as do legacy apps and devices that need NTLM.

---

## 6.3 Protecting Admin Access to DCs

### Tier model

| Tier | Contents | Who logs in |
|---|---|---|
| Tier 0 | DCs, AD, Entra Connect, PKI | Tier 0 admin accounts only |
| Tier 1 | Member servers and applications | Server admin accounts |
| Tier 2 | Workstations and laptops | Helpdesk and desktop support accounts |

- **Rule:** a higher-tier account never logs in to a lower-tier machine.
- Credentials stay in a machine's memory after login. A Domain Admin login on one compromised workstation can expose the whole domain.

### Practical controls
- **Separate admin accounts** (e.g. `aksh` for daily work, `aksh-adm` for admin work). No email or browsing on admin accounts.
- **Deny lower-tier logons by GPO:** add Tier 0 groups to "Deny log on locally" and "Deny log on through Remote Desktop Services" on workstations.
- **PAW:** a dedicated, locked-down admin workstation for Tier 0 tasks.

### DC hardening
- Run only DC roles (AD, DNS, optionally DHCP). No file shares, apps, or browsing.
- Patch DCs first and quickly.
- Limit who can log on (Default Domain Controllers Policy, user rights).
- Physical security for on-prem DCs. Use an RODC where physical security is weak.
- Consider Server Core to reduce attack surface.
- Encrypt disks with BitLocker.

### Authentication Policies and Silos
- Restrict **where** privileged accounts can authenticate from (e.g. Domain Admins only from designated PAWs).
- Powerful but requires careful planning. Less common in small environments.

---

## 6.4 Authentication Protocols

| | Kerberos | NTLM |
|---|---|---|
| Status | Modern default | Legacy |
| Mechanism | Tickets issued by a DC | Challenge and response with a password hash |
| Weakness | Hard to forge when configured well | Vulnerable to pass-the-hash |
| Used when | Connecting by name within a domain | Connecting by IP, to non-domain machines, or as fallback |

### Reducing NTLM
1. **Audit:** enable NTLM auditing by GPO and review event logs to find dependencies.
2. **Restrict:** use the "Network security: Restrict NTLM" policies to block it where it's no longer needed.
- Never block NTLM in a single step. Legacy apps, printers, and scanners often depend on it.

### Kerberos encryption
- Use **AES**. RC4 and DES are weak.
- Microsoft is phasing out RC4 for Kerberos. Old service accounts and accounts with very old passwords are the most likely to break.

---

## 6.5 Windows LAPS

### Problem
- An identical local admin password on every machine lets an attacker move from one compromised machine to all others.

### What Windows LAPS does
- Sets a **unique, random** local admin password per machine.
- **Rotates** it automatically (30 days by default).
- **Backs it up** to AD or Entra ID for authorized lookup.
- Can rotate again after the password is used (optional).
- Can manage the **DSRM password** on DCs.

### Windows LAPS vs legacy LAPS
- **Legacy LAPS:** a separate download that stored passwords in plain text in AD.
- **Windows LAPS:** built into Windows 11, Windows Server 2019+ (with updates), and Server 2025. Supports **encryption** and **Entra ID** backup.
- Replaces the insecure legacy GPO Preference passwords.

### Setup (AD backup)
1. Extend the schema once: `Update-LapsADSchema`
2. Grant computers permission to write their password: `Set-LapsADComputerSelfPermission`
3. Create a GPO to enable LAPS and set the backup directory and password settings.
4. Grant read access to authorized groups: `Set-LapsADReadPasswordPermission`
- Retrieve a password:
```powershell
Get-LapsADPassword -Identity SRV01 -AsPlainText
```
- Typical delegation: helpdesk can read passwords on the **Workstations** OU only, consistent with the tier model.

---

## 6.6 Protecting the Server OS

### Credential Guard
- Uses **VBS** to isolate login secrets (NTLM hashes, Kerberos tickets) from **LSASS**. Credential-dumping tools can't read them, even with admin rights.
- Requires UEFI Secure Boot and virtualization support. A TPM is recommended.
- **Not used on DCs.**
- Can break legacy features that rely on NTLMv1 or saved credentials for delegation.
- Enabled by default on eligible Windows 11 22H2+ and Windows Server 2025 machines (not DCs).

### Exploit protection
- System- and app-level memory mitigations (e.g. DEP, ASLR).
- Configure in Windows Security, **export to XML**, and deploy by GPO or Intune.

### App Control for Business (formerly WDAC)
- Application **allow list**: only approved software can run.
- Deploy in **Audit** mode first, then **Enforce**.
- **AppLocker** is the older, simpler option. App Control is recommended.

### Microsoft Defender SmartScreen
- Warns about or blocks unknown downloads, unknown apps, and phishing sites.
- Enable and lock it by GPO.

### Security baselines
- **GPO:** import baseline GPOs from the Microsoft **Security Compliance Toolkit**.
- **OSConfig** (Windows Server 2025): built-in tool that applies the baseline and provides **drift control**, automatically reverting changed settings.
  - Separate scenarios for member servers, DCs, and workgroup servers.
  - Test before deploying. Baselines can change logon rights, SMB settings, and more.

### Microsoft Defender for Servers
- Part of **Microsoft Defender for Cloud**. Covers Azure servers, and on-prem servers through **Azure Arc**.

| | Plan 1 | Plan 2 |
|---|---|---|
| Includes | Defender for Endpoint (EDR) | Plan 1, plus JIT VM access, file integrity monitoring, vulnerability assessment, and more |

---

## 6.7 Windows Firewall

### Profiles

| Profile | Active when |
|---|---|
| Domain | The machine can reach a DC and authenticate to the domain network |
| Private | The network is marked as trusted |
| Public | Any other network. The strictest profile |

- A domain-joined server on the **Public** profile usually couldn't reach a DC at startup (often DNS). Domain-scoped rules then don't apply.
```powershell
Get-NetConnectionProfile
```

### Rules
- **Inbound:** controls connections *to* the server. Most rules go here.
- **Outbound:** controls connections *from* the server. Allowed by default.
- Manage rules centrally by GPO.

### Connection security rules (IPsec)
- Authenticate the connecting computer and optionally encrypt traffic.
- Used for **server isolation** and **domain isolation** (e.g. only domain-joined computers can reach a finance server).

---

## 6.8 Lab: PSO, Account Audit, Protected Users, LAPS, Firewall, Credential Guard, OSConfig

Environment: DC01 (`10.10.1.4`), DC02 (`10.10.2.4`), SRV01 (`10.10.1.10`), domain `lab.internal`.

**Mac terminal**
```bash
# 0. Start all three VMs
az vm start -g rg-winsrv-lab -n DC01
az vm start -g rg-winsrv-lab -n DC02
az vm start -g rg-winsrv-lab -n SRV01
```

**PowerShell on DC01**
```powershell
# 1. Fine-grained password policy for helpdesk
New-ADFineGrainedPasswordPolicy -Name "PSO-Helpdesk" -Precedence 10 -MinPasswordLength 16 -ComplexityEnabled $true -PasswordHistoryCount 24 -MaxPasswordAge 180.00:00:00 -MinPasswordAge 1.00:00:00 -LockoutThreshold 5 -LockoutDuration 00:30:00 -LockoutObservationWindow 00:30:00 -ReversibleEncryptionEnabled $false
Add-ADFineGrainedPasswordPolicySubject -Identity "PSO-Helpdesk" -Subjects GG-Helpdesk

Get-ADUserResultantPasswordPolicy -Identity hd.tech     # Expect PSO-Helpdesk
Get-ADUserResultantPasswordPolicy -Identity jdoe        # Expect nothing (domain policy applies)

# 2. Find risky account settings
Get-ADUser -Filter 'DoesNotRequirePreAuth -eq $true' | Select-Object Name
Get-ADUser -Filter 'PasswordNeverExpires -eq $true' | Select-Object Name
Set-ADAccountControl -Identity labadmin -AccountNotDelegated $true

# 3. Review built-in privileged groups
"Schema Admins","Enterprise Admins","Account Operators","Backup Operators","Server Operators","Print Operators" | ForEach-Object { "--- $_ ---"; Get-ADGroupMember $_ | Select-Object -ExpandProperty Name }

# 4a. Add Sam to Protected Users
Add-ADGroupMember -Identity "Protected Users" -Members slee
```

**PowerShell on SRV01 (signed in as LAB\\labadmin)**
```powershell
# 4b. By name (Kerberos): expect success
$cred = Get-Credential LAB\slee
New-PSDrive -Name K -PSProvider FileSystem -Root "\\\\dc01.lab.internal\\SYSVOL" -Credential $cred

# By IP (NTLM): expect failure, because Protected Users blocks NTLM
Remove-PSDrive K
New-PSDrive -Name N -PSProvider FileSystem -Root "\\\\10.10.1.4\\SYSVOL" -Credential $cred
```

**PowerShell on DC01**
```powershell
# 4c. Remove Sam from Protected Users (keeps RDP from a non-domain Mac working)
Remove-ADGroupMember -Identity "Protected Users" -Members slee -Confirm:$false

# 5a. Windows LAPS: schema, self-permission, GPO
Update-LapsADSchema
Set-LapsADComputerSelfPermission -Identity "OU=Servers,OU=Lab,DC=lab,DC=internal"
New-GPO -Name "SRV-LAPS" | New-GPLink -Target "OU=Servers,OU=Lab,DC=lab,DC=internal"
```

**GUI on DC01 (`gpmc.msc`)**, edit **SRV-LAPS**:
- Computer Configuration → Policies → Administrative Templates → System → LAPS
  - **Configure password backup directory:** Enabled, Backup directory = Active Directory
  - **Password Settings:** Enabled, Length = 20, Age = 30 days

**PowerShell on SRV01**
```powershell
# 5b. Apply the LAPS policy now
gpupdate /force
Invoke-LapsPolicyProcessing
```

**PowerShell on DC01**
```powershell
# 5c. Retrieve the password (expect 20 random characters and an expiry date)
Get-LapsADPassword -Identity SRV01 -AsPlainText

# Optional: delegate read access (in production, target the Workstations OU)
Set-LapsADReadPasswordPermission -Identity "OU=Servers,OU=Lab,DC=lab,DC=internal" -AllowedPrincipals "LAB\\GG-Helpdesk"

# 6a. Ping SRV01 (expect failure: inbound ICMP is blocked by default)
Test-NetConnection srv01.lab.internal
```

Note: LAPS manages the built-in local administrator account. On Azure VMs, that's the admin account created with the VM (`labadmin`). SRV01's **local** `labadmin` password is now managed by LAPS. Sign in with the domain account `LAB\\labadmin`.

**PowerShell on SRV01**
```powershell
# 6b. Confirm the Domain profile, then allow ping from the lab network on that profile only
Get-NetConnectionProfile          # Expect DomainAuthenticated
New-NetFirewallRule -DisplayName "LAB-Allow-Ping-Internal" -Direction Inbound -Protocol ICMPv4 -IcmpType 8 -RemoteAddress 10.10.0.0/16 -Profile Domain -Action Allow
```

**PowerShell on DC01**
```powershell
# 6c. Ping again (expect success)
Test-NetConnection srv01.lab.internal
```

**PowerShell on SRV01**
```powershell
# 7. Credential Guard status: 1 in the list = running; 0 or empty = not running
#    (an Azure VM without VBS support shows 0 or empty)
(Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard).SecurityServicesRunning

# 8. Optional: OSConfig security baseline (may restrict local-account network logons; use LAB\\labadmin afterward)
Install-Module -Name Microsoft.OSConfig -Scope AllUsers -Repository PSGallery -Force
Set-OSConfigDesiredConfiguration -Scenario SecurityBaseline/WS2025/MemberServer -Default
# Restart SRV01, then check compliance
Get-OSConfigDesiredConfiguration -Scenario SecurityBaseline/WS2025/MemberServer | Format-Table Name, @{Name="Status";Expression={$_.Compliance.Status}} -AutoSize
# To remove the baseline if it causes issues:
Remove-OSConfigDesiredConfiguration -Scenario SecurityBaseline/WS2025/MemberServer
```

**Mac terminal**
```bash
# 9. Stop billing
az vm deallocate -g rg-winsrv-lab -n DC01
az vm deallocate -g rg-winsrv-lab -n DC02
az vm deallocate -g rg-winsrv-lab -n SRV01
```

**Expected results**
- `hd.tech` resolves to PSO-Helpdesk (16-character minimum). `jdoe` uses the domain policy.
- No accounts have preauthentication disabled.
- Operators groups are empty. `labadmin` is in Schema Admins and Enterprise Admins as the forest creator (remove it in production after setup).
- With Sam in Protected Users, the connection by name succeeds and the connection by IP fails.
- `Get-LapsADPassword` returns a 20-character password for SRV01.
- Ping to SRV01 fails before the firewall rule and succeeds after.

---

## Key Takeaways

1. One domain password policy per domain, set at the domain level. OU-linked password settings don't affect domain accounts.
2. PSOs apply to users or global groups. The lowest precedence number wins.
3. Entra Password Protection blocks banned passwords. It needs an agent on every DC plus a proxy. Audit first.
4. Enable "Account is sensitive and cannot be delegated" for admins. Never disable Kerberos preauthentication.
5. Keep Schema Admins, Enterprise Admins, and the Operators groups empty.
6. Protected Users: no NTLM, no weak encryption, no cached logons, no delegation. Admins only. Connections by IP fail.
7. Tier model: a higher-tier account never logs in to a lower-tier machine. Use separate admin accounts.
8. DCs run only DC roles, are patched first, and only Tier 0 admins log in to them.
9. Audit NTLM before restricting it. Kerberos should use AES. RC4 is being retired.
10. Windows LAPS gives each machine a unique, rotating local admin password. Setup: schema, self-permission, GPO, read permission.
11. Credential Guard isolates secrets from LSASS. It isn't used on DCs.
12. App Control and exploit protection: audit first, then enforce. Deploy exploit protection as XML.
13. OSConfig applies the Server 2025 baseline with drift control. Test before deploying.
14. Defender for Servers covers Azure, and on-prem servers through Arc. Plan 2 adds JIT and more.
15. A domain server on the Public firewall profile usually can't reach a DC. Check DNS.
16. Connection security rules use IPsec for server and domain isolation.

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
