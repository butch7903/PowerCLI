<#
.NOTES
Created by:		Russell Hamker
Date:			July 24,2023
Version:		1.2
Twitter:		@butch7903
GitHub:			https://github.com/butch7903

.SYNOPSIS
	This script Imports a Role to a VCSA from a file 

.DESCRIPTION
	Use this script to import a role to a VCSA from a file

.EXAMPLE
#EXAMPLE 1
$VCSA = "hamvc01.hamker.local"
$ROLEPATH = "C:\VMware\Import_Export_Roles\VMware Service Account Roles"
./import-allvsphererole_to_vcsa.ps1 -VCSA $VCSA -ROLEPATH $ROLEPATH
		
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
#$VCSA = read-host "Please Provide VCSA FQDN for Role Import"

#Type in Full Path to Role to Import
#$ROLEPATH = read-host "Please Provide the full file path to exported roles
#Example: R:\INFR\Scripts\Import-Export_Roles\Export\VCSANAME
#"
$FILELIST = Get-ChildItem $ROLEPATH | Where-Object {$_.Extension -eq ".role"}

##Check for VCSA Parameter
If(!$VCSA){
 Write-Error "No VCSA Specified"
}
IF($VCSA){
	Write-Host "VCSA Specified in Parameter is $VCSA"
}

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + $VCSA + "_" + $LOGDATE + ".txt"
#Create Log Folder
$LogFolder = $LOCATION.path+"\Log"
If (Test-Path $LogFolder){
	Write-Host "Log Directory Created. Continuing..."
}Else{
	New-Item $LogFolder -type directory
}
#Specify Log File
$LOGFILE = $LOCATION.path+"\log\"+$LOGFILENAME

##Clean up old logs
Write-Host "Cleaning up logs that are over 30 days old"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Get-ChildItem -Path $LogFolder -Recurse | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays(-30))} | Remove-Item -Recurse -Force -Confirm:$false

##Starting Logging
Start-Transcript -path $LOGFILE -Append
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Logging Started"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

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
$VCSA = Connect-VIServer -server $VCSA -Credential $MyCredential
$VCSAIP = ([System.Net.Dns]::GetHostEntry($VCSA)).AddressList.IPAddressToString
Write-Host "Connected to vCenter - $VCSA - $VCSAIP"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

<#
##Get Existing Role List
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
$ROLELIST = Get-VIRole | Sort-Object Name
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
#>

#Import Role
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
#$FILELISTNAMES = ($FILELIST | Select-Object BaseName).BaseName
$EXISTINGROLES = (Get-Virole |Select-Object Name).Name #added 8/10/2021
ForEach($FILE in $FILELIST)
{
	$ROLENAME = (($FILE).BaseName)
	$ROLEPATH = ($FILE).FullName
	Write-Host "Checking if Role $ROLENAME Exists"
	IF($EXISTINGROLES -contains $ROLENAME)
	{
		Write-Host "Role $ROLENAME Already Exists, skipping..."
	}
	IF($EXISTINGROLES -notcontains $ROLENAME)
	{
		Write-Host "Role $($ROLENAME) not found"
		Write-Host "Importing Role $($ROLENAME) to $VCSA"
		##.\PowerShellTools\Import-vSphereRoles.ps1 -Path $ROLEPATH
		$ROLEDATA = Get-Content -Path $ROLEPATH | Where-Object {$_}
		New-Virole -Name $ROLENAME | Out-Null
		Write-Host "Created Role $($ROLENAME)" -BackgroundColor Green
		ForEach($PRIV in $ROLEDATA)
		{
			Write-Host "Setting Permissions $PRIV on Role $ROLENAME" -ForegroundColor Yellow
			Set-VIRole -Role $ROLENAME -AddPrivilege (Get-VIPrivilege -ID $PRIV) | Out-Null  
		}
		Write-Host "Completed Importing Role $($ROLENAME)"
	}
}
Write-Host "All Files in Role List have Completed to be checked"
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
Write-Host "Start Time: $STARTTIME"
$ENDTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
Write-Host "End Time: $ENDTIME"
Stop-Transcript
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Script Completed
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Completed for Importing Roles to $VCSA" -ForegroundColor Green
Write-Host "Press Enter to close this PowerShell Script"
PAUSE
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
