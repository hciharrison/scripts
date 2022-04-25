## MANUAL BUILD STEPS ##
## Azure Stack HCI ##

#Manually run each section on each node in the cluster unless cluster wide settings
#Examples have been used in this document - change the values to reflect your solution

## WORKFLOW ##
#Ensure physical infrastructure / servers are powered and all Interfaces cabled correctly
#Download Latest GA ISO: https://azure.microsoft.com/en-us/products/azure-stack/hci/hci-download/
#Access servers via console or remote access card and mount media via USB or virtual connect
#Install OS on OS specific drive(s), e.g. BOSS Card (drives that won't be used by S2D)
#Once OS installed:
#Install Roles
#Name Phsycial Adapters
#Create SET Team for Mgmt, rename Mgmt Adapter
#Set Mgmt IP Address
#Enable RDP and log onto nodes remotely
#AD Join and set hostname
#Ensure time is syncing with Domain correctly
#Set time zone and regional settings
#Configure Storage Adapter IPs
#Uninstall SMB1
#Enable RDMA on Storage Adapters
#Enable Jumbo MTU on all adapters (but mainly Storage)
#Update Chipset, Drivers, Firmware and BIOS
#Patch OS before creating the cluster and especially before enabling S2D



#Install latest GA Azure Stack HCI OS


#Install roles now as need the hyper-v role to create vSwitch
Install-WindowsFeature -Name Hyper-V, Failover-Clustering, FS-Data-Deduplication, BitLocker, Data-Center-Bridging, RSAT-AD-PowerShell, Storage-Replica, FS-SMBBW -IncludeAllSubFeature -IncludeManagementTools –verbose


#Rename Adapters
#Assumes you have following configuration
#2 x Physical Intefaces for Management / Compute (which is where VM traffic will flow)
#2 x Storage Interfaces
#In this example only 1 x SET team is created and used for Mgmt and VM [compute] traffic
#Storage adapters are Raw with no teaming

#List Adapters
Get-NetAdapter

#You will need to identify you Adapters somehow, either by MAC address, Slot No, Description, link speed, etc.
#Note the adapter name
#Once you know which apapter is which you can rename them using these example commands
Rename-NetAdapter -Name "Ethernet" -NewName "MGMT-A"
Rename-NetAdapter -Name "Ethernet 2" -NewName "MGMT-B"
Rename-NetAdapter -Name "Ethernet 3" -NewName "STORAGE-A"
Rename-NetAdapter -Name "Ethernet 4" -NewName "STORAGE-B"


#Create SET Team - this example is to use same Team for Management and Compute
#Consider enabling SR-IOV at this point if you need guest RDMA as you can't enable it once the team is created '-EnableIov $true'
New-VMSwitch -Name SETvSwitch-MGMTCOMP -NetAdapterName "MGMT-A","MGMT-B" -EnableEmbeddedTeaming $true -MinimumBandwidthMode Weight -Verbose
#Rename the Management adapter
Rename-VMNetworkAdapter -ManagementOS -Name SETvSwitch-MGMTCOMP -NewName Management

#Set the VLAN and Mode (if needed)
Set-VMNetworkAdapterVlan -ManagementOS -Name Management -Access -VlanId 0


#Node01
#Set Mgmt IP Address - change the values for your deployment
$interface = Get-NetAdapter | ? { $_.name -eq "vEthernet (Management)" }
New-NetIPAddress -InterfaceIndex $interface.ifIndex -IPAddress "10.10.1.46" -PrefixLength 24 -DefaultGateway 10.10.1.1
Set-DnsClientServerAddress -InterfaceIndex $interface.IfIndex -ServerAddresses "10.10.1.20", "10.10.1.21"
Resolve-DnsName -Name $env:ComputerName


#Node02
#Set Mgmt IP Address - change the values for your deployment
$interface = Get-NetAdapter | ? { $_.name -eq "vEthernet (Management)" }
New-NetIPAddress -InterfaceIndex $interface.ifIndex -IPAddress "10.10.1.47" -PrefixLength 24 -DefaultGateway 10.10.1.1
Set-DnsClientServerAddress -InterfaceIndex $interface.IfIndex -ServerAddresses "10.10.1.20", "10.10.1.21"
Resolve-DnsName -Name $env:ComputerName


#Enable RDP using below command or via sconfig
#Allow RDP Connections to this computer
#Require Network Level Authentication
#Set firewall
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name UserAuthentication -Value 1
Set-NetFirewallRule -DisplayGroup "Remote Desktop" -Enabled True


#Log in via RDP

#Disable unused adapters
Get-NetAdapter | ? { $_.Status -eq 'Disconnected' } | Disable-NetAdapter -confirm:$false


#Domain Join Nodes
#Node01
$Hostname = "node01"
$Domain = "lab01.local"
$Account = "lab01\user1"
Rename-Computer -NewName $Hostname
Sleep 20
Add-Computer -DomainName $Domain -Credential $Account -Options JoinWithNewName,accountcreate -Restart

#Node02
$Hostname = "node02"
$Domain = "lab01.local"
$Account = "lab01\user1"
Rename-Computer -NewName $Hostname
Sleep 20
Add-Computer -DomainName $Domain -Credential $Account -Options JoinWithNewName,accountcreate -Restart


#Ensure time is syncing with domain correctly
w32tm /query /peers


#Set time zone and regional settings
Set-TimeZone -Name "GMT Standard Time"
Set-WinUserLanguageList -LanguageList en-gb -Force
Set-WinSystemLocale -systemlocale en-gb

#Set nice date format to your requirements
#Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name sCountry -Value "United Kingdom";
#Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name sLongDate -Value "dd MMMM yyyy";
#Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name sShortDate -Value "dd/MM/yyyy";
#Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name sShortTime -Value "HH:mm";
#Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name sTimeFormat -Value "HH:mm:ss";
#Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name sYearMonth -Value "MMMM yyyy";
#Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name iFirstDayOfWeek -Value 0;


#Add Storage IPs - change values for your deployment
#Node01
#Storage A
$interface = Get-NetAdapter | ? { $_.name -eq 'STORAGE-A' }
#remove-NetIPAddress -InterfaceIndex $interface.ifIndex
New-NetIPAddress -InterfaceIndex $interface.ifIndex -IPAddress "192.168.10.46" -PrefixLength 24
Sleep 3
#Storage B
$interface = Get-NetAdapter | ? { $_.name -eq 'STORAGE-B' }
#remove-NetIPAddress -InterfaceIndex $interface.ifIndex
New-NetIPAddress -InterfaceIndex $interface.ifIndex -IPAddress "192.168.11.46" -PrefixLength 24


#Node02
#Storage A
$interface = Get-NetAdapter | ? { $_.name -eq 'STORAGE-A' }
#remove-NetIPAddress -InterfaceIndex $interface.ifIndex
New-NetIPAddress -InterfaceIndex $interface.ifIndex -IPAddress "192.168.10.47" -PrefixLength 24
Sleep 3
#Storage B
$interface = Get-NetAdapter | ? { $_.name -eq 'STORAGE-B' }
#remove-NetIPAddress -InterfaceIndex $interface.ifIndex
New-NetIPAddress -InterfaceIndex $interface.ifIndex -IPAddress "192.168.11.47" -PrefixLength 24

#Disable regsiter dns on storage adapters
$Interfaces = Get-NetAdapter | ? { $_.name -like 'STORAGE*' }
foreach($Interface in $Interfaces) {
Set-DNSClient -InterfaceIndex $Interface.IfIndex -RegisterThisConnectionsAddress $false }


#Create SRLM Team if Stretched Cluster
#Create SET Team
New-VMSwitch -Name SETvSwitch-SRLM -NetAdapterName "SRLM-A","SRLM-B" -EnableEmbeddedTeaming $true ; Sleep 3 ; Rename-VMNetworkAdapter -ManagementOS -Name SETvSwitch-SRLM -NewName SR
Add-VMNetworkAdapter -ManagementOS -SwitchName SETvSwitch-SRLM -Name LM


#Allow ICMP
#Set-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)" -Enabled True
#Allow SMB-In
#Set-NetFirewallRule -DisplayName "File and Printer Sharing (SMB-In)" -Enabled True


#Storage related
#Remove SMB1
Uninstall-WindowsFeature -Name FS-SMB1

#Enable RDMA
Enable-NetAdapterRdma -Name STORAGE*
Get-NetAdapterRdma

#Set Jumbo MTU
$adapters = Get-NetAdapter
Foreach($adapter in $adapters) { Set-NetAdapterAdvancedProperty -Name $adapter.name -RegistryKeyword “*JumboPacket” -Registryvalue 9014 }
Get-NetAdapterAdvancedProperty -RegistryKeyword  *JumboPacket

#Enable iWARP firewall rule (if iWARP is used)
Enable-NetFirewallRule -Name "FPSSMBD-iWARP-In-TCP"


#Ensure Remote Management is enabled or use sconfig to enable it


#Before moving onto building the cluster and enabling S2D patch your servers
#Update Chipset, Drivers, Firmware and BIOS
#Patch OS ensuring you have the latest CU's installed


#Test cluster
Test-Cluster -Node node01,node02 -Include "Storage Spaces Direct","Inventory","Network","System Configuration"

#Create cluster with static IP - ignore strorage IPs if switchless
New-Cluster -Name azshci-cluster -Node node01,nod02 -NoStorage -StaticAddress "10.10.1.45"


#Add quroum
#Ideally setup a cloud witness or this can be used with a file share:
#https://docs.microsoft.com/en-us/windows-server/failover-clustering/deploy-cloud-witness
#Set-ClusterQuorum -FileShareWitness \\azshci-mgmt\shares\azshci-c1-witness



#After cluster is created
#SMB Bandwidth Limit
#Need to run on all nodes
#Set SMB bandswith limit - check its correct for the speed of you Adapaters
Set-SmbBandwidthLimit -Category LiveMigration -BytesPerSecond 750MB
#Set Max No Live Migrations
Set-VMHost -MaximumVirtualMachineMigrations 2
#Set Live Migration to SMB
Set-VMHost -VirtualMachineMigrationPerformanceOption SMB



#Cluster Networks
#Rename Cluster networks - change your IPs to match your deployment
Get-ClusterNetwork | sort Address | ft *

$newname = "MGMT"
$oldname = Get-ClusterNetwork  | ? {$_.Address -like "10.10.1.0" } | Select-Object Name
(Get-ClusterNetwork -Name $oldname.name).Name = $newname

$newname = "STORAGE-A"
$oldname = Get-ClusterNetwork  | ? {$_.Address -like "192.168.10.0" } | Select-Object Name
(Get-ClusterNetwork -Name $oldname.name).Name = $newname

$newname = "STORAGE-B"
$oldname = Get-ClusterNetwork  | ? {$_.Address -like "192.168.11.0" } | Select-Object Name
(Get-ClusterNetwork -Name $oldname.name).Name = $newname

Get-ClusterNetwork | sort Address | ft *


#Set Live Migration Network(s)
Get-ClusterResourceType -Name "Virtual Machine" | Set-ClusterParameter -Name MigrationExcludeNetworks -Value ([String]::Join(";",(Get-ClusterNetwork | Where-Object {$_.Name -notlike '*STORAGE*' }).ID))


#Enable storage spaces
Enable-ClusterS2D


#Update the hardware timeout for Spaceport - will require reboot of each node
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\spaceport\Parameters -Name HwTimeout -Value 0x00002710 -Verbose


#For iWarp enable port 5445
Enable-NetFirewallRule FPSSMBD-iWARP-In-TCP

#2-Node Nested Cache to tolerate cache drive failure if node is down
Get-StorageSubSystem Cluster* | Set-StorageHealthSetting -Name "System.Storage.NestedResiliency.DisableWriteCacheOnNodeDown.Enabled" -Value "True"

#Check RDMA Mode is iWarp or RoCE
Get-NetAdapterAdvancedProperty -name pSMB.1 -DisplayName "Network*"


#Configuration for RoCE
#Configure the DCB settings
#SMB always use Priority 3 as best practice
#Cluster HeartBeat uses Priority 7

#Create QoS Policies
New-NetQosPolicy "SMB" -NetDirectPortMatchCondition 445 -PriorityValue8021Action 3
New-NetQosPolicy "Cluster" -PriorityValue8021Action 7

# Turn on Flow Control for SMB and Cluster
Enable-NetQosFlowControl -Priority 3,7

# Make sure flow control is off for other traffic
Disable-NetQosFlowControl -Priority 0,1,2,4,5,6

#Disable DCBx
Set-NetQosDcbxSetting -Willing $false -Confirm:$false

# Apply a Quality of Service (QoS) policy to the target adapters
Enable-NetAdapterQos -InterfaceAlias "STORAGE-A","STORAGE-B"

# Give SMB Direct a minimum bandwidth of 50%
New-NetQosTrafficClass "SMB" -Priority 3 -BandwidthPercentage 50 -Algorithm ETS

#Give Cluser a minimum bandwith of 1%
New-NetQosTrafficClass "Cluster" -Priority 7 -BandwidthPercentage 1 -Algorithm ETS

#Disable Flow Controll on physical Nics
Set-NetAdapterAdvancedProperty -Name "STORAGE-A" -RegistryKeyword "*FlowControl" -RegistryValue 0
Set-NetAdapterAdvancedProperty -Name "STORAGE-B" -RegistryKeyword "*FlowControl" -RegistryValue 0

#Enable QoS and RDMA on nic's
Get-NetAdapterQos -Name "STORAGE-A","STORAGE-B" | Enable-NetAdapterQos
#RDMA should already be enabled above but check
#Get-NetAdapterRDMA -Name "NIC1","NIC2" | Enable-NetAdapterRDMA
Get-NetAdapterRdma
