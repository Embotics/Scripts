<#
Description: Script that Calls out to IPAM to get the next available IP address for the VM in the request based on the Service Type Attribute on the request form in vCommander.
Requirements: 
-VComamnder 6.1.x
-Powershell V4 or greater
-PhpIpam 1.3.1 or greater

Note:
Your Environment maye require additional or diffrent logic depending on how phpipam has been configured. This Example assumes the virtual Portgroup Name matches the subnet Description in PhpIpam. 

vCommander workflow Run Syntax:
powershell.exe c:\Scripts\phpipam\phpipam_nextIP.ps1 -RequestID "#{request.id}" -ServiceType "#{request.services[1].settings.customAttribute['Service Type']}"
#>

################################################
# Variables Passed in by vCommander when user requests the vm
################################################

[CmdletBinding()]
	param(
        [switch]$Elevated,
        [Parameter(Mandatory=$True)]
        [String] $RequestID = $(Throw "Provide the vCommander Request ID"),
        [String] $ServiceType = $(Throw "Provide the Service Type")
        )

################################################
# Configure the variables below using the Production vCommander & ZVM.
################################################
    #phpipam Info
    $phpipamURL = "http://phpipamIPaddress/phpipam"         #Phpipam Base URL
    $phpipamCred = "C:\scripts\phpipam.pwd"           #Encrypted CredFile for Phpipam
    $phpipamAppID = "vcommander"                     #AppID in svrphpipam Set to "None" for security to use password auth only not token auth. 
    $Description = "Created by vCommander"         #Tag for each Entry Created in phpipam so admin's know the source
    #vCommander Info
    $vCredFile = "c:\Scripts\superuser.xml"           #Encrypted Credfile for vCommander
    $vCommanderURL = "https://yourvCommander"    #VCommander URL

########################################################################################################################
# Logic to Align Service Type Attribute to subnetID and network in PhPiPAM
########################################################################################################################

    IF ($ServiceType -eq "Production"){$Portgroup = "ProductionPG"}
    elseif ($ServiceType -eq "Development"){$Portgroup = "DevelopmentPG"}

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
        }Catch{Write-Host "Failed to Authenticate to Ipam" -ForegroundColor Red
                $error[0] | Format-List -Force
                Exit 1
                }
#Extracting Token from the response, and adding it to the actual API
    $phpipamToken = ($iPamSessionResponse | ConvertFrom-Json).data.token
    $phpipamsessionHeader = @{"token"=$phpipamToken}

#Get All Sections for phpIpam to pull all subnets
    $SectionsURL =  $phpipamURL +"/api/$phpipamAppID/sections/"
    Try{$SectionJson = Invoke-WebRequest -Uri $SectionsURL -Headers $phpipamsessionHeader -Method GET -ContentType $contentType
        $SectionData = ($SectionJson | ConvertFrom-Json).data | Select-Object name,id
         }Catch {Write-Host "Failed to Authenticate to get Sections from Ipam" -ForegroundColor Red
                $error[0] | Format-List -Force
                Exit 1
                }
    
#foreach Section Pull all Subnets.
    Try{
    $allSubnets = @()
    Foreach($Section in $SectionData){
        $SectionID = $Section.id
        $GetSubnetsURL =  $phpipamURL +"/api/$phpipamAppID/sections/$Sectionid/subnets/"
        $GetSubnetsJson = Invoke-WebRequest -Uri $GetSubnetsURL -Headers $phpipamsessionHeader -Method GET -ContentType $contentType
        $GetSubnetData = ($GetSubnetsJson | ConvertFrom-Json).data | Select-Object id,description,subnet
        $allSubnets += $GetSubnetData
        }
        }Catch {Write-Host "Failed to Get Subnets from Ipam" -ForegroundColor Red
                $error[0] | Format-List -Force
                Exit 1
                }
#Set Subnet ID to Patch PortGroup
    $subnetid = ($allSubnets | Where-Object {$_.description -eq $Portgroup}).id

#Get Data from Specific Subnet(Gateway, netmask, dns)
    Try{$SubnetURL = $phpipamURL +"/api/$phpipamAppID/subnets/$subnetid/"
        $SubNetJson = Invoke-WebRequest -Uri $SubnetURL -Headers $phpipamsessionHeader -Method GET -ContentType $contentType
        $SubnetData = $SubNetJson | ConvertFrom-Json
        $Gateway = $SubnetData.data.gateway.ip_addr
        $Netmask = $SubnetData.data.calculation.'Subnet netmask'
        $PrimaryDNS = ($SubnetData.data.nameservers.namesrv1).Split(';')[0]
        $SecondaryDNS = ($SubnetData.data.nameservers.namesrv1).Split(';')[1]
        }Catch {Write-Host "Failed to retrieve subnet data from Ipam" -ForegroundColor Red
                $error[0] | Format-List -Force
                Exit 1
                }

#Setup Auth to Vcommander
    $vCred = New-DecryptCredential $vCredfile

#Get Service request Information from request
    Try{$serviceRequestsendpoint = "/rest/v3/servicerequests"
        $RequestidURL = $vCommanderURL+$serviceRequestsendpoint+'/'+$requestId
        $convertedJson = Invoke-RestMethod $RequestidURL -Credential $vCred
        $Requester = $convertedJson.summary.submitted_by
        }Catch {Write-Host "Failed to get requester information from vCommander" -ForegroundColor Red
                $error[0] | Format-List -Force
                Exit 1
                }

#Setup request body to Assign name to the IP address
    $JSONbody = 
    "{
    ""description"":""$Description"",
    ""owner"":""$Requester""
    }"

#Service requests
    Try{$serviceRequests = $convertedJson.service_requests
        $ServicesURL = $vCommanderURL+'/rest/v3/services'
        $Services = Invoke-WebRequest -contentType "application/json" -Uri $ServicesURL -Method GET -Credential $vCred
        $AllServices = ($services |ConvertFrom-Json).items
         }
         Catch {Write-Host "Failed to Get vCommander Services" -ForegroundColor Red
                $error[0] | Format-List -Force
                Exit 1
                }

#Iterate through the Request and set IP address information
    foreach ($service in $serviceRequests) {
            $serviceName = $($service | Get-Member -MemberType *Property).Name
            $ServiceID = ($AllServices | Select-Object id,name  | Where-Object {$_.name -eq $serviceName}).id
            $components = $service.$serviceName.components
            foreach ($component in $components) {
                $componentName = $($component | Get-Member -MemberType *Property).Name
                $PostParamsURL = $vCommanderURL+'/rest/v3/servicerequests/'+$RequestId+'/services/'+$serviceName+'/components/'+$componentName+'/deploymentparameters'

            #Perform Get Request for next available IP from phpipam
                $nextFreeURL = $phpipamURL +"/api/$phpipamAppID/addresses/first_free/$subnetid/"
                $nextfreeRequest = Invoke-WebRequest -Uri $nextFreeURL -Headers $phpipamsessionHeader -Body $JSONbody -Method POST -ContentType $contentType
                $nextFreeIP = ($nextfreeRequest | ConvertFrom-Json).data 
                $Status = ($nextfreeRequest | ConvertFrom-Json).message
                if($Status -eq 'Address created'){
                     Write-host $status}
                elseif($Status -ne 'Address created')
                      {Write-host "Failed to Get net IP fro IPAM" -ForegroundColor Red
                       Exit;1}
                 

            #Setup Json param body to post to the service
$postBody = @"
    {
    "deployment_parameters": {
        "nics": [
                    {
                        "ip": "$nextFreeIP",
                        "netmask": "$netmask",
                        "gateway": "$Gateway",
                        "dns_primary": "$PrimaryDNS",
                        "dns_secondary": "$SecondaryDNS",
                        "network": "$Portgroup"
                    }
            ]
        }
    }
"@
            #  Write-Host $postBody
            Try{$postJSON = Invoke-WebRequest -contentType "application/json" -Uri $PostParamsURL -Method POST -Body $postBody -Credential $vCred
                }
                Catch {Write-Host "Failed to post deployment parameters to vCommander" -ForegroundColor Red
                       $error[0] | Format-List -Force
                       Exit 1
                       }
           }   
        }





 
