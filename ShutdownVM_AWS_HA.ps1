<#
Requirements: 
-Comamnder 8.0.0 or higher
-Powershell V5 or greater

Aws asume role assigned to each instance ith permissions to shut down the other. 
#>       

#Update this line with the instance id of the other node in the cluster
$region = "ap-northeast-2"
$node = "i-00101010101010"

#shutdown the failed node
aws ec2 stop-instances --instance-ids $node --force --region $region

#Collect nodes running status
$nodestate = aws ec2 describe-instances --instance-ids $node --region $region
$nodestate = $nodestate | ConvertFrom-Json
$currentstate = $nodestate.Reservations[0].Instances[0].State.Name

#set while loop condition
$state = "1"
$status = $currentstate

#monitor the nodes status to confirm it has shutdown
while ($state -eq "1")
{
if ($currentstate -ne "stopped")
{
Write-Host "$node instance state is $currentstate"
Start-Sleep 1
$status = aws ec2 describe-instances --instance-ids $node --region $region
$status = $status | ConvertFrom-Json
$status = $status.Reservations[0].Instances[0].State.Name
}
if ($status -eq "stopped")
{
Write-Host "$node instance state is $status"
exit 0
}
}