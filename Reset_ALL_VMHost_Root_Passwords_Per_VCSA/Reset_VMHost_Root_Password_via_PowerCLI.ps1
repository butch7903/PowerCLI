<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			September 24, 2020
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script will reset all VMHost Root passwords.

	.DESCRIPTION
		Use this script to connect to a VCSA and reset all VMHost root passwords.
		
	.NOTES
		This script requires a VMware PowerCLI minimum version 11.4 or greater. 

	.TROUBLESHOOTING
		
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

##Provide VMHost FQDN
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Please Provide the VMHost FQDN:"
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
$title = 'VMHost FQDN'
$msg   = 'Enter VMHost FQDN: (Example: myvmhost.contso.lab'
$HOSTNAME = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)
Write-Host "VMHost $HOSTNAME Selected"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select VCSA
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
$vCenter = Read-Host "Please provide FQDN of the VCSA:"
Write-Host "VCSA Selected is $vCenter"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Provide Credentials
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Please Provide VCSA/NSXV Credentials"
$MyCredential = Get-Credential -Message "Please Provide VCSA Creds"
Write-Host "Credential UserName provided is:"$MyCredential.UserName
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
Write-Host "Connecting to vCenter "$vCenter
$VISERVER = Connect-VIServer -server $vCenter -Credential $MyCredential
Write-Host "Connected to vCenter "
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

# https://www.linkedin.com/pulse/reset-esxi-root-password-through-vcenter-esxcli-method-buschhaus
# First, setup $vmhosts. You can do this many ways.$vmhosts = Get-Cluster -Name ClusterWithUnknownPassword | Get-VMHost
# Just so it contains one or more VMHost objects.
# To reset all ESXi host passwords use
$vmhosts = Get-VMHost $HOSTNAME 
#### $vmhosts = Get-Cluster -Name "Cluster Name" | Get-VMHost

#$PATH = ""
#$vmhosts = Import-CSV -Path $PATH

# Since this only works on ESXi 6 and up I used this option to skip the 5.5 hosts that will error out. -AD
#$vmhosts = get-vmhost |Where-Object {$_.Version -eq '6.0.0'}

# This will prompt for the new root password -AD
Write-Host "Enter an existing ESXi username (not vCenter/Usually root), and what you want their password to be reset to."
$NewCredential = Get-Credential -UserName "root" -Message "Enter an existing ESXi username (not vCenter), and what you want their password to be reset to."
Foreach ($vmhost in $vmhosts) {
	Write-Host "VMHost is $VMHOST"
	$HOSTVM = Get-VMHost $VMHOST | Where-Object {$_.Version -eq '6.0.0'}
	$esxcli = get-esxcli -vmhost $VMHOST -v2 #Gain access to ESXCLI on the host.
	$esxcliargs = $esxcli.system.account.set.CreateArgs() #Get Parameter list (Arguments)
	$esxcliargs.id = $NewCredential.UserName #Specify the user to reset
	$esxcliargs.password = $NewCredential.GetNetworkCredential().Password #Specify the new password
	$esxcliargs.passwordconfirmation = $NewCredential.GetNetworkCredential().Password
	Write-Host ("Resetting password for: " + $vmhost) #Debug line so admin can see what's happening.
	$esxcli.system.account.set.Invoke($esxcliargs) #Run command, if returns "true" it was successful.
}

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
disconnect-viserver $vCenter -confirm:$false
IF ($NSXSERVER)
{
Write-Host "Disconnecting from NSX Manager"
Disconnect-NSXServer -NSXServer $NSXSERVER -Confirm:$false
}
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
