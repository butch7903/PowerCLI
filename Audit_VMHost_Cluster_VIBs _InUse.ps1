<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			November 20,2020
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script will audit the 4 main pillars of drivers used on a VMHost
		Including:
		NIC
		Block
		SCSI
		FC
		This Script will also provide details on what the boot device is

	.DESCRIPTION
		Use this script to audit all the hosts in a VCSA		
#>

##Get Current Path
$pwd = pwd

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

Import-Module VMware.PowerCLI

#Type in VCSA Name
$VCSA = read-host "Please Provide VCSA FQDN"

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + $VCSA + "_" + $LOGDATE + ".txt"
#Create Log Folder
$LogFolder = $pwd.path+"\Log"
If (Test-Path $LogFolder){
	Write-Host "Log Directory Created. Continuing..."
}Else{
	New-Item $LogFolder -type directory
}
#Specify Log File
$LOGFILE = $pwd.path+"\Log\"+$LOGFILENAME

##Specify Export File Info
$EXPORTFILENAME = "VMHostAudit_" + $VCSA + "_" + $LOGDATE + ".csv"
#Create Export Folder
$ExportFolder = $pwd.path+"\Export"
If (Test-Path $ExportFolder){
	Write-Host "Export Directory Created. Continuing..."
}Else{
	New-Item $ExportFolder -type directory
}
#Specify Log File
$EXPORTFILE = $pwd.path+"\Export\"+$EXPORTFILENAME

##Starting Logging
Start-Transcript -path $LOGFILE -Append
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Logging Started"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"


##Provide Credentials
CLS
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
$VCSA = Connect-VIServer -server $VCSA -Credential $MyCredential
Write-Host "Connected to vCenter "
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"


Write-Host "Getting VMHost List"
$VMHOSTLIST = Get-VMHOST | Sort Name

$LISTARRAY = @()

ForEach($VMHOST in $VMHOSTLIST)
{
	Write-Host "Getting VMHost Info for $VMHOST" -Foregroundcolor Green
	$TEMPARRAY = "" | Select VMHost, Cluster, Model, NicVIBinUse, FCVIBinUse, BlockVIBinUse, SCSIVIBinUse, BootDeviceModel, BootDeviceIsLocal, BootDeviceVendor, BootDeviceSize, BootDeviceSCSILevel, BootDeviceIsUSB
	
	#VMHost
	$TEMPARRAY.VMHOST = ($VMHOST).Name
	
	#Cluster
	$TEMPARRAY.Cluster = ($VMHOST | Get-Cluster).Name
	
	#Model
	$TEMPARRAY.Model = $VMHOST.extensiondata.Hardware.SystemInfo.Model
	
	#Get NIC Driver Name(s)
	$NicVIBinUse = (get-vmhost $VMHOST | Get-VMHostNetworkAdapter).ExtensionData.Driver | Sort | get-Unique
	$TEMPARRAY.NicVIBinUse = [string]$NicVIBinUse -join ""
	
	#Get FC Driver Name
	$TEMPARRAY.FCVIBinUse = (Get-VMhost $VMHOST | Get-VMHostHBA -Type FibreChannel).Driver | Sort | Get-Unique
	
	#Get Block Driver Name
	$BlockVIBinUse = (Get-VMhost $VMHOST | Get-VMHostHBA -Type Block).Driver | Sort | Get-Unique
	$TEMPARRAY.BlockVIBinUse = [string]$BlockVIBinUse -join ""
	
	#Get SCSI Driver Name
	$TEMPARRAY.SCSIVIBinUse = (Get-VMhost $VMHOST | Get-VMHostHBA -Type ParallelScsi).Driver
	
	#ESXCLI
	$esxcli = Get-EsxCli -VMHost $VMHOST -V2
	
	#Get Boot Device
	$BOOTDEVICE = $esxcli.storage.core.device.list.Invoke() | Where {$_.IsBootDevice -eq $true}
	
	$TEMPARRAY.BootDeviceModel = $BOOTDEVICE.Model
	$TEMPARRAY.BootDeviceIsLocal = $BOOTDEVICE.IsLocal
	$TEMPARRAY.BootDeviceVendor = $BOOTDEVICE.Vendor
	$TEMPARRAY.BootDeviceSize = $BOOTDEVICE.Size
	$TEMPARRAY.BootDeviceSCSILevel = $BOOTDEVICE.SCSILevel
	$TEMPARRAY.BootDeviceIsUSB = $BOOTDEVICE.IsUSB
	
	$LISTARRAY += $TEMPARRAY
}

##Export Data to CSV
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Exporting Data to CSV"
$LISTARRAY | Sort Cluster,VMHost | Export-CSV -PATH $EXPORTFILE -NoTypeInformation
Write-Host "Exporting Data to CSV Completed"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Document Script Total Run time
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
$STARTTIMESW.STOP()
Write-Host "Total Script Time:"$STARTTIMESW.Elapsed.TotalMinutes"Minutes"
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
Write-Host "Script Completed for $VCENTER"
Write-Host "Press Enter to close this PowerShell Script"
PAUSE
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
