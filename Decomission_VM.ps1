<#
Usage, Migrate a Decomissioning VM to a specific Folder
Requires Powershell V4 and Embotics vCommander Rest API V2.8
Tested against vCommander 6.1.X In the form of  "powershell.exe c:\Scripts\Decomission_VM.ps1 "#{target.id}""
Additional parameters can be passed in and used to populate the comments with more completion workflow details http://www.embotics.com/documentation/index.html?variables_completion_wf.htm
#>

[CmdletBinding()]
	param(
        [Parameter(Mandatory=$True)]
        [String] $Targetid = $(Throw "Provide the VM ID to Continue.")
        )            

##############################################################################################################
###                                 Edit These for your Environment                                        ###
##############################################################################################################

    $vCommanderServer = "localhost" #address of your vCommander server
    $CredFile = 'c:\scripts\superuser.xml'  #Credential file to access your vCommander
    $VIServer = 'viServer.domain.com'      #< vCenter Server name must be reachable (DNS/IP)
    $vCredFile = 'c:\scripts\viServerCred.xml'   #< vCenter Cred File
        
    $newowner = "Retired Servers"   #Retired Organization 
    $NewUser = "RetiredUser"        #Retired User
    $prevowner = "Previous Owner"      #previous Ownner set to an attribute for tracking 
    $Prevorg = "Previous Organization"   #previous Organization set to an attribute for tracking 
    $DecomDate = "Decomissioned"      #Attribute to track the Decomissioned date
    $date = Get-date -Format d     #Date Stamp for when it was decomissioned

    $DecomFolder = "Decom"    #folder to move the decomissioned vm

##############################################################################################################
###                                 Do Not Edit Below these Lines                                          ###
##############################################################################################################

#Remove and re-add the modules 
        $Modules = @("vCommanderRestClient","vCommander","VMware.VimAutomation.Core")
        Foreach($modulename in $modules){
            If (-not (Get-Module -name $moduleName)) {Import-Module -Name $moduleName 
                } else {Remove-Module $moduleName
               Import-Module -Name $moduleName 
                }
                }

#Connect to vCommander to get comments
    $Global:SERVICE_HOST = $vCommanderServer
    $Global:REQUEST_HEADERS =@{}
    $Global:BASE_SERVICE_URI = $Global:BASE_SERVICE_URI_PATTERN.Replace("{service_host}",$Global:SERVICE_HOST)   
	$cred = (New-DecryptCredential -keyFilePath $CredFile) 	
    $Global:CREDENTIAL = $cred
    VCommander\Set-IgnoreSslErrors
    $Connect = Connect-Client

#Check and make sure Org and user exists
    Try{$testorg = Get-OrganizationByName -name $newowner
        $testaccount = Get-Account -loginId $NewUser
        }
        Catch{write-host "Replacement organization or user account does not appear to exist in vCommander"
               Write-Host $_.Exception.ToString()
              $error[0] | Format-List -Force
            }

#Connect to vCenter
    $Cred = (New-DecryptCredential -keyFilePath $vCredFile) 
    $vConnect = Connect-VIServer -Server $VIServer -Credential $Cred
    Write-Host "Connected to $VIServer" 
    
#Get target VM Info
    $VMowner = (Get-vm -id $Targetid).VirtualMachine.owners.loginId
    $VMorganization = (Get-vm -id $Targetid).VirtualMachine.organization.displayName
    $VmRemoteID =  "VirtualMachine-"+((Get-VM -Id $Targetid).VirtualMachine.remoteid)

#Grab the organization
    $org = Get-OrganizationByName -name "$newowner"
	
#Create an ownership DTO
    $ownershipDto = New-DTOTemplateObject -DTOTagName "Ownership"
    $ownershipDto.Ownership.organization.displayName = $org.Organization.name
    $ownershipDto.Ownership.organization.id = $org.Organization.id

#Ensure Custom attribs are in vCommander for Previous Org and Owner.
    #Owner Attrib
    $CheckAttrib1 = ($Attrib1 = Get-CustomAttributes).CustomAttributeCollection.CustomAttributes | Where-Object{$_.Name -EQ $prevowner}
    If ($CheckAttrib1.displayName -ne $prevowner)
        {   $caObject1 = New-DTOTemplateObject -DTOTagName "CustomAttribute"
            #Specify attribute value
            $caObject1.CustomAttribute.name="$prevowner"
            $caObject1.CustomAttribute.description=""
            $caObject1.CustomAttribute.targetManagedObjectTypes = @("ALL")
            $caObject1.CustomAttribute.id = -1
            $caObject1.CustomAttribute.allowedValues = @()
            $createdCa1 = New-CustomAttribute -customAttributeDTo $caObject1
            }  
            start-sleep 5
    #Organization Attrib
    $CheckAttrib2 = ($Attrib2 = Get-CustomAttributes).CustomAttributeCollection.CustomAttributes | Where-Object{$_.Name -EQ $Prevorg}
    If ($CheckAttrib2.displayName -ne $Prevorg)
        {   $caObject2 = New-DTOTemplateObject -DTOTagName "CustomAttribute"
            #Specify attribute value
            $caObject2.CustomAttribute.name="$Prevorg"
            $caObject2.CustomAttribute.description=""
            $caObject2.CustomAttribute.targetManagedObjectTypes = @("ALL")
            $caObject2.CustomAttribute.id = -1
            $caObject2.CustomAttribute.allowedValues = @()
            $createdCa2 = New-CustomAttribute -customAttributeDTo $caObject2
            }   
            start-sleep 5
    #Decom Date Attrib
    $CheckAttrib3 = ($Attrib3 = Get-CustomAttributes).CustomAttributeCollection.CustomAttributes | Where-Object{$_.Name -EQ $DecomDate}
    If ($CheckAttrib3.displayName -ne $DecomDate)
        {   $caObject3 = New-DTOTemplateObject -DTOTagName "CustomAttribute"
            #Specify attribute value
            $caObject3.CustomAttribute.name= $DecomDate
            $caObject3.CustomAttribute.description="Date the Service was Decomissioned"
            $caObject3.CustomAttribute.targetManagedObjectTypes = @("ALL")
            $caObject3.CustomAttribute.id = -1
            $caObject3.CustomAttribute.allowedValues = @()
            $createdCa3 = New-CustomAttribute -customAttributeDTo $caObject3
            }   
            start-sleep 5
            
#Set Attributes
    #Create a custom attribute DTO for Organization
    $attributeDTO = New-DTOTemplateObject -DTOTagName "CustomAttribute"
    $attributeDTO.CustomAttribute.allowedValues = @() #not important
    $attributeDTO.CustomAttribute.description = $null #not important
    $attributeDTO.CustomAttribute.targetManagedObjectTypes = @()  #not important
    $attributeDTO.CustomAttribute.name= $Prevorg
    $attributeDTO.CustomAttribute.value = $VMorganization
    $result = Set-Attribute -vmId  $Targetid -customAttributeDTo $attributeDTO        
    start-sleep 1
    #Create a custom attribute DTO for user
    $attributeDTO1 = New-DTOTemplateObject -DTOTagName "CustomAttribute"
    $attributeDTO1.CustomAttribute.allowedValues = @() #not important
    $attributeDTO1.CustomAttribute.description = $null #not important
    $attributeDTO1.CustomAttribute.targetManagedObjectTypes = @()  #not important
    $attributeDTO1.CustomAttribute.name= $prevowner
    $attributeDTO1.CustomAttribute.value = $VMowner
    $result = Set-Attribute -vmId  $Targetid -customAttributeDTo $attributeDTO1        
    start-sleep 1
    #Create a custom attribute DTO for Date
    $attributeDTO2 = New-DTOTemplateObject -DTOTagName "CustomAttribute"
    $attributeDTO2.CustomAttribute.allowedValues = @() #not important
    $attributeDTO2.CustomAttribute.description = $null #not important
    $attributeDTO2.CustomAttribute.targetManagedObjectTypes = @()  #not important
    $attributeDTO2.CustomAttribute.name= $DecomDate
    $attributeDTO2.CustomAttribute.value = $date
    $result = Set-Attribute -vmId  $Targetid -customAttributeDTo $attributeDTO2   
    start-sleep 1

# Make Sure $owner is the primary owner
    $user1DTO = New-DTOTemplateObject -DTOTagName "OwnerInfo"
    $user1DTO.OwnerInfo.displayName  = $NewUser
    $user1DTO.OwnerInfo.loginId  = $NewUser
    $user1DTO.OwnerInfo.email = ""
    $user1DTO.OwnerInfo.itContact = $false
    $user1DTO.OwnerInfo.primary = $true
    $ownershipDto.Ownership.Owners = @()
    $ownershipDto.Ownership.Owners  += $user1DTO.OwnerInfo
    #Set Ownership
    Set-Ownership -vmId $Targetid -dto $ownershipDto

#Move VM Based on above logic
    $vm = VMware.VimAutomation.Core\Get-VM -Id $VmRemoteID
    $Folder = (VMware.VimAutomation.Core\Get-Folder -Name $DecomFolder)[0] # [0] added incase two folders in same datacenter from vcenterApi
    $performmove = VMware.VimAutomation.Core\Move-VM -VM $vm.Name -Destination $Folder
