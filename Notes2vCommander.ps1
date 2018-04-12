
<#
Requires Vmware PowerCLI as well as vCommanders Rest API

This Script ignores Templates and will truncates values to 255 characters in vCommander.
The Attribute name Will equal the category in vCenter, and the Tag value will be the Value of the attribute.
Attribute will be created if it does not exist in vCommander

Time to process 60 VMs is about 10 minutes due to the query on the vCenter side.
#>

    $vCommanderServer = 'Localhost'   #< vCommander Server
    $CredFile = 'C:\scripts\apiuser.xml'  #< vCommander Cred File
    $VIServer = 'vcenter.com'               #< vCenter Server name as it appears in vcommander must be reachable (DNS)
    $vCredFile = 'C:\scripts\vcred.xml'   #< vCenter Cred File
    $Attrib2update = "vCenter Notes"     #Name of the attribute field to update Attribute 

################################################################################################################
#Remove and re-add the modules 
        Write-Host "Loading Modules"
        $module = @("VCommanderRestClient","VCommander", "VMware.VimAutomation.Core"  )
        ForEach($Modulename in $module){
                If (-not (Get-Module -name $moduleName)) {Import-Module -Name $moduleName 
                } else {Remove-Module $moduleName
                        Import-Module -Name $moduleName
                        }
                        Start-Sleep 1
                }



#Connect to vCenter and Disable Cert warnings 
        Set-PowerCLIConfiguration -InvalidCertificateAction ignore -Confirm:$False
        $vcred = (New-DecryptCredential -keyFilePath $vCredFile) 
        Connect-VIServer -Server $VIServer -credential $vcred
        Write-Host "Connected to $VIServer" 

#Connecting to vCommander
        $Global:SERVICE_HOST = $vCommanderServer
        $Global:REQUEST_HEADERS =@{}
        $Global:BASE_SERVICE_URI = $Global:BASE_SERVICE_URI_PATTERN.Replace("{service_host}",$Global:SERVICE_HOST)   
	    $cred = (New-DecryptCredential -keyFilePath $CredFile) 	
        $Global:CREDENTIAL = $cred
        VCommander\Set-IgnoreSslErrors
        Connect-Client  

#Check and see if the Attribute exists in vCommander: Create if it does not exist.
        $CheckAttrib = (Get-CustomAttributes).CustomAttributeCollection.CustomAttributes | Where-Object{$_.Name -EQ $Attrib2update}
        If ($CheckAttrib.displayName -ne $Attrib2update)
            {   Write-host "Creating Custom attribute - $Attrib2update"
                $caObject = New-DTOTemplateObject -DTOTagName "CustomAttribute"
                #Specify attribute value
                $caObject.CustomAttribute.name="$Attrib2update"
                $caObject.CustomAttribute.description="The name of the database to be created"
                $caObject.CustomAttribute.targetManagedObjectTypes = @("ALL")
                $caObject.CustomAttribute.portalEditable = "false"
                $caObject.CustomAttribute.id = -1
                $caObject.CustomAttribute.allowedValues = @()
                $createdCa = New-CustomAttribute -customAttributeDTo $caObject
                }
                Start-Sleep 5 #Wait to be sure the job completes before proceeding

# Pull your VMs into an array
        Write-Host "Get Management Server ID"
        $MGServer = (Get-ManagementServers).ManagementServerCollection.ManagementServers | Select-Object -Property displayName,ID | Where displayName -eq $VIServer
        $MgserverID = $MGServer.id
        Write-host "VMware ServerID = $MGServerID"

#Get DataCenters from Managed System ID
        $Datacenters = (Get-Datacenters -msId $MgserverID).DatacenterCollection.Datacenters.name
        $DatacenterType = $Datacenters.GetType().Name
            If($DatacenterType -eq "String"){
                $toarray = $Datacenters
                $Datacenters = @($Datacenters)
                } 
        ForEach ($Datacenter in $Datacenters){
                $DCID = (VMware.VimAutomation.Core\Get-Datacenter -Name $Datacenter).id
                $DCRemoteID = $DCID.substring(11) # Removes Datacenter- From the Vmware ID
                $Datacentervcid = (((Get-Datacenters -msId $MgserverID).DatacenterCollection.Datacenters) | Where displayName -eq $Datacenter).id
            #set paginated loop throughthe vm's 20 at a time 
                 $offset = 0
                 $Maxcount = 20
            #Loop 20 vm's at a time Until all vm's complete 
                Do {$vmList = ((get-vms -max $Maxcount -offset $offset -datacenterId $Datacentervcid).VirtualMachineCollection.VirtualMachines| Where-Object {$_.template -eq $false}).remoteid
                    $vmLoopCount = $vmList.Count
                    ForEach ($VMRemoteID in $VMList) {
                        #new Offset
                        $offset = [int]$offset + 20
                        Try{
                            Start-Sleep -Milliseconds 10
                        #Get vcommander VMid for Virtual machines only
                            $Vmid=$null
                            $Vmid = (Get-VMByRemoteId -vmRemoteId $VMRemoteID).VirtualMachineCollection.VirtualMachines.id
                            If ($vmid -ne $null){
                                #Get Notes For the VM
                                $NewVMid = "VirtualMachine-"+$VMRemoteID
                                $Vmnotes = $null
                                $VmNotes = (VMware.VimAutomation.Core\Get-vm -Id $NewVMid).Notes
                                    If ($VmNotes -ne $null)
                                        {
                                        #Create a custom attribute DTO
                                            $attributeDTO = New-DTOTemplateObject -DTOTagName "CustomAttribute"
                                            $attributeDTO.CustomAttribute.allowedValues = @() #not important
                                            $attributeDTO.CustomAttribute.description = $null #not important
                                            $attributeDTO.CustomAttribute.targetManagedObjectTypes = @()  #not important
                                            $attributeDTO.CustomAttribute.name= $Attrib2update
                                        #Write-Notes to Notes Attrib In vCommander
                                            $attributeDTO.CustomAttribute.value = "$VmNotes"
                                            $result = Set-Attribute -vmId $vmID -customAttributeDTo $attributeDTO
                                        #Done
                                        }
                            }
                        }
                        Catch{
                            #catching Any Exception
                             write-host "Caught an exception:" -ForegroundColor Red
                             write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
                             write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
                             Write-host "Exception occured on $VM"}
                        } 
                    }
                Until($vmloopcount -eq 0)
        }

Disconnect-VIServer -Force -Confirm:$False
Write-host "Sync Complete"
