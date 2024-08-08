<#
  .SYNOPSIS
  Script to enable Replication on VMs

  .DESCRIPTION
  This script will enable hyper-v replica on vms
  The script can accept mulitple vm names
  This script will will move the replicated vms storage to a nice directory structure
  The script will randomly choose a target volume from the list in the script

  .NOTES
  Written by: Lee Harrison
  Created: 2024/02/09
 
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$VMNames,
    [string]$SourceCluster = $(Read-Host -Prompt 'Enter Source Cluster'),
    [string]$DestinationCluster = $(Read-Host -Prompt 'Enter Destination Cluster')

)

Start-Transcript -Path "$((Get-Location).Path)\setup-hyper-v-replica_$(Get-date -Format "yyyyMMdd-hhmmss").log" -NoClobber

#Check cluster(s) exist
function CheckForCluster($Cluster) {
    $CheckForCluster = Get-ClusterResource -Cluster $Cluster -ErrorAction Ignore
    if($CheckForCluster -eq $null){
    Write-Host "No cluster found for name $Cluster, please check the spelling and rerun the script!" -ForegroundColor Yellow
    Exit
    }
}

#Check VM(s) exist
function CheckForVM($VM) {
    $CheckForVM = Get-ClusterResource -Cluster $SourceCluster | where { $_.ResourceType -like "Virtual Machine" -and $_.OwnerGroup -like "*$VM*"} -ErrorAction Ignore
    if($CheckForVM -eq $null){
    Write-Host "No VM found with name $VM, please check the spelling and rerun the script!" -ForegroundColor Yellow
    Exit
    }
}

CheckForCluster $SourceCluster
CheckForCluster $DestinationCluster

#Start main loop
foreach($VMName in $VMNames) {
    #Check VMName exists
    CheckForVM $VMName
    Write-Host "Attempting to enable replication for VM: $VMname" -ForegroundColor Cyan 

    #Get Source host name where VM is running
    [string]$SourceHostName = (Get-ClusterResource -Cluster $SourceCluster | where { $_.ResourceType -like "Virtual Machine" -and $_.OwnerGroup -like "*$VMName*"}).OwnerNode

    #Get destiantion broker name
    [string]$DestinationBroker = (Get-ClusterResourceType -Cluster $DestinationCluster -Name "Virtual Machine Replication Broker" | Get-ClusterResource).OwnerGroup.Name

    #Set virtual seiwthc name
    [string]$VMSwitchName = "ConvergedSwitch(compute_management)"

    #Enable replication on VM from source node
    Write-Host "Enabling replication from source cluster: $SourceCluster to destination cluster: $DestinationCluster"
    Invoke-Command -ComputerName $SourceHostName -ScriptBlock {
    $TS = New-TimeSpan -Hours 1
    $Repldate = (Get-Date) + $TS
        try{
        Enable-VMReplication -VMName $args[0] -ComputerName $args[1] -ReplicaServerName $args[2] -CompressionEnabled $true -AuthenticationType Kerberos -ReplicaServerPort 80 -ErrorAction Stop | Out-Null
        #Enable-VMReplication $args[0] $args[1] -CompressionEnabled $true 443 -AuthenticationType Certificate -CertificateThumbprint "9f45c54a30ec409eb4f8b721ab36016a498dd268"
        Start-VMInitialReplication $args[0] -InitialReplicationStartTime $Repldate
        }
        catch{Write-Host "An error occurred enabling replication: $($_.Exception.Message)"}
    } -ArgumentList $VMName,$SourceHostName,$DestinationBroker,$VolumeName

    #Get destination hostname where replication vm is located
    [string]$DestinationHostName = (Get-ClusterResource -Cluster $DestinationCluster | where { $_.ResourceType -like "Virtual Machine" -and $_.OwnerGroup -like $VMName}).OwnerNode
    #Set Destination Volume
    [String[]]$VolNameList='UserStorage_1','UserStorage_2'
    #Volume name can be random or set to your choosing
    [String]$VolumeName = Get-Random -InputObject $VolNameList
    #[String]$VolumeName = 'ASHA_SSD_V01'

    #Configure directory structure and move storage
    Write-Host "Creating directory structure in volume: $VolumeName"
    Invoke-Command -ComputerName $DestinationHostName -ScriptBlock {
        $vm = $args[0]
        $vol = $args[1]
        try{
            $VM | ForEach-Object {
            $destination = "C:\ClusterStorage\$vol\Hyper-V"
                New-Item -ItemType Directory -Path "$DESTINATION\$vm"
                New-Item -ItemType Directory -Path "$DESTINATION\$vm\Virtual Machines"
                New-Item -ItemType Directory -Path "$DESTINATION\$vm\Smart Paging"
                New-Item -ItemType Directory -Path "$DESTINATION\$vm\Snapshots"
                New-Item -ItemType Directory -Path "$DESTINATION\$vm\Virtual Hard Disks"
                Move-VMStorage $vm -SnapshotFilePath "$DESTINATION\$vm\Snapshots" -SmartPagingFilePath "$DESTINATION\$vm\Smart Paging" -VirtualMachinePath "$DESTINATION\$vm\Virtual Machines" -ErrorAction Stop | Out-Null
                $diskdest = "$DESTINATION\$vm\Virtual Hard Disks"
                Get-VM  $vm | Select-Object -expand HardDrives | ForEach-Object {
                #get file name
                $file = $_.Path | Split-Path -Leaf
                #create the destination
                $destfile = Join-Path $diskdest $file
                #create the hash table putting the value in quotes
                $hash = @{  
                    "SourceFilePath" = "$($_.path)";
                    "DestinationFilePath" = "$destfile";
                }
                #pass the VM name to Move-VMStorage and move the VHD
                Write-Host "Moving $($hash.sourceFilePath) to $($hash.DestinationFilePath)" -foregroundcolor Cyan
                Move-VMStorage $_.VMName -vhds $hash
                }
            }
        }
        catch{Write-Host "An error occurred enabling replication: $($_.Exception.Message)"}
    } -ArgumentList $VMName,$VolumeName

    #Connect VM to vSwitch
    Write-Host "Connecting vSwitch to VM"
    try{
    Connect-VMNetworkAdapter -ComputerName $DestinationHostName -VMName $VMName -SwitchName $VMSwitchName -ErrorAction Stop | Out-Null
    }
    catch{Write-Host "An error occurred connecitng the vSwitch: $($_.Exception.Message)"}
}#end main loop

Stop-transcript
