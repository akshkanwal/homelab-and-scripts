# Lab 01 — Azure Environment Setup

**Repo:** homelab-and-scripts  
**Date Completed:** June 2026  
**Certification Track:** AZ-104 Microsoft Azure Administrator

## Lab Overview

This lab covers the foundational setup of an Azure environment from scratch — creating a tenant and subscription, configuring cost controls, establishing a resource group, and adopting a consistent naming convention. These are the first steps in any real Azure deployment and the building blocks everything else in this lab series sits on.

The goal was not just to click through the portal, but to understand *why* each layer of the Azure hierarchy exists and what it controls.

---

## Architecture Diagram

```
Azure Active Directory Tenant
│  (akshkanwal — Identity and access root)
│
└── Subscription: Pay-as-you-go (CAD Billing)
    │
    ├── Cost Management
    │   ├── Budget: $10 CAD
    │   ├── Alert 1: Actual spend ≥ 80% ($8 CAD) → Email notification
    │   └── Alert 2: Forecasted spend ≥ 80% ($8 CAD) → Email notification
    │
    └── Resource Group: rg-azurelab
        Region: Canada Central
        │
        └── [Future resources deployed here]
```

---

## Resources Created

| Resource | Name | Details |
|---|---|---|
| Tenant | akshkanwal | Azure AD root — identity and access management |
| Subscription | Pay-as-you-go | CAD billing, linked to tenant |
| Budget | $10 CAD | With actual and forecasted alert thresholds |
| Resource Group | `rg-azurelab` | Canada Central — container for all lab resources |

---

## Naming Convention Adopted

All Azure resources in this lab series follow the pattern:

```
type-project-environment
```

**Examples:**
| Resource | Name | Breakdown |
|---|---|---|
| Resource Group | `rg-azurelab` | rg (resource group) — azurelab (project) |
| Virtual Network | `vnet-watchguard-lab` | vnet — watchguard — lab |
| Virtual Machine | `vmwgfirebox` | vm — wg (watchguard) — firebox |
| Subnet | `subnet-wan` | subnet — wan (role) |

Consistent naming makes resources immediately identifiable in large subscriptions and is a requirement in real enterprise environments where dozens of teams deploy into the same tenant.

---

## Concepts Learned

### Azure Hierarchy

```
Management Groups    ← Govern multiple subscriptions with policy
    │
    Subscriptions    ← Billing boundary and access control scope
        │
        Resource Groups  ← Logical container for related resources
            │
            Resources    ← Individual services (VMs, VNets, etc.)
```

**Tenant** — The Azure Active Directory instance. Root of identity and access. One organization = one tenant (typically).

**Subscription** — The billing unit. Resources are deployed into subscriptions. A tenant can have multiple subscriptions (e.g. Dev, Prod, Lab).

**Resource Group** — A logical container for resources that share a lifecycle. Deleting a resource group deletes everything inside it. Resources in the same group are typically deployed, managed, and decommissioned together.

**Resource** — An individual Azure service: a VM, a VNet, a storage account, a public IP, etc.

### Azure Resource Manager (ARM)

ARM is the deployment and management layer for all Azure resources. Every action taken in the portal, CLI, PowerShell, or SDK goes through ARM. ARM handles:
- Authentication and authorization (via Azure RBAC)
- Template-based deployments (ARM templates / Bicep)
- Resource locking and tagging
- Consistent API surface via REST

### REST API

Azure is entirely API-driven. The portal is a GUI built on top of the same REST API accessible via CLI, PowerShell (`Az` module), SDKs, and direct HTTP calls. Understanding this means anything done in the portal can be scripted, automated, and templated.

### Azure Policy

Azure Policy enforces organizational rules at scale. Policies can:
- Audit resources that do not meet a standard (e.g. all VMs must have a specific tag)
- Deny deployment of resources that violate rules (e.g. no resources outside Canada Central)
- Auto-remediate non-compliant resources

In enterprise environments, Policy is how governance is enforced without relying on manual processes.

### Tags

Key-value metadata attached to resources. Used for:
- Cost allocation (tag resources by department or project, then filter billing)
- Automation (scripts target resources by tag rather than hardcoded names)
- Governance (Policy can require specific tags on all resources)

### Regions and Availability Zones

**Region:** A geographic area containing one or more Azure datacentres. Resources are deployed to a specific region. Canada Central (Toronto) was selected for this lab — low latency from BC and data residency within Canada.

**Availability Zones:** Physically separate datacentre locations within a single region. Deploying resources across AZs provides redundancy against a single facility failure. AZ-redundant deployments are a key concept in AZ-104 and in real production architecture.

---

## Next Steps

- Deploy a virtual machine into `rg-azurelab` and document the compute concepts (Lab 03)
- Create a VNet and practice subnetting, NSG configuration, and routing (Lab 04)
- Explore ARM template export to understand infrastructure-as-code
- Review AZ-104 topic: Manage Azure subscriptions and governance

---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
