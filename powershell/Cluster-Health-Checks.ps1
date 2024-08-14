<# List of checks
Pool health
Check virtual disk health
Drive health
Check nodes are healthy 
Check all Cluster networks are healthy 
Check VMs are healthy 
Check no checkpoints 
Check no ISOs mounted to VMs
#>


$Cluster = "clustername"

#Function that checks health status for any resources that use the 'HealthStatus'  & 'FriendlyName' fields
Function Check-Resources($Resources){
    Foreach($Resource in $Resources){
        If($Resource.HealthStatus -ne 'Healthy'){
        Write-Host "WARNING - Unhealthy status detected for resource:" $Resource.FriendlyName -ForegroundColor Yellow
        }
        Else{
        Write-Host $Resource.FriendlyName "is healthy" -ForegroundColor Green
        }
    }
}
    
    #Check storage pools
    Write-Host "`nStorage Pools:" -ForegroundColor Cyan
    $Resources = Get-StoragePool -IsPrimordial $False -CimSession $Cluster | sort FriendlyName
    Check-Resources $Resources

    #Check virtual disks
    Write-Host "`nVirtual Disks:" -ForegroundColor Cyan
    $Resources = Get-VirtualDisk -CimSession $Cluster | sort FriendlyName
    Check-Resources $Resources

    #Check physical disks
    Write-Host "`nPhysical Disks:" -ForegroundColor Cyan
    $Resources = Get-PhysicalDisk -CimSession $Cluster | sort FriendlyName
    Check-Resources $Resources

    #Check cluster nodes
    Write-Host "`nCluster Nodes:" -ForegroundColor Cyan
    $Resources = Get-ClusterNode -Cluster $Cluster | sort Name
    Foreach($Resource in $Resources){
        If($Resource.State -ne 'Up'){
        Write-Host "WARNING - Unhealthy status detected for resource:" $Resource.Name -ForegroundColor Yellow
        }
        Else{
        Write-Host $Resource.Name "is healthy" -ForegroundColor Green
        }
    }

    #Check cluster networks
    Write-Host "`nCluster Networks:" -ForegroundColor Cyan
    $Resources = Get-ClusterNetwork -Cluster $Cluster | sort Name
    Foreach($Resource in $Resources){
        If($Resource.State -ne 'Up'){
        Write-Host "WARNING - Unhealthy status detected for resource:" $Resource.Name -ForegroundColor Yellow
        }
        Else{
        Write-Host $Resource.Name "is healthy" -ForegroundColor Green
        }
    }

    #Check VMs
    Write-Host "`nVirtual Machines:" -ForegroundColor Cyan
    $Resources = Get-VM -CimSession $Cluster | sort Name
    Foreach($Resource in $Resources){
        If($Resource.Status -ne 'Operating normally'){
        Write-Host "WARNING - Unhealthy status detected for resource:" $Resource.Name -ForegroundColor Yellow
        }
        Else{
        Write-Host $Resource.Name "is healthy" -ForegroundColor Green
        }
    }

    #Check for aVHDXs
    Write-Host "`nChecking for aVHDXs:" -ForegroundColor Cyan
    $Resources = Get-VM -CimSession $Cluster | sort Name
    Foreach($Resource in $Resources){
        $VHDs = Get-VMSnapshot -CimSession $Cluster -VMName $Resource.Name
        if($vhds.path -match "avhdx"){
        $VMSnapshots = Get-VMSnapshot -VMName $VHDs.VMName
         Write-Host $Resource.Name "is running off aVHDXs" -ForegroundColor Yellow
        "Disk Name(s):"
        $VHDs | % { $_.Path }
        "Checkpoint Name(s):"
        $VMSnapshots | % { $_.Name } -ErrorAction SilentlyContinue
        }
        Else{
        Write-Host $Resource.Name "is not running off aVHDXs" -ForegroundColor Green
        }
    }

    #Check attached ISOs
    Write-Host "`nChecking for attached ISOs:" -ForegroundColor Cyan
    $Resources = Get-VM -CimSession $Cluster | sort Name
    Foreach($Resource in $Resources){
        $VMDvd = Get-VMDvdDrive -CimSession $Cluster -VMName $Resource.Name
        If(!$VMDvd.DvdMediaType){
        Write-Host "No ISO attached to" $Resource.Name -ForegroundColor Green
        }
        Else{
        Write-Host "There is an ISO attached to" $Resource.Name -ForegroundColor Yellow
        }
    }
