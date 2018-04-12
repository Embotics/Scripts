<#
Usage, Execute command WF against a vm. 
Requires Powershell V4 and Embotics vCommander Rest API V2.8
Tested against vCommander 6.1.X
Syntax: "powershell.exe c:\Scripts\Execute_CWF.ps1 -vmname "VM001" -workflow "Quick De-Com"
#>

[CmdletBinding()]
	param(
        [Parameter(Mandatory=$true)]
        [String] $vmname = $(Throw "You must supply a value for 'vmname'"),
        [String] $workflow = $(Throw "Provide the workflow name to Continue.")
        ) 

##############################################################################################################
###                                 Edit These for your Environment                                        ###
##############################################################################################################

    $vCommanderServer = "localhost" #address of your vCommander server
    $CredFile = 'C:\scripts\superuser.xml'  #Credential file to access your vCommander
                         
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

#Verify VM exists
    Try{$vm = Get-VMs -vmName $vmname
        $vmId = $vm.VirtualMachineCollection.VirtualMachines[0].id
        }
        Catch{Write-Host $_.Exception.ToString()
             $error[0] | Format-List -Force
             Exit 1 
             }
#Get workflow
    Try{$workflows = Get-WorkflowDefinitionsByType -workflowType "VM"
        $wfId = $workflows.WorkflowDefinitionCollection.WorkflowDefinitions | Where-Object {$_.displayName -eq $workflow} | select -ExpandProperty "Id"
        $result = Start-CommandWorkflow -vmId $vmId -workflowDefinitionId $wfId
        $result = Wait-ForTaskFinalState -taskId $result.TaskInfo.id -waitTimeInMillis 10000
        if ($result.TaskInfo.state -ne "COMPLETE") {
            Write-Error "Task failed"
        }
        }
        Catch{Write-Host $_.Exception.ToString()
             $error[0] | Format-List -Force
             Exit 1 
             }
#EOF