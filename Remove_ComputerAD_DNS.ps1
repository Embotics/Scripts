<#
Usage, Remove a computer account from AD and DNS A record
Requires Powershell V4 and Embotics vCommander Rest API V2.8
Tested against vCommander 6.1.X In the form of  powershell.exe c:\scripts\Remove_ComputerAD_DNS.ps1 #{target.id}
Additional parameters can be passed in and used to populate the comments with more details http://www.embotics.com/documentation/index.html?variables_completion_wf.htm
#>

[CmdletBinding()]
	param(
        [Parameter(Mandatory=$True)]
        [String] $Targetid = $(Throw "Provide the VM ID to Continue.")
        ) 

##############################################################################################################
###                                 Edit These for your Environment                                        ###
##############################################################################################################

#Connect to the vCommander system
$vCommanderServer = "localhost" #address of your vCommander server
$CredFile = 'c:\scripts\superuser.xml'  #Credential file to access your vCommander

#AD Creds
$AdCredfile = 'C:\scripts\adcred.pass'  #Credential file to access AD
$Ad2Credfile = 'C:\scripts\ad2cred.pass'  #Credential file to access AD

##############################################################################################################
###                                                                                                        ###
##############################################################################################################

#Remove and re-add the modules 
        $Modules = @("vCommanderRestClient","vCommander")
        Foreach($modulename in $modules){
            If (-not (Get-Module -name $moduleName)) {Import-Module -Name $moduleName 
                } else {Remove-Module $moduleName
               Import-Module -Name $moduleName 
                }
                }

#Connecting to vCommander
    $Global:SERVICE_HOST = $vCommanderServer
    $Global:REQUEST_HEADERS =@{}
    $Global:BASE_SERVICE_URI = $Global:BASE_SERVICE_URI_PATTERN.Replace("{service_host}",$Global:SERVICE_HOST)   
    $cred = (New-DecryptCredential -keyFilePath $CredFile) 	
    $Global:CREDENTIAL = $cred
    VCommander\Set-IgnoreSslErrors
    $Connect = Connect-Client

#Get vm Information
    Try{$VmInfo = Get-VM -Id $Targetid
        $vmdnsName = $vminfo.VirtualMachine.dnsName
        $vmDnsarray = @($vmdnsName.split(".",2))
        $Domainname = $vmDnsarray[1]
        }
        Catch{Write-Host $_.Exception.ToString()
              $error[0] | Format-List -Force
        }

#Set Active Directory Domain Controller address for PSSession
    IF($DomainName -eq "domain.com"){
       $TargetDC = "dc1.domain.com"
       Write-debug "Connecting to $TargetDC"
       #Create the AD credentials
       $Acred = (New-DecryptCredential -keyFilePath $AdCredfile) 
        }
    elseIF($DomainName -eq "domain2.com"){
       $TargetDC = "dc1.domain2.com"
       Write-debug "Connecting to $TargetDC"
       $Acred = (New-DecryptCredential -keyFilePath $otherADCredfile) 
        }
    else{Write-host "Domain is not in the supplied List, Nothing to do"
        Exit 1;
        }

#Test AD DC connection
    $vcmdrConnectionResult = Test-Connection -computer $TargetDC -quiet
    if (!$vcmdrConnectionResult) {
        Write-Error "The ActiveDirectory server $TargetDC could not be reached."
        Throw “The ActiveDirectory server $TargetDC could not be reached. Connectivity to the specified server could not be established.”
    }  
    else{
        Write-Debug "Connected to $TargetDC"
    }

#Create remote session to ad controller 
    $session = new-pssession -ComputerName $TargetDC -Credential $Acred
    $Computer = invoke-command -session $session  -ArgumentList $vmDnsarray[0] -ScriptBlock {   
        #Parameters List
        param ($vmParam)    
        #Set executionpolicy to bypass warnings in this session
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
        Import-Module activedirectory
         Try{#Delete Computer from AD
            $VMInfo = @((Get-ADComputer $vmParam).DNSHostName.split(".",2))
            $DomainName = $VMInfo[1]
            Get-ADComputer $vmParam| Remove-ADObject -Confirm:$False
            #Remove-ADComputer $vmname -Confirm:$False
            }
            Catch{Write-Host $_.Exception.ToString()
                  $error[0] | Format-List -Force
                  }  
        Try{#Build our DNSCMD DELETE command syntax this can be done in PS on newer DC's but should still work.  
            $cmdDelete = "dnscmd localhost /RecordDelete $DomainName $vmParam A /f" 
            Invoke-Expression $cmdDelete 
            }
           Catch{Write-Host $_.Exception.ToString()
                 $error[0] | Format-List -Force
                 } 
    }

Remove-PSSession $TargetDC