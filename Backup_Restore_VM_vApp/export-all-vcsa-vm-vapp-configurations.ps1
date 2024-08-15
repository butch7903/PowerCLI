<#
.NOTES
	Created by:		Russell Hamker
	Date:			August 15, 2024
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903

.SYNOPSIS
	This script will Export the vApp Settings for any VM to a JSON File.

.DESCRIPTION
	Use this script to select a VM that had vApp settings originally 
	applied. This script will then export the VMs vApp configuration to a
	JSON file.
	
.EXAMPLE
	#Example 1 
	$VCSA = "hamvc01.hamker.local"
	$Confirm = $false #Do false for full automation tasks
	./export-all-vcsa-vm-vapp-configurations.ps1 -VCSA $VCSA -Confirm $false
		
#>

param(
	[Parameter(Mandatory=$true)][String]$VCSA,
	[Parameter(Mandatory=$false)][Boolean]$Confirm
)
If($Confirm.Count -eq 0){$Confirm = $true}

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

##Written by Russell Hamker
function Export-VM-vApp-Configuration {
	param([string]$VMNAME)
	If(!$VMNAME){
		$VMNAME = Read-Host "Please Provide the VM Name"
	}
	Write-Output "Exporting VM vAPP settings for $VMNAME"
	##Get Current Path
	$LOCATION = Get-Location
	#Convert File PATH
	$FILEPATH = $LOCATION.path
	##Create Export Folder
	$ExportFolder = "$FILEPATH\export"
	If (Test-Path $ExportFolder){
		Write-Host "Export Directory Created. Continuing..."
	}Else{
		New-Item $ExportFolder -type directory
	}
	$VCSAExportFolder = "$FILEPATH\export\$VCSA"
	If (Test-Path $VCSAExportFolder){
		Write-Host "VCSA Export Directory Created. Continuing..."
	}Else{
		New-Item $VCSAExportFolder -type directory
	}
	#Setting JSON PATH
	$JSONPATH = "$VCSAExportFolder\$VMNAME"+"_export-vm-vapp-configuration.json"
	##Get VM Info
	$VM = Get-VM $VMNAME
	##Parse VM Data
	$vAppConfig = $VM.ExtensionData.Config.vAppConfig | Select-Object *
	##Convert to JSON
	$JSON = ConvertTo-Json $vAppConfig
	##Export JSON to File
	Write-Host "Exporting JSON to $JSONPATH"
	$JSON | Out-File $JSONPATH 
	Write-Host "Completed Export"
}

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
Write-Host "Start Time $STARTTIME"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

##Get Current Path
$LOCATION = Get-Location

<#
##Setting CSV File Location 
$CSVFILELOCATION = $LOCATION.path

##Select VCSA
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
##Import VCSA File or Create 1
$VCSACSVFILENAME = "VCSAlist.csv"
$VCSACSVFILEGET = Get-Item "$CSVFILELOCATION\$VCSACSVFILENAME" -ErrorAction SilentlyContinue
$VCSACSVFILE = "$CSVFILELOCATION\$VCSACSVFILENAME"
If(!$VCSACSVFILEGET)
{
	Clear-Host
	Write-Host "VCSA List CSV File not found"
	$VCSANAME = @()
	$CREATENEWRECORD = "" | Select-Object VCSA
	$CREATENEWRECORD.VCSA = "Create New Record" 
	$VCSANAME += $CREATENEWRECORD
	$VCSATEMPLIST = "" | Select-Object VCSA
	$VCSATEMPLIST.VCSA = Read-Host "Please provide a VCSA FQDN"
	$VCSANAME += $VCSATEMPLIST
	$VCSANAME | Export-CSV -NoTypeInformation -PATH $VCSACSVFILE
	$VCSA = $VCSATEMPLIST.VCSA
	Write-Host "VCSA Selected is $VCSA"
}
If($VCSACSVFILEGET)
{
	Clear-Host
	Write-Host "VCSA List CSV File found. Importing file..."
	$VCSALIST = Import-CSV -PATH $VCSACSVFILE
	$VCSASITELIST = $VCSALIST | Where-Object {$_.Site -eq $SITE -or $_.Site -eq "NA"}
	$countCL = 0  
	foreach($oC in $VCSASITELIST)
	{   
		$NAME = $oC.VCSA
		Write-Output "[$countCL] $NAME" 
		$countCL = $countCL+1  
	}
	Write-Host " "  
	$choice = $null
	$choice = Read-Host "On which VCSA do you wish to work with a vApp"
	$CHOICEPICKED = ($VCSASITELIST[$choice]).VCSA
	If($CHOICEPICKED -eq "Create New Record")
	{
		$VCSANAME = $VCSALIST
		Write-Host "Creating New Record Selected..."
		$VCSATEMPLIST = "" | Select-Object VCSA
		$VCSATEMPLIST.VCSA = Read-Host "Please provide a VCSA FQDN"
		$VCSANAME += $VCSATEMPLIST
		$VCSANAME | Export-CSV -NoTypeInformation -PATH $VCSACSVFILE -Confirm:$false
		$VCSA = $VCSATEMPLIST.VCSA
		Write-Host "VCSA Selected is $VCSA"
	}Else{
		$VCSA = $CHOICEPICKED
		Write-Host "VCSA Selected is $VCSA"
	}
}
Write-Host "VCSA Selected is $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
#>

##Check for VCSA Parameter
If(!$VCSA){
Write-Error "No VCSA Specified"
}
IF($VCSA){
	Write-Host "VCSA Specified in Parameter is $VCSA"
}
   
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

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + $VCSA + "_" + $LOGDATE + ".txt"
#Create Log Folder
$LogFolder = $LOCATION.path+"\log"
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

##Clean up old logs
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Cleaning up logs that are over 30 days old"
Get-ChildItem -Path $LogFolder -Recurse | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays(-30))} | Remove-Item -Recurse -Force -Confirm:$false
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Provide Credentials
Clear-Host
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
$VISERVER = Connect-VIServer -server $VCSA -Credential $MyCredential -ErrorAction Stop
Write-Host "Connected to vCenter $VISERVER"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Export VM vApp Configuration
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Beginning Export of VM vApp Configuration"
#$VMNAME = Read-Host "Please Provide the VM Name of the VM with vApp settings you wish to Export"
$VMLIST = Get-VM | Sort-Object Name
$VMARRAY = @()
ForEach($VM in $VMLIST){
	If($VM.Name -notmatch "vCLS|vSAN*" -And $VM.ExtensionData.Config.vAppConfig -ne $null){
		$VMARRAY += $VM
	}
}
Write-Output $VMARRAY

##Get Current Path
$LOCATION = Get-Location
#Convert File PATH
$FILEPATH = $LOCATION.path
##Create Export Folder
$ExportFolder = "$FILEPATH\export"
If (Test-Path $ExportFolder){
	Write-Host "Export Directory Created. Continuing..."
}Else{
	New-Item $ExportFolder -type directory
}
$VCSAExportFolder = "$FILEPATH\export\$VCSA"
If (Test-Path $VCSAExportFolder){
	Write-Host "VCSA Export Directory Created. Continuing..."
}Else{
	New-Item $VCSAExportFolder -type directory
}
#Setting JSON PATH
$CSVPATH = "$VCSAExportFolder\$VCSA"+"_export-vm-list.csv"
#Export CSV of VMArray
Write-Host "Export VMs with vApp Enabled List"
$VMARRAY | Export-Csv -Path $CSVPATH -IncludeTypeInformation

#Export all vApps to VCSA Folder
ForEach($VM in $VMARRAY){
	$VMNAME = $null
	$VMNAME = $VM.Name
	Export-VM-vApp-Configuration $VMNAME
}
Write-Host "Completed Export of all VMs with vApp Configuration"
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
Write-Host "Script Completed for $VCSA"
Write-Host "Press Enter to close this PowerShell Script"
PAUSE
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
