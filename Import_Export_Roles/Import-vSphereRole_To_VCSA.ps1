<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			July 24,2023
	Version:		1.2
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script Imports a Role to a VCSA from a file 

	.DESCRIPTION
		Use this script to import a role to a VCSA from a file

	.EXAMPLE
	#EXAMPLE 1
	$VCSA = "hamvc01.hamker.local"
	$ROLEPATH = "C:\VMware\Import_Export_Roles\VMware Service Account Roles\Skyline Role.role"
	./import-vsphererole_to_vcsa.ps1 -VCSA $VCSA -ROLEPATH $ROLEPATH

#>
param(
	[Parameter(Mandatory=$true)][String]$VCSA,
	[Parameter(Mandatory=$true)][String]$ROLEPATH
)

##Get Current Path
$LOCATION = Get-Location

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

#Type in VCSA Name
#$VCSA = read-host "Please Provide VCSA FQDN"

#Ttpe in Full Path to Role to Import
#$ROLEPATH = read-host "Please Provide the full file path to exported roles
#Example: R:\SomeFolder\$VCSA\Test.role"

##Provide Credentials
##Create Secure AES Keys for User and Password Management
$KeyFile = $LOCATION.path+"\"+"AES.key"
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
$MgrCreds = $LOCATION.path+"\"+"$VCSA.xml"
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
Write-Host "Connecting to vCenter $VCSA"
$vCenter = Connect-VIServer -server $VCSA -Credential $MyCredential
Write-Host "Connected to vCenter "
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + $vCenter + "_" + $LOGDATE + ".txt"
#Create Log Folder
$LogFolder = $LOCATION.path+"\Log"
If (Test-Path $LogFolder){
	Write-Host "Log Directory Created. Continuing..."
}Else{
	New-Item $LogFolder -type directory
}
#Specify Log File
$LOGFILE = $LOCATION.path+"\log\"+$LOGFILENAME

##Starting Logging
Start-Transcript -path $LOGFILE -Append
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Logging Started"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Import Role
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
$ROLENAME = (Get-ChildItem $ROLEPATH).BaseName
$EXISTINGROLES = (Get-Virole |Select-Object Name).Name #added 8/10/2021
IF($EXISTINGROLES -contains $ROLENAME)
{
	Write-Warning "Role $ROLENAME Already Exists, skipping..."
}Else{
	Write-Host "Importing Role $ROLENAME to $VCSA"
	#.\PowerShellTools\Import-vSphereRoles.ps1 -Path $ROLEPATH
	$ROLEDATA = Get-Content -Path $ROLEPATH | Where-Object {$_}
	New-Virole -Name $ROLENAME | Out-Null
	Write-Host "Created Role `"$ROLENAME`"" -BackgroundColor Green
	ForEach($PRIV in $ROLEDATA)
	{
		Write-Host "Setting Permissions $PRIV on Role $ROLENAME" -ForegroundColor Yellow
		Set-VIRole -Role $ROLENAME -AddPrivilege (Get-VIPrivilege -ID $PRIV) | Out-Null  
	}
}
Write-Host "Completed Importing Role $ROLENAME"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Disconnect from vCenter
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Disconnecting from vCenter"
disconnect-viserver $vCenter -confirm:$false
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
Write-Host "Start Time: $STARTTIME"
$ENDTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
Write-Host "End Time: $ENDTIME"
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
Write-Host "Script Completed for Importing Role $ROLENAME to $VCSA" -ForegroundColor Green
Write-Host "Press Enter to close this PowerShell Script"
PAUSE
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
