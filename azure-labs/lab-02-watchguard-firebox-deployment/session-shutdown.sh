#!/bin/bash
# WatchGuard Lab Session Shutdown Script
# Author: Aksh
# Date: June 2026

# Deallocate VMs
az vm deallocate --resource-group rg-wg-firebox --name vmwgfirebox
az vm deallocate --resource-group rg-wg-firebox --name vm-linux-client

# Detach and delete Public IP
az network nic ip-config update \
  --resource-group rg-wg-firebox \
  --nic-name vmwgfireboxEth0-NSG \
  --name ipconfig1 \
  --remove publicIpAddress

az network public-ip delete \
  --resource-group rg-wg-firebox \
  --name pip-wg-firebox
