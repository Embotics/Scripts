<# 
VERSION 1.0.0
DATE 11.2.18
When run it assigns any VM without an org to the organization assigned by the $TempOrg Variable, if that org does not exist it will be created. 
Requires: 
Powershell v4 or higher
vCommander version 6.1.6or higher    https://www.embotics.com/embotics-support-downloads
vCommander PowerShell cmdlet version 2.8 or higher   https://support.embotics.com/support/solutions/articles/8000035227-download-vcommander-rest-client

#>

$vCommanderServer = "localhost" #address of your vCommander server
$CredFile = 'C:\scripts\superuser.xml'  #Credential file to access your vCommander
$TempOrg = "No Organization"

#Verify PS Version 4 or higher.
    $Powershell = $PSVersionTable
    if($PSVersionTable.PSVersion.Major -lt "4"){
        Write-Host "Powershell is not V4 or higer, please upgrade Poswershell"
        Exit 1;
        }


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
        Connect-Client

# Get Organizations 
    Try{$org = $null
        $org = Get-Organization -name $TempOrg
        }
        Catch{$_.Exception.ToString()
             Write-host "Org does not exist"
                }

    if (!$org){
        #org does not exist creating org
        $orgDto = New-DTOTemplateObject -DTOTagName "Organization"
        $orgDto.Organization.name= $TempOrg
        $orgDto.Organization.PSObject.Properties.Remove("resourceQuota")
        #Add organization user(s)
        $orgDto.Organization.Members = @()
        $taskInfo = New-Organization -orgDto $orgDto
        $org = Get-OrganizationByName -name $TempOrg
        }

#Create an ownership DTO
                        $ownershipDto = New-DTOTemplateObject -DTOTagName "Ownership"
                        $ownershipDto.Ownership.organization.displayName = $org.Organization.name
                        $ownershipDto.Ownership.organization.id = $org.Organization.id

                        #Create a user
                        $user1DTO = New-DTOTemplateObject -DTOTagName "OwnerInfo"
                        $user1DTO.OwnerInfo.id = -1
                        $user1DTO.OwnerInfo.loginId  = "superuser"
                        $user1DTO.OwnerInfo.itContact = $true
                        $user1DTO.OwnerInfo.primary = $false
                        $user1DTO.OwnerInfo.email = $null
                        $user1DTO.OwnerInfo.displayName = $null

                        #Add the user to ownership structure
                        $ownershipDto.Ownership.Owners = @()
                        #$ownershipDto.Ownership.Owners  += $user1DTO.OwnerInfo

#loop throughthe vm's 20 at a time 
    $offset = 0
    $Maxcount = 20
#Loop 20 vm's at a time Until all vm's complete         
        Do {$vmloop = (get-vms -max $Maxcount -offset $offset).VirtualMachineCollection.VirtualMachines| Where-Object{$_.template -eq "false"} 
            $vmLoopCount = $vmloop.Count
            #new Offset
            $offset = [int]$offset + 20
            ForEach($vmdata in $vmloop){
                     $VMNAME = $VMData.displayName
                     if(!($Org = $VMData.organization.displayName)){
                        Write-host "$VMNAME does not have an Org Setting to '$TempOrg'"
                        $vmId = $vmdata.id

                        Set-Ownership -vmId $vmId -dto $ownershipDto
                        }
                        else{$Org = $VMData.organization.displayName
                            Write-host "$Vmname organization is $org"
                            }
            }}
             Until($vmloopcount -eq 0)
Write-host "Sync Complete"