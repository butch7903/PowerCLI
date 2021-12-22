$vcsa = Read-Host "Provide the VCSA FQDN"
$creds = get-credential

import-module vmware.powercli

connect-viserver $vcsa -credential $creds

#Get List of Deploy Rules
$RULELIST = Get-DeployRule | Sort Name

#Add Image to be updated
Add-ESXSoftwareDepot "E:\VMware\ESXi\Current\Cisco-UCS-Custom-ESXi-70U2-17867351_4.1.3-a_custom_Oct262021_7.0.2-0.25.18538813\Cisco-UCS-Custom-ESXi-70U2-17867351_4.1.3-a_custom_Oct262021_7.0.2-0.25.18538813.zip"

#Get Image Info
$IMAGE = Get-EsxImageProfile

Write-Host "Cloning Existing Auto Deploy Rules" -Foregroundcolor Green
Write-Host "	Note: First Clone will Upload the New Image to the Auto Deploy Image Depot" -foregroundcolor Cyan
#Clone Deploy Rule and update it with the new Image
$RULELIST | Copy-DeployRule -ReplaceItem $IMAGE
Write-Host "Completed cloning Existing Auto Deploy Rules" -Foregroundcolor Black -Backgroundcolor White

#Get Updated Rule List
Write-Host "Getting updated Deploy Rule List"
$RULELIST = Get-DeployRule -Name * | Sort Name
Write-Host "Getting list of Deploy Rules with New Image $($IMAGE.Name)"
$NEWRULELIST = $RULELIST | Where{$_.ItemList -Contains $IMAGE}

#Set new rule to Active
Write-Host "Setting Clone Deploy Rules to Activated Status"
Set-DeployRuleSet -DeployRule $NEWRULELIST

#Get Old Rule list
Write-Host "Getting list of Deploy Rules WITHOUT New Image $($IMAGE.Name)"
$OLDRULELIST = $RULELIST | Where{$_.ItemList -NotContains $IMAGE}

#Delete Old Deploy Rules
Write-Host "Deleting Old Deploy Rule:"
Write-Output $OLDRULELIST | select Name
$OLDRULELIST| Remove-DeployRule -Delete


