#Set cluster
[string]$Cluster = "hci-c1"
#Get CSV's from cluster
[string[]]$CSVs = Get-ClusterSharedVolume -Cluster "$Cluster"
#Set required owners
$RequiredOwners = @{"RequiredOwner-Volume01" = "hci-c1-n1";
                    "RequiredOwner-Volume02" = "hci-c1-n1";
                    "RequiredOwner-Volume03" = "hci-c1-n2";
                    "RequiredOwner-Volume04" = "hci-c1-n2";
                    }

    #Start loop through CSV's
    $CSVs | % {

    #Set CSV name in usable variable
    $CSV = $_

    #Get current owner node
    [string]$CurrentOwner = (Get-ClusterSharedVolume -Cluster $Cluster -Name "$CSV").OwnerNode
    #Get Volume number by taking subsrting value away from name
    $volsubslength = ((((Get-ClusterSharedVolume -Cluster $Cluster -Name "$CSV").SharedVolumeInfo.FriendlyVolumeName) | Split-Path -Leaf).Length) - 2
    [string]$VolNumber = (((Get-ClusterSharedVolume -Cluster $Cluster -Name "$CSV").SharedVolumeInfo.FriendlyVolumeName) | Split-Path -Leaf).Substring($volsubslength)


        #Check volume ownership
        $ReqOwner = $RequiredOwners.Get_Item("RequiredOwner-Volume$VolNumber")
        If($CurrentOwner -eq $ReqOwner){
        Write-Host ""$CSV" is already owned by Node $ReqOwner" -ForegroundColor Green
        }
        Else{
        #Change ownership
        Write-Host "$CSV not balanced, it will be moved to Node $ReqOwner" -ForegroundColor Yellow
        $(Read-Host -Prompt 'Press Enter to move CSV, or cancel the script to stop')
        Move-ClusterSharedVolume -Name $CSV -Cluster $Cluster -Node $ReqOwner
        Sleep 1
        }
    }
    
