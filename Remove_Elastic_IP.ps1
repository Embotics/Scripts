<#
.SYNOPSIS
Script to remove an elastic IP to an AWS EC2 instance

.DESCRIPTION
 Requires vCommander Release 6.1.7 or higher
 vCommander Powershell cmdlet
 AWS Powershell Tools
 Run Syntax in vCommander Completion WF/Decomissioning step 
 powershell.exe C:\Scripts\Remove_Elastic_Ip.ps1 '#{target.remoteId}' '#{target.id}' '#{target.region.name}' '#{target.ipAddress}'

#>

[CmdletBinding()]
	param(
        [Parameter(Mandatory=$true)]
        [String] $Instance = $(Throw "Provide the RemoteID to Continue."),
        [String] $vCmdrID = $(Throw "Provide the vCommanderID to Continue."),
        [String] $Region = $(Throw "Provide the region to Continue."),
        [String] $ElasticIP = $(Throw "Provide the IP to Continue.")
        ) 


#-------------------------------------------------
#  Configuration Settings
#-------------------------------------------------

#vCommander
    $vCommanderServer = "localhost"         #address of your vCommander server
    $CredFile = 'c:\scripts\superuser.xml'  #Credential file to access your vCommander
    $Attrib = "AWS ElasticIP"               #
#AWS
    $AWSAccesskey = '0000000000000000000'
    $AwsSecretkey = '00000000000000000000000000000000'

#-------------------------------------------------
#  Script
#-------------------------------------------------

#Remove and re-add the modules 
        Write-Host "Loading Modules"
        $module = @("VCommanderRestClient","VCommander","AWSPowerShell" )
        ForEach($Modulename in $module){
                If (-not (Get-Module -name $moduleName)) {Import-Module -Name $moduleName 
                } else {Remove-Module $moduleName
                        Import-Module -Name $moduleName
                        }
                        Start-Sleep 1
                }

#Connect to AWS in the specified region. 
    $AWSCred=(Set-AWSCredentials -AccessKey $AWSAccessKey -SecretKey $AWSSecretKey -StoreAs vCommander)
    Set-DefaultAWSRegion -Region $Region
    $awsconnect = Initialize-AWSDefaults -ProfileName vCommander -Region $Region

#Connecting to vCommander
    $Global:SERVICE_HOST = $vCommanderServer
    $Global:REQUEST_HEADERS =@{}
    $Global:BASE_SERVICE_URI = $Global:BASE_SERVICE_URI_PATTERN.Replace("{service_host}",$Global:SERVICE_HOST)   
	$cred = (New-DecryptCredential -keyFilePath $CredFile) 	
    $Global:CREDENTIAL = $cred
    VCommander\Set-IgnoreSslErrors
    $vcConnect = Connect-Client
    if($vcConnect -eq "True"){
        Write-Host "Not Connected to vCommander, please perform Login to continue"
        Exit 1;
        }

#Check and see if the Attribute exists in vCommander: Create if it does not exist.
    $Attrib = "AWS ElasticIP"
    $CheckAttrib = (Get-CustomAttributes).CustomAttributeCollection.CustomAttributes | Where-Object{$_.Name -EQ  $Attrib}
    If ($CheckAttrib.displayName -ne  $Attrib)
        {   Write-host "Creating Custom attribute - $Attrib"
            $caObject = New-DTOTemplateObject -DTOTagName "CustomAttribute"
            #Specify attribute value
            $caObject.CustomAttribute.name="$Attrib"
            $caObject.CustomAttribute.description=""
            $caObject.CustomAttribute.targetManagedObjectTypes = @("ALL")
            $caObject.CustomAttribute.portalEditable = "false"
            $caObject.CustomAttribute.id = -1
            $caObject.CustomAttribute.allowedValues = @()
            $createdCa = New-CustomAttribute -customAttributeDTo $caObject
            }
            Start-Sleep 5 #Wait to be sure the job completes before proceeding

#Set Elastic IP
    Try{$unassigned = Get-EC2Address -Filter @{ Name="public-ip";Value=$ElasticIP } 
        $Associd = $unassigned.AssociationId
        Unregister-EC2Address -AssociationId $Associd
        $result = Remove-EC2Address -AllocationId $unassigned.AllocationId -Force
        }
        Catch{
        $error[0] | Format-List -Force
        Exit 1;
        }

#Set Custom attribute if Elastic IP set 
    Try{
        $attributeDTO = New-DTOTemplateObject -DTOTagName "CustomAttribute"
        $attributeDTO.CustomAttribute.allowedValues = @() #not important
        $attributeDTO.CustomAttribute.description = $null #not important
        $attributeDTO.CustomAttribute.targetManagedObjectTypes = @()  #not important
        $attributeDTO.CustomAttribute.name= $Attrib
        $attributeDTO.CustomAttribute.value = "No"
        $result = Set-Attribute -vmId  $vCmdrID -customAttributeDTo $attributeDTO
        }
        Catch{#doing nothing here on purpose
        }
    
#EOF