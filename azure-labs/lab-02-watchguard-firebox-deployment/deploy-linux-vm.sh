#!/bin/bash
# Deploy Linux Client VM in WatchGuard Lab
# Author: Aksh
# Date: June 2026

az vm create \
  --resource-group rg-wg-firebox \
  --name vm-linux-client \
  --image Ubuntu2204 \
  --vnet-name vnet-watchguard-lab \
  --subnet subnet-lan \
  --admin-username azureuser \
  --generate-ssh-keys \
  --size Standard_D2s_v3 \
  --output table
