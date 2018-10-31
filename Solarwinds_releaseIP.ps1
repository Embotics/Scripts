<#
.SYNOPSIS
Script to remove address reservation from Solarwinds IPAM

.DESCRIPTION
 Requires vCommander Release 6.1.9 or higher
 vCommander Powershell cmdlet
 Solarwinds SDK installed for Orion IPAM 4.6.0  https://github.com/solarwinds/OrionSDK/wiki/IPAM-4.6-API
 Run Syntax in vCommander Completion WF or Command WF
 powershell.exe C:\Scripts\Solarwinds\SW_releaseIP.ps1  "#{target.ipv4Addresses}"

#>

[CmdletBinding()]
	param(
        [Parameter(Mandatory=$true)]
        [String] $TargetAddress = $(Throw "IP address to release from Ipam.")     
        ) 

#-------------------------------------------------
#  Configuration Settings
#-------------------------------------------------

#vCommander
    $vCommanderServer = "localhost"         #address of your vCommander server
    $CredFile = 'c:\scripts\superuser.xml'  #Credential file to access your vCommander
#IPAM
    $SWCredfile = 'C:\Scripts\Solarwinds\swipam.xml'    #Credential file to access your SolarWinds IPAM
    $hostname = "solarwindsipam.pv.embotics.com"         #address of your Solarwinds server
    $ModulePath = "C:\Program Files (x86)\SolarWinds\Orion SDK\SWQL Studio\SwisPowerShell.dll"   # Module Path for the SolarWinds IPAM SDK Powwershell DLL

#-------------------------------------------------
#  Script Start
#-------------------------------------------------

#Remove and re-add the vCommander modules 
        Write-Host "Loading Modules"
        $module = @("VCommanderRestClient","VCommander" )
        ForEach($Modulename in $module){
                If (-not (Get-Module -name $moduleName)) {Import-Module -Name $moduleName 
                } else {Remove-Module $moduleName
                        Import-Module -Name $moduleName
                        }
                        Start-Sleep 1
                }

#Load the SolarWinds SDK
    Import-Module  $ModulePath 
 
#Setup the connection to Solwarwinds Swis
    $swcred = (New-DecryptCredential -keyFilePath $SWCredfile) 
    $swis = Connect-Swis -host $hostname -cred $swcred

#Release IP from solarwinds Ipam
    $Status = Invoke-SwisVerb $swis IPAM.SubnetManagement ChangeIPStatus @("$TargetAddress", "Available")
    if($Status.nil -eq 'true'){ Write-Host "Reservation for address $TargetAddress has been removed from solarwinds IPAM"  
        Exit 0;
        }