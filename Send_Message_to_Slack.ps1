<#  
.SYNOPSIS
Sends a chat message to a Slack channel or user.
Tested with vCommander 6.1.X          
.DESCRIPTION
The Post-ToSlack cmdlet is used to send a chat message to a Slack channel, group, or person.
Slack requires a token to authenticate to an org. Either place a file named token.txt in the same directory as this cmdlet,
or provide the token using the -token parameter. For more details on Slack tokens, use Get-Help with the -Full arg.  Thanks to Chris Wahl for the example code.
.EXAMPLE
powershell.exe c:\scripts\slack\send_message_to_slack.ps1 -channel '#{request.service.settings.customAttribute['Notify Slack Channel']}' -message 'Recently deployed  VM/Instance #{target.Name} on #{target.managedSystem.type}'   
This will send a message to the #General channel using a specific token 1234567890, and the bot's name will be default (vCommander Bot).
.LINK
Validate or update your Slack tokens:
https://api.slack.com/tokens
Create a Slack token:
https://api.slack.com/web
More information on Bot Users:
https://api.slack.com/bot-users
#>

[CmdletBinding()]
	param(
        [Parameter(Mandatory=$true)]
        [String] $Channel = $(Throw "Provide the Slack Channel to Continue(such as #General)"),
        [String] $Message = $(Throw "Provide the chat message.")
        ) 


########## Edit For your Environment ##########
  
$BotName = 'vCommander Bot'         #'Optional name for the bot - this will appear in Slack'
$Token = 'xoxp-000000000-00000000000-0000000000-00000000000000000000000000000000'   # your Account token to post to Slack

#########################################################
### Do Not edit below this line
#########################################################


# Build the body as per https://api.slack.com/methods/chat.postMessage
$body = @{
    token    = $token
    channel  = $Channel
    text     = $Message
    username = $BotName
    parse    = 'full'
}

# Call the API
    Try{
        $uri = 'https://slack.com/api/chat.postMessage'
        $Result = Invoke-RestMethod -Uri $uri -Body $body
        if ($Result.ok -eq "True"){
            Write-host "Message sucessfully posted to Slack Channel"
            }
            }
            Catch{
                Write-Host $_.Exception.ToString()
                $error[0] | Format-List -Force
                Exit 1
                }
  
