Connect-AzAccount

New-AzVM `
  -ResourceGroupName "rg-wg-firebox" `
  -Name "vm-win-client" `
  -Location "canadacentral" `
  -Image "MicrosoftWindowsServer:WindowsServer:2022-datacenter-core:latest" `
  -SubnetId "/subscriptions/a8a0098a-207e-48b5-b2be-5ee996faaf7a/resourceGroups/rg-watchguard-lab/providers/Microsoft.Network/virtualNetworks/vnet-watchguard-lab/subnets/subnet-lan" `
  -Size "Standard_D2s_v3"

$vnet = Get-AzVirtualNetwork `
  -ResourceGroupName "rg-watchguard-lab" `
  -Name "vnet-watchguard-lab"

$subnet = Get-AzVirtualNetworkSubnetConfig `
  -VirtualNetwork $vnet `
  -Name "subnet-lan"

$nic = New-AzNetworkInterface `
  -ResourceGroupName "rg-wg-firebox" `
  -Name "vm-win-clientNic" `
  -Location "canadacentral" `
  -SubnetId $subnet.Id

$vm = New-AzVMConfig `
  -VMName "vm-win-client" `
  -VMSize "Standard_D2s_v3"

$cred = Get-Credential

$vm = Set-AzVMOperatingSystem `
  -VM $vm `
  -Windows `
  -ComputerName "vm-win-client" `
  -Credential $cred

$vm = Set-AzVMSourceImage `
  -VM $vm `
  -PublisherName "MicrosoftWindowsServer" `
  -Offer "WindowsServer" `
  -Skus "2022-datacenter-core" `
  -Version "latest"

$vm = Add-AzVMNetworkInterface `
  -VM $vm `
  -Id $nic.Id

New-AzVM `
  -ResourceGroupName "rg-wg-firebox" `
  -Location "canadacentral" `
  -VM $vm
