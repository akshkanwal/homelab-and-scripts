#!/bin/bash
# WatchGuard Lab Session Startup Script
# Author: Aksh
# Date: June 2026

# Create and attach Public IP
az network public-ip create \
  --resource-group rg-wg-firebox \
  --name pip-wg-firebox \
  --sku Standard \
  --allocation-method Static \
  --dns-name wg-firebox-lab \
  --location canadacentral

az network nic ip-config update \
  --resource-group rg-wg-firebox \
  --nic-name vmwgfireboxEth0-NSG \
  --name ipconfig1 \
  --public-ip-address pip-wg-firebox

# Start VMs
az vm start --resource-group rg-wg-firebox --name vmwgfirebox
az vm start --resource-group rg-wg-firebox --name vm-linux-client

