# Deploy Windows Server VM in WatchGuard Lab
# Author: Aksh
# Date: June 2026

New-AzVM `
  -ResourceGroupName "rg-wg-firebox" `
  -Name "vm-win-client" `
  -Location "canadacentral" `
  -Image "MicrosoftWindowsServer:WindowsServer:2022-datacenter-core:latest" `
  -VirtualNetworkName "vnet-watchguard-lab" `
  -SubnetName "subnet-lan" `
  -Size "Standard_D2s_v3"
