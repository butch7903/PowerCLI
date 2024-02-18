<#
.NOTES
	Created by:		Russell Hamker
	Date:			July 21, 2023
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903

.SYNOPSIS
	This script will import a VMware Skyline Collector 3.4+ OVA into the environment from a VCSA Content Library. This script was written to deploy VMware Skyline.
	If you wish to deploy a different OVA run the below commands to get all the variables you need to input and update the code
	accordingly.

	$OVACONFIG = Get-OvfConfiguration $OVAPATH
	Write-Output $OVACONFIG
		
.DESCRIPTION
	Use this script to import a VMware Skyline Collector 3.4+ OVA from a VCSA Content Library. 

	Prior to OVA Deployment, please create a DNS entry for said OVA.
	
	Skyline does require specific password complexity for deployment.
	
	Details on Password Strength
		Valid Character class: Group 1: [a-z], [A-Z], [0-9]
		Valid Character class: Group 2: [~!@#$%^&|]
		Password Validation Rules

    Password must be of at least 8 characters
    Password must have characters from any of the 2 classes of Group1
    Password must have at least one character from class Group 2
    Password must not have space as one of the characters

	Sample
		Th1sISV@lid
		ThisIsVali$Too
	Additionally root password has requirements enforced by cracklib
	
.EXAMPLE
#Example 1
$VCSA = "hamvc01.hamker.local"
$VMNAME = "ham-skyline-col-001"
$HOSTNAME = "ham-skyline-col-001.hamker.local"
$ROOTPASSWORD = 'VMware1!'
$DOMAINSEARCHPATH = "hamker.local"
$IPv4Address = "192.168.1.29"
$NetworkPrefix = "24" #Use an IP Calculator to get the NetworkPrefix of your Subnet Mask If needed
$DefaultGateway = "192.168.1.1"
$DNSServers = "192.168.1.32,192.168.1.33" #Must be Comma Seperated List

./import-skyline-collector-ova-from-contentlibrary.ps1 `
-VCSA $VCSA `
-VMName $VMNAME `
-HostName $HOSTNAME `
-RootPassword $ROOTPASSWORD `
-DomainSearchPath $DOMAINSEARCHPATH `
-IPv4Address $IPv4Address `
-NetworkPrefix $NetworkPrefix `
-DefaultGateway $DefaultGateway `
-DNSServers $DNSServers

#>

param(
	[Parameter(Mandatory=$true)][String]$VCSA,
	[Parameter(Mandatory=$true)][String]$VMName,
	[Parameter(Mandatory=$true)][String]$HostName,
	[Parameter(Mandatory=$true)][String]$DomainSearchPath,
	[Parameter(Mandatory=$true)][String]$RootPassword,
	[Parameter(Mandatory=$true)][ipaddress]$IPv4Address,
	[Parameter(Mandatory=$true)][ValidateSet('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31','32')][String]$NetworkPrefix,
	[Parameter(Mandatory=$true)][ipaddress]$DefaultGateway,
	[Parameter(Mandatory=$true)][String]$DNSServers,
	[Parameter(Mandatory=$false)][Boolean]$Confirm
)
If($Confirm.Count -eq 0){$Confirm = $true}

##Get Current Path
$pwd = pwd

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

##Import Module
Write-Host "Importing Module VMware.PowerCLI..."
Import-Module VMware.PowerCLI

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "log_" + $VCSA + "_import_skyline_collector_ova_" + $LOGDATE + ".txt"
#Create Log Folder
$LogFolder = $pwd.path+"\log"
If (Test-Path $LogFolder){
	Write-Host "Log Directory Created. Continuing..."
}Else{
	New-Item $LogFolder -type directory
}
#Specify Log File
$LOGFILE = $pwd.path+"\log\"+$LOGFILENAME

##Starting Logging
Start-Transcript -path $LOGFILE -Append
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Logging Started"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")

##Check for VCSA Parameter
If(!$VCSA){
 Write-Error "No VCSA Specified"
}
IF($VCSA){
	Write-Host "VCSA Specified in Parameter is $VCSA"
}

##Create Secure AES Keys for User and Password Management
$KeyFile = $pwd.path+"\"+"AES.key"
If (Test-Path $KeyFile){
	Write-Host "AES File Exists"
	$Key = Get-Content $KeyFile
	Write-Host "Continuing..."
}Else{
	$Key = New-Object Byte[] 16   # You can use 16, 24, or 32 for AES
	[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
	$Key | out-file $KeyFile
}

##Create Secure XML Credential File for vCenter/NSX Access
$MgrCreds = $pwd.path+"\"+"$VCSA.xml"
If (Test-Path $MgrCreds){
	Write-Host "$VCSA.xml file found"
	Write-Host "Continuing..."
	$ImportObject = Import-Clixml $MgrCreds
	$SecureString = ConvertTo-SecureString -String $ImportObject.Password -Key $Key
	$MyCredential = New-Object System.Management.Automation.PSCredential($ImportObject.UserName, $SecureString)
}Else{
	Write-Host "Credentials File Not Found, Please input Credentials"
	$newPScreds = Get-Credential -message "Enter vCenter Admin Creds here:"
	#$rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
	#$rng.GetBytes($Key)
	$exportObject = New-Object psobject -Property @{
		UserName = $newPScreds.UserName
		Password = ConvertFrom-SecureString -SecureString $newPScreds.Password -Key $Key
	}

	$exportObject | Export-Clixml ($VCSA +".xml")
	$MyCredential = $newPScreds
}

##Document Selections
Do
{
CLS
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Documenting User Selections"
Write-Host "VCSA: $VCSA"
Write-Host "VMName: $VMName"
Write-Host "Host Name: $HostName"
Write-Host "IPv4 Address: $IPv4Address"
Write-Host "Network Prefix: $NetworkPrefix"
Write-Host "Default Gateway: $DefaultGateway"
Write-Host "DNS Server List: $DNSServers"
Write-host "Are the Above Settings Correct?" -ForegroundColor Yellow 
$Readhost = Read-Host " ( y / n ) " 
Switch ($ReadHost){ 
		Y {Write-host "Yes selected"; $VERIFICATION=$true} 
		N {Write-Host "No selected, Please Close this Window to Stop this Script"; $VERIFICATION=$false; PAUSE; CLS} 
		Default {Write-Host "Default,  Yes"; $VERIFICATION=$true} 
}
}Until($VERIFICATION -eq $true)
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Validate that the Self Signed VCSA Certificates do not cause an issue with PowerCLI Connecting to the VCSA
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope User -Confirm:$false

##Disconnect from any open vCenter Sessions,
#This can cause problems if there are any
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Disconnecting from any Open vCenter Sessions"
TRY
{Disconnect-VIServer * -Confirm:$false}
CATCH
{Write-Host "No Open vCenter Sessions found"}
Write-Host "Disconnecting from any Open NSX Manager Sessions"
if($DefaultNSXConnection.Server)
{
	Disconnect-NSXServer * -Confirm:$false
}ELSE{
	Write-Host "No Open NSX Server Sessions found"
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Connect to vCenter Server
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Connecting to vCenter Server Appliance (VCSA) $VCSA"
$VISERVER = Connect-VIServer -server $VCSA -Credential $MyCredential
$VCSAIP = ([System.Net.Dns]::GetHostEntry($VCSA)).AddressList.IPAddressToString
Write-Host "Connected to VCSA $VIServer"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select CLUSTER
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select Cluster on VCSA $VCSA"
$CLUSTER = Get-Cluster | Sort-Object Name
$countCL = 0   
Write-Host " " 
Write-Host "Clusters: " 
Write-Host " " 
foreach($oC in $CLUSTER)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "On which Cluster do you want to deploy to?"
$CLUSTER = Get-Cluster $CLUSTER[$choice]
#$VMHOST = ($CLUSTER | Get-VMHost | Sort-Object Name | Where-Object {$_.State -eq "Connected"})[0]
$VMHOST = (Get-Cluster $CLUSTER | Get-VMHost | Sort-Object Name | Where-Object {$_.State -eq "Connected"}) | Get-Random
Write-Host "You have selected Cluster $CLUSTER / VMHost $VMHOST on VCSA $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select Datastore
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select Datastore on Cluster $CLUSTER on VCSA $VCSA"
$DATASTORE = $VMHOST | Get-Datastore | Sort-Object Name
$countCL = 0   
Write-Host " " 
Write-Host "Datastores: " 
Write-Host " " 
foreach($oC in $DATASTORE)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "On which Datastore do you wish to deploy the OVA to?"
$DATASTORE = Get-Datastore $DATASTORE[$choice]
Write-Host "You have selected Datastore $DATASTORE on Cluster $CLUSTER on VCSA $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select Resource Pool/Optional
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Optional - Select Resource Pool on vCenter $VCSA"
$RESOURCEPOOLLIST = Get-Cluster $CLUSTER | Get-ResourcePool | Sort-Object Name
IF($RESOURCEPOOLLIST.Count -gt 1){
$countCL = 0   
Write-Host " " 
Write-Host "ResourcePools: " 
Write-Host " " 
foreach($oC in $RESOURCEPOOLLIST)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "On which Resource Pool do you wish to deploy the OVA to?"
$RESOURCEPOOL = (Get-Cluster $CLUSTER | Get-ResourcePool | Sort-Object Name)[$choice]
}Else{
	Write-Host "Only the Default ResourcePool is Detected - $($RESOURCEPOOLLIST.Name)"
	$RESOURCEPOOL = $RESOURCEPOOLLIST
}
Write-Host "You have selected Resource Pool $($RESOURCEPOOL.Name) on Cluster $CLUSTER on vCenter $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select Network
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select Port Group on VMHost $VMHOST from VCSA $VCSA"
$PORTGROUP = Get-VMHost $VMHOST | Get-VirtualPortGroup | Sort-Object Name
$countCL = 0   
Write-Host " " 
Write-Host "Virtual Port Group: " 
Write-Host " " 
foreach($oC in $PORTGROUP)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "On which Virtual Port Group do you wish to deploy the OVA to?"
$PORTGROUP = (Get-VMHost $VMHOST | Get-VirtualPortGroup | Sort-Object Name)[$choice]
Write-Host "You have selected Port Group $PORTGROUP on Cluster $CLUSTER on VCSA $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select Content Library
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select the Content Library of where the OVA is Stored on VCSA $VCSA"
$CONTENTLIBRARYLIST = (Get-ContentLibrary | Select-Object Name | Sort-Object Name).Name
If($CONTENTLIBRARYLIST.count -eq 1){
	Write-Host "Only the Single Content Library is Detected - $($CONTENTLIBRARYLIST.Name)"
	$CONTENTLIBRARY = $CONTENTLIBRARYLIST
}Else{
$countCL = 0   
Write-Host " " 
Write-Host "Content Library: " 
Write-Host " " 
foreach($oC in $CONTENTLIBRARYLIST)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "Which Content Library do you wish to deploy the OVA from?"
$CONTENTLIBRARY = $CONTENTLIBRARYLIST[$choice]
}
Write-Host "You have selected Content Library $($CONTENTLIBRARY) on VCSA $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select Content Library Item
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select the Content Library of where the OVA is Stored on VCSA $VCSA"
$CONTENTLIBRARYITEMLIST = (Get-ContentLibraryItem -ContentLibrary $CONTENTLIBRARY | Select-Object Name | Sort-Object).Name
$countCL = 0   
Write-Host " " 
Write-Host "Content Library Item List: " 
Write-Host " " 
foreach($oC in $CONTENTLIBRARYITEMLIST)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "Which Content Library Item do you wish to deploy the OVA from?"
$CONTENTLIBRARYITEM = $CONTENTLIBRARYITEMLIST[$choice]
Write-Host "You have selected Content Library Item $($CONTENTLIBRARYITEM.Name) on VCSA $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select VM Folder Location
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select the VM Folder for where the OVA is Stored on VCSA $VCSA"
$VMFOLDERLIST  = Get-Folder -Type VM | Sort-Object Name
$countCL = 0   
Write-Host " " 
Write-Host "Folder Item List: " 
Write-Host " " 
foreach($oC in $VMFOLDERLIST)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "Which VM Folder do you wish to deploy the OVA to?"
$VMFOLDER = (Get-Folder -Type VM | Sort-Object Name)[$choice]
Write-Host "You have selected Content Library Item $($CONTENTLIBRARYITEM.Name) on VCSA $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Import OVA
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
#CLS
##Skyline
$OVAPATH = Get-ContentLibraryItem -Name $CONTENTLIBRARYITEM -ContentLibrary $CONTENTLIBRARY
$OVACONFIG = Get-OvfConfiguration -ContentLibraryItem $OVAPATH -Target $CLUSTER
$OVACONFIG.EULAs.Accept.Value = $true
$OVACONFIG.NetworkMapping.Network_1.Value = $PORTGROUP
$OVACONFIG.Common.varoot_password.Value = $RootPassword
$OVACONFIG.vami.VMware_Skyline_Appliance.gateway.Value = $DefaultGateway
$OVACONFIG.vami.VMware_Skyline_Appliance.domain.Value = $HostName
$OVACONFIG.vami.VMware_Skyline_Appliance.searchpath.Value = $DomainSearchPath
$OVACONFIG.vami.VMware_Skyline_Appliance.DNS.Value = $DNSServers
$OVACONFIG.vami.VMware_Skyline_Appliance.ip0.Value = $IPv4Address
$OVACONFIG.vami.VMware_Skyline_Appliance.netmask0.Value = $NetworkPrefix #=Subnet Mask

#####Output Selections
Write-Host "Importing OVA"
Write-Host "VCSA: "$VCSA
Write-Host "OVA: "$OVAPATH
Write-Host "Cluster: "$CLUSTER
Write-Host "VMHost: "$VMHOST
Write-Host "Datastore: "$DATASTORE
Write-Host "ResourcePool: "$RESOURCEPOOL
Write-Host "Port Group: "$PORTGROUP
Write-Host "Content Library: "$CONTENTLIBRARY
Write-Host "Content Item: "$CONTENTLIBRARYITEM
Write-Host "Host Name: "$HostName
Write-Host "IPv4 Address: "$IPv4Address
Write-Host "Network Prefix: "$NetworkPrefix
Write-Host "Default Gateway: "$DefaultGateway
Write-Host "DNS Server List: "$DNSServers
Write-Host "VM Folder: "$VMFOLDER
Start-Sleep 10
Write-Host " "
#Deploy OVA
Do{
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	Write-Host "Deploying VM - $VMNAME"
	Get-ContentLibraryItem -Name $CONTENTLIBRARYITEM -ContentLibrary $CONTENTLIBRARY | `
	New-VM -Name $VMNAME `
	-VMHost $VMHOST `
	-Datastore $DATASTORE `
	-DiskStorageFormat Thin `
	-OvfConfiguration $OVACONFIG `
	-ResourcePool $RESOURCEPOOL `
	-Location $VMFOLDER `
	-Confirm:$false
	Start-Sleep 10
	$VM = $null
	$VM = Get-VM $VMNAME -ErrorAction SilentlyContinue
}Until($VM -ne $null)
Write-Host " "   
Write-Host "OVA Import Completed"
Start-Sleep -Seconds 5
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Upgrade VM Hardware to newest
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Upgrading VM Hardware Version - $VMNAME"
IF($VMHOST.Version -eq "7.0.0"){
	$VMVERSION = "vmx-19"
}
IF($VMHOST.Version -match "8"){
	$VMVERSION = "vmx-20"
}
IF($VMHOST.Version -match "8.0.2"){
	$VMVERSION = "vmx-21"
}
Write-Host "Upgrading VM Hardware Version to $VMVERSION"
(Get-VM -Name $VMNAME).ExtensionData.UpgradeVM($VMVERSION)
Write-Host "Upgrading VM Hardware to Version $VMVERSION - $VMNAME"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Power on VM
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Powering on Skyline - $VMNAME"
Start-VM -VM $VMNAME -Confirm:$false
Write-Host "Completed Powering on Skyline - $VMNAME"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Document Next Steps
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Open a Browser to https://$HostName and login with the admin account with a password of default to configure" -ForegroundColor Green
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Disconnect from vCenter
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Disconnecting from vCenter"
disconnect-viserver $VCSA -confirm:$false
IF ($NSXSERVER)
{
Write-Host "Disconnecting from NSX Manager"
Disconnect-NSXServer -NSXServer $NSXSERVER -Confirm:$false
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Document Script Total Run time
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
$STARTTIMESW.STOP()
Write-Host "Total Script Time:"$STARTTIMESW.Elapsed.TotalMinutes"Minutes"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Stopping Logging
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "All Processes Completed"
Write-Host "Stopping Transcript"
Stop-Transcript
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Script Completed
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
If($Confirm -eq $true){
Write-Host "Press Enter to close this PowerShell Script"
PAUSE
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
}