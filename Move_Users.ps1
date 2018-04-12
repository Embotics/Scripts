<#
CREATED March 7,2018
VERSION 1.0.0
Requires vCommanders Rest API, Powershell v4

If the user does not exist in org1 they will not be moved to org2 the user ids must be read in from a text file

#>

    $vCommanderServer = 'vCommander.company.com'   #< vCommander Server
    $CredFile = 'C:\scripts\credential.xml'  #< vCommander Cred File
    $oldorg = "Old Org Name"     #< Name of org to move users from
    $neworg = "New Org Name"     #< Name of org to move users to 
    $filemodify = "c:\scripts\Users.txt"  #< temp txt file to create and modify

################################################################################################################
#Remove and re-add the modules 
        Write-Host "Loading Modules"
        $module = @("VCommanderRestClient","VCommander" )
        ForEach($Modulename in $module){
                If (-not (Get-Module -name $moduleName)) {Import-Module -Name $moduleName 
                } else {Remove-Module $moduleName
                        Import-Module -Name $moduleName
                        }
                        Start-Sleep 1
                }

#Connecting to vCommander
        $Global:SERVICE_HOST = $vCommanderServer
        $Global:REQUEST_HEADERS =@{}
        $Global:BASE_SERVICE_URI = $Global:BASE_SERVICE_URI_PATTERN.Replace("{service_host}",$Global:SERVICE_HOST)   
	    $cred = (New-DecryptCredential -keyFilePath $CredFile) 	
        $Global:CREDENTIAL = $cred
        VCommander\Set-IgnoreSslErrors
        Connect-Client  

#Get the Org Information for the existing Org
        Try{
            $org1 = Get-Organization -name $OldOrg
            $orgid1 = $org1.Organization.id
            }
            Catch{Write-Host $_.Exception.ToString()
                  $error[0] | Format-List -Force
                  Exit 1}
#Get the org information for the new org
        Try{
            $org2 = Get-Organization -name $NewOrg
            $orgid2 = $org2.Organization.id
            }
            Catch{Write-Host $_.Exception.ToString()
                 $error[0] | Format-List -Force
                 Exit 1
                 }

#Write User list to file. 
        $org1Members = $org1.Organization.Members
        $org1Members | Select-Object -Property userid | Format-Table -AutoSize -HideTableHeaders |  Out-File -filePath $filemodify -append

#Display popup
        [System.Windows.MessageBox]::Show("Please edit the user list saved in $filemodify then click 'OK'")

#Get Path to Update list
        $usrs = Get-Content $filemodify
        $usrs = $usrs.trim()

#save first orgs members
        $org1Members = $org1.Organization.Members

#Generate members list
          if (!($org2.Organization.Members)) {
                #add a members field
                Add-Member -InputObject $org2.Organization -MemberType NoteProperty -Name "Members" -Value @() -Force
                }

#save second org members
        $org2Members = $org2.Organization.Members

#Clear the Org members list
        $org2.Organization.Members = @()
        $org2.Organization.Members += $org2Members
        $org1.Organization.Members = @()

#Update the Org
        foreach ($usr in $usrs)
        {

            if ($org1members.userid -ccontains $usr)
                {
                $member = ($org1members | where-object{$_.userid -eq $usr})
                $org2.Organization.Members += $member
                $org1Members = $org1Members | Where-Object{$_ -ne $member}
                             
                }
                {
                Add-Member -InputObject $org2.Organization.Members -Value $member -Force
                }    
                
        }
        $org1.Organization.Members += $org1Members

#Update the organization 
        Try{   
            Update-Organization -Id $org2.Organization.id -dto $org2
            Update-Organization -Id $org1.Organization.id -dto $org1
            }
             Catch{Write-Host $_.Exception.ToString()
                 $error[0] | Format-List -Force
                 Exit 1
                 }          
#EOF
Exit 0;