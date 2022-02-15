<#
  .SYNOPSIS
  Gets Defender details for servers in a cluster, i.e. defender

  .DESCRIPTION
  This script is to get antimalware details for cluster nodes.
  The ComputerNames are read from the clustername(s) given to the function.
  If a connection to a node fails then the output will generate a row with Null values and show a 'Disconnected' status
  Defender cmdlets for reference:
    Get-MpComputerStatus
    Get-MpPreference
    Get-MpThreat
    Get-MpThreatCatalog
  Requires -runasadministrator

  .PARAMETER InputPath

  .INPUTS
  Requires ClusterName(s)

  .OUTPUTS
  Malware stats for cluster nodes

  .EXAMPLE
  #First load function
  C:\PS>. .\Get-DefenderDetails.ps1
  C:\PS>Get-DefenderDetails -ClusterName cluster1 | Format-Table -AutoSize
  C:\PS>Get-DefenderDetails -ClusterName cluster1, cluster2 | Format-Table -AutoSize

  .NOTES
  Written by: Lee Harrison
  Created: 2020/02/01
  URL: https://hciharrison.com
#>

Function Get-DefenderDetails { #make a function out of the below code

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$ClusterName #require a clustername
        #[Parameter()]
        #[string[]]$ComputerName #here if you want to expand script to choose just a single node
    )

    BEGIN {
    #Set cluster name(s) manually to report on
    #$ClusterName = "cluster1", "cluster2"
        }

    PROCESS {
    foreach($cluster in $ClusterName)  {
        $ComputerName = Get-ClusterNode -Cluster $cluster -ErrorAction SilentlyContinue -ErrorVariable ClusterNameError; #check cluster names are valid
        If($ClusterNameError) { #if clustername is not valid write warning message
        Write-Warning -Message "The ClusterName $Cluster is not recognised";
        }

    foreach ($computer in $ComputerName) {
        try { #check if can connect to server
            $session = New-CimSession -ComputerName $computer -ErrorAction Stop #connect to each computer and set error action
            $ams = Get-MpComputerStatus -CimSession $session #get values
            #$amp = Get-MpPreference -CimSession $session #placeholder if need preference info
            Write-Verbose "Connected to $computer" #included in verbose output
            $properties = [ordered]@{ComputerName = $Computer #values for hashtable if able to connect to computer
                            Status = 'Connected'
                            AMEngineVersion = $ams.AMEngineVersion
                            AMProductVersion = $ams.AMProductVersion
                            AMServiceEnabled = $ams.AMServiceEnabled
                            AMServiceVersion = $ams.AMServiceVersion
                            AntispywareEnabled = $ams.AntispywareEnabled
                            AntispywareSignatureAge = $ams.AntispywareSignatureAge
                            AntispywareSignatureLastUpdated = $ams.AntispywareSignatureLastUpdated
                            AntispywareSignatureVersion = $ams.AntispywareSignatureVersion
                            AntivirusEnabled = $ams.AntivirusEnabled
                            AntivirusSignatureAge = $ams.AntivirusSignatureAge
                            AntivirusSignatureLastUpdated = $ams.AntivirusSignatureLastUpdated
                            AntivirusSignatureVersion = $ams.AntispywareSignatureVersion
                            OnAccessProtectionEnabled = $ams.OnAccessProtectionEnabled
                            RealTimeProtectionEnabled = $ams.RealTimeProtectionEnabled}
        } catch { #if can't connect then add row with disconnected status and null values
            Write-Verbose "Couldn't connect to $computer" #included in verbose output
            $properties = [ordered]@{ComputerName = $computer #values for hashtable if can't connect to computer
                            Status = 'Disconnected'
                            AMEngineVersion = $null
                            AMProductVersion = $null
                            AMServiceEnabled = $null
                            AMServiceVersion = $null
                            AntispywareEnabled = $null
                            AntispywareSignatureAge = $null
                            AntispywareSignatureLastUpdated = $null
                            AntispywareSignatureVersion = $null
                            AntivirusEnabled = $null
                            AntivirusSignatureAge = $null
                            AntivirusSignatureLastUpdated = $null
                            AntivirusSignatureVersion = $null
                            OnAccessProtectionEnabled = $null
                            RealTimeProtectionEnabled = $null}
        }  finally { #run after try and catch

            $obj = New-Object -TypeName psobject -Property $properties #create hashtable from values
            Write-Output $obj

        }
        }

        }

    }

    END {}

}
