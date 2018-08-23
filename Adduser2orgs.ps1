<#
Usage, add user to multiple organizations via API. 
Requires Powershell V4 and Embotics vCommander Rest API V2.8
Tested against vCommander 6.1.X
#>


##############################################################################################################
###                                 Edit These for your Environment                                        ###
##############################################################################################################

    $vCommanderServer = "localhost" #address of your vCommander server
    $CredFile = 'C:\scripts\superuser.xml'  #Credential file to access your vCommander
    $User = "user@domain.com"                #User to add to orgs by userid ro e-mail address for AD users
    $Organizations = "Company A", "Development"    #comma seperated list of orgs
    $role = "customer"                          #Role to assignto the user in the orgs
    

   
##############################################################################################################
###                                 Do Not Edit Below these Lines                                          ###
##############################################################################################################

#Remove and re-add the modules 
        $Modules = @("vCommanderRestClient","vCommander")
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

#Validate user
    Try{$Account = Get-account $user
        }
        Catch{Write-Host $_.Exception.ToString()
              $error[0] | Format-List -Force
              }

#Create User DTO   
    $user1DTO = New-DTOTemplateObject -DTOTagName "OrganizationUser"
    $user1DTO.OrganizationUser.userId = $user
    $user1DTO.OrganizationUser.manager = $false
    $user1DTO.OrganizationUser.portalRole = $role

#Update Organizations
    foreach($org in $Organizations){
        $orgDto = Get-OrganizationByName -name $org
        $orgDto.Organization.Members += $user1DTO.OrganizationUser
        $taskInfo = Update-Organization -Id $orgDto.Organization.id -dto $orgDto
        }