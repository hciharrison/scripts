<#
.Synopsis
   Connects to cluster nodes, checks VM replication state and resumes/repairs Replication if needed
   Based on script from here: https://community.spiceworks.com/scripts/show/2565-repair-vmreplication
   My changes:
      Made it cluster aware to iterate through nodes in cluster(s)
      Added logging and error checking
      Changed the logic to suite my needs
.DESCRIPTION
    Connects to nodes in a specified cluster(s), processes through each VM, and verifies Replication is working. If not 
    it will try to resume replication, then clear out the replication statistics and resume replication, then try a resync,
    then move the target VM, then move the source VM.
.EXAMPLE
    Repair-VMReplication -ClusterNames mycluster01, mycluster02
.EXAMPLE
    PS C:\> Repair-VMReplication
    Supply values for the following parameters:
    ClusterNames[0]: Cluster01
    ClusterNames[1]:
    Checking replication for VMs on cluster Cluster01
    Checking replication for VMs on Node C01Node01
    VM01 is replicating
    VM02 is replicating
    VM03 is replicating
    Checking replication for VMs on Node C01Node02
    VM04 replication is Critical and in Error - trying a resume operation
    Processed resume operation for VM04 - this has been tried 1 times
    WSUS01 replication is Critical and in Error - trying a resume operation
    Processed resume operation for VM04 - this has been tried 2 times
    VM04 is replicating
    All VM's have been checked on Cluster Cluster01
.NOTES
    Requires Failover Cluster Management Tools to be installed on all Cluster Nodes
    C:\>Get-WindowsFeature *cluster*

    Display Name                                            Name                       Install State
    ------------                                            ----                       -------------
    [ ] Failover Clustering                                 Failover-Clustering            Installed
            [X] Failover Clustering Tools                   RSAT-Clustering                Installed
                [X] Failover Cluster Management Tools       RSAT-Clustering-Mgmt           Installed
#>

#Setup error log file name
$pathToLogs = "logs\hvr\"
$datetimelogfile = get-date -format "ddMMyyyy-HHmmss"
$2ndpartlogfilename = "_repair_replication_log_" +$datetimelogfile+ ".txt"
#echo "Logfiles for setting up replication will be saved to $pathToLogs"
$error.clear()

function WriteLog($message) 
    {
     $datetime = get-date -format "dd-MM-yyyy-HH:mm:ss"
     $datetime +" - "+ $message | Add-Content $logfilename 
     $error.clear()
     Write-Host $message
     sleep 1
    }

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

#Set sleep after each resume attempt
$SleepTime = 10

### MAIN FUNCTION ###
Function Repair-VMReplication
    {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$ClusterNames #require a clustername
        #[Parameter()]
        #[string[]]$ComputerName #here if you want to expand script to choose just a single node
        )


    BEGIN
    {
        <#Set Cluster Names manually if needed
        If ($ClusterNames -eq $null)
        {
        $ClusterNames  = "psp03-hvc01", "psp03-c02"
        
        }#End If
        #>
    }#End BEGIN
    

    PROCESS
    {

        #Get nodes for each cluster
        foreach($Cluster in $ClusterNames)
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

            #Get HVR Primary VMs
            $VMReplication = Get-VM -ComputerName $ClusterNode | Where-Object ReplicationMode -eq Primary | Get-VMReplication

                Foreach ($VMReplica in $VMReplication)
                {

                    $RetryCount = -1
                    DO
                    {
                    #Break out of loop if VM cannot be repaired
                    if($FailedVM) {Break}

                        $VMReplicaName = $VMReplica.Name
                        If($VMReplica.Health -eq "Critical" -and $VMReplica.State -eq "Resynchronizing")
                        {
                            ## LOG ##
                            $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                            WriteLog("$VMReplicaName is Resynchronizing and critical")
                            Break
                        }

                        ElseIf($VMReplica.Health -eq "Warning" -and $VMReplica.State -eq "Resynchronizing")
                        {
                            ## LOG ##
                            $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                            WriteLog("$VMReplicaName is Resynchronizing and warning")
                            Break
                        }

                        ElseIf( $VMReplica.State -eq "InitialReplicationInProgress")
                        {
                            ## LOG ##
                            $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                            WriteLog("$VMReplicaName Initial Replication In Progress")
                            Break
                        }

                        ElseIf($VMReplica.Health -eq "Critical" -and $VMReplica.State -eq "Error")
                        {
                        $RetryCount++
                        $VMReplicaName = $VMReplica.Name
                            if($RetryCount -eq 2)
                            {
                                ## LOG ##
                                $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                                WriteLog("$VMReplicaName couldn't be resumed after $RetryCount times - resetting replication statistics and trying a resume operation")
                                $Session = New-CimSession -ComputerName $ClusterNode -ErrorAction Stop
                                Reset-VMReplicationStatistics -CimSession $Session -VMName $VMReplica.Name
                                CheckError "Reset statistics for $VMReplicaName" "Error resetting  statistics for $VMReplicaName"
                                #Resume-VMReplication -CimSession $Session -VMName $VMReplica.Name
                                #CheckError "Processed a resume operation for $VMReplicaName" "Error resuming replication for $VMReplicaName"
                                Start-Sleep -Seconds $SleepTime
                            }
                            
                            if($RetryCount -eq 4)
                            {
                                $ClusterNodeTargetName = $VMReplica.CurrentReplicaServerName
                                ## LOG ##
                                $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                                WriteLog("$VMReplicaName couldn't be resumed after $RetryCount times - Quick Migrating target VM from Node $ClusterNodeTargetName")
                                $ClusterTarget = Invoke-Command -ComputerName $VMReplica.CurrentReplicaServerName {Get-Cluster}
                                Get-Cluster -Name $ClusterTarget.Name | Get-ClusterGroup -Name $VMReplica.Name | Move-ClusterVirtualMachineRole -MigrationType Quick -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                                CheckError "Processed move of HVR target VM for $VMReplicaName" "Error moving HVR target VM for $VMReplicaName"
                                Start-Sleep -Seconds $SleepTime
                            }

                            if($RetryCount -eq 6)
                            {
                                ## LOG ##
                                $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                                WriteLog("$VMReplicaName couldn't be resumed after $RetryCount times - trying a resume and resync operation")
                                $Session = New-CimSession -ComputerName $ClusterNode -ErrorAction Stop
                                Resume-VMReplication -CimSession $Session -VMName $VMReplica.Name -Resynchronize
                                CheckError "Processed a resume and resync operation for $VMReplicaName" "Error resuming and resync operation for $VMReplicaName"
                                Start-Sleep -Seconds $SleepTime
                            }

                            if($RetryCount -eq 8)
                            {
                                ## LOG ##
                                $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                                WriteLog("$VMReplicaName couldn't be resumed after $RetryCount times - trying a resume on HVR target VM")
                                $Session = New-CimSession -ComputerName $VMReplica.CurrentReplicaServerName -ErrorAction Stop
                                Resume-VMReplication -CimSession $Session -VMName $VMReplica.Name
                                CheckError "Processed a resume on HVR Target VM for $VMReplicaName" "Error resuming on HVR Target VM for $VMReplicaName"
                                Start-Sleep -Seconds $SleepTime
                            }

                            if($RetryCount -eq 10)
                            {
                                $ClusterNodeSourceName = $VMReplica.PrimaryServerName
                                ## LOG ##
                                $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                                WriteLog("$VMReplicaName couldn't be resumed after $RetryCount times - Live Migrating VM off and back from node $ClusterNodeSourceName")
                                $ClusterSource = Invoke-Command -ComputerName $VMReplica.PrimaryServerName {Get-Cluster}
                                Get-Cluster -Name $ClusterSource.Name | Get-ClusterGroup -Name $VMReplica.Name | Move-ClusterVirtualMachineRole -MigrationType Live -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                                Sleep -Seconds $SleepTime
                                Get-Cluster -Name $ClusterSource.Name | Get-ClusterGroup -Name $VMReplica.Name | Move-ClusterVirtualMachineRole -MigrationType Live -Node $VMReplica.PrimaryServerName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                                CheckError "Processed move of VM $VMReplicaName" "Error moving VM $VMReplicaName"
                                Start-Sleep -Seconds $SleepTime
                            }

                            if($RetryCount -eq 12)
                            {
                                ## LOG ##
                                $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                                WriteLog("$VMReplicaName could not be repaired after $RetryCount times - skipping to next VM")
                                $FailedVM = $VMReplica.Name
                                #Start-Sleep -Seconds $SleepTime
                                Break
                            }

                            ## LOG ##
                            $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                            WriteLog("$VMReplicaName replication is Critical and in Error - trying a resume operation")
                            $Session = New-CimSession -ComputerName $ClusterNode -ErrorAction Stop
                            Resume-VMReplication -CimSession $Session -VMName $VMReplica.Name
                            $RetryCountActual = $RetryCount + 1
                            CheckError "Processed resume operation for $VMReplicaName - this has been tried $RetryCountActual times" "Error resuming replication for $VMReplicaName"
                            Sleep -Seconds $SleepTime
                            
                        }

                        ElseIf( $VMReplica.State -eq "Suspended")
                        {
                            $VMReplicaName = $VMReplica.Name
                            ## LOG ##
                            $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                            WriteLog("$VMReplicaName is in a suspended state - trying to resume")
                            Reset-VMReplicationStatistics -CimSession $Session -VMName $VMReplica.Name
                            CheckError "Reset statistics for $VMReplicaName" "Error resetting  statistics for $VMReplicaName"
                            $Session = New-CimSession -ComputerName $ClusterNode -ErrorAction Stop
                            Resume-VMReplication -CimSession $Session -VMName $VMReplica.Name
                            CheckError "Processed a resume operation for $VMReplicaName" "Error resuming replication for $VMReplicaName"
                            Sleep -Seconds $SleepTime
                        }

                        ElseIf( $VMReplica.Health -eq "Critical" -and $VMReplica.State -eq "WaitingForStartResynchronize")
                        {
                        $RetryCount2++
                        $VMReplicaName = $VMReplica.Name
                            if($RetryCount2 -eq 2)
                            {
                            ## LOG ##
                            $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                            WriteLog("$VMReplicaName could not be resyncronised after $RetryCount times - skipping to next VM")
                            $FailedVM = $VMReplica.Name
                            Break
                            }
                            ## LOG ##
                            $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                            WriteLog("$VMReplicaName is in a critical state and is waiting for resynchronize to start - trying to resume")
                            #Reset-VMReplicationStatistics -CimSession $Session -VMName $VMReplica.Name
                            #CheckError "Reset statistics for $VMReplicaName" "Error resetting  statistics for $VMReplicaName"
                            $Session = New-CimSession -ComputerName $ClusterNode -ErrorAction Stop
                            Resume-VMReplication -CimSession $Session -VMName $VMReplica.Name -Resynchronize
                            CheckError "Processed a resume operation for $VMReplicaName" "Error resuming replication for $VMReplicaName"
                            Sleep -Seconds $SleepTime
                            
                        }

                        ElseIf( $VMReplica.Health -eq "Warning")
                        {
                            $VMReplicaName = $VMReplica.Name
                            ## LOG ##
                            $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                            WriteLog("$VMReplicaName is in a Warning state - trying to resume")
                            #Reset-VMReplicationStatistics -CimSession $Session -VMName $VMReplica.Name
                            #CheckError "Reset statistics for $VMReplicaName" "Error resetting  statistics for $VMReplicaName"
                            $Session = New-CimSession -ComputerName $ClusterNode -ErrorAction Stop
                            Resume-VMReplication -CimSession $Session -VMName $VMReplica.Name
                            CheckError "Processed a resume operation for $VMReplicaName" "Error resuming replication for $VMReplicaName"
                            Sleep -Seconds $SleepTime
                        }

                        ElseIf( $VMReplica.Health -eq "Critical" -and $VMReplica.State -eq "Replicating")
                        {
                            ## LOG ##
                            $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                            WriteLog("$VMReplicaName is in a critical state but is replicating")
                            Break
                        }
                        
                    }#End DO

                    UNTIL
                    ($VMReplica.Health -eq "Normal" -and $VMReplica.State -eq "Replicating")
                    
                    if(!$FailedVM)
                    {
                    ## LOG ##
                    $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                    WriteLog("$VMReplicaName is replicating")
                    #$FailedVM = ""
                    }
                    Elseif($FailedVM)
                    {
                    ## LOG ##
                    $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
                    WriteLog("$VMReplicaName needs repairing manually")
                    $FailedVM = ""
                    }
                }
            }
        }
    }#End PROCESS

        END
        {
        ##LOG##        
        $logfilename = "$pathToLogs" +$Cluster+ $2ndpartlogfilename
        WriteLog("All VM's have been checked on Cluster $Cluster")


        }#End END

    }#End Function Repair-VMReplication

    Repair-VMReplication
