<#
Description: Script that Calls out to IPAM to get the next available IP address for the VM in the request based on the Service Type Attribute on the request form in vCommander.
Requirements: 
-VComamnder 7.0.2 or higher
-Powershell V4 or greater
-InfoBlox 8.1.2 or greater

Note:
Your Environment maye require additional or diffrent logic depending on how infoblox has been configured. This Example assumes the virtual Portgroup Name matches the subnet Description in infoblox. 

vCommander workflow Run Syntax:
powershell.exe c:\Scripts\infoblox\infobloxs_GetNextIP.ps1 -RequestID "#{request.id}" -ServiceType "#{request.services[1].settings.customAttribute['Service Type']}"
#>

################################################
# Variables Passed in by vCommander when user requests the vm
################################################

[CmdletBinding()]
	param(                 
        [Parameter(Mandatory=$True)]
        [String] $ServiceType = $(Throw "Provide the Service Type"),
        [Parameter(Mandatory=$True)]
        [String] $RequestID = $(Throw "Provide the vCommander Request ID")      
        )

########################################################################################################################
# Configure the variables below using the Production vCommander
########################################################################################################################
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

#Setup Auth to Infoblox
    $iCred = New-DecryptCredential $infoBloxCred
    $authInfo = ("{0}:{1}" -f $iCred.GetNetworkCredential().userName,$iCred.GetNetworkCredential().Password)
    $authInfo = [System.Text.Encoding]::UTF8.GetBytes($authInfo)
    $authInfo = [System.Convert]::ToBase64String($authInfo)
    $infobloxsessionHeader = @{Authorization=("Basic {0}" -f $authInfo)}
    $contentType = "application/json"

#Get All Networks from Infoblox
    $NetworksURL =  $infobloxURL +"/wapi/v2.6/network?comment~:=$ServiceType&_return_fields=comment,ipv4addr,netmask,network,network_view,options"
    Try
	{
		$NetworksJson = Invoke-WebRequest -Uri $NetworksURL -Headers $infobloxsessionHeader -Method GET -ContentType $contentType
		$NetworkData = ConvertFrom-Json -InputObject $NetworksJson
	}Catch {
		Write-Host "Failed to Authenticate to get Networks from Ipam" -ForegroundColor Red
		$error[0] | Format-List -Force
		Exit 1
	}  

#Get the Network Details
    foreach($elm in $NetworkData.options)
	{
		if($elm.name -eq "routers")
        {
            $Gateway = $elm.value
        }

        if($elm.name -eq "domain-name-servers")
        {
            $addresses = $elm.value.Split(",")

            if($addresses.count  -gt 0 -And $addresses[0] -ne $null)
            {
                $dns_primary = $addresses[0]
            }
            if($addresses.count -gt 1)
            {
                $dns_secondary = $addresses[1]
            }
        }

        if($elm.name -eq "domain-name")
        {
            $domainName = $elm.value
        }
	}

	
	$infobloxNetmask = $NetworkData.network

    switch ($NetworkData.netmask) 
    { 
        1 {$vCommanderNetmask = "128.0.0.0"} 
        2 {$vCommanderNetmask = "192.0.0.0"}
        3 {$vCommanderNetmask = "224.0.0.0"}
        4 {$vCommanderNetmask = "240.0.0.0"}
        5 {$vCommanderNetmask = "248.0.0.0"}
        6 {$vCommanderNetmask = "252.0.0.0"}
        7 {$vCommanderNetmask = "254.0.0.0"}
        8 {$vCommanderNetmask = "255.0.0.0"}
        9 {$vCommanderNetmask = "255.0.0.0"}
        10 {$vCommanderNetmask = "255.192.0.0"}
        11 {$vCommanderNetmask = "255.224.0.0"}
        12 {$vCommanderNetmask = "255.240.0.0"}
        13 {$vCommanderNetmask = "255.248.0.0"}
        14 {$vCommanderNetmask = "255.252.0.0"}
        15 {$vCommanderNetmask = "255.254.0.0"}
        16 {$vCommanderNetmask = "255.255.0.0"}
        17 {$vCommanderNetmask = "255.255.128.0"}
        18 {$vCommanderNetmask = "255.255.192.0"}
        19 {$vCommanderNetmask = "255.255.224.0"}
        20 {$vCommanderNetmask = "255.255.240.0"}
        21 {$vCommanderNetmask = "255.255.248.0"}
        22 {$vCommanderNetmask = "255.255.252.0"}
        23 {$vCommanderNetmask = "255.255.254.0"}
        24 {$vCommanderNetmask = "255.255.255.0"}
        25 {$vCommanderNetmask = "255.255.255.128"}
        26 {$vCommanderNetmask = "255.255.255.192"}
        27 {$vCommanderNetmask = "255.255.255.224"}
        28 {$vCommanderNetmask = "255.255.255.240"}
        29 {$vCommanderNetmask = "255.255.255.248"}
        30 {$vCommanderNetmask = "255.255.255.252"}
        31 {$vCommanderNetmask = "255.255.255.254"}
        32 {$vCommanderNetmask = "255.255.255.255"}

        default {Write-Host "The netmask is invalid" Exit 1}

    }
        

#Setup Auth to Vcommander
    $vCred = New-DecryptCredential $vCredfile

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
            foreach ($component in $components) 
            {
                $componentName = $component
                $PostParamsURL = $vCommanderURL+'/rest/v3/service-requests/'+$RequestId+'/services/'+$serviceName+'/components/'+$componentName+'/deployment-parameters'
                
                $date1 = Get-Date -Date "01/01/1970"
                $date2 = Get-Date                
                $DateValue = (New-TimeSpan -Start $date1 -End $date2).TotalSeconds

                $JSONbody = 
                    "{
	                  ""name"": ""$DateValue.reserved.$domainName"",
	                  ""ipv4addrs"": [
		                {
		                  ""ipv4addr"": ""func:nextavailableip:$infobloxNetmask""
		                }
	                  ]
	                }"

            #Perform POST Request to attach the next available IP from infoblox
                $nextFreeURL = $infobloxURL +"/wapi/v2.6/record:host"
                $nextfreeRequest = Invoke-WebRequest -Uri $nextFreeURL -Headers $infobloxsessionHeader -Body $JSONbody -Method POST -ContentType $contentType
                
                if($nextfreeRequest.StatusDescription -eq 'Created'){
                     Write-host $nextfreeRequest.StatusDescription}
                elseif($nextfreeRequest.StatusDescription -ne 'Created')
                      {Write-host "Failed to Get net IP fro IPAM" -ForegroundColor Red
                       Exit;1}
                 
            #Get the IP addres value
            $addressGETURL = $infobloxURL + "/wapi/v2.6/" + $nextfreeRequest.Content.Substring(1,$nextfreeRequest.Content.Length - 2)
            $ipGETResponse = Invoke-WebRequest -Uri $addressGETURL -Headers $infobloxsessionHeader -Method GET -ContentType $contentType

            $nextFreeIP = ($ipGETResponse.Content |ConvertFrom-Json).ipv4addrs.ipv4addr


            #Setup Json param body to post to the service
$postBody = @"
    {
        "nics": [
                    {
                        "ip": "$nextFreeIP",
                        "netmask": "$vCommanderNetmask",
                        "gateway": "$Gateway",
                        "dns_primary": "$dns_primary",
                        "dns_secondary": "$dns_secondary",
                        "network": "$ServiceType"
                    }
            ]
        }
"@
            #  Write-Host $postBody
            Try
            {
                $postJSON = Invoke-WebRequest -contentType "application/json" -Uri $PostParamsURL -Method POST -Body $postBody -Credential $vCred
            }
            Catch 
            {
                Write-Host "Failed to post deployment parameters to vCommander" -ForegroundColor Red
                $error[0] | Format-List -Force
                Exit 1
            }
           }   
        }





 
