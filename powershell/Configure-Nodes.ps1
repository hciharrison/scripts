<#
.Synopsis
   Configuration Script for HCI Nodes after OS Installation
.DESCRIPTION
    Run on each node after OS installation to configure them    
.EXAMPLE
    PS C:\> .\Configure-Nodes.ps1
    Logs Folder found at Logs\nodeconfig\
    Logfiles for configuring nodes will be saved to Logs\nodeconfig\
.NOTES
    Edit the Parameters and IP Addreses in the EDIT SECTION for your deployment, copy Script to Nodes via the Remote Access Card, run Script
    The IPs section has examples of configuring switched and switchless nodes, comment / uncomment as needed
    Requires Hyper-V Role to be installed for SET Team creation, script will prompt to install and reboot server if needed (then re-run script)
#>

<#
### TO DO ####
Variables for Adapter suffix
   Then update the renaming commands with that variable
Variable for Storage Adapter network prefix
#>

######## EDIT SECTION ########
#### ONLY SET THESE VARIABLES AS PER YOUR DEPLOYMENT #####
#region Script Parameters
$pathToLogs = "Logs\nodeconfig\"
$hostnames = "ashci-c6-h1","ashci-c6-h2"
$SETAdapterNaming = "MGMT"
$StorageAdapterNaming = "STORAGE"
$vSwitchName = "vSwitch1"
$Domain = "lab01.local"
[int]$NetPrefix = "24"
#endregion

#region Set IPs
    ### SET NODE IP ADDRESSES ###
    <# IF DIRECT CONNECT SWITCHLESS - 3-Node
    $nodeips = @{"ashci-c1-n1-MGMT" = "10.10.1.3";  "ashci-c1-n1-STORAGE-A" = "192.168.10.3"; "ashci-c1-n1-STORAGE-B" = "192.168.11.3"; "ashci-c1-n1-STORAGE-C" = "192.168.12.3"; "ashci-c1-n1-STORAGE-D" = "192.168.13.3";
                "ashci-c1-n2-MGMT" = "10.10.1.4";  "ashci-c1-n2-STORAGE-A" = "192.168.10.4"; "ashci-c1-n2-STORAGE-B" = "192.168.11.4"; "ashci-c1-n2-STORAGE-C" = "192.168.12.4"; "ashci-c1-n2-STORAGE-D" = "192.168.13.4";
                "ashci-c1-n3-MGMT" = "10.10.1.5";  "ashci-c1-n3-STORAGE-A" = "192.168.10.5"; "ashci-c1-n3-STORAGE-B" = "192.168.11.5"; "ashci-c1-n3-STORAGE-C" = "192.168.12.5"; "ashci-c1-n3-STORAGE-D" = "192.168.13.5";
               }
    #>
    
    <# IF SWITCHED - 4-Node
    $nodeips = @{"ashci-c1-n1-MGMT" = "10.10.1.3";  "ashci-c1-n1-STORAGE-A" = "10.10.2.3"; "ashci-c1-n1-STORAGE-B" = "10.10.3.3";
                "ashci-c1-n2-MGMT" = "10.10.1.4";  "ashci-c1-n2-STORAGE-A" = "10.10.2.4"; "ashci-c1-n2-STORAGE-B" = "10.10.3.4";
                "ashci-c1-n3-MGMT" = "10.10.1.5";  "ashci-c1-n3-STORAGE-A" = "10.10.2.5"; "ashci-c1-n3-STORAGE-B" = "10.10.3.5";
                "ashci-c1-n4-MGMT" = "10.10.1.6";  "ashci-c1-n4-STORAGE-A" = "10.10.2.6"; "ashci-c1-n4-STORAGE-B" = "10.10.3.6";
               }
    #>

    # IF SWITCHED - 2-Node - 1 x Site
    $nodeips = @{"ashci-c6-h1-MGMT" = "10.10.1.81";  "ashci-c6-h1-STORAGE-A" = "192.168.10.81"; "ashci-c6-h1-STORAGE-B" = "192.168.11.81";
                "ashci-c6-h2-MGMT" = "10.10.1.82";  "ashci-c6-h2-STORAGE-A" = "192.168.10.82"; "ashci-c6-h2-STORAGE-B" = "192.168.11.82";
               }
    $defaultgateway = "10.10.1.1"
    $dnsservers = "10.10.1.20","10.10.1.21","10.10.2.20"
#endregion
####### DO NOT EDIT BELOW ########


#########################
###### START POINT ######
#Prompt for elevated console
Read-Host "Script must be run as Administrator, press Enter to continue or stop the script and open a elevated console to run again"


#region select hostname
#Loop to ensure selection is made           
Do
{
Write-Host "Please choose the Hostname of the node"
For ($i=0; $i -lt $hostnames.Count; $i++)  {
Write-Host "$($i+1): $($hostnames[$i].Name) - $($hostnames[$i])"
}
    [int]$number = Read-Host "Enter number to select Hostname: "
    if([int]$number -eq 0)
    {
    Write-Host "No Selection Made!" -ForegroundColor Yellow
    }

}While([int]$number -eq 0)#end loop

$Hostname = $($Hostnames[$number-1])
Write-Host "$Hostname selected" -ForegroundColor Yellow
#endregion


#region Configure logging
  #$pathToLogs = "Logs\nodeconfig\"
  $datetimelogfile = get-date -format "ddMMyyyy-HHmmss"
  $logfilename = "$pathToLogs" +$hostname+ "_nodeconfig_" +$datetimelogfile+ ".log"
 
  #Function to write to log file
  function WriteLog($message) 
    {
      $datetime = get-date -format "dd-MM-yyyy-HH:mm:ss"
      $datetime +" - "+ $message | Add-Content $logfilename 
      $error.clear()
      Write-Host $message
      Start-Sleep 1
    }

  #Function to check for errors
  function CheckError($success,$failure) 
    {
      if (!$error) 
          {
            WriteLog("$success") 
          }
      else 
          {
            WriteLog("#### Error #### $failure ### $error") 
          }
      $error.clear()
    }

 #Check and create Logs Folder if needed
  $CheckLogPath = Test-Path -Path "$pathToLogs"
  If(!$CheckLogPath)
    {
      Write-Host "Logs Folder not found" -ForegroundColor Yellow
      New-Item $pathToLogs -ItemType Directory | Out-Null
      Write-Host "Logs Folder created at $pathToLogs" -ForegroundColor Yellow
    }
  Else
    {
      Write-Host "Logs Folder found at $pathToLogs" -ForegroundColor Green
    }

  #Confirm log file location
  $Location = Get-Location
  WriteLog("Logfile located at $Location\$pathToLogs$logfilename")
  $error.clear()
#endregion

WriteLog("$Hostname selected")


#region Check if the Hyper-V Role is Installed
WriteLog("Checking for Hyper-V role")
$CheckRoleHV = (Get-WindowsFeature -Name Hyper-V).Installed
if($CheckRoleHV -eq $true)
{ WriteLog("Hyper-V Role is installed")
}else
  {
    Read-Host "Hyper-V Role is not installed, press enter to install it and reboot the Server, or stop the Script and install manually"
    Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart
    CheckError("Hyper-V installed")
  }
#endregion

      
#region Configure Management Networking
    WriteLog(">> Configure SET Team and Management networking <<")
    #1. Select first Adapter
    #List Adapters to choose from
    ######## TURN INTO A FUNCTION? #########
    $Adapters = Get-NetAdapter | Sort-Object MacAddress
    #Loop to ensure selection is made           
    Do
    {
    Write-Host "Choose 1st SET Team Adapter:"
    For ($i=0; $i -lt $Adapters.Count; $i++)  {
    Write-Host "$($i+1): $($Adapters[$i].Name) - $($Adapters[$i].InterfaceDescription) - $($Adapters[$i].MacAddress)"
    }
      [int]$number = Read-Host "Enter number to select Adapter: "
        if([int]$number -eq 0)
        {
        Write-Host "No Selection Made!" -ForegroundColor Yellow
        }

    }While([int]$number -eq 0)#end loop

    $SETAdapter1 = $($Adapters[$number-1])
    $SETAdapter1Name = ($SETAdapter1).Name
    CheckError("First Adapter chosen for SET Team is ""$SETAdapter1Name""")
    #$SETAdapter1 
    #[int]$number
    #$SETAdapter1Name

    #2. Select second Adapter
    #List Adapters to choose from
    $Adapters = Get-NetAdapter | Sort-Object MacAddress
    #Loop to ensure selection is made
    Do
    {
        Write-Host "Choose 2nd SET Team Adapter:"
        For ($i=0; $i -lt $Adapters.Count; $i++)  {
        Write-Host "$($i+1): $($Adapters[$i].Name) - $($Adapters[$i].InterfaceDescription) - $($Adapters[$i].MacAddress)"
    }
      [int]$number = Read-Host "Enter number to select Adapter: "
        if([int]$number -eq 0)
        {
        Write-Host "No Selection Made!" -ForegroundColor Yellow
        }

    }While([int]$number -eq 0)#end loop

    $SETAdapter2 = $($Adapters[$number-1])
    $SETAdapter2Name = ($SETAdapter2).Name
    CheckError("Second Adapter chosen for SET Team is ""$SETAdapter2Name""")
    #$SETAdapter1 
    #[int]$number
    #$SETAdapter1Name

    #3. Rename Adapters
    WriteLog("Configuring SET Adapters and creating SET vSwitch")
    Rename-NetAdapter -Name $SETAdapter1.Name -NewName "$SETAdapterNaming-A"
    CheckError("SET Adapter ""$SETAdapter1Name"" renamed to $SETAdapterNaming-A")
    Rename-NetAdapter -Name $SETAdapter2.Name -NewName "$SETAdapterNaming-B"
    CheckError("SET Adapter ""$SETAdapter2Name"" renamed to $SETAdapterNaming-B")
  
    #4. Setting advanced settings
    # Set MGMT Jumbo MTU - QLogic supports "9014"
    WriteLog("Setting jumbo MTU on management interfaces")
    Get-NetAdapter * | Where-Object { $_.Name -eq "$SETAdapterNaming-A" } | Set-NetAdapterAdvancedProperty -RegistryKeyword "*JumboPacket" -Registryvalue 9014
    CheckError("Jumbo MTU set successfully on $SETAdapterNaming-A")
    Get-NetAdapter * | Where-Object { $_.Name -eq "$SETAdapterNaming-B" } | Set-NetAdapterAdvancedProperty -RegistryKeyword "*JumboPacket" -Registryvalue 9014
    CheckError("Jumbo MTU set successfully on $SETAdapterNaming-B")
   
    #5. Create vSwitch
    WriteLog("Creating vSwitch")
    New-VMSwitch -Name $vSwitchName -NetAdapterName "MGMT-A","MGMT-B" -EnableEmbeddedTeaming $true -MinimumBandwidthMode Weight -Confirm:$false | Out-Null
    CheckError("SET vSwitch created")

    #6. Rename ManagementOS VMNetAdapter NIC and set Jumbo MTU
    WriteLog("Renaming vEthernet NIC and setting Jumbo MTU")
    Rename-VMNetworkAdapter -ManagementOS -Name vSwitch1 -NewName Management
    #Rename-NetAdapter -Name "vEthernet (vSwitch1)" -NewName "vEthernet (Management)"
    CheckError("ManagementOS Adapter renamed")
    Set-NetAdapterAdvancedProperty -Name "vEthernet (Management)" -DisplayName "Jumbo Packet" -DisplayValue "9014 Bytes"
    CheckError("Jumbo MTU set successfully on vEthernet")

    #7. Set IP Addressing
    WriteLog("Setting IP Addresses for Management")
    $interface = Get-NetAdapter | Where-Object { $_.name -eq "vEthernet (Management)" }
    New-NetIPAddress -InterfaceIndex $interface.ifIndex -IPAddress $nodeips.Get_Item("$hostname-MGMT") -Prefixlength $NetPrefix -DefaultGateway $defaultgateway -Confirm:$false  | Out-Null
    Start-Sleep -s 5
    CheckError("Management IP, subnet mask and Gateway set")
    Set-DnsClientServerAddress -InterfaceIndex $interface.IfIndex -ServerAddresses $dnsservers -Confirm:$false
    CheckError("DNS Servers set")
#endregion


#region Configure Storage Networking
    WriteLog(">> Configure Storage networking <<")
#1. Select first Adapter
    #List Adapters to choose from
    ######## TURN INTO A FUNCTION? #########
    $Adapters = Get-NetAdapter | Sort-Object MacAddress
    #Loop to ensure selection is made           
    Do
    {
    Write-Host "Choose 1st Storage Adapter:"
    For ($i=0; $i -lt $Adapters.Count; $i++)  {
    Write-Host "$($i+1): $($Adapters[$i].Name) - $($Adapters[$i].InterfaceDescription) - $($Adapters[$i].MacAddress)"
    }
      [int]$number = Read-Host "Enter number to select Adapter: "
        if([int]$number -eq 0)
        {
        Write-Host "No Selection Made!" -ForegroundColor Yellow
        }

    }While([int]$number -eq 0)#end loop

    $StorageAdapter1 = $($Adapters[$number-1])
    $StorageAdapter1Name = ($StorageAdapter1).Name
    CheckError("First Storage Adapter chosen is ""$StorageAdapter1Name""")
    #$SETAdapter1 
    #[int]$number
    #$SETAdapter1Name

    #2. Select second Adapter
    #List Adapters to choose from
    $Adapters = Get-NetAdapter | Sort-Object MacAddress
    #Loop to ensure selection is made
    Do
    {
        Write-Host "Choose 2nd Storage Adapter:"
        For ($i=0; $i -lt $Adapters.Count; $i++)  {
        Write-Host "$($i+1): $($Adapters[$i].Name) - $($Adapters[$i].InterfaceDescription) - $($Adapters[$i].MacAddress)"
    }
      [int]$number = Read-Host "Enter number to select Adapter: "
        if([int]$number -eq 0)
        {
        Write-Host "No Selection Made!" -ForegroundColor Yellow
        }

    }While([int]$number -eq 0)#end loop

    $StorageAdapter2 = $($Adapters[$number-1])
    $StorageAdapter2Name = ($StorageAdapter2).Name
    CheckError("Second Storage Adapter chosen is ""$StorageAdapter2Name""")

    #3. Rename Adapters
    WriteLog("Configuring Storage Adapters")
    Rename-NetAdapter -Name $StorageAdapter1.Name -NewName "$StorageAdapterNaming-A"
    CheckError("SET Adapter ""$StorageAdapter1Name"" renamed to $StorageAdapterNaming-A")
    Rename-NetAdapter -Name $StorageAdapter2.Name -NewName "$StorageAdapterNaming-B"
    CheckError("SET Adapter ""$StorageAdapter2Name"" renamed to $StorageAdapterNaming-B")
  
    #4. Setting advanced settings
    # Set MGMT Jumbo MTU - QLogic supports "9014"
    WriteLog("Setting jumbo MTU on Storage interfaces")
    Get-NetAdapter * | Where-Object { $_.Name -eq "$StorageAdapterNaming-A" } | Set-NetAdapterAdvancedProperty -RegistryKeyword "*JumboPacket" -Registryvalue 9014
    CheckError("Jumbo MTU set successfully on $StorageAdapterNaming-A")
    Get-NetAdapter * | Where-Object { $_.Name -eq "$StorageAdapterNaming-B" } | Set-NetAdapterAdvancedProperty -RegistryKeyword "*JumboPacket" -Registryvalue 9014
    CheckError("Jumbo MTU set successfully on $StorageAdapterNaming-B")
   
    #5. Set IP Addressing on first Storage Adapter
    WriteLog("Setting IP Addresses for $StorageAdapterNaming-A")
    $interface = Get-NetAdapter | Where-Object { $_.name -eq "$StorageAdapterNaming-A" }
    New-NetIPAddress -InterfaceIndex $interface.ifIndex -IPAddress $nodeips.Get_Item("$hostname-STORAGE-A") -Prefixlength 24 -Confirm:$false | Out-Null
    Start-Sleep -s 5
    CheckError("$StorageAdapterNaming-A IP and subnet mask set")

    #6. Set IP Addressing on first Storage Adapter
    WriteLog("Setting IP Addresses for $StorageAdapterNaming-B")
    $interface = Get-NetAdapter | Where-Object { $_.name -eq "$StorageAdapterNaming-B" }
    New-NetIPAddress -InterfaceIndex $interface.ifIndex -IPAddress $nodeips.Get_Item("$hostname-STORAGE-B") -Prefixlength 24 -Confirm:$false  | Out-Null
    Start-Sleep -s 5
    CheckError("$StorageAdapterNaming-B IP and subnet mask set")

    #7. Enable RDMA
    WriteLog("Enabling RDMA on Storage Adapters")
    Enable-NetAdapterRdma -Name $StorageAdapterNaming*
    CheckError("RDMA enabled successfully")
#endregion


#region Add Roles
    WriteLog("Installing Windows Roles")
    Install-WindowsFeature -Name Failover-Clustering, FS-Data-Deduplication, BitLocker, Data-Center-Bridging, RSAT-AD-PowerShell, Storage-Replica, FS-SMBBW -IncludeAllSubFeature -IncludeManagementTools -confirm:$false -Restart:$false | Out-Null
    CheckError("Windows Roles installed")
#endregion


#region Set various OS config settings
    #1. Set time zone and regional settings
    WriteLog("Setting timezone")
    Set-TimeZone -Name "GMT Standard Time"
    Set-WinUserLanguageList -LanguageList en-gb -Force
    Set-WinSystemLocale -systemlocale en-gb
    CheckError("Timezone set successfully")
   
    #2. Allow RDP Connections to this computer
    WriteLog("Enabling RDP")
    #Require Network Level Authentication
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name UserAuthentication -Value 1
    #Enable firewall rule
    Set-NetFirewallRule -DisplayGroup "Remote Desktop" -Enabled True
    CheckError("RDP Enabled succesfully")

    #3. Enable iWARP firewall rule (if iWARP is used)
    WriteLog("Enabling iWARP firewall rule")
    Enable-NetFirewallRule -Name "FPSSMBD-iWARP-In-TCP"
    CheckError("iWARP firewall rule enabled")

    #4. Disable disconnected adapters
    WriteLog("Disabling disconnected Adapters")
    Get-NetAdapter | Where-Object { $_.Status -eq 'Disconnected' } | Disable-NetAdapter -confirm:$false
    CheckError("Disconnected Adapters disabled")

    #5. Allow ICMP
    WriteLog("Allowing ICMP")
    Set-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)" -Enabled True
    CheckError("ICMP allowed")

    #6. #Allow SMB-In
    WriteLog("Allowing SMB-In")
    Set-NetFirewallRule -DisplayName "File and Printer Sharing (SMB-In)" -Enabled True
    CheckError("SMB-In allowed")

    #7. Update the hardware timeout for Spaceport (requires reboot)
    WriteLog("Setting spaceport timeout")
    Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\spaceport\Parameters -Name HwTimeout -Value 0x00002710 | Out-Null
    CheckError("spaceport timeout set")

    #8. Remove SMB1
    WriteLog("remove SMB1")
    Uninstall-WindowsFeature -Name FS-SMB1 | Out-Null
    CheckError("SMB1 removed")
#endregion

WriteLog(">> Moving on to node domain join and rename <<")
Read-Host "Configuration complete, hit Enter to domain join node or stop script to exit"

#region Domain join and rename
    WriteLog("Domain join and rename node")
    #$Hostname = "node01"
    #$Domain = "lab01.local"
    #$Account = "lab01\user1"
    $CheckHostname = $Env:ComputerName
    if($Hostname -eq $CheckHostname)
    {
        Add-Computer -DomainName $Domain -Options JoinWithNewName,accountcreate -Restart:$false | Out-Null
    }
    Else
    {
        Rename-Computer -NewName $Hostname
        Start-Sleep 20
        Add-Computer -DomainName $Domain -Options JoinWithNewName,accountcreate -Restart:$false | Out-Null
    }
    CheckError("Domain join and rename operation successful")
#endregion

WriteLog("User input required to reboot node")
Read-Host "Domain join and rename complete, hit Enter to reboot node or stop script to exit"
Restart-Computer -Force
CheckError("Node was rebooted")
