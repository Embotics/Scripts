

<# 
.SYNOPSIS
Script to assign a Route53 address along with ElasticIP to  an AWS EC2 instance

Requires vCommander Release 6.1.11 or higher
vCommander Powershell cmdlet
AWS Powershell Tools
Run Syntax in vCommander Completion WF 

powershell.exe C:\Scripts\CreateRoute53.ps1 '#{target.remoteId}' '#{target.id}' '#{target.region.name}' '#{target.deployedName}' 

#>

[CmdletBinding()]
	param(
        [Parameter(Mandatory=$true)]
        [String] $Instance = $(Throw "Provide the RemoteID to Continue."),
        [String] $vCmdrID = $(Throw "Provide the vCommander VMID to Continue."),
        [String] $Region = $(Throw "Provide the region to Continue."),
        [String] $VMName = $(Throw "Provide the name of the instance to Continue.")
        )  


#-------------------------------------------------
#  Configuration Settings
#-------------------------------------------------

#vCommander
    $vCommanderServer = "localhost"         # address of your vCommander server
    $CredFile = 'c:\scripts\superuser.xml'  # Credential file to access your vCommander
    $Attrib = "AWS Route53 DNS Address"     # used to store the route 53 address for visability in portal and automated cleanup.
    $Attrib1 = "AWS Elastic IP set"         # Yes/No of elastic IP configured
    $Attrib2 =  "AWS Elastic IP Address"    # Used to store the Elastic IP address

#AWS
    $AWSAccesskey = 'XXXXXXXXXXXXXXXXX'
    $AwsSecretkey = 'XXXXXXXXXXXXXXXXXXXXXXXXX'

#Route53 Entry Params
    $Domain = "Your.Route53.Domain"
    $Type = "A"
    $TTL = "300"
    $Comment = "Created by vCommander"

#Script Flag
    $ForceCreateFlag = 'yes'       #Create elastic IP if it does not exist. defaulton the target(yes)

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
    Initialize-AWSDefaults -ProfileName vCommander -Region $Region

#Connecting to vCommander
    $Global:SERVICE_HOST = $vCommanderServer
    $Global:REQUEST_HEADERS =@{}
    $Global:BASE_SERVICE_URI = $Global:BASE_SERVICE_URI_PATTERN.Replace("{service_host}",$Global:SERVICE_HOST)   
	$cred = (New-DecryptCredential -keyFilePath $CredFile) 	
    $Global:CREDENTIAL = $cred
    VCommander\Set-IgnoreSslErrors
    $Connect = Connect-Client
    if($Connect -ne "True"){
        Write-Host "Not Connected to vCommander, please perform Login to continue"
        Exit 1;
        }

    #Check and see if the Attribute exists in vCommander: Create if it does not exist.
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
            $caObject.CustomAttribute.allowedValues =  @()
            $createdCa = New-CustomAttribute -customAttributeDTo $caObject
            }
            Start-Sleep 1 #Wait to be sure the job completes before proceeding

    #Check and see if the Attribute exists in vCommander: Create if it does not exist.
    $CheckAttrib1 = (Get-CustomAttributes).CustomAttributeCollection.CustomAttributes | Where-Object{$_.Name -EQ  $Attrib1}
    If ($CheckAttrib1.displayName -ne  $Attrib1)
        {   Write-host "Creating Custom attribute - $Attrib1"
            $caObject1 = New-DTOTemplateObject -DTOTagName "CustomAttribute"
            #Specify attribute value
            $caObject1.CustomAttribute.name="$Attrib1"
            $caObject1.CustomAttribute.description=""
            $caObject1.CustomAttribute.targetManagedObjectTypes = @("ALL")
            $caObject1.CustomAttribute.portalEditable = "false"
            $caObject1.CustomAttribute.id = -1
            $caObject1.CustomAttribute.allowedValues = @( "Yes", "No" )
            $createdCa1 = New-CustomAttribute -customAttributeDTo $caObject1
            }
            Start-Sleep 1 #Wait to be sure the job completes before proceeding

    #Check and see if the Attribute exists in vCommander: Create if it does not exist.
    $CheckAttrib2 = (Get-CustomAttributes).CustomAttributeCollection.CustomAttributes | Where-Object{$_.Name -EQ  $Attrib2}
    If ($CheckAttrib2.displayName -ne  $Attrib2)
        {   Write-host "Creating Custom attribute - $Attrib2"
            $caObject2 = New-DTOTemplateObject -DTOTagName "CustomAttribute"
            #Specify attribute value
            $caObject2.CustomAttribute.name="$Attrib2"
            $caObject2.CustomAttribute.description=""
            $caObject2.CustomAttribute.targetManagedObjectTypes = @("ALL")
            $caObject2.CustomAttribute.portalEditable = "false"
            $caObject2.CustomAttribute.id = -1
            $caObject2.CustomAttribute.allowedValues = @()
            $createdCa2 = New-CustomAttribute -customAttributeDTo $caObject2
            }
            Start-Sleep 1 #Wait to be sure the job completes before proceeding

#Check of user entered domain without the dot, and add it
    if ($Domain.Substring($Domain.Length-1) -ne ".") {
        $DomainDot = $Domain + "."
    } else {
        $DomainDot = $Domain
    }

#Check Instance for Elastic IP to continue.
    $Elastic_Address = Get-EC2Address -Filter @{ Name="instance-id";Value="$Instance" }
     IF(($Elastic_Address -eq $null) -and ($ForceCreateFlag -eq 'yes')){
        Try{$address = New-EC2Address -Domain "Vpc"
            $Status = Register-EC2Address -InstanceId $Instance -AllocationId $address.AllocationId
            $value = $address.PublicIp
            #Set Custom attribute if Elastic IP set 
            $attributeDTO1 = New-DTOTemplateObject -DTOTagName "CustomAttribute"
            $attributeDTO1.CustomAttribute.allowedValues = @() #not important
            $attributeDTO1.CustomAttribute.description = $null #not important
            $attributeDTO1.CustomAttribute.targetManagedObjectTypes = @()  #not important
            $attributeDTO1.CustomAttribute.name= $Attrib1
            $attributeDTO1.CustomAttribute.value = "Yes"
            $result = Set-Attribute -vmId  $vCmdrID -customAttributeDTo $attributeDTO1
            }
            Catch{$error[0] | Format-List -Force
                 Exit 1;
                 }}
        Elseif($Elastic_Address -ne $null){
                #Set Custom attribute if Elastic IP set 
                    $attributeDTO1 = New-DTOTemplateObject -DTOTagName "CustomAttribute"
                    $attributeDTO1.CustomAttribute.allowedValues = @() #not important
                    $attributeDTO1.CustomAttribute.description = $null #not important
                    $attributeDTO1.CustomAttribute.targetManagedObjectTypes = @()  #not important
                    $attributeDTO1.CustomAttribute.name= $Attrib1
                    $attributeDTO1.CustomAttribute.value = "Yes"
                    $result = Set-Attribute -vmId  $vCmdrID -customAttributeDTo $attributeDTO1
            }
        Else {Write-host "Exiting because the target instance does not have an elastic IP"
            Exit 1
            }

#Pull the existing or created values from the Instance
    $instancedata = Get-EC2Instance -InstanceId $Instance
    $Value = $instancedata.Instances.PublicIPAddress
    
#Remove the Spaces from the name if they exist
    $VMname = $Vmname.replace(' ','')

# Create new objects for R53 update
    $Change = New-Object Amazon.Route53.Model.Change
    $Change.Action = "UPSERT"
        # CREATE: Creates a resource record set that has the specified values.
        # DELETE: Deletes an existing resource record set that has the specified values.
        # UPSERT: If a resource record set doesn't already exist, AWS creates it. If it does, Route 53 updates it with values in the request.
    $Change.ResourceRecordSet = New-Object Amazon.Route53.Model.ResourceRecordSet
    $Change.ResourceRecordSet.Name = "$VMname.$Domain"
    $Change.ResourceRecordSet.Type = $Type
    $Change.ResourceRecordSet.Region = $Region
    $Change.ResourceRecordSet.TTL = $TTL
    $Change.ResourceRecordSet.SetIdentifier = "vCommander"
    #$Change.ResourceRecordSet.ResourceRecords.Add(@{Value=$Value})
    $Change.ResourceRecordSet.ResourceRecords.Add(@{Value=if ($Type -eq "TXT") {"""$Value"""} else {$Value}})

# Get hosted zone
    $HostedZone = Get-R53HostedZones | Where-Object {$_.Name -eq $DomainDot}

# Set final parameters and execute
    $Parameters = @{
        HostedZoneId = $HostedZone.Id
        ChangeBatch_Change = $Change # Object
        ChangeBatch_Comment = $Comment # "Edited A record"
    }
    $Result = Edit-R53ResourceRecordSet @Parameters

# Set Custom attribute value in vCommander for the Instance
    Try{$attributeDTO = New-DTOTemplateObject -DTOTagName "CustomAttribute"
        $attributeDTO.CustomAttribute.allowedValues = @() #not important
        $attributeDTO.CustomAttribute.description = $null #not important
        $attributeDTO.CustomAttribute.targetManagedObjectTypes = @()  #not important
        $attributeDTO.CustomAttribute.name= "$Attrib"
        $attributeDTO.CustomAttribute.value = "$VMname.$Domain"
        Set-Attribute -vmId $vCmdrID -customAttributeDTo $attributeDTO

        #Set Custom attribute of Route 53 DNS Address  
        $attributeDTO2 = New-DTOTemplateObject -DTOTagName "CustomAttribute"
        $attributeDTO2.CustomAttribute.allowedValues = @() #not important
        $attributeDTO2.CustomAttribute.description = $null #not important
        $attributeDTO2.CustomAttribute.targetManagedObjectTypes = @()  #not important
        $attributeDTO2.CustomAttribute.name= $Attrib2
        $attributeDTO2.CustomAttribute.value = $Value
        $result = Set-Attribute -vmId  $vCmdrID -customAttributeDTo $attributeDTO2
        }
        Catch{
        Write-host "Failed to set $Attrib value."
        $error[0] | Format-List -Force
        Exit 1;
        }
    
#End
