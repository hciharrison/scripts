#Set cluster
[string]$Cluster = "hci-c01"
#Get CSV's from cluster
[string[]]$CSVs = Get-ClusterSharedVolume -Cluster "$Cluster" | Where-Object {$_.Name -notlike '*Infrastructure_1*'}
#Set required owners
$RequiredOwners = @{"RequiredOwner-UserStorage_1" = "hci-c01-n01";
                    "RequiredOwner-UserStorage_2" = "hci-c01-n02";
                    "RequiredOwner-UserStorage_3" = "hci-c01-n03";
                    "RequiredOwner-UserStorage_4" = "hci-c01-n04";
                    }

    #Start loop through CSV's
    $CSVs | % {

    #Set CSV name in usable variable
    $CSV = $_

    #Get current owner node
    [string]$CurrentOwner = (Get-ClusterSharedVolume -Cluster $Cluster -Name "$CSV").OwnerNode
    #Get Volume number by taking subsrting value away from name
    $volsubslength = ((((Get-ClusterSharedVolume -Cluster $Cluster -Name "$CSV").SharedVolumeInfo.FriendlyVolumeName) | Split-Path -Leaf).Length) - 1
    [string]$VolNumber = (((Get-ClusterSharedVolume -Cluster $Cluster -Name "$CSV").SharedVolumeInfo.FriendlyVolumeName) | Split-Path -Leaf).Substring($volsubslength)


        #Check volume ownership
        $ReqOwner = $RequiredOwners.Get_Item("RequiredOwner-UserStorage_$VolNumber")
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


