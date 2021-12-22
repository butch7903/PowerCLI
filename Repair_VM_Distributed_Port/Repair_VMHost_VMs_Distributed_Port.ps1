<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			December 16, 2021
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script will repair a VMs Distributed port if it not in a good state.

	.DESCRIPTION
		Use this script repair a VM so it can move to another host.
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

##Get Current Path
$pwd = pwd

##Gather Basic info
$VCSA = Read-Host "Please provide VCSA FQDN"
$VMHOSTLIST = Read-Host "Please provide the VMHost name(s) to repair"

##Provide Credentials
CLS
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
If(!$MyCredential)
{
	Write-Host "Please Provide VCSA Administrator based Credentials for VCSA $VCSA"
	$MyCredential = Get-Credential -Message "Please Provide VCSA Creds"
	Write-Host "Credential Username provided is:"$MyCredential.UserName
}
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

##Starting Logging
Start-Transcript -path $LOGFILE -Append
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Logging Started"
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
$VISERVER = Connect-VIServer -server $VCSA -Credential $MyCredential
$VCSAIP = ([System.Net.Dns]::GetHostEntry($VCSA)).AddressList.IPAddressToString
Write-Host "Connected to vCenter "
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Get VDS Info
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Gathering Distributed Switch Info on $VCSA"
$VDSwitch = Get-VDSwitch
Write-Host "Completed gathering Distributed Switch Info on $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Get VMHost VM List to vCenter Server
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Gathering List of VMs on VMHost $VMHOSTLIST"
$VMLIST = @()
ForEach($VMH in $VMHOSTLIST)
{
	$TEMPVMLIST = Get-VMHost $VMH | Get-VM | Sort Name
	$VMLIST += $TEMPVMLIST
}
Write-Host "VMList includes:"
$VMLIST
Write-Host " "
Write-Host "Completed gathering List of VMs on VMHost $VMHOSTLIST"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Reviewing and fixing VM if needed"
ForEach($VM in $VMLIST)
{

    #Start an ESXCLI session with the host where the VM resides
	Write-Host "Getting VM Details - $VM"
    $vmobj = Get-VM -Name $VM
	
	#Get VMHost Info
	Write-Host "Getting VMHost Details - $($vmobj.VMHost)"
    $esxcli = Get-EsxCli -VMHost ($vmobj.VMHost) -v2
    #ESXCLI call to obtain information about the VM, specifically its WorldID
    $vmNetInfo = $esxcli.network.vm.list.Invoke() | ? {$_.Name -eq $vmobj.Name}
    $portArgs = $esxcli.network.vm.port.list.CreateArgs()
    $portArgs.worldid = $vmNetInfo.WorldID
    $DVPortIDs = $esxcli.network.vm.port.list.Invoke($portArgs).DVPortID
	
	#Review the DVPortIDs of all the NICS on the VM
	Write-Host "Reviewing/Repairing the DVPortIDs of all the NICS on the VM $VM" -foregroundcolor green
    ForEach($DVPortID in $DVPortIDs) 
	{
		Write-Host "Reviewing DVPortID $DVPortID on VDS $VDSwitch"
		Write-Host "Getting DVPortIDs of VDS $VDSwitch"
        $result = $VDSwitch | Get-VDPort -Key $DVPortID | Select Switch,Portgroup,@{N='VM';E={$_.ConnectedEntity.Parent.Name}}
        $result2 = $VDSwitch | Get-VDPort -Key $DVPortID | Select *
        $ConnectedEntity = $result2.ConnectedEntity
        $Portgroup = $result2.Portgroup
        if (!$result) {
            Write-Host "VM $VM has an issue with DVPortId $DVPortID" -foregroundcolor red
			Write-Host "Repairing DVPort"
            $ConnectedEntity | Where { $_.NetworkName -eq "$($($ConnectedEntity).NetworkName)" } | Set-NetworkAdapter -NetworkName "$($($ConnectedEntity).NetworkName)" #-Confirm:$false
            Write-Host "Completed repairing DVPort"

        }ELSE{
			#$result
			Write-Host "VM DVPort is Healthy - $VM - DVPortId $DVPortID" -foregroundcolor Cyan
        }
		Write-Host "Completed reviewing DVPortID $DVPortID on VDS $VDSwitch"
    }
	Write-Host "Completed Reviewing/Repairing the DVPortIDs of all the NICS on the VM $VM" -foregroundcolor green
}
Write-Host "Completed reviewing and fixing VM if needed"
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
