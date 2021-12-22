<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			July 15,2021
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script exports all roles from a VCSA as files and stores them to a 
		specific path

	.DESCRIPTION
		Use this script to export all roles to individual files

	.TROUBLESHOOTING
		
#>

##Get Current Path
$pwd = pwd

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

#Type in VCSA Name
$VCSA = read-host "Please Provide VCSA FQDN"

##Provide Credentials
#CLS
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
If(!$MyCredential)
{
	Write-Host "Please Provide VCSA Administrator based Credentials for VCSA $VCSA"
	$MyCredential = Get-Credential -Message "Please Provide VCSA Creds"
	Write-Host "Credential UserName provided is:"$MyCredential.UserName
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

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
$LogFolder = $pwd.path+"\Log"
If (Test-Path $LogFolder){
	Write-Host "Log Directory Created. Continuing..."
}Else{
	New-Item $LogFolder -type directory
}
#Specify Log File
$LOGFILE = $pwd.path+"\Log\"+$LOGFILENAME

##Starting Logging
Start-Transcript -path $LOGFILE -Append
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Logging Started"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Specify Export File Info
#Create Export Folder
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Creating Export Location if it does not Exist"
$ExportFolder = $pwd.path+"\Export\$VCSA"
If (Test-Path $ExportFolder){
	Write-Host "Export Directory Created. Continuing..."
}Else{
	New-Item $ExportFolder -type directory
}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Get List of all Roles
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Getting Global (datacenter) list of VCSA Permissions"
$GLOBALPERMLIST = Get-VIPermission | Select * | where {$_.EntityId -like "*datacenter*"} | Select Principal,Role,Propagate,isGroup
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Export Roles
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Exporting Global (datacenter) list of VCSA Permissions"
Write-Host "Exporting Permissions to $ExportFolder"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
$FILEPATH = $ExportFolder + "\" + $vCenter + ".csv"
$GLOBALPERMLIST | Export-CSV -Path $FILEPATH -NoTypeInformation
Write-Host "Completed Exporting Permissions to $ExportFolder"
Write-Host "Completed Exporting Global (datacenter) list of VCSA Permissions from VCSA $VCSA" -ForegroundColor Green
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
Write-Host "Script Completed for Exporting Role $ROLENAME to $ExportFolder" -ForegroundColor Green
Write-Host "Press Enter to close this PowerShell Script"
PAUSE
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
