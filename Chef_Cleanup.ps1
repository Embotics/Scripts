
<#
.NOTES
    1. Requires vCommander Rest API 2.5
    2. A Chef cleanup command workflow. The command workflow would have steps similar to ones shown below:
            -Power off the VM (Conditional - "#{target.tools.runningStatus} -eq Running")
            -Remove Node from Chef (Conditional - "#{target.chefNode} -eq true")
            -Delete VM
    3.

.DESCRIPTION
Designed to be run as a Sheduled task in vCommander.
This script finds requests that have failed for a particular reason (e.g. Chef failure), after a configurable time.
- Create command workflow that deletes Chef node, powers off VM, deletes VM. 
- Reject request via API, and provide a reject reason that will get emailed to the requestor. Needs to consider rejection error reasons for multi-VM failures, and for failures other than Chef (e.g. It just took too long). 

.EXAMPLE
.\Chef_Cleanup.ps1

Run Syntax
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe & c:\Scripts\Chef_Cleanup.ps1
#>
###################################################################################################################################################  
###    Edit these for your Environment   ##########################################################################################################
###################################################################################################################################################      
$defaultVCmdrHostName = "localhost"   #vCommander Host name ior IP
$defaultEncryptedCredFilePath = "C:\Scripts\vCommApi_cred.xml" #API user crendential file.
$CleanupAge = "60"   #Minutes
$CleanupCmdWF = "Delete Failed VM"
###################################################################################################################################################
###### Mail Settings
###################################################################################################################################################
$SMTPServer = 'X.X.X.X'           # Mail Server
$SMTPPort = '25'                     # Mail Server Port
$From = 'vCommander@domain.com'    #From address
$MailCred = ""   #Location of Encrypted Cred file for mail authentication if not required leave "" for nothing
$MailSubject = "Requested Services Failed to Deploy"      
###################################################################################################################################################
###################################################################################################################################################
#Reload modules 
        Write-Host "Loading Modules"
        $moduleName = "VCommanderRestClient"
        If (-not (Get-Module -name $moduleName)) {
                        Import-Module -Name $moduleName 
        } else {
                        Remove-Module $moduleName
                        Import-Module -Name $moduleName 
        }
        $moduleName = "VCommander"
        If (-not (Get-Module -name $moduleName)) {
                        Import-Module -Name $moduleName 
        } else {
                        Remove-Module $moduleName
                        Import-Module -Name $moduleName 
        }
#Setup vCommander connection
function Connect-VCmdr {
    $Global:SERVICE_HOST = $defaultVCmdrHostName
    $Global:BASE_SERVICE_URI = $Global:BASE_SERVICE_URI_PATTERN.Replace("{service_host}",$Global:SERVICE_HOST)
    $Global:CREDENTIAL = New-DecryptCredential -keyFilePath $defaultEncryptedCredFilePath
    VCommander\Set-IgnoreSslErrors
    Connect-Client
}
#Connect to vCommander
$connected = Connect-VCmdr

######################################################################
# Get Running workflows with Chef Errors or time has exceeded        #
######################################################################
    $runningWorkflows = Get-RunningWorkflows
    if($runningWorkflows.RunningWorkflowCollection -eq $Null)
                {Write-host "$runningWorkflows not set, Nothing to do"
                Exit
                }
    ForEach ($Workflow in $runningWorkflows.RunningWorkflowCollection.RunningWorkflows){
       Try {
               $ts = new-Timespan -Minutes $CleanupAge
                $time = (Get-date).AddDays(-$ts.Days).AddHours(-$ts.hours).AddMinutes(-$ts.Minutes)
                $WFStarttime = [datetime]$workflow.startTimestamp 
                $latestRunningWorkflowID = $Workflow.id
                $stepId = $Workflow | Where-Object {$WFStarttime -lt $Time -or $_.steps.name -match "Chef" -or $_.steps.name -match "Node" -and $_.status -match "ERROR"} | Select-Object -ExpandProperty "currentStepId"
                if($stepID -eq $Null)
                    {Write-host "Workflow does not match criteria, proceeding to process"
                    continue
                    }
                $WorkflowVar = Get-RunningWorkflowStepById -workflowId $latestRunningWorkflowId -stepId $stepId
                #GetWorkFlow Comments With Error
                   Try{$Comment = $workflow.comments | Select -Expand systemGeneratedText
                        }
                        Catch{$($Error[0])}
                        $Comments = [string]$Comment
                # Reject request with workflow
                 $requestId = ($Workflow.initiator) -replace "Service Request ",""
                 $RequestInfo = (Get-ServiceRequest -Id $requestId)
                 $RequestStatus = $RequestInfo.request.state 
                 $RequestRequester = $RequestInfo.request.requester
                    if($RequestStatus -eq "IN_Progress")
                        {$commandWorkflows = Get-WorkflowDefinitionsByType -workflowType "VM"
                         $CMDworkflowID = $commandWorkflows.WorkflowDefinitionCollection.WorkflowDefinitions | Where-Object {$_.displayName -eq "$CleanupCmdWF"} | Select-Object -ExpandProperty "id"
                         #Reject the request with Failiure comments
                         Submit-RejectRequest -requestId $requestId -comment $Comments -workflowId $CMDworkflowID  
                         #Notify requester
                         if($RequestRequester -contains "@"){
                         send-mailmessage -from $from -to $RequestRequester -subject $MailSubject -body $Comments -smtpServer $SMTPServer -Port $SMTPPort # -Credential $MailCred   -UseSsl
                         }
                         }   
                    Else {write-host "Request state is no longer 'In progress',nothing to do"}    
                }
                Catch{
                    write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
                }}

