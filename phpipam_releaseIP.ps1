<#
Description: Script that Calls out to IPAM to release address for the VM in the decommissioning request
Requirements: 
-VComamnder 6.1.4 or higher
-Powershell V4 or greater
-PhpIpam 1.3.1 or greater

Note:
Your Environment maye require additional or diffrent logic depending on how phpipam has been configured. This Example assumes there is no overlapping subnets in IPAM

vCommander workflow Run Syntax:
powershell.exe c:\Scripts\phpipam\phpipam_releaseIP.ps1 -IPAddress "#{target.ipv4Addresses}"
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
# Configure the variables below using the PHPIpam Server
################################################
    #phpipam Info
    $phpipamURL = "http://ipamserverIP"         #Phpipam Base URL
    $phpipamCred = "C:\scripts\phpipam.pwd"           #Encrypted CredFile for Phpipam
    $phpipamAppID = "vcommander"                     #AppID in svrphpipam Set to "None" for security to use password auth only not token auth. 

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
# Setting Cert Policy - required for successful auth with the phpipam API if set to https
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
# Building phpipam API string and invoking API
########################################################################################################################
    $baseAuthURL = $phpipamURL +"/api/$phpipamAppID/user/"
    # Authenticating with phpipam APIs
    $PHPcred = New-DecryptCredential $phpipamCred
    $authInfo = ("{0}:{1}" -f $PHPcred.GetNetworkCredential().userName,$PHPcred.GetNetworkCredential().Password)
    $authInfo = [System.Text.Encoding]::UTF8.GetBytes($authInfo)
    $authInfo = [System.Convert]::ToBase64String($authInfo)
    $headers = @{Authorization=("Basic {0}" -f $authInfo)}
    $sessionBody = '{"AuthenticationMethod": "1"}'
    $contentType = "application/json"
    Try{$iPamSessionResponse = Invoke-WebRequest -Uri $baseAuthURL -Headers $headers -Method POST -ContentType $contentType
          }Catch{Write-Host "Failed to authenticate to Ipam" -ForegroundColor Red
                $error[0] | Format-List -Force
                Exit 1
                }
     
#Extracting Token from the response, and adding it to the actual API
    $phpipamToken = ($iPamSessionResponse | ConvertFrom-Json).data.token
    $phpipamsessionHeader = @{"token"=$phpipamToken}

#Get All Sections for phpIpam to pull all subnets ***Not needed but here just incase an alternate use case would need it***
   # $SectionsURL =  $phpipamURL +"/api/$phpipamAppID/sections/"
   # $SectionJson = Invoke-WebRequest -Uri $SectionsURL -Headers $phpipamsessionHeader -Method GET -ContentType $contentType
   # $SectionData = ($SectionJson | ConvertFrom-Json).data | Select-Object name,id
    
#foreach Section Pull all Subnets.***Not needed but here just incase an alternate use case would need it***
    #$allSubnets = @()
    #Foreach($Section in $SectionData){
     #   $SectionID = $Section.id
     #   $GetSubnetsURL =  $phpipamURL +"/api/$phpipamAppID/sections/$Sectionid/subnets/"
     #   $GetSubnetsJson = Invoke-WebRequest -Uri $GetSubnetsURL -Headers $phpipamsessionHeader -Method GET -ContentType $contentType
     #   $GetSubnetData = ($GetSubnetsJson | ConvertFrom-Json).data | Select-Object id,description,subnet
     #   $allSubnets += $GetSubnetData
     #   }

#Set Subnet ID to Patch PortGroup ***Not needed but here just incase an alternate use case would need it***
    #$subnetid = ($allSubnets | Where-Object {$_.description -eq $Portgroup}).id

#Get Data from Specific Subnet(Gateway, netmask, dns)
    Try{$IPURL = $phpipamURL +"/api/$phpipamAppID/addresses/search/$IPAddress/"
        $IPJson = Invoke-WebRequest -Uri $IPURL -Headers $phpipamsessionHeader -Method GET -ContentType $contentType
        $IPData = $IPJson | ConvertFrom-Json
        $IPSubnetID = $IPData.data.subnetid
         }Catch{Write-Host "Failed to get existing IP data from Ipam" -ForegroundColor Red
                $error[0] | Format-List -Force
                Exit 1
                }
    
#Setup request body to remove DNS Entry ***Not required - Depends on implementation of PhpIpam***
 $JSONbody = 
    "{
    ""remove_dns"":""1""
    }"

#perform Remove 
    Try{$DeleteURL = $phpipamURL +"/api/$phpipamAppID/addresses/$IPAddress/"+"$IPSubnetID/"
        $Delete = Invoke-WebRequest -Uri $DeleteURL -Headers $phpipamsessionHeader -Method Delete -ContentType $contentType
        #$DeleteURL1 = $phpipamURL +"/api/$phpipamAppID/addresses/$IPAddress"
        #$Delete1 = Invoke-WebRequest -Uri $DeleteURL -Headers $phpipamsessionHeader -Body $JSONbody -Method DELETE -ContentType $contentType
        $Status = ($Delete1 | ConvertFrom-Json).message
         }Catch{Write-Host "Failed to Delete Address $IPAddress from IPAM" -ForegroundColor Red
                $error[0] | Format-List -Force
                Exit 1
                }
        if($Status -eq 'Address deleted'){
           Write-host $status
          # Exit;0
           }
        else{Write-host "$Status"
            #Exit;1
        }
