<#
Requirements: 
-VComamnder 6.1.4 or higher
-Powershell V4 or greater

Connect to VC and shutdown VM
#>        

# Edit these lines to specify the vSphere host, the location of the credential file,
# and the name of the vm that should be quarantined

$VIServer = "VCenter.domain.com"
$CredFile = "C:\scripts\cred.XML"
$VMName = "OtherHAhostname"

#Remove and re-add the modules 
    Write-Host "Loading Modules"
    $module = @("VCommanderRestClient","VCommander","VMware.VimAutomation.core" )
    ForEach($Modulename in $module){
            If (-not (Get-Module -name $moduleName)) {Import-Module -Name $moduleName 
            } else {Remove-Module $moduleName
                    Import-Module -Name $moduleName
                    }
                    Start-Sleep 1
            }

# Validate that the script has been set up properly

If ($VIServer -eq $null)
{
	Write-Error 'Set the $VIServer variable to the location of the VmWare server that is running the machine to be quarantined'
	Exit 1
}

If ($CredFile -eq $null)
{
	Write-Error 'Run the New-EncryptCredentials command and set the location of the saved credentials in the $CredFile variable'
	Exit 1
}

If ($VMName -eq $null)
{
	Write-Error 'Set the $VMName variable to the name of the virtual machine that is to be quarantined'
	Exit 1
}

# Get the credentials from the file

$cred = (New-DecryptCredential -keyFilePath $CredFile) 

# Connect to the Server

Connect-VIServer -Server $VIServer -credential $cred
Write-Host "Connected to $VIServer" 

# Shut down the given virtual machine

$vm = Get-VM $VMName
$State = $vm.PowerState
If ($State -eq "PoweredOn")
{
	Stop-VM $VMName -Confirm:$False
	$State = ((Get-VM $VMName).Powerstate)
}

Write-Host "$VMName is $State"