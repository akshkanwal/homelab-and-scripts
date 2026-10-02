# Chapter 4: Group Policy

Windows Server study notes (AZ-802 content). Plain-language summary.

---

## Acronym Key

| Short | Full form | Meaning |
|---|---|---|
| GPO | Group Policy Object | One Group Policy |
| GPMC | Group Policy Management Console | The GPO tool (`gpmc.msc`) |
| GPC | Group Policy Container | The half of a GPO stored in the AD database |
| GPT | Group Policy Template | The half of a GPO stored in SYSVOL |
| SYSVOL | System Volume | Shared folder on DCs with Group Policy files |
| DC | Domain Controller | A server that holds the directory database |
| LSDOU | Local, Site, Domain, OU | The order GPOs apply in |
| OU | Organizational Unit | A folder in AD |
| GPP | Group Policy Preferences | The "Preferences" half of a GPO |
| WMI | Windows Management Instrumentation | Lets a GPO check computer facts (OS, model) |
| RSoP | Resultant Set of Policy | The final result after all GPOs apply |
| ADMX | Administrative Template XML | Files that define the settings in the GPO editor |
| XML | Extensible Markup Language | A structured text file format |
| RDS | Remote Desktop Services | Terminal servers and remote apps |
| RDP | Remote Desktop Protocol | Remote Desktop |
| LAPS | Local Administrator Password Solution | Rotates local admin passwords |
| HKLM | HKEY_LOCAL_MACHINE | Computer-wide registry |
| HKCU | HKEY_CURRENT_USER | Per-user registry |
| DWORD | Double Word | A number value type in the registry |
| vCPU | Virtual CPU | Processor cores assigned to a VM |

---

## 4.1 How Group Policy Works

- Every GPO has two halves:
  - **Computer Configuration:** applies to computers at **startup**, and follows the **computer's** OU.
  - **User Configuration:** applies to users at **login**, and follows the **user's** OU.
- When GPOs apply:
  - At startup and login.
  - In the background every **90 minutes**, plus a random 0–30 minute offset.
  - On DCs, every **5 minutes**.
  - Right away with `gpupdate /force`.
- Some settings apply only at startup or login, never in the background: software installation, folder redirection, and drive maps set to "Replace." For these, `gpupdate` asks for a log off or restart.
- Each GPO is stored in two parts: the GPC (AD database) and the GPT (SYSVOL). They replicate separately.

---

## 4.2 Processing Order

- GPOs apply in **LSDOU** order:
  1. Local (the PC's own policy)
  2. Site
  3. Domain
  4. OU (parent first, then child)
- **The last one applied wins** when two settings conflict. Settings that don't conflict all apply.
- The OU closest to the object usually wins.
- When several GPOs are linked to the same OU, **Link Order 1 wins**, because it's applied last.
- **Block Inheritance** (set on an OU): ignores GPOs from parent containers.
- **Enforced** (set on a GPO link): its settings win and can't be blocked.
- **Enforced beats Block Inheritance.**
- Use Block and Enforced sparingly. Each one makes troubleshooting harder.
- Naming tip: prefix GPOs by target, e.g. `SRV-` (servers), `WKS-` (workstations), `USR-` (user settings).

---

## 4.3 Filtering

### Security filtering
- By default a GPO applies to **Authenticated Users**: all users and computers in the linked OU.
- If you filter to a user group and remove Authenticated Users, add **Domain Computers** with **Read** permission on the Delegation tab.
  - Since a 2016 security update, computers must be able to read user GPOs. Without Read, the GPO silently fails.

### WMI filtering
- Checks a fact about the computer before applying the GPO (e.g. only Windows 11, only laptops).
- If the filter returns false, the GPO is skipped.
- Keep filters simple. Slow filters slow down logins.

### Item-level targeting
- Applies to single **Preference** items (e.g. map this drive only for the Finance group, or only on one subnet).
- Lets one GPO handle many cases.

---

## 4.4 Loopback Processing

- User settings in a GPO linked to a **computer** OU do nothing by default, because user settings follow the user's OU.
- **Loopback** makes the user settings from the computer's OU apply to anyone who logs in to those computers.
- Two modes:
  - **Merge:** the user's normal settings apply, then the computer's OU user settings on top. The computer's side wins conflicts.
  - **Replace:** only the computer's OU user settings apply.
- Use cases: RDS and terminal servers, thin clients, kiosks, shared PCs.
- Setting location: Computer Configuration → Policies → Administrative Templates → System → Group Policy → **Configure user Group Policy loopback processing mode**.
- Registry value: `HKLM\\Software\\Policies\\Microsoft\\Windows\\System`, `UserPolicyMode` (1 = Merge, 2 = Replace).

---

## 4.5 Preferences vs Policies

| | Policies | Preferences (GPP) |
|---|---|---|
| Can the user change it? | No (greyed out) | Yes |
| When the GPO is removed | The setting is removed | The setting stays, unless "Remove this item when it is no longer applied" is ticked |
| Examples | Block Control Panel, password rules, Windows Update settings | Drive maps, printers, shortcuts, registry keys, local group members |

- Preference actions:
  - **Create:** add it only if it doesn't exist.
  - **Replace:** delete and recreate it every time.
  - **Update:** change only the fields filled in. The most common choice.
  - **Delete:** remove it.
- Security note: before 2014, Preferences could store passwords. They were weakly encrypted with a public key. Old GPOs may still hold them in SYSVOL, readable by any domain user. Find and remove them, and use LAPS instead.

---

## 4.6 Troubleshooting and the Central Store

### "GPO isn't applying" checklist
1. **Wrong OU.** The object isn't where you think (e.g. the default `Computers` container).
2. **User settings linked to a computer OU** with no loopback.
3. **Security filtering.** The wrong group, or Domain Computers is missing Read.
4. **New group membership not picked up.** Log off and on, or reboot.
5. **A WMI filter returned false.**
6. **Another GPO won** on processing order.
7. **Replication between DCs isn't finished.**

### Tools
```powershell
gpresult /r                          # Summary for the current user
gpresult /r /scope computer          # Computer side (run as admin)
gpresult /h C:\gp-report.html        # Full HTML report
```
- **GPMC → Group Policy Results:** the same report, run remotely.
- **GPMC → Group Policy Modeling:** "what if" simulation before you make a change.
- **Event Viewer:** Applications and Services Logs → Microsoft → Windows → GroupPolicy → **Operational**.
- In the HTML report, the **Denied GPOs** section lists why each GPO was skipped (e.g. Security, WMI filter).

### Central Store
- The GPO editor reads settings from ADMX files. By default, each admin PC uses its own local copy.
- The Central Store is one shared copy in SYSVOL, used by all admins:
```
\\\\<domain>\\SYSVOL\\<domain>\\Policies\\PolicyDefinitions
```
- Keep it updated with current Windows 11, Edge, and Office ADMX files.

### Backup and restore
```powershell
Backup-GPO -All -Path C:\GPOBackup
Restore-GPO -Name "GPO Name" -Path C:\GPOBackup
```
- Back up GPOs before any major change. In production, store backups off the DC.

---

## 4.7 Lab: SRV01, Policies, Preferences, and Loopback

**Result:** SRV01 joined to the domain in a Servers OU, with a logon banner, an RDP access grant for Finance, a Control Panel block for Staff, and a working loopback demo.

Environment: DC01, DC02, and new member server SRV01 (`10.10.1.10`), domain `lab.internal`. SRV01 is reused in Chapters 7–9.

**Mac terminal**
```bash
# 0. Check quota (Standard DSv3 Family needs 6 vCPUs available), then start the DCs
az vm list-usage -l canadacentral -o table
az vm start -g rg-winsrv-lab -n DC01
az vm start -g rg-winsrv-lab -n DC02

# 1. Create SRV01 and allow RDP from home IP only
az vm create -g rg-winsrv-lab -n SRV01 \
  --image MicrosoftWindowsServer:WindowsServer:2025-datacenter-g2:latest \
  --size Standard_D2s_v3 \
  --vnet-name vnet-lab --subnet snet-servers \
  --private-ip-address 10.10.1.10 \
  --admin-username labadmin \
  --nsg-rule NONE

az network nsg rule create -g rg-winsrv-lab --nsg-name SRV01NSG \
  -n allow-rdp-home --priority 1000 \
  --source-address-prefixes YOUR_IP/32 \
  --destination-port-ranges 3389 --protocol Tcp --access Allow
```

**PowerShell on DC01**
```powershell
# 2. Servers OU
New-ADOrganizationalUnit -Name "Servers" -Path "OU=Lab,DC=lab,DC=internal"
```

**PowerShell on SRV01 (local labadmin)**
```powershell
# 3. Join the domain into the Servers OU (restarts)
Add-Computer -DomainName lab.internal -OUPath "OU=Servers,OU=Lab,DC=lab,DC=internal" -Credential (Get-Credential LAB\labadmin) -Restart
```

**PowerShell on DC01**
```powershell
# 4. Create the Central Store
Copy-Item C:\Windows\PolicyDefinitions "\\\\lab.internal\\SYSVOL\\lab.internal\\Policies\\" -Recurse

# 5. GPO 1: logon banner (computer policy)
New-GPO -Name "SRV-LogonBanner" | New-GPLink -Target "OU=Servers,OU=Lab,DC=lab,DC=internal"

# 6. GPO 2: Finance RDP access (preference)
New-GPO -Name "SRV-RDP-Finance" | New-GPLink -Target "OU=Servers,OU=Lab,DC=lab,DC=internal"

# 7. GPO 3: block Control Panel for Staff (user policy)
New-GPO -Name "USR-NoControlPanel" | New-GPLink -Target "OU=Staff,OU=Lab,DC=lab,DC=internal"
Set-GPRegistryValue -Name "USR-NoControlPanel" -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer" -ValueName NoControlPanel -Type DWord -Value 1
```

**GUI on DC01 (`gpmc.msc`)**
- **SRV-LogonBanner:** Edit → Computer Configuration → Policies → Windows Settings → Security Settings → Local Policies → Security Options:
  - "Interactive logon: Message title for users attempting to log on" = `Lab Notice`
  - "Interactive logon: Message text for users attempting to log on" = `Authorized use only.`
- **SRV-RDP-Finance:** Edit → Computer Configuration → Preferences → Control Panel Settings → Local Users and Groups → New → Local Group:
  - Action: **Update**
  - Group name: **Remote Desktop Users (built-in)**
  - Members: add `LAB\\GG-Finance`

**Test as Sam Lee (slee, member of GG-Finance, in the Staff OU)**
1. On SRV01 as `labadmin`, run `gpupdate /force` and sign out.
2. RDP to SRV01 as `LAB\\slee`.
3. Check the results:
   - The banner appears before login (GPO 1, computer policy).
   - The login succeeds without admin rights (GPO 2, preference).
   - Control Panel is blocked (GPO 3). It follows Sam's OU, not the server's.
4. Run `gpresult /r` and confirm `USR-NoControlPanel` is listed under Applied Group Policy Objects.

**PowerShell on DC01**
```powershell
# 9. Loopback mistake: a user setting linked to the Servers OU
New-GPO -Name "SRV-UserLockdown" | New-GPLink -Target "OU=Servers,OU=Lab,DC=lab,DC=internal"
Set-GPRegistryValue -Name "SRV-UserLockdown" -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer" -ValueName NoRun -Type DWord -Value 1
```
- RDP to SRV01 as `LAB\\slee` and press Win+R. **Expected: the Run box still opens.** The setting doesn't apply, because Sam isn't in the Servers OU.

```powershell
# 10. Loopback fix: Merge mode (1 = Merge, 2 = Replace)
Set-GPRegistryValue -Name "SRV-UserLockdown" -Key "HKLM\\Software\\Policies\\Microsoft\\Windows\\System" -ValueName UserPolicyMode -Type DWord -Value 1
```
- On SRV01 as `labadmin`, run `gpupdate /force`. Loopback is a computer setting, so the server needs it first.
- RDP back in as `LAB\\slee` and press Win+R. **Expected: the Run box is blocked**, and Control Panel stays blocked (Merge keeps Sam's own settings).

```powershell
# 11a. On SRV01 as slee: full report (open it in Edge)
gpresult /h C:\Users\slee\gp-report.html

# 11b. On DC01: back up all GPOs
Backup-GPO -All -Path C:\GPOBackup
```

**Mac terminal**
```bash
# 12. Stop billing
az vm deallocate -g rg-winsrv-lab -n DC01
az vm deallocate -g rg-winsrv-lab -n DC02
az vm deallocate -g rg-winsrv-lab -n SRV01
```

---

## Key Takeaways

1. Computer settings follow the computer's OU and apply at startup. User settings follow the user's OU and apply at login.
2. Background refresh runs every 90 minutes plus a random offset. `gpupdate /force` applies now.
3. LSDOU: Local, Site, Domain, OU. The last one applied wins conflicts.
4. On the same OU, Link Order 1 wins. Enforced beats Block Inheritance.
5. If you filter a GPO to a user group, give Domain Computers Read, or it silently fails.
6. User settings linked to a computer OU need loopback. Merge adds on top; Replace uses only the computer's side.
7. Policies are locked and removed with the GPO. Preferences are changeable and stay behind unless set to remove.
8. Old Preference passwords in SYSVOL are a security risk. Use LAPS.
9. Troubleshoot with `gpresult /h`. The Denied GPOs section shows why each GPO was skipped.
10. Use a Central Store for ADMX files, and back up GPOs before major changes.

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
