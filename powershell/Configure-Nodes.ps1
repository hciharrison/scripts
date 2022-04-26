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

#Configure logging
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


#Check if the HYper-V Role is Installed
$CheckRoleHV = (Get-WindowsFeature -Name Hyper-V).Installed
if($CheckRoleHV -eq $True)
{ WriteLog("Hyper-V Role is installed")
  else
  {
    Read-Host "Hyper-V Role is not installed, press enter to install it and reboot the Server, or stop the Script and install them manually"
    Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart $true
  }
}

#Set Hostname
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


    ### CREATE SET TEAM ###

    #1. need to provide list of Adapters to choose first team member and capture in variable
    #2. need to provide list of Adapters to choose second team member and capture in variable
    #3. then rename adapters (from variable?)
    #4. then create SET Team
    #5. Then rename ManagementOS VMNetworkAdapter to Management
    #6. then add ip address, dns servers, gw to mgmt adapter from IPs above
    
  

    #1.

    #List Adapters to choose from
    #$Adapter = ""
    $Adapters = Get-NetAdapter | Sort-Object Name

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

    }While([int]$number -eq 0)

    $Adapter1 = $($Adapters[$number-1])
    
    WriteLog("First Adapter chosen for SET Team - $Adapter1")
    #$Adapter
    #[int]$number


    #2.

    #List Adapters to choose from
    #$Adapter = ""
    $Adapters = Get-NetAdapter | Sort-Object Name

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

    }While([int]$number -eq 0)

    $Adapter2 = $($Adapters[$number-1])
    
    WriteLog("Second Adapter chosen for SET Team - $Adapter2")
    #$Adapter
    #[int]$number

