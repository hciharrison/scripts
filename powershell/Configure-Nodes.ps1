<#
.Synopsis
   Post Build Script for HCI Nodes after OS Installation
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
#>


#Variables
#$Clusters = "ws2022-c1","azshci-c1"
#$DestHVBRNames = "ws2022-c1-hvbr.lab01.local","azshci-c1-hvbr.lab01.local"
#$DestSharePaths = "ws2022-c1","azshci-c1"
#$DestStoragePaths = "c:\ClusterStorage\","c:\ClusterStorage\"
$DestStoragePath = "c:\ClusterStorage\"
$BrokerSuffix = "-hvbr.lab01.local"
$ReplicationFrequencySec = 300
$VMSwitchName = "SETvSwitch-MGMT"


#Configure logging
$pathToLogs = "Logs\nodeconfig\"
$datetimelogfile = get-date -format "ddMMyyyy-HHmmss"
$2ndpartlogfilename = "_node_config_log_" +$datetimelogfile+ ".log"

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
Write-Host "Logfiles for setting up replication will be saved to $pathToLogs" -ForegroundColor Yellow
$error.clear()

#Function to write to log file
function WriteLog($message) 
   {
     $datetime = get-date -format "dd-MM-yyyy-HH:mm:ss"
     $datetime +" - "+ $message | Add-Content $logfilename 
     $error.clear()
     Write-Host $message
     sleep 1
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