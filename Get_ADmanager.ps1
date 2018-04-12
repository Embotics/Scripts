<#
VERSION 1.0.0
Created Feb11.18
Requirements
- Powershell V4
- RSAT or AD snapin installed. 
- Assumes the vCommander service account has access to do the AD lookup. If not credentials would be to be supplied
Usage - Approval WF
- powershell.exe -ExecutionPolicy Bypass "&{c:\scripts\GetManager.ps1 '#{request.requester.userid}'}"
#>

[CmdletBinding()]
Param(
[Parameter(Mandatory=$True,Position=1)]
[string]$UserName
)

#Verify PS Version 4 or higher.
    $Powershell = $PSVersionTable
    if($PSVersionTable.PSVersion.Major -lt "4"){
        Write-Host "Powershell is not V4 or higer, please upgrade Poswershell"
        Exit 1;
        }
#Call AD
$User=Get-ADUser -Identity $UserName -Properties *
$manager = Get-ADUser $User.manager -Properties DisplayName
$managerUPN = $Manager.UserPrincipalName
# Write out so vCommander can consume it as a variable in the next step.  

Write-Host $ManagerUPN
