# Chapter 3: Users, Groups, and Service Accounts

Windows Server study notes (AZ-802 content). Plain-language summary.

---

## Acronym Key

| Short | Full form | Meaning |
|---|---|---|
| OU | Organizational Unit | A folder in AD for users, computers, and groups |
| ADUC | Active Directory Users and Computers | The classic AD console (`dsa.msc`) |
| GPO | Group Policy Object | One Group Policy |
| UPN | User Principal Name | Email-style login, e.g. `jdoe@lab.internal` |
| SAM | Security Account Manager | As in "SAM account name", the old-style login `LAB\\jdoe` |
| AGDLP | Accounts, Global groups, Domain Local groups, Permissions | The group nesting rule |
| GC | Global Catalog | Forest-wide lookup index |
| SQL | Structured Query Language | As in SQL Server, a common app that runs as a service |
| MSA | Managed Service Account | A service account whose password Windows manages |
| sMSA | Standalone Managed Service Account | MSA for one server |
| gMSA | Group Managed Service Account | MSA shared by several servers |
| dMSA | Delegated Managed Service Account | Windows Server 2025; replaces a legacy service account |
| KDS | Key Distribution Services | Generates gMSA passwords |
| ACL | Access Control List | The permission list on an object |
| SDProp | Security Descriptor Propagator | Background job that resets permissions on admin accounts |

---

## 3.1 Users and OUs

- **OUs** are folders in AD. Group objects into OUs by department or location, so policy and delegation can be applied to the whole OU.
- The built-in `Users` and `Computers` folders are **containers**, not OUs.
  - GPOs can't be linked to containers. They link only to OUs.
  - A new PC that lands in the default `Computers` container gets no OU-linked policies.
- Change where new objects land by default:
```powershell
redircmp "OU=Workstations,DC=lab,DC=internal"
redirusr "OU=Staff,DC=lab,DC=internal"
```
- OUs are created with **Protect from accidental deletion** turned on.
  - Deleting a protected OU returns "Access denied", even for Domain Admins.
  - Turn the protection off first.
- Every user has two login names:
  - **UPN:** `jdoe@lab.internal` (email-style, the modern default).
  - **SAM account name:** `LAB\\jdoe` (legacy, 20-character limit).

### Daily commands
```powershell
Search-ADAccount -LockedOut                                          # Locked-out accounts
Unlock-ADAccount -Identity jdoe                                      # Unlock one user
Search-ADAccount -AccountInactive -TimeSpan 90.00:00:00 -UsersOnly   # No login in 90 days
Get-ADUser jdoe -Properties *                                        # All attributes for one user
```

---

## 3.2 Groups

### Types
- **Security group:** used for permissions. Can also be mail-enabled.
- **Distribution group:** email only. Can't be given permissions.

### Scopes

| Scope | Who can be a member | Where it can be used | Role |
|---|---|---|---|
| Global | Accounts from its own domain only | Anywhere in the forest or trusted forests | Groups people by role (e.g. "Finance") |
| Domain Local | Accounts and groups from any domain or trusted forest | Only in its own domain | Grants access to a resource |
| Universal | Accounts and groups from any domain in the forest | Anywhere in the forest | Forest-wide groups |

- Universal group membership is stored in the **Global Catalog**.

### AGDLP
```
Accounts  →  Global group  →  Domain Local group      →  Permission
  jdoe    →  GG-Finance    →  DL-FinanceShare-Modify  →  "Modify" on the Finance share
```
- To onboard a new finance user, add them to `GG-Finance`. They get every finance resource, and the resource permissions never need to change.
- Small single-domain environments often assign global groups directly to resources. AGDLP is the cleaner, exam-standard approach.

### Group changes take effect at the next login
- Group membership is read at login and stored in the Kerberos ticket.
- **Users:** log off and back on to pick up new groups.
- **Computers:** reboot, or clear the computer's tickets:
```powershell
klist -li 0x3e7 purge
```
- This is the usual cause of "I added them to the group and it still doesn't work."

### Users from other forests
- Adding a user from a trusted forest to a Domain Local group creates a placeholder in the **ForeignSecurityPrincipals** container. This is expected; don't delete it.

---

## 3.3 Service Accounts

- The legacy approach is a normal user account with "password never expires." The password is shared, rarely changed, and works forever if it leaks.

| Option | Password managed by | Scope | Use when |
|---|---|---|---|
| Normal user account | A human, rarely changed | Anywhere | Only if the app supports nothing else |
| Built-in accounts (LocalSystem, NetworkService, LocalService) | Windows | One server | Simple local services |
| Virtual account (`NT SERVICE\\AppName`) | Windows | One server | Services that only need local access |
| sMSA | AD, automatic | One server | Single-server apps |
| gMSA | AD, automatic | Many servers | The default choice for most apps |
| dMSA | AD, automatic | Many servers | Replacing a legacy service account (Windows Server 2025) |

- **LocalSystem** has full control of the server. Use it only when required.

### gMSA
- AD generates a random 240-character password and rotates it every 30 days by default.
- No person knows the password. Only servers you authorize can retrieve it.
- Configure the service to log on as `DOMAIN\\name$` with the password left blank. The `$` marks a machine-style account.
- It requires a **KDS root key**, created once per forest.
  - Production: `Add-KdsRootKey -EffectiveImmediately`, then wait 10 hours for replication.
- Some older applications don't support gMSAs. Check the vendor's documentation.

### dMSA
- New in Windows Server 2025.
- Replaces a legacy service account: the dMSA takes over its permissions, and the old account is disabled. The app doesn't need to be reconfigured from scratch.
- Security note: the 2025 "BadSuccessor" research showed that anyone with rights to create objects in an OU could abuse dMSAs to take over accounts. Restrict who has create rights in OUs.

---

## 3.4 Delegation

- **Delegation** grants a group specific tasks on specific OUs, without Domain Admin rights.
  - Example: helpdesk can reset passwords for users in the Staff OU, and nothing else.
- Use the **Delegation of Control Wizard**: ADUC, right-click the OU, then **Delegate Control**.
  - Built-in task: "Reset user passwords and force password change at next logon."
- Always delegate to a **group**, never to one person.

### Protected admin accounts
- Members of admin groups (Domain Admins, Enterprise Admins, Administrators, Account Operators, and others) are **protected**.
- **SDProp** runs every 60 minutes and resets their permissions to the **AdminSDHolder** template, which removes any delegation.
- A former admin keeps `adminCount = 1` after being removed from the admin group. Delegated helpdesk still can't reset that user's password.

### Viewing permissions
- **GUI:** ADUC, then View, Advanced Features. Right-click the OU, then Properties, Security, Advanced.
- **Command line:**
```powershell
dsacls "OU=Staff,OU=Lab,DC=lab,DC=internal"
```

---

## 3.5 Lab: OUs, AGDLP, Delegation, and a gMSA

Environment: DC01 and DC02 from Chapters 1–2, domain `lab.internal`.

**Mac terminal**
```bash
# 0. Start both DCs
az vm start -g rg-winsrv-lab -n DC01
az vm start -g rg-winsrv-lab -n DC02
```

**PowerShell on DC01**
```powershell
# 1. OUs
New-ADOrganizationalUnit -Name "Lab" -Path "DC=lab,DC=internal"
New-ADOrganizationalUnit -Name "Staff" -Path "OU=Lab,DC=lab,DC=internal"
New-ADOrganizationalUnit -Name "Groups" -Path "OU=Lab,DC=lab,DC=internal"

# 2. Users (prompts once for a shared test password)
$pw = Read-Host -AsSecureString "Password for new users"
New-ADUser -Name "Jane Doe" -SamAccountName jdoe -UserPrincipalName jdoe@lab.internal -Path "OU=Staff,OU=Lab,DC=lab,DC=internal" -AccountPassword $pw -Enabled $true
New-ADUser -Name "Sam Lee" -SamAccountName slee -UserPrincipalName slee@lab.internal -Path "OU=Staff,OU=Lab,DC=lab,DC=internal" -AccountPassword $pw -Enabled $true
New-ADUser -Name "Helpdesk Tech" -SamAccountName hd.tech -UserPrincipalName hd.tech@lab.internal -Path "OU=Lab,DC=lab,DC=internal" -AccountPassword $pw -Enabled $true

# 3. AGDLP groups
New-ADGroup -Name "GG-Finance" -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=Lab,DC=lab,DC=internal"
New-ADGroup -Name "DL-FinanceShare-Modify" -GroupScope DomainLocal -GroupCategory Security -Path "OU=Groups,OU=Lab,DC=lab,DC=internal"
Add-ADGroupMember -Identity GG-Finance -Members slee
Add-ADGroupMember -Identity DL-FinanceShare-Modify -Members GG-Finance
Get-ADGroupMember DL-FinanceShare-Modify -Recursive      # Should show Sam Lee

# 4. Helpdesk group
New-ADGroup -Name "GG-Helpdesk" -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=Lab,DC=lab,DC=internal"
Add-ADGroupMember -Identity GG-Helpdesk -Members hd.tech
```

**Delegate password resets (GUI on DC01)**
1. Run `dsa.msc`.
2. Expand `lab.internal`, then `Lab`. Right-click **Staff**, then **Delegate Control**.
3. Click **Add**, enter `GG-Helpdesk`, then **OK** and **Next**.
4. Tick **"Reset user passwords and force password change at next logon."**
5. Click **Next**, then **Finish**.

**PowerShell on DC01**
```powershell
# 5. Test the delegation as the helpdesk tech
$cred = Get-Credential LAB\hd.tech

# Inside the Staff OU: should succeed (no output)
Set-ADAccountPassword -Identity jdoe -Reset -NewPassword (Read-Host -AsSecureString "New password for jdoe") -Credential $cred

# Outside the Staff OU (Chapter 2 test user): should return "Access is denied"
Set-ADAccountPassword -Identity tkelowna -Reset -NewPassword (Read-Host -AsSecureString "New password") -Credential $cred

# 6. gMSA
# LAB ONLY: back-dates the key to skip the 10-hour wait. Production: -EffectiveImmediately
Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10))

New-ADGroup -Name "GG-AppServers" -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=Lab,DC=lab,DC=internal"
Add-ADGroupMember -Identity GG-AppServers -Members "DC02$"

New-ADServiceAccount -Name gmsa-app -DNSHostName gmsa-app.lab.internal -PrincipalsAllowedToRetrieveManagedPassword GG-AppServers
```

**PowerShell on DC02**
```powershell
# 7. Refresh DC02's group membership, then install and test the gMSA
klist -li 0x3e7 purge
Install-ADServiceAccount -Identity gmsa-app
Test-ADServiceAccount -Identity gmsa-app      # Expected: True. If False, reboot DC02 and retest
```

Note: in production, a gMSA runs on an app server, not a DC. DC02 is used here because it's the only other server in the lab. To assign a gMSA to a service, open `services.msc` and set **Log On As** to `LAB\\gmsa-app$`, with both password fields blank.

**Mac terminal**
```bash
# 8. Stop billing
az vm deallocate -g rg-winsrv-lab -n DC01
az vm deallocate -g rg-winsrv-lab -n DC02
```

**Expected results**
- `Get-ADGroupMember -Recursive` shows Sam Lee in `DL-FinanceShare-Modify`.
- The helpdesk tech can reset `jdoe`, and gets "Access is denied" for `tkelowna`.
- `Test-ADServiceAccount` returns `True` on DC02.

---

## Key Takeaways

1. OUs can take GPOs and delegation. The built-in containers can't take GPOs.
2. A new PC in the default `Computers` container gets no OU policies. Move it, or use `redircmp`.
3. Security groups are for permissions. Distribution groups are for email only.
4. Global groups hold people. Domain local groups grant access to resources. Universal groups span the forest.
5. AGDLP: accounts, then global groups, then domain local groups, then the permission.
6. Group changes apply at the next login for users, or the next reboot or ticket purge for computers.
7. Replace never-expiring service account passwords with gMSAs.
8. A gMSA needs a KDS root key, an authorized server group, and the account itself. Use `DOMAIN\\name$` with a blank password.
9. A dMSA (Windows Server 2025) takes over from a legacy service account. Restrict OU create rights because of BadSuccessor.
10. Delegate specific tasks, on specific OUs, to groups.
11. Admin accounts are protected by AdminSDHolder and SDProp. Former admins keep `adminCount = 1`, which blocks helpdesk resets.

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
