<#
Description: Script that calls out to Infoblox to delete the dns for a VM in the decommissioning request
Requirements: 
-VComamnder 6.1.4 or higher
-Powershell V4 or greater
-InfoBlox 8.1.2 or greater
-ssl cert on infoblox or trusting the default selfsigned cert to avoid: "Could not create SSL/TLS secure channel"

Note:
Your Environment may differ depending on how infoblox has been configured. 

vCommander workflow Run Syntax:
powershell.exe c:\Scripts\InfoBlox\InfoBlox_deleteArecord.ps1 -DnsName "#{target.dnsName}" -Address "#{target.ipv4Addresses}"
#>

########################################################################################################################
# Variables Passed in by vCommander passed in on the decomissioning workflow for a VM
########################################################################################################################

[CmdletBinding()]
	param(                 
        [Parameter(Mandatory=$True)]
        [String] $DNSName = $(Throw "Provide the VM's DNS Name"),
        $ADDRESS = $(Throw "Provide the Target VM's IP address")      
        )

##################################################################
# Configure the variables below using the Production vCommander
##################################################################

    #infoblox Info
    $infobloxURL = "https://10.10.20.10"        # infoblox Base URL
    $infoBloxCred = "c:\Scripts\infoblox.xml"   # Encrypted Credfile for Infoblo
    $Zone = "bullet.local"                      # Zone to add records 

########################################################################################################################
# Nothing to configure below this line - Starting the main function of the script
########################################################################################################################
# Load vCommander Modules
########################################################################################################################

#Reload the modules for credential encryption
        Write-Host "Loading Modules"
        $module = @("VCommanderRestClient","VCommander" )
        ForEach($Modulename in $module){
                If (-not (Get-Module -name $moduleName)) {Import-Module -Name $moduleName 
                } else {Remove-Module $moduleName
                        Import-Module -Name $moduleName
                        }
                        Start-Sleep 1}

########################################################################################################################
# Setting Cert Policy - required for successful auth with the infoblox API if set to https
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
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

#Setup Auth to Infoblox
    $iCred = New-DecryptCredential $infoBloxCred
    $authInfo = ("{0}:{1}" -f $iCred.GetNetworkCredential().userName,$iCred.GetNetworkCredential().Password)
    $authInfo = [System.Text.Encoding]::UTF8.GetBytes($authInfo)
    $authInfo = [System.Convert]::ToBase64String($authInfo)
    $headers = @{Authorization=("Basic {0}" -f $authInfo)}
    $contentType = "application/json"

#Only grab the first(primary)address if there are more than one
    $Address = ($ADDRESS.split(","))[0]

#force Dnsname to lowercase to be handled by infoblox correctly
    $DNSName = $DNSName.ToLower()

#Verify Target Name has correct syntax and Zone Specifically to handle Linux which may have a localhost.local
    If($DNSName -like "*$zone*")
        {$Domainname=$Dnsname}
        Else{$Name = ($DNSName.split("."))[0]
             $Domainname = "$name"+"."+"$zone"
            }

#Write out for Comments/Debug
    Write-debug "Address = $ADDRESS"
    Write-debug "DNSName = $DomainName"

#Get All Zones from Infoblox
    
    #Get record Ref
    $Getrecords = $infobloxURL +"/wapi/v2.6/record:a?name=$Domainname"
    $Records_result = Invoke-WebRequest -Uri $Getrecords -Headers $headers -Method GET -ContentType $contentType
    $RefData = ConvertFrom-Json $Records_result.Content
    $Ref = $RefData._ref
  
    #delete based on ref
    $DeleteURL = $infobloxURL +"/wapi/v2.6/"+"$Ref"
    $DeleteResult = Invoke-WebRequest -Uri $DeleteURL -Headers $headers -Method DELETE -ContentType $contentType   
    $StatusCode = $DeleteResult.StatusCode
    $StatusDescription = $DeleteResult.StatusDescription
	Write-debug "Record deleted with Status Code $StatusCode - $StatusDescription"
          

