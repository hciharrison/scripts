<#
.Synopsis
   Configuration Script for HCI Nodes after OS Installation
.DESCRIPTION
    Run on each node after OS installation to configure them 
.EXAMPLE
    Edit the parameters for the cluster, copy Script to Nodes via the Remote Access Card, run Script
.EXAMPLE
    PS C:\> .\Configure-Nodes.ps1
    Logs Folder found at Logs\nodeconfig\
    Logfiles for configuring nodes will be saved to Logs\nodeconfig\
.NOTES
    Requires paramters specific to cluster
    Requires Hyper-V Role to be installed for SET Team creation, script will prompt to install and reboot server if needed (then script will need to be re-run)
#>


#Variables

#Prompt for elevated console
Read-Host "This script must be run as administrator on the host being built, press enter to continue or stop the script and open a elevated console and run again"

#region Configure logging
  $pathToLogs = "Logs\nodeconfig\"
  $datetimelogfile = get-date -format "ddMMyyyy-HHmmss"
  $logfilename = "$pathToLogs" +$hostname+ "_nodeconfig_" +$datetimelogfile+ ".log"

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
  WriteLog("Logfiles for setting up replication will be saved to $pathToLogs")
  $error.clear()


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
#endregion

#region Check if the Hyper-V Role is Installed
$CheckRoleHV = (Get-WindowsFeature -Name Hyper-V).Installed
if($CheckRoleHV -eq $True)
{ WriteLog("Hyper-V Role is installed")
  else
  {
    Read-Host "Hyper-V Role is not installed, press enter to install it and reboot the Server, or stop the Script and install them manually"
    Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart $true
  }
}
#endregion


#region Set Hostname and IPs
$hostname = Read-Host "Please enter the hostname in the format ashci-c1-n1"

    ### SET NODE IP ADDRESSES ###

    <# IF DIRECT CONNECT SWITCHLESS - 3-Node - 2 x Site
    $nodeips = @{"ashci-c1-n1-MGMT" = "10.44.83.3";  "ashci-c1-n1-STORAGE-A" = "10.44.82.131"; "ashci-c1-n1-STORAGE-B" = "10.44.82.163"; "ashci-c1-n1-STORAGE-C" = "10.44.83.195"; "ashci-c1-n1-STORAGE-D" = "10.44.83.227";
                "ashci-c1-n2-MGMT" = "10.44.83.4";  "ashci-c1-n2-STORAGE-A" = "10.44.82.132"; "ashci-c1-n2-STORAGE-B" = "10.44.82.164"; "ashci-c1-n2-STORAGE-C" = "10.44.83.196"; "ashci-c1-n2-STORAGE-D" = "10.44.83.228";
                "ashci-c1-n3-MGMT" = "10.44.83.5";  "ashci-c1-n3-STORAGE-A" = "10.44.82.133"; "ashci-c1-n3-STORAGE-B" = "10.44.82.165"; "ashci-c1-n3-STORAGE-C" = "10.44.83.197"; "ashci-c1-n3-STORAGE-D" = "10.44.83.229";
                "ashci-c2-n1-MGMT" = "10.44.83.9";  "ashci-c2-n1-STORAGE-A" = "10.44.82.137"; "ashci-c2-n1-STORAGE-B" = "10.44.82.169"; "ashci-c2-n1-STORAGE-C" = "10.44.83.201"; "ashci-c2-n1-STORAGE-D" = "10.44.83.233";
                "ashci-c2-n2-MGMT" = "10.44.83.10"; "ashci-c2-n2-STORAGE-A" = "10.44.82.138"; "ashci-c2-n2-STORAGE-B" = "10.44.82.170"; "ashci-c2-n2-STORAGE-C" = "10.44.83.202"; "ashci-c2-n2-STORAGE-D" = "10.44.83.234";
                "ashci-c2-n3-MGMT" = "10.44.83.11"; "ashci-c2-n3-STORAGE-A" = "10.44.82.139"; "ashci-c2-n3-STORAGE-B" = "10.44.82.171"; "ashci-c2-n3-STORAGE-C" = "10.44.83.203"; "ashci-c2-n3-STORAGE-D" = "10.44.83.235"
               }
    #>
    
    <# IF SWITCHED - 4-Node - 2 x Site
    $nodeips = @{"ashci-c1-n1-MGMT" = "10.44.83.3";  "ashci-c1-n1-STORAGE-A" = "10.44.82.3"; "ashci-c1-n1-STORAGE-B" = "10.44.82.131";
                "ashci-c1-n2-MGMT" = "10.44.83.4";  "ashci-c1-n2-STORAGE-A" = "10.44.82.4"; "ashci-c1-n2-STORAGE-B" = "10.44.82.132";
                "ashci-c1-n3-MGMT" = "10.44.83.5";  "ashci-c1-n3-STORAGE-A" = "10.44.82.5"; "ashci-c1-n3-STORAGE-B" = "10.44.82.133";
                "ashci-c1-n4-MGMT" = "10.44.83.6";  "ashci-c1-n4-STORAGE-A" = "10.44.82.6"; "ashci-c1-n4-STORAGE-B" = "10.44.82.134";
                "ashci-c2-n1-MGMT" = "10.44.83.9";  "ashci-c2-n1-STORAGE-A" = "10.44.82.9"; "ashci-c2-n1-STORAGE-B" = "10.44.82.137";
                "ashci-c2-n2-MGMT" = "10.44.83.10"; "ashci-c2-n2-STORAGE-A" = "10.44.82.10"; "ashci-c2-n2-STORAGE-B" = "10.44.82.138";
                "ashci-c2-n3-MGMT" = "10.44.83.11"; "ashci-c2-n3-STORAGE-A" = "10.44.82.11"; "ashci-c2-n3-STORAGE-B" = "10.44.82.139";
                "ashci-c2-n4-MGMT" = "10.44.83.12"; "ashci-c2-n4-STORAGE-A" = "10.44.82.12"; "ashci-c2-n4-STORAGE-B" = "10.44.82.140"
               }
    #>

    # IF SWITCHED - 2-Node - 1 x Site
    $nodeips = @{"ashci-c1-n1-MGMT" = "10.44.83.3";  "ashci-c1-n1-STORAGE-A" = "10.44.82.3"; "ashci-c1-n1-STORAGE-B" = "10.44.82.131";
                "ashci-c1-n2-MGMT" = "10.44.83.4";  "ashci-c1-n2-STORAGE-A" = "10.44.82.4"; "ashci-c1-n2-STORAGE-B" = "10.44.82.132";
               }
    
 
    $defaultgateway = "10.10.1.1"
    $dnsservers = "10.10.1.20","10.10.1.21","10.10.2.20"
#endregion
   
   
#region Configure Management Networking
  #1. Select first Adapter
    #List Adapters to choose from
    $Adapters = Get-NetAdapter | Sort-Object Name
    #Loop to ensure selection is made           
    Do
    {
    Write-Host "Please choose Adapter:"
    For ($i=0; $i -lt $Adapters.Count; $i++)  {
    Write-Host "$($i+1): $($Adapters[$i].Name) - $($Adapters[$i].InterfaceDescription)"
    }
      [int]$number = Read-Host "Enter number to select Adapter: "
        if([int]$number -eq 0)
        {
        Write-Host "No Selection Made!" -ForegroundColor Yellow
        }

    }While([int]$number -eq 0)#end loop

    $SETAdapter1 = $($Adapters[$number-1])
    
    CheckError("First Adapter chosen for SET Team is $SETAdapter1.Name")
    #$Adapter
    #[int]$number

  #2. Select second Adapter
    #List Adapters to choose from
    $Adapters = Get-NetAdapter | Sort-Object Name
    #Loop to ensure selection is made
    Do
    {
    Write-Host "Please choose Adapter:"
    For ($i=0; $i -lt $Adapters.Count; $i++)  {
    Write-Host "$($i+1): $($Adapters[$i].Name) - $($Adapters[$i].InterfaceDescription)"
    }
      [int]$number = Read-Host "Enter number to select Adapter: "
        if([int]$number -eq 0)
        {
        Write-Host "No Selection Made!" -ForegroundColor Yellow
        }

    }While([int]$number -eq 0)#end loop

    $SETAdapter2 = $($Adapters[$number-1])
    
    CheckError("Second Adapter chosen for SET Team is $SETAdapter2.Name")
    #$Adapter
    #[int]$number

  #3. Rename Adapters
    WriteLog("Configuring SET Adapters and creating SET vSwitch")
    Rename-NetAdapter -Name $SETAdapter1.Name -NewName "MGMT-A"
    CheckError("SET Adapter $SETAdapter1.Name renamed to MGMT-A")
    Rename-NetAdapter -Name $SETAdapter2.Name -NewName "MGMT-B"
    CheckError("SET Adapter $SETAdapter2.Name renamed to MGMT-B")
  
  #4. Setting advanced settings
    # Set MGMT Jumbo MTU - QLogic supports "9014"
    WriteLog("Setting jumbo MTU on management interfaces")
    Get-NetAdapter * | Where-Object { $_.Name -eq "MGMT-A" } | Set-NetAdapterAdvancedProperty -DisplayName "Jumbo Packet" -DisplayValue "9014"
    CheckError("Jumbo MTU set successfully on MGMT-A")
    Get-NetAdapter * | Where-Object { $_.Name -eq "MGMT-B" } | Set-NetAdapterAdvancedProperty -DisplayName "Jumbo Packet" -DisplayValue "9014"
    CheckError("Jumbo MTU set successfully on MGMT-B")
   
  #5. Create vSwitch
    New-VMSwitch -Name vSwitch1 -NetAdapterName "MGMT-A","MGMT-B" -EnableEmbeddedTeaming $true -MinimumBandwidthMode Weight
    CheckError("SET vSwitch created")
    #Rename the Management adapter
    Rename-VMNetworkAdapter -ManagementOS -Name vSwitch1 -NewName Management
    CheckError("ManagementOS Adapter renamed")

  #6. Rename ManagementOS VMNetAdapter NIC and set Jumbo MTU
    WriteLog("Renaming vEthernet NIC and setting Jumbo MTU")
    Rename-VMNetworkAdapter -ManagementOS -Name vSwitch1 -NewName Management
    #Rename-NetAdapter -Name "vEthernet (vSwitch1)" -NewName "vEthernet (Management)"
    CheckError("vEthernet renamed")
    Set-NetAdapterAdvancedProperty -Name "vEthernet (Management)" -DisplayName "Jumbo Packet" -DisplayValue "9014 Bytes"
    CheckError("Jumbo MTU set successfully on vEthernet")

  #7. Set IP Addressing
    WriteLog("Setting IP Addresses for Management")
    $interface = Get-NetAdapter | Where-Object { $_.name -eq "vEthernet (Management)" }
    New-NetIPAddress -InterfaceIndex $interface.ifIndex -IPAddress $nodeips.Get_Item("$hostname-MGMT") -Prefixlength 24 -DefaultGateway $defaultgateway
    Start-Sleep -s 5
    CheckError("Management IP, subnet mask and Gateway set")
    Set-DnsClientServerAddress -InterfaceIndex $interface.IfIndex -ServerAddresses $dnsservers
    CheckError("DNS Servers set")

#endregion

#region Enable RDP
  #Allow RDP Connections to this computer
  #Require Network Level Authentication
  #Enable firewall rule
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name UserAuthentication -Value 1
  Set-NetFirewallRule -DisplayGroup "Remote Desktop" -Enabled True
#endregion



#ADD STORAGE ADAPTERS HERE
#USE ABOVE SYNTAX LIKE FOR MANAGEMENT
Enable-NetAdapterRdma -Name STORAGE*


#Set time zone and regional settings
Set-TimeZone -Name "GMT Standard Time"
Set-WinUserLanguageList -LanguageList en-gb -Force
Set-WinSystemLocale -systemlocale en-gb

#Disable unused adapters
Get-NetAdapter | ? { $_.Status -eq 'Disconnected' } | Disable-NetAdapter -confirm:$false



#Allow ICMP
#Set-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)" -Enabled True
#Allow SMB-In
#Set-NetFirewallRule -DisplayName "File and Printer Sharing (SMB-In)" -Enabled True

#Enable iWARP firewall rule (if iWARP is used)
Enable-NetFirewallRule -Name "FPSSMBD-iWARP-In-TCP"

#NOT SURE IF CAN BE SET BEFORE S2D ENABLED?
#Update the hardware timeout for Spaceport - will require reboot of each node
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\spaceport\Parameters -Name HwTimeout -Value 0x00002710 -Verbose
