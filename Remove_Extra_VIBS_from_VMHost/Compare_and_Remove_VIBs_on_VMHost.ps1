<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			October 29,2021
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script will import a CSV list of VIBs that are approved to be on a
		VMHost. It will them remove any VIBs that are not in that approved list.

	.DESCRIPTION
		Use this script to audit/cleanup a host in a VCSA		
#>

##Check if Modules are installed, if so load them, else install them
if (Get-InstalledModule -Name VMware.PowerCLI -MinimumVersion 11.4) {
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host "PowerShell Module VMware PowerCLI required minimum version was found previously installed"
	Write-Host "Importing PowerShell Module VMware PowerCLI"
	Import-Module -Name VMware.PowerCLI
	Write-Host "Importing PowerShell Module VMware PowerCLI Completed"
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	#CLEAR
} else {
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host "PowerShell Module VMware PowerCLI does not exist"
	Write-Host "Setting Micrsoft PowerShell Gallery as a Trusted Repository"
	Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
	Write-Host "Verifying that NuGet is at minimum version 2.8.5.201 to proceed with update"
	Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false
	Write-Host "Uninstalling any older versions of the VMware PowerCLI Module"
	Get-Module VMware.PowerCLI | Uninstall-Module -Force
	Write-Host "Installing Newest version of VMware PowerCLI PowerShell Module"
	Install-Module -Name VMware.PowerCLI -Scope AllUsers
	Write-Host "Creating a Desktop shortcut to the VMware PowerCLI Module"
	$AppLocation = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
	$Arguments = '-noe -c "Import-Module VMware.PowerCLI"'
	$WshShell = New-Object -ComObject WScript.Shell
	$Shortcut = $WshShell.CreateShortcut("$Home\Desktop\VMware PowerCLI.lnk")
	$Shortcut.TargetPath = $AppLocation
	$Shortcut.Arguments = $Arguments
	$ShortCut.Hotkey = "CTRL+SHIFT+V"
	$Shortcut.IconLocation = "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe,1"
	$Shortcut.Description ="Launch VMware PowerCLI"
	$Shortcut.WorkingDirectory ="C:\"
	$Shortcut.Save()
	Write-Host "Shortcut Created"
	Write-Host "You may use the CTRL+SHIFT+V method to open VMware PowerCLI"
	Write-Host "Importing PowerShell Module VMware PowerCLI"
	Import-Module -Name VMware.PowerCLI
	Write-Host "PowerShell Module VMware PowerCLI Loaded"
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	#Clear
}

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

##Get Current Path
$pwd = pwd

##Setting CSV File Location 
$CSVFILELOCATION = $pwd.path

##VIB Ignore List
#This is a list of VIB Names you want to ignore due to them not being built into the ESXi Image
$IGNORELIST = "vmware-fdm"

##Select VCSA
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
##Get VCSA
$VCSA = Read-Host "Please provide the VCSA FQDN"
Write-Host "VCSA Selected is $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"


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

#Get Export CSV
$ExportFolder = $pwd.path+"\Export"
$NEWESTCSVFILE = Get-ChildItem -Path $ExportFolder | Where {$_.Extension -eq ".csv"} | sort LastWriteTime | select -last 1
$REFVIBS = Import-Csv $NEWESTCSVFILE.FullName

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

##Select CLUSTER
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select Cluster on vCenter $VCSA"
$CLUSTER = Get-Cluster | Sort Name
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
$choice = Read-Host "On which Cluster do you want to export the Host Profile from?"
$CLUSTER = Get-Cluster $CLUSTER[$choice]
Write-Host "You have selected Cluster $CLUSTER on vCenter $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select VMHost
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select VMHost on vCenter $VCSA"
$VMHOST = Get-Cluster $CLUSTER | Get-VMHost | Sort Name
$countCL = 0   
Write-Host " " 
Write-Host "VMHost: " 
Write-Host " " 
foreach($oC in $VMHOST)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "Please select the VMHost from Cluster $CLUSTER as your VMHost to check"
$CHKVMHOST = get-vmhost $VMHOST[$choice]
Write-Host "You have selected 
VMHost $CHKVMHOST
Cluster $CLUSTER 
vCenter $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Specify Export File Info
$EXPORTFILENAME = "VMHost_Compare_" + $VCSA + "_Ref_" + $NEWESTCSVFILE.BaseName + "_Compare_" + $CHKVMHOST.Name + "_" + $LOGDATE + ".csv"
#Create Export Folder
$ExportFolder = $pwd.path+"\Export_Bundle_to_Host_Audit"
If (Test-Path $ExportFolder){
	Write-Host "Export Directory Created. Continuing..."
}Else{
	New-Item $ExportFolder -type directory
}
#Specify Log File
$EXPORTFILE = $ExportFolder + "\" + $EXPORTFILENAME

##Get VIB List
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Getting VIBs List from Reference VMHost"
#ESXCLI
$esxcli = Get-EsxCli -VMHost $CHKVMHOST -V2
$CHKVIBs = $esxcli.software.vib.get.Invoke() | Select Name, ID, Description, Version, CreationDate | Sort Name
Write-Host "Completed getting VIBs List"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Comparing VIB Lists
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Comparing VIBS Lists"
$VIBDIFF = @()
ForEach($VIB in $CHKVIBS)
{
	#If Name Match Check to make sure Version Matches, if not add to list
	$MATCHEDVIB = $REFVIBS | where {$_.Name -eq $VIB.Name}
	If($MATCHEDVIB)
	{
		#VIB name match found, checking Version
		If($VIB.Version -ne $MATCHEDVIB.Version)
		{
			Write-Host "VIB Versions do not Match!"
			Write-Host "REFVIB Version:"
			Write-Host $MATCHEDVIB.Name
			Write-Host $MATCHEDVIB.Version
			Write-Host "VMHost Version:"
			Write-Host $VIB.Name
			Write-Host $VIB.Version
			$TARRAY = ""| Select VMHost,Reason,Name,ID,Description,Version,CreationDate
			$TARRAY.VMHost = $CHKVMHOST.Name
			$TARRAY.Reason = "Version Mismatch"
			$TARRAY.Name = $VIB.Name
			$TARRAY.ID = $VIB.ID
			$TARRAY.Description = $VIB.Description
			$TARRAY.Version = $VIB.Version
			$TARRAY.CreationDate = $VIB.CreationDate
			$VIBDIFF += $TARRAY
		}
	}
	#If Name does not match add to list
	IF(!$MATCHEDVIB)
	{
			$TARRAY = ""| Select VMHost,Reason,Name,ID,Description,Version,CreationDate
			$TARRAY.VMHost = $CHKVMHOST.Name
			$TARRAY.Reason = "Name Not Found"
			$TARRAY.Name = $VIB.Name
			$TARRAY.ID = $VIB.ID
			$TARRAY.Description = $VIB.Description
			$TARRAY.Version = $VIB.Version
			$TARRAY.CreationDate = $VIB.CreationDate
			$VIBDIFF += $TARRAY
	}
}
Write-Host "List of Different VIBs includes:" -ForeGroundColor Green
$VIBDIFF | Where {$_.Name -ne $IGNORELIST} | Sort Name | ft
$VIBLISTTOREMOVE = ($VIBDIFF | Where {$_.Name -ne $IGNORELIST} | Select Name).Name
Write-Host "Completed comparing VIBS Lists"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Remove VIBs from VMHost
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Removing Orphaned VIBs from VMHost $CHKVMHOST"
Write-Host "VIBs to remove include:"
$VIBLISTTOREMOVE
ForEach ($VIB in $VIBLISTTOREMOVE)
{
	#List VIB to remove
	Write-Host "VIB Removal starting for $VIB" -ForegroundColor green
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
	#Create Arg List
	$esxcliRemoveVibArgs = $esxcli.software.vib.remove.CreateArgs()
	$esxcliRemoveVibArgs.vibname = $VIB
	If($VIB -eq "net-mlx4-core"){$esxcliRemoveVibArgs.noliveinstall = $true}
		
	#Remove VIB
	$esxcli.software.vib.remove.Invoke($esxcliRemoveVibArgs)
	Write-Host "VIB Removal completed for $VIB" -ForegroundColor green
	Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
}
Write-Host "Completed Removing Orphaned VIBs from VMHost $CHKVMHOST"
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
