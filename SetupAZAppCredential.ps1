#######################################################################################################################
# Publisher:          					Embotics Corporation                                                          #
# Copyright:          					2020 Embotics Corporation. All rights reserved.                               #
#######################################################################################################################

#######################################################################################################################
# This script is used to set up Azure Service Principal, which can be used by vCommander to authenticate.             #
#######################################################################################################################

############################################################
# Import ARM module
############################################################
Import-Module AZ

############################################################
# Login to ARM
############################################################
Connect-AzAccount

############################################################
# Collect required information
############################################################
$subscriptions = Get-AzSubscription 
If ($subscriptions.Count -eq 1) {
    $subscription = $subscriptions[0]
} Else {
    $i = 1
    Echo "Please select your subscription:"
    Foreach ($s in $subscriptions) {
        $name = $s.Name
        Echo "$i : $name"
        $i++
    }
    $i--
    Do {
        $index = Read-Host -Prompt "Please choose between 1 and $i"
    } While ($index -lt 1 -or $index -gt $i)
    $subscription = $subscriptions[$index - 1]
}
$spName = Read-Host -Prompt "Please enter the name of the application and service principal"
$homepage = Read-Host -Prompt "Please enter the URL of the application's homepage"
$roleName = "Owner"

############################################################
# Change subscription
############################################################
Select-AZSubscription -SubscriptionName $subscription.Name

############################################################
# Change subscription
############################################################
$tenant = Get-AzTenant

############################################################
# Generate password credential (API key)
############################################################
$minLength = 25 ## characters
$maxLength = 35 ## characters
$length = Get-Random -Minimum $minLength -Maximum $maxLength
$nonAlphaChars = 5
$password = [System.Web.Security.Membership]::GeneratePassword($length, $nonAlphaChars)
$keyValue = ConvertTo-SecureString -String $password -AsPlainText -Force

############################################################
# Create application
############################################################
$app = New-AzADApplication -DisplayName $spName -HomePage $homepage -IdentifierUris $homepage -Password $keyValue

############################################################
# Create service principal
############################################################
$sp = New-AZADServicePrincipal -ApplicationId $app.ApplicationId

############################################################
# Assign role
############################################################
Sleep 20
New-AzRoleAssignment -RoleDefinitionName $roleName -ApplicationId $app.ApplicationId

$subId = $subscription.Id
$tenantId = $tenant[0].id
$appId = $app.ApplicationId

Echo "Service principal creation successful. Here is the information to enter into vCommander:"
Echo "Subscription ID: $subId"
Echo "Tenant ID:       $tenantId"
Echo "Application ID:  $appId"
Echo "API Key:         $password"
