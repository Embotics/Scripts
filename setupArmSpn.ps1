#######################################################################################################################
# Publisher:          					Embotics Corporation                                                          #
# Copyright:          					2017 Embotics Corporation. All rights reserved.                               #
#######################################################################################################################

#######################################################################################################################
# This script is used to set up Azure Service Principal, which can be used by vCommander to authenticate.             #
#######################################################################################################################

############################################################
# Import ARM module
############################################################
Import-Module AzureRM

############################################################
# Login to ARM
############################################################
Login-AzureRmAccount

############################################################
# Collect required information
############################################################
$subscriptions = Get-AzureRmSubscription
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
Select-AzureRmSubscription -SubscriptionName $subscription.Name

############################################################
# Change subscription
############################################################
$tenant = Get-AzureRmTenant

############################################################
# Generate password credential (API key)
############################################################
$aesManaged = New-Object System.Security.Cryptography.AesManaged
$aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
$aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
$aesManaged.BlockSize = 128
$aesManaged.KeySize = 256
$aesManaged.GenerateKey()
$keyValue = [System.Convert]::ToBase64String($aesManaged.Key)

$psadCredential = New-Object Microsoft.Azure.Commands.Resources.Models.ActiveDirectory.PSADPasswordCredential
$startDate = Get-Date
$psadCredential.StartDate = $startDate
$psadCredential.EndDate = $startDate.AddYears(1)
$psadCredential.KeyId = [guid]::NewGuid()
$psadCredential.Password = $KeyValue

############################################################
# Create application
############################################################
$app = New-AzureRmADApplication -DisplayName $spName -HomePage $homepage -IdentifierUris $homepage -PasswordCredentials $psadCredential

############################################################
# Create service principal
############################################################
$sp = New-AzureRmADServicePrincipal -ApplicationId $app.ApplicationId

############################################################
# Assign role
############################################################
Sleep 20
New-AzureRmRoleAssignment -RoleDefinitionName $roleName -ServicePrincipalName $app.ApplicationId.Guid

$subId = $subscription.Id
$tenantId = $tenant.Directory
$appId = $app.ApplicationId

Echo "Service principal creation successful. Here is the information to enter into vCommander:"
Echo "Subscription ID: $subId"
Echo "Tenant ID:       $tenantId"
Echo "Application ID:  $appId"
Echo "API Key:         $keyValue"
