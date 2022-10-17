<#
.Synopsis
   PowerShell Script to export VM Stats to CSV file
.DESCRIPTION
    Run from management server to produce report on VMs from multiple clusters  
.EXAMPLE
    PS C:\> .\Get-VMReport.ps1
    Adding VM Details for Cluster r630-c1 to file: C:\temp\vmreport_2022-10-12-1416.csv
.NOTES
    Need to manually set the clusters variable to one or more cluster names
#>


#Reset  values
$TotalDynamicHDDSpaceAllocated = 0
$TotalHDDSpaceUsed = 0
$report = @()
$reports = @()
$vms = $null

#Get datetime for output file
$datetime = (get-date -f yyyy-MM-dd-HHmm)

#Set Clusters
$clusters = "r630-c1","r630-c2"


#Start amin loop
Foreach($Cluster in $Clusters){
    
    #Get VMs per cluster
    $VMs = Get-ClusterGroup -Cluster $Cluster | where { $_.GroupType -like "VirtualMachine"} | Get-VM

    #Output report file location to console
    write-host "Adding VM Details for Cluster $Cluster to file: C:\temp\vmreport_$datetime.csv"

    #Loop VMs to get VHD stats
    foreach($VM in $VMs){

    $VHDs = Get-VHD -ComputerName $vm.ComputerName -VmId $vm.VmId
    $TotalDynamicHDDSpaceAllocated = 0
    $TotalHDDSpaceUsed = 0
        
        #Get stats for each VHD
        foreach ($vhd in $vhds) {

            #If checkpoint is in play, get vhd sizes from file system
            If ($vhd.VHDType -eq "Differencing") {
            $VHDLocalPath = $vm.Path
                
                #Get Share path - depends on volume names being default names of Volume01, Volume02, etc.
                $VHDShareParentPath = "\\$Cluster\ClusterStorage$\"
                $VHDPathLeaf = $VHDLocalPath | Split-Path -Leaf
                $VHDPath = $VHDLocalPath.Substring($VHDLocalPath.Length - (9+($VHDPathLeaf).Length))
            
            #Get VHDX stats via Cluster fileshare
            $files = Get-ChildItem -Recurse -Include *vhdx "$VHDShareParentPath$VHDPath"
            $totalSize = ($files | Measure-Object -Sum Length).Sum
            $TotalHDDSpaceUsed = $totalSize
            $TotalDynamicHDDSpaceAllocated = $TotalDynamicHDDSpaceAllocated + $vhd.Size
            $checkpoint = "True"
            }
    
            Else{
            $TotalHDDSpaceUsed = $TotalHDDSpaceUsed + $vhd.Filesize   
            $TotalDynamicHDDSpaceAllocated = $TotalDynamicHDDSpaceAllocated + $vhd.Size
            $checkpoint = "False"
            }
        }

    #Format vhd sizes to GB
    $TotalDynamicHDDSpaceAllocated = "{0:N0}" -f ($TotalDynamicHDDSpaceAllocated / 1070491238)
    $TotalHDDSpaceUsed = "{0:N0}" -f ($TotalHDDSpaceUsed  / 1070491238)

    #Add variables to report object
    $report = New-Object System.Object
    $report |  Add-Member -type NoteProperty -name "VMName" -value $vm.VMName
    $report |  Add-Member -type NoteProperty -name "State" -value $vm.state
    $report |  Add-Member -type NoteProperty -name "Status" -value $vm.status
    $report |  Add-Member -type NoteProperty -name "HostName" -value $vm.ComputerName
    $report |  Add-Member -type NoteProperty -name "Generation" -value $vm.Generation
    $report |  Add-Member -type NoteProperty -name "Version" -value $vm.Version
    $report |  Add-Member -type NoteProperty -name "ReplicationState" -value $vm.ReplicationState
    $report |  Add-Member -type NoteProperty -name "Notes" -value  $vm.Notes
    $report |  Add-Member -type NoteProperty -name "CPUCount" -value $vm.ProcessorCount
    $report |  Add-Member -type NoteProperty -name "DynamicMemoryEnabled" -value $vm.DynamicMemoryEnabled
    $report |  Add-Member -type NoteProperty -name "MemoryStartup" -value ($vm.MemoryStartup/1024/1024/1024)
    $report |  Add-Member -type NoteProperty -name "MemoryMinimum" -value ($vm.MemoryMinimum/1024/1024/1024)
    $report |  Add-Member -type NoteProperty -name "MemoryMaximum" -value ($vm.MemoryMaximum/1024/1024/1024)
    $report |  Add-Member -type NoteProperty -name "MemoryAssignedGB" -value ($vm.MemoryAssigned/1024/1024/1024)
    $report |  Add-Member -type NoteProperty -name "MemoryDemandGB" -value ($vm.MemoryDemand/1024/1024/1024)
    $report |  Add-Member -type NoteProperty -name "Checkpoint" -value $checkpoint
    $report |  Add-Member -type NoteProperty -name "Volume" -value $vm.ConfigurationLocation
    $report |  Add-Member -type NoteProperty -name "VHDMaxGB" -value $TotalDynamicHDDSpaceAllocated
    $report |  Add-Member -type NoteProperty -name "VHDActualGB" -value  $TotalHDDSpaceUsed
    $reports +=  $report

    }

}

#generate output file from report object
$reports | Export-Csv -Path C:\temp\vmreport_$datetime.csv -NoTypeInformation 
