<#
.Synopsis
   Sets up Hyper-V Replication
.DESCRIPTION
    Checks for VMs on a cluster not already replicating and configures and enables rebplication for them 
    Requires the Broker Role to be setup on each cluster already
.EXAMPLE
    Just run the script, it will prompt for source and destination cluster names
.EXAMPLE
    PS C:\Scripts> .\Hyper-V-Replica.ps1
    Logs Folder found at Logs\SetupHVReplica\
    Logfiles for setting up replication will be saved to Logs\SetupHVReplica\

    cmdlet Setup-VMReplication at command pipeline position 1
    Supply values for the following parameters:
    SourceCluster: azshci-c1
    DestCluster: ws2022-c1
    Checking replication for VMs on cluster azshci-c1
    Checking replication for VMs on Node azshci-c1-h1
    Checking replication for VMs on Node azshci-c1-h2
    Setting up replication for VMs on Node azshci-c1-h2
    Hyper-V replica required on test-rep-02
    Source Cluster HVBR name is azshci-c1-hvbr.lab01.local
    Destination volume is Volume01
    Destination HVBR is ws2022-c1-hvbr.lab01.local
    Destination cluster is ws2022-c1
    test-rep-02 does not already exist on destination cluster node ws2022-c1-h1, proceeding
    test-rep-02 does not already exist on destination cluster node ws2022-c1-h2, proceeding
    Destination path is c:\ClusterStorage\Volume01
    Changed Hyper-V replica broker service path to c:\ClusterStorage\Volume01
    Enabled Hyper-V replica on test-rep-02
    test-rep-02 replica destination is ws2022-c1-h1.lab01.local
    Moving VM config and VHDs to c:\ClusterStorage\Volume01\test-rep-02
    F5C7D253-4F53-4EA9-8557-E5434559FEDC.vhdx will be moved to c:\ClusterStorage\Volume01\test-rep-02\
.NOTES
    Requires the Broker Role to be setup on each cluster
    The Broker Role should have the Primary Server, Storage Location and Trust Group set
    The Primary Server is the other cluster you are replicationg VMs from
    The Hyper-V Replica firewall rules need enabling on each node using the below cmdlet:
    Enable-Netfirewallrule -displayname "Hyper-V Replica HTTP Listener (TCP-In)"
    The $DestStoragePath variable is normally "C:\ClusterStorage\" on HCI Clusters and can be changed if needed
    The $BrokerSuffix variable needs to match the naming convention of your Broker Roles and assumes clusters are in the same domain
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
$pathToLogs = "Logs\SetupHVReplica\"
$datetimelogfile = get-date -format "ddMMyyyy-HHmmss"
$2ndpartlogfilename = "_setup_hvr_log_" +$datetimelogfile+ ".txt"

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



### MAIN FUNCTION ###
Function Setup-VMReplication
    {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourceCluster, #require a clustername
        [Parameter(Mandatory)]
        [string]$DestCluster #require a clustername
        )


    BEGIN
    {
    #Check for same source and dest cluster names
    If ($DestCluster -eq $SourceCluster)
    {
    Write-Host "Source and Desition Clusters cannot be the same, please re-run the script" -ForegroundColor Yellow
    Break
       
    }#End If
    #>
    }#End BEGIN
    

    PROCESS
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    {
        #Get nodes for each cluster
        foreach($Cluster in $SourceCluster)
        {
        
        ## LOG ##        
        $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
        WriteLog("Checking replication for VMs on cluster $Cluster")


            $ClusterNodes = Get-ClusterNode -Cluster $Cluster
            foreach($ClusterNode in $ClusterNodes)
            {

            ## LOG ##        
            $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
            WriteLog("Checking replication for VMs on Node $ClusterNode")
            
            #Get VMs
            $AllVMs = Get-VM -ComputerName $ClusterNode | ? { $_.ReplicationState -eq "Disabled" -or $_.ReplicationState.length -lt 1 -and $_.IsClustered -eq $True } 

                Foreach ($VM in $AllVMs)
                {


                        $VMName = $vm.name

                        ## LOG ##        
                        $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                        WriteLog("Setting up replication for VMs on Node $ClusterNode")
                        WriteLog("Hyper-V replica required on $vmname")
                        #echo $destcluster
                        Start-Sleep -s 5
          
                            # Change Hyper-V replica broker service path
                            $VMHost = $clusterNode
                            #Set Source Broker name
                            $SourceHVBRName = $SourceCluster + $BrokerSuffix
                            WriteLog("Source Cluster HVBroker name is $SourceHVBRName")
                            Start-Sleep -s 5
                            #Set volume name = assumes volume names are Volume01, Volume02, etc.
                            $index = ($VM.Path).ToUpper().IndexOf("C:\ClusterStorage\volume")
                            $volnum = ($VM.Path).SubString($index+25,2)
                            $DestRepVol = "Volume" + $volnum

                                WriteLog("Destination volume is $DestRepVol")
                                $DestHVBRName = $DestCluster + $BrokerSuffix
                                WriteLog("Destination HVBroker is $DestHVBRName")
                                WriteLog("Destination cluster is $destcluster")
                                Start-Sleep -s 5


                                    # Checking the VM does not already exist on the destination cluster nodes
                                    $DestClusterNodes = Get-ClusterNode -Cluster $DestCluster
                                    foreach($DestClusterNode in $DestClusterNodes)
                                    {
                                        $CheckVMOnDestCluster = Get-VM -ComputerName $DestClusterNode | ? { $_.VMName -eq $VMName }
                                        if ($CheckVMOnDestCluster) 
                                        { 
                                        WriteLog("$VMName already exists on destination cluster, skipping this VM")
                                        WriteLog("$CheckVMOnDestCluster")
                                        Continue
                                        }
                                        else 
                                        {
                                        WriteLog("$VMName does not already exist on destination cluster node $DestClusterNode, proceeding")
                                        }

                                    }

                                        #$DestStorageCluster = $DestCluster
                                        $NewPath = $DestStoragePath + $DestRepVol
                                        WriteLog("Destination path is $NewPath")
                                        Start-Sleep -s 5
                                        Invoke-Command -ComputerName $DestHVBRName -ScriptBlock { Set-VMReplicationAuthorizationEntry -AllowedPrimaryServer $using:SourceHVBRName -StorageLoc $using:NewPath }
                                        CheckError "Changed Hyper-V replica broker service path to $NewPath" "Error changing Hyper-V replica broker path"
                                        Start-Sleep -s 5

                                        # Enable replication on VM
                                        Enable-VMReplication -VMName $VMName -ComputerName $ClusterNode -AuthenticationType Kerberos -ReplicationFrequencySec $ReplicationFrequencySec -ReplicaServerName $DestHVBRName -ReplicaServerPort 80 
                                        CheckError "Enabled Hyper-V replica on $VMName" "Error enabling Hyper-V replica on $VMName"
                                        #WriteLog("Waiting 60 seconds to allow replication to settle")
                                        Start-Sleep -s 5


                                            # Fix up path to VHDs on replica destination to be in vmname folder rather than a GUID
                                            $NewVMHost = Get-VM -ComputerName $VMHost | ? { $_.Name -eq $VMName } | Get-VMReplication | select-object -expandproperty CurrentReplicaServerName
                                            $vmObject = Invoke-Command -ComputerName $NewVMHost -ScriptBlock { get-vm -name $using:VMName }
                                            $VHDs = Invoke-Command -ComputerName $NewVMHost -ScriptBlock { get-vm -name $using:VMName | Select-Object VMId | get-vhd }
                                            WriteLog($vmname + " replica destination is $NewVMHost")
                                            $NewNamePath = $NewPath + "\" + $vmname
                                            WriteLog("Moving VM config and VHDs to $NewNamePath")
                                            Start-Sleep -s 5

                                            # Move each individual disk to the root of the vmname folder, and move the config file
                                            $ArrayOfVHDs = @()
                                            foreach ($vhd in $VHDs)
                                            {
                                            $vhdMap = New-Object -TypeName System.Collections.Hashtable
                                            $vhdMap.Add("SourceFilePath", $VHD.Path)
                                            $vhdMap.Add("DestinationFilePath", $NewNamePath + "\" + (split-path $VHD.Path -leaf) )
                                            WriteLog((split-path $VHD.Path -leaf) + " will be moved to " + $NewNamePath + "\")  
                                            $ArrayOfVHDs += $vhdMap
                                            }
                                            $ArrayOfVHDs
                                            Start-Sleep -s 10
                                            Move-VMStorage -ComputerName $NewVMHost -VMName $vmname -VirtualMachinePath $NewNamePath -SnapshotFilePath $NewNamePath -SmartPagingFilePath $NewNamePath -VHDs $ArrayOfVHDs
                                            CheckError "VM config and VHDs moved" "Error moving VM config and/or VHDs"  
 
                                                # Start initial replication
                                                Start-Sleep -s 10
                                                Start-VMInitialReplication -VMName $vmname -ComputerName $VMHost
                                                CheckError "Initial replication started" "Error starting initial replication"
          
                                                WriteLog("Connecting network adapter(s) on destination VM")
                                                Connect-VMNetworkAdapter -ComputerName $NewVMHost -VMName $vmname -SwitchName $VMSwitchName
                                                WriteLog("Setting up replication on $VMname complete, moving on to the next VM in 5 seconds")
                                                Sleep -s 5

                                                                                                    <#
                                                    # Check initial replication has completed before moving on to the next VM
                                                    do 
                                                    { 
                                                    $ReplicationStatus = $(Measure-VMReplication -ComputerName $NewVMHost -VMName $VMName)
                                                    $now = get-date
                                                    $percentcomplete = $ReplicationStatus.CurrentTask.Caption
                                                    WriteLog("$now - Waiting for initial replication of $VMname to complete... checking every 60 seconds - $percentcomplete")
                                                    # write-host $percentcomplete
                                                    sleep 60
                                                    }
                                                    until ($ReplicationStatus.Health -eq "Normal" -and $ReplicationStatus.State -eq "Replicating")

                                                    WriteLog("Setting Custom2 on source VM")
                                                    Set-SCCustomPropertyValue -InputObject $VM -CustomProperty $custom2 -value "Hyper-V Replica: Source"

                                                    WriteLog("Connecting network adapter(s) on destination VM")
                                                    Connect-VMNetworkAdapter -ComputerName $NewVMHost -VMName $vmname -SwitchName "PSP - SET"

                                                    WriteLog("Initial replication of $VMname complete, moving on to the next VM in 10 seconds")
                                                    Start-Sleep -s 10
                                                    #>
                  
                                                    #echo "All done, exiting!"
                            
                
            }
        }#End PROCESS
    }
    }
        END
            {
            ##LOG##
            If(!$VM)
            {        
            $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
            WriteLog("There are no VMs to replicate on Cluster $SourceCluster")
            }
            Else
            {
            $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
            WriteLog("Replication has been setup for $VM on Cluster $Cluster")
            }

            }#End END
            
    }#End Function Repair-VMReplication
            
Setup-VMReplication
