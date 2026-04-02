<# 
.SYNOPSIS
    Aligns Cluster Shared Volume ownership sequentially across cluster nodes.
.DESCRIPTION
    Dynamically retrieves all nodes and CSVs and assigns CSV ownership sequentially.
    Logs BEFORE + AFTER state to a UTF-8 encoded log file.
    Console output is color-coded and shows final ownership after all moves.
    Created for clusters with 1 x CSV per Node (should work with multiple volumes).
.NOTES
    Dot source the script first: . .\Set-CsvBalancedOwnership.ps1
#>
function Set-CsvBalancedOwnership {
    param(
        [Parameter(Mandatory=$true)][string]$Cluster,
        [string]$LogPath
    )

    # Log path handling
    if (-not $LogPath) {
        $LogPath = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
    }
    if (-not (Test-Path $LogPath)) { New-Item -ItemType Directory -Path $LogPath | Out-Null }
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $LogFile = Join-Path $LogPath "CSV_Ownership_$Cluster`_$Timestamp.log"

    function Write-Log { param([string]$Message)
        $Time = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        "$Time $Message" | Out-File -FilePath $LogFile -Encoding utf8 -Append
    }

    Write-Host "`n=== Balancing CSV Ownership on '$Cluster' ===`n" -ForegroundColor Cyan
    Write-Log "=== Start CSV Balancing on $Cluster ==="

    $Nodes = Get-ClusterNode -Cluster $Cluster | Sort-Object Name
    $CSVs  = Get-ClusterSharedVolume -Cluster $Cluster |
             Where-Object { $_.Name -notlike '*Infrastructure_1*' } |
             Sort-Object Name

    # BEFORE STATE
    Write-Log "---- BEFORE STATE ----"
    foreach ($CSV in $CSVs) { Write-Log ("{0,-40} owned by {1}" -f $CSV.Name, $CSV.OwnerNode) }

    Write-Host "Found $($Nodes.Count) Nodes" -ForegroundColor DarkGray
    Write-Host "Found $($CSVs.Count) CSVs`n" -ForegroundColor DarkGray

    $MovedCount = 0; $AlignedCount = 0

    # Balance loop
    for ($i = 0; $i -lt $CSVs.Count; $i++) {
        $CSV = $CSVs[$i]
        $TargetNode = $Nodes[$i % $Nodes.Count]
        $CurrentOwner = $CSV.OwnerNode

        if ($CurrentOwner -eq $TargetNode.Name) {
            Write-Host ("{0} already aligned to {1}" -f $CSV.Name, $TargetNode.Name) -ForegroundColor Green
            $AlignedCount++
            continue
        }

        Write-Host ("{0} → moving to {1}" -f $CSV.Name, $TargetNode.Name) -ForegroundColor Yellow
        Write-Log "$($CSV.Name) moving from $CurrentOwner → $($TargetNode.Name)"

        try {
            Move-ClusterSharedVolume -Cluster $Cluster -Name $CSV.Name -Node $TargetNode.Name -ErrorAction Stop | Out-Null
            Write-Host " ✓ moved" -ForegroundColor Cyan
            Write-Log "Move success."
            $MovedCount++
            Start-Sleep 3
        }
        catch {
            Write-Host (" !! ERROR moving {0}" -f $CSV.Name) -ForegroundColor Red
            Write-Log "ERROR: failed to move $($CSV.Name)"
            Write-Log $_
        }
    }

    # AFTER STATE
    Write-Host "`n---- Final CSV Ownership ----`n" -ForegroundColor Cyan
    Write-Log "---- AFTER STATE ----"
    foreach ($CSV in $CSVs) {
        $UpdatedOwner = (Get-ClusterSharedVolume -Cluster $Cluster -Name $CSV.Name).OwnerNode
        $ExpectedNode = $Nodes[($CSVs.IndexOf($CSV) % $Nodes.Count)].Name
        $Color = if ($UpdatedOwner -eq $ExpectedNode) { 'Green' } else { 'Red' }
        Write-Host ("{0,-40} {1}" -f $CSV.Name, $UpdatedOwner) -ForegroundColor $Color
        Write-Log ("{0,-40} owned by {1}" -f $CSV.Name, $UpdatedOwner)
    }

    # Summary
    Write-Host "`n=== Summary ===`n" -ForegroundColor Cyan
    Write-Host "CSV Moved: $MovedCount" -ForegroundColor Cyan
    Write-Host "CSV Already Aligned: $AlignedCount" -ForegroundColor Green
    Write-Log "CSV Moved: $MovedCount"
    Write-Log "CSV Already Aligned: $AlignedCount"
    Write-Log "=== Completed ==="

    Write-Host "`nDone." -ForegroundColor Cyan
    Write-Host "Log located at: $LogFile`n" -ForegroundColor DarkGray
}
