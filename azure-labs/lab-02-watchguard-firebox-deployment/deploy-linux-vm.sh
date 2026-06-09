#!/bin/bash
# deploy-linux-vm.sh
# Deploy Ubuntu 22.04 VM into subnet-lan (cross-resource-group VNet reference)
#
# Usage:
#   chmod +x deploy-linux-vm.sh
#   ./deploy-linux-vm.sh
#
# Prerequisites:
#   - Azure CLI installed and logged in (az login)
#   - rg-watchguard-lab and vnet-watchguard-lab already exist
#   - subnet-lan exists with address prefix 10.10.2.0/24
#
# IMPORTANT: Replace <SUBSCRIPTION-ID> and <FIREBOX-LAN-IP> with real values
# before running. Never commit real IDs or IPs to version control.

set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────

SUBSCRIPTION_ID="<SUBSCRIPTION-ID>"
RG_VM="rg-wg-firebox"
RG_NET="rg-watchguard-lab"
VNET_NAME="vnet-watchguard-lab"
SUBNET_NAME="subnet-lan"
VM_NAME="vm-linux-client"
IMAGE="Ubuntu2204"
SIZE="Standard_D2s_v3"
ADMIN_USER="azureuser"
LOCATION="canadacentral"
FIREBOX_LAN_IP="<FIREBOX-LAN-IP>"

# Full subnet resource ID — required for cross-resource-group VNet references.
SUBNET_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NET}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/${SUBNET_NAME}"

# ─── Pre-flight ───────────────────────────────────────────────────────────────

echo "==> Verifying Azure CLI login..."
az account show --query "{Subscription:id, Name:name}" --output table

echo ""
echo "==> Verifying subnet exists..."
az network vnet subnet show \
  --resource-group "${RG_NET}" \
  --vnet-name "${VNET_NAME}" \
  --name "${SUBNET_NAME}" \
  --query "{Name:name, Prefix:addressPrefix}" \
  --output table

# ─── Deploy VM ────────────────────────────────────────────────────────────────

echo ""
echo "==> Deploying Linux VM: ${VM_NAME} (${SIZE}, ${IMAGE})"

az vm create \
  --resource-group "${RG_VM}" \
  --name "${VM_NAME}" \
  --image "${IMAGE}" \
  --subnet "${SUBNET_ID}" \
  --admin-username "${ADMIN_USER}" \
  --generate-ssh-keys \
  --size "${SIZE}"

# ─── Route Table (UDR) ────────────────────────────────────────────────────────
# Forces all LAN traffic through Firebox to prevent asymmetric routing.

echo ""
echo "==> Creating UDR rt-subnet-lan..."
az network route-table create \
  --resource-group "${RG_NET}" \
  --name rt-subnet-lan \
  --location "${LOCATION}" 2>/dev/null || echo "    Already exists."

az network route-table route create \
  --resource-group "${RG_NET}" \
  --route-table-name rt-subnet-lan \
  --name default-via-firebox \
  --address-prefix 0.0.0.0/0 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address "${FIREBOX_LAN_IP}" 2>/dev/null || echo "    Route already exists."

az network vnet subnet update \
  --resource-group "${RG_NET}" \
  --vnet-name "${VNET_NAME}" \
  --name "${SUBNET_NAME}" \
  --route-table rt-subnet-lan

echo ""
echo "==> Route table attached. Verifying routes..."
az network route-table show \
  --resource-group "${RG_NET}" \
  --name rt-subnet-lan \
  --query "routes[].{Name:name, Prefix:addressPrefix, NextHop:nextHopIpAddress}" \
  --output table

# ─── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo "==> Deployment complete."
echo "    SSH via Firebox SNAT: ssh -i ~/.ssh/id_rsa ${ADMIN_USER}@<PUBLIC-IP>"
echo ""
echo "    Deallocate when done:"
echo "    az vm deallocate --resource-group ${RG_VM} --name ${VM_NAME}"
echo "    az network public-ip delete --resource-group ${RG_VM} --name pip-wg-firebox"


---
*This repository was structured and documented with the assistance of Claude AI (Anthropic) as part of an agentic portfolio workflow.*
