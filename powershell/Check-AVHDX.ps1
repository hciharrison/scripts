#Set Clusters
$clusters = “hci-cluster01”

foreach($cluster in $clusters) {
    $clusternodes = Get-ClusterNode -Cluster $cluster
        foreach($node in $clusternodes) {
            $ping = Test-Connection $node -Count 1 -Quiet
            if($ping -eq $false) {
            Write-Host "Cannot connect to node: $node so skipping" -ForegroundColor Red
            }
            Else {
            Write-Host "Running command on node:" $node -ForegroundColor Yellow
                    Invoke-Command -ComputerName $node -ScriptBlock {
                        $VMs = Get-VM –ErrorAction Ignore
                        foreach($VM in $VMs){
                            $VHDs = Get-VM -Name $VM.Name | Get-VMHardDiskDrive
                            if($vhds.path -match "avhdx"){
                            $VMSnapshots = Get-VMSnapshot -VMName $VHDs.VMName
                            "$($VM.Name) is $($VM.Status) and running on AVHDXs"
                            "Disk Name(s):"
                            $VHDs | % { $_.Path }
                            "Checkpoint Name(s):"
                            $VMSnapshots | % { $_.Name } -ErrorAction SilentlyContinue
                            }
                        }
                    }
            }
        }
}
