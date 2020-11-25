<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			November 19,2020
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script removes specified VIBs from a selected VMHost

	.DESCRIPTION
		Use this script to prep a VMHost for NSX-T

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
$choice = Read-Host "On which Cluster do you want to look at?"
$CLUSTER = Get-Cluster $CLUSTER[$choice]
Write-Host "You have selected Cluster $CLUSTER on vCenter $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select VMHost
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select VMHost on vCenter $VCSA"
$VMHOST = Get-Cluster $CLUSTER| Get-VMHost | Sort Name
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
$choice = Read-Host "Which VMHost do you wish to review?"
$VMHOST = get-vmhost $VMHOST[$choice]
$HOSTNAME = $VMHOST.NAME
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + $HOSTNAME + "_" + $LOGDATE + ".txt"
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

#ESXCLI
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Connecting ESXCLI to VMHost $VMHOST" -ForegroundColor green
$esxcli = Get-EsxCli -VMHost $VMHOST -V2

#Get NIC Driver Name(s)
Write-Host "Getting NIC VIBs in Use"
$NicVIBinUse = (get-vmhost $VMHOST | Get-VMHostNetworkAdapter).ExtensionData.Driver | Sort | get-Unique

#Get FC Driver Name
Write-Host "Getting FC VIBs in Use"
$FCVIBinUse = (Get-VMhost $VMHOST | Get-VMHostHBA -Type FibreChannel).Driver | Sort | Get-Unique

#Get Block Driver Name
Write-Host "Getting Block VIBs in Use"
$BlockVIBinUse = (Get-VMhost $VMHOST | Get-VMHostHBA -Type Block).Driver | Sort | Get-Unique

#Get SCSI Driver Name
Write-Host "Getting SCSI VIBs in Use"
$SCSIVIBinUse = (Get-VMhost $VMHOST | Get-VMHostHBA -Type ParallelScsi).Driver

#Get VIB List
Write-Host "Getting All VIBs installed on Host"
$VIBSONHOST = $esxcli.software.vib.list.invoke()

#List of VIBs to Remove from Host
$VIBLISTTOREMOVE = "ata-pata-amd",`
"ata-pata-atiixp",`
"ata-pata-cmd64x",`
"ata-pata-hpt3x2n",`
"ata-pata-pdc2027x",`
"ata-pata-serverworks",`
"ata-pata-sil680",`
"ata-pata-via",`
"block-cciss",`
"bnxtnet",`
"bnxtroce",`
"brcmfcoe",`
"elx-esx-libelxima.so",`
"elx-esx-libelxima-8169922.so",`
"elxiscsi",`
"elxnet",`
"igbn",`
"ima-qla4xxx",`
"ixgben",`
"lpnic",`
"lsi-mr3",`
"lsi-msgpt2",`
"lsi-msgpt3",`
"lsi-msgpt35",`
"lsu-lsi-drivers-plugin",`
"lsu-lsi-lsi-mr3-plugin",`
"lsu-lsi-lsi-msgpt3-plugin",`
"lsu-lsi-megaraid-sas-plugin",`
"lsu-lsi-mpt2sas-plugin",`
"mtip32xx-native",`
"ne1000",`
"nenic",`
"net-enic",`
"net-mlx4-en",`
"net-mlx4-core",`
"net-nx-nic",`
"net-tg3",`
"nfnic",`
"nmlx4-core",`
"nmlx4-en",`
"nmlx4-rdma",`
"nmlx5-core",`
"nmlx5-rdma",`
"nmst",`
"qcnic",`
"qedf",`
"qedi",`
"qedrntv",`
"qfle3f",`
"qfle3i",`
"qflge",`
"sata-sata-nv",`
"sata-sata-promise",`
"sata-sata-sil",`
"sata-sata-sil24",`
"sata-sata-svw",`
"scsi-aacraid",`
"scsi-adp94xx",`
"scsi-aic79xx",`
"scsi-fnic",`
"scsi-ips",`
"scsi-megaraid2",`
"scsi-megaraid-mbox",`
"scsi-megaraid-sas",`
"scsi-mpt2sas",`
"scsi-mptsas",`
"scsi-mptspi",`
"scsi-qla4xxx",`
"sfvmk"
#"qfle3"		#Added for testing


#Compare VIB lists and prevent the actively used VIBs from being removed
#NIC
ForEach($VIB in $NicVIBinUse)
{
	If($VIBLISTTOREMOVE -eq $VIB)
	{
		Write-Host "VIB Driver found in list that is in use"
		$VIBLISTTOREMOVE = $VIBLISTTOREMOVE | Where{$_ -ne $VIB}
	}
}
#FC
ForEach($VIB in $FCVIBinUse)
{
	If($VIBLISTTOREMOVE -eq $VIB)
	{
		Write-Host "VIB Driver found in list that is in use"
		$VIBLISTTOREMOVE = $VIBLISTTOREMOVE | Where{$_ -ne $VIB}
	}
}
#Block
ForEach($VIB in $BlockVIBinUse)
{
	If($VIBLISTTOREMOVE -eq $VIB)
	{
		Write-Host "VIB Driver found in list that is in use"
		$VIBLISTTOREMOVE = $VIBLISTTOREMOVE | Where{$_ -ne $VIB}
	}
}
#SCSI
ForEach($VIB in $SCSIVIBinUse)
{
	If($VIBLISTTOREMOVE -eq $VIB)
	{
		Write-Host "VIB Driver found in list that is in use"
		$VIBLISTTOREMOVE = $VIBLISTTOREMOVE | Where{$_ -ne $VIB}
	}
}


#List VIBS to remove
Write-Host "$VMHOST will have these VIBs Removed:"
Write-Output $VIBLISTTOREMOVE | ft
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Remove VIBs from Host
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Starting VIB Removal for VMHost $VMHOST"
ForEach ($VIB in $VIBLISTTOREMOVE)
{
	If($VIBSONHOST.Name -Contains $VIB)
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
}
Write-Host "Completed removing VIBS for VMHost $VMHOST"
Write-Host "Disconnecting ESXCLI from VMHOST $VMHOST" -ForegroundColor green
$esxcli = $null

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
