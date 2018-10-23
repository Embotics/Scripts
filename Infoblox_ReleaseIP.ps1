<#
Description: Script that Calls out to IPAM to release address for the VM in the decommissioning request
Requirements: 
-VComamnder 6.1.4 or higher
-Powershell V4 or greater
-InfoBlox 8.1.2 or greater

Note:
Your Environment may require additional or diffrent logic depending on how InfoBlox has been configured. This Example assumes there is no overlapping subnets in IPAM

vCommander workflow Run Syntax:
powershell.exe c:\Scripts\InfoBlox\InfoBlox_releaseIP.ps1 -IPAddress "#{target.ipv4Addresses}"
#>

########################################################################################################################
# Variables Passed in by vCommander passed in on the decomissioning workflow for a VM
########################################################################################################################

[CmdletBinding()]
	param(
        [switch]$Elevated,
        [Parameter(Mandatory=$True)]
        [String] $IPAddress = $(Throw "Provide the IP To Release")
        )

################################################
# Configure the variables below using the InfoBlox Server
################################################
    #############################################
    #infoblox Info
    $infobloxURL = "https://55.5.55.5"        #infoblox Base URL
    $infoBloxCred = "c:\Scripts\infoblox.xml"     # Encrypted Credfile for Infoblox
    #vCommander Info
    $vCredFile = "c:\Scripts\vCommanderCreds.xml"           #Encrypted Credfile for vCommander
    $vCommanderURL = "https://localhost"                    #VCommander URL
########################################################################################################################
# Nothing to configure below this line - Starting the main function of the script
########################################################################################################################
#Load vCommander Modules
########################################################################################################################
        Write-Host "Loading Modules"
        $moduleName = "VCommander"
        If (-not (Get-Module -name $moduleName)) {Import-Module -Name $moduleName 
        } else {Remove-Module $moduleName
                        Import-Module -Name $moduleName }

########################################################################################################################
# Setting Cert Policy - required for successful auth with the infoblox API if infoblox is unsigned
########################################################################################################################
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
########################################################################################################################
# Building InfoBlox API string and invoking API
########################################################################################################################

    #Setup Auth to Infoblox
    $iCred = New-DecryptCredential $infoBloxCred
    $authInfo = ("{0}:{1}" -f $iCred.GetNetworkCredential().userName,$iCred.GetNetworkCredential().Password)
    $authInfo = [System.Text.Encoding]::UTF8.GetBytes($authInfo)
    $authInfo = [System.Convert]::ToBase64String($authInfo)
    $InfoBloxsessionHeader = @{Authorization=("Basic {0}" -f $authInfo)}

    $getIPDetailsURL = $infobloxURL +"/wapi/v2.6/record:host?ipv4addr=$IPAddress"
    Try
    {
        $getIPDetails = Invoke-WebRequest -Uri $getIPDetailsURL -Headers $InfoBloxsessionHeader -Method GET
        $result = ($getIPDetails.Content | ConvertFrom-Json)
    }
    Catch
    {
        Write-Host "Failed to get Address details for $IPAddress from IPAM" -ForegroundColor Red
        exit 1
    }

	$ReclaimIPURL =  $infobloxURL + "/wapi/v2.6/" +$result._ref

#perform Remove 
    Try
    {
        $Delete = Invoke-WebRequest -Uri $ReclaimIPURL -Headers $InfoBloxsessionHeader -Method DELETE        
    }
    Catch
    {
        Write-Host "Failed to Delete Address $IPAddress from IPAM" -ForegroundColor Red
        $error[0] | Format-List -Force
        Exit 1
    }

    
    Write-host $Delete.StatusDescription
    
    if($Delete.StatusCode -eq 200){
       
        Exit;0
    }
    else
    {
        Exit;1
    }
