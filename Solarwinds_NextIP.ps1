<#
.SYNOPSIS
Script to reserve and assign IP from Solarwinds IPAM

.DESCRIPTION
 Requires vCommander Release 6.1.7 or higher
 vCommander Powershell cmdlet
 Solarwinds SDK installed for Orion IPAM 4.6.0  https://github.com/solarwinds/OrionSDK/wiki/IPAM-4.6-API
 Run Syntax in vCommander Approval WF 
 powershell.exe C:\Scripts\solarwinds\SW_GetIP.ps1 -RequestID "#{request.id}" -ServiceType "#{request.services[1].settings.customAttribute['Service Type']}"

#>

[CmdletBinding()]
	param(
        [switch]$Elevated,
        [Parameter(Mandatory=$True)]
        [String] $RequestID = $(Throw "Provide the vCommander Request ID"),
        [String] $ServiceType = $(Throw "Provide the Service Type")
        )

########################################################################################################################
#  Configuration Settings
########################################################################################################################


#vCommander
    $vCommanderURL = "https://localhost"         #address of your vCommander server
    $CredFile = 'c:\scripts\superuser.xml'  #Credential file to access your vCommander
#IPAM
    $SWCredfile = 'C:\Scripts\Solarwinds\swipam.xml'    #Credential file to access your SolarWinds IPAM
    $hostname = "solarwindsipam.pv.embotics.com"         #FQDN of your Solarwinds server
    $ModulePath = "C:\Program Files (x86)\SolarWinds\Orion SDK\SWQL Studio\SwisPowerShell.dll"   # Module Path for the SolarWinds IPAM SDK Powwershell DLL


########################################################################################################################
#  Script Logic
########################################################################################################################
 
IF($ServiceType -eq "Production"){
    $PortGroupName =  "PVNet21"
    $Subnet = '10.10.21.0'
    $Gateway = '10.10.21.251'
    $PrimaryDNS = '10.10.2.10'
    $SecondaryDNS = '10.10.2.11'
    $NetMask = '255.255.255.0'
    }
ElseIF($ServiceType -eq "Development"){
        $PortGroupName =  "DevNet22"
        $Subnet = '10.10.22.0'
        $Gateway = '10.10.22.251'
        $PrimaryDNS = '10.10.2.10'
        $SecondaryDNS = '10.10.2.11'
        $NetMask = '255.255.255.0'
        }
Else{Write-Error "Portgroup Variables Undefined" 
    Exit 1;
    }
########################################################################################################################
# Setting Cert Policy - required for successful auth if API is untrusted https
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
#  Script Start
########################################################################################################################

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

########################################################################################################################

#Setup the connection to Solwarwinds
    $swcred = (New-DecryptCredential -keyFilePath $SWCredfile) 
    $swis = Connect-Swis -host $hostname -cred $swcred

#Get All Data
    $AllSubnetData = Get-SwisData $swis 'SELECT R.Comments, R.Address as SubnetAddress, R.CIDR, R.FriendlyName, R.PercentUsed, R.SubnetID,(SELECT TOP 1 I2.IpAddress FROM IPAM.IPNode as I2 WHERE I2.Status=2 AND I2.SubnetId = R.GroupID ) AS FreeIpAddress FROM IPAM.GroupReport as R Where R.GroupType = ''8'''
    $AllIPData = Get-SwisData $swis "SELECT IPAddress, IPNodeId, SubnetId FROM IPAM.IPNode"
    $Subnet = $AllSubnetData  | Where-Object {$_.Comments -eq $PortGroupName}

#Setup Auth to Vcommander
    $vCred = New-DecryptCredential $Credfile

#Get Service request Information from request
    Try{$serviceRequestsendpoint = "/rest/v3/service-requests"
        $RequestidURL = $vCommanderURL+$serviceRequestsendpoint+'/'+$requestId
        $convertedJson = Invoke-RestMethod $RequestidURL -Credential $vCred
        $Requester = $convertedJson.summary.submitted_by
        }Catch {Write-Host "Failed to get requester information from vCommander" -ForegroundColor Red
                $error[0] | Format-List -Force
                Exit 1
                }

#Service requests
    Try{$serviceRequests = $convertedJson.services
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
           $serviceName = $service.service.name
            $ServiceID = ($AllServices | Select-Object id,name  | Where-Object {$_.name -eq $serviceName}).id
            $components = $service.components.name
            foreach ($component in $components) {
                $componentName = $component
                $PostParamsURL = $vCommanderURL+'/rest/v3/service-requests/'+$RequestId+'/services/'+$serviceName+'/components/'+$componentName+'/deployment-parameters'

            #Reserve the Next available IP in IPAM
                $AllSubnetData = Get-SwisData $swis 'SELECT R.Comments, R.Address as SubnetAddress, R.CIDR, R.FriendlyName, R.PercentUsed, R.SubnetID,(SELECT TOP 1 I2.IpAddress FROM IPAM.IPNode as I2 WHERE I2.Status=2 AND I2.SubnetId = R.GroupID ) AS FreeIpAddress FROM IPAM.GroupReport as R Where R.GroupType = ''8'''
                $Subnet = $AllSubnetData  | Where-Object {$_.Comments -eq $PortGroupName}
                $nextFreeIP = $Subnet.FreeIpAddress
                $IPData = $AllIPData | Where-Object {$_.IPAddress -eq $nextFreeIP}
                $IPID = $IPData.IPNodeId
                $IPSubnet = $IPData.SubnetId
                $Status = Invoke-SwisVerb $swis IPAM.SubnetManagement FinishIpReservation @($nextFreeIP, "Reserved")
                if($Status.nil -eq 'true'){
                    Set-SwisObject $swis -Uri "swis://$hostname/Orion/IPAM.IPNode/IpNodeId=$IPID" -Properties @{ Comments = 'Reserved by vCommander' }
                    }
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
                        "network": "$PortGroupName"
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