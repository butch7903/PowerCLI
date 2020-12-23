<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			December 1,2020
	Version:		1.1
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script removes specified VIBs from a selected VMHost

	.DESCRIPTION
		Use this script to prep a VMHost for NSX-T

	.TROUBLESHOOTING
		
#>

##Get Current Path
$pwd = pwd

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

#Type in VCSA Name
$VCSA = read-host "Please Provide VCSA FQDN"

Import-Module VMware.PowerCLI

##Updating PS Window Configuration
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Updating PowerShell Window info"
$pshost = get-host
$pswindow = $pshost.ui.rawui
#$newsize = $pswindow.buffersize
#$newsize.height = 30000
#$newsize.width = 130
#$pswindow.buffersize = $newsize
#$newsize = $pswindow.windowsize
#$newsize.height = (get-host).UI.RawUI.MaxWindowSize.Height
#$newsize.width = 130
$pswindow.windowtitle = "Please Enter Credentials"
#$pswindow.windowsize = $newsize
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

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

##Updating PS Window Configuration
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Updating PowerShell Window info"
$pshost = get-host
$pswindow = $pshost.ui.rawui
#$newsize = $pswindow.buffersize
#$newsize.height = 30000
#$newsize.width = 130
#$pswindow.buffersize = $newsize
#$newsize = $pswindow.windowsize
#$newsize.height = (get-host).UI.RawUI.MaxWindowSize.Height
#$newsize.width = 130
$pswindow.windowtitle = "Please Select Cluster"
#$pswindow.windowsize = $newsize
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

##Updating PS Window Configuration
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Updating PowerShell Window info"
$pshost = get-host
$pswindow = $pshost.ui.rawui
#$newsize = $pswindow.buffersize
#$newsize.height = 30000
#$newsize.width = 130
#$pswindow.buffersize = $newsize
#$newsize = $pswindow.windowsize
#$newsize.height = (get-host).UI.RawUI.MaxWindowSize.Height
#$newsize.width = 130
$pswindow.windowtitle = "Please Select Host on Cluster $CLUSTER"
#$pswindow.windowsize = $newsize
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select VMHost
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select VMHost on vCenter $VCSA in Cluster $CLUSTER"
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

##Updating PS Window Configuration
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Updating PowerShell Window info"
$pshost = get-host
$pswindow = $pshost.ui.rawui
#$newsize = $pswindow.buffersize
#$newsize.height = 30000
#$newsize.width = 130
#$pswindow.buffersize = $newsize
#$newsize = $pswindow.windowsize
#$newsize.height = (get-host).UI.RawUI.MaxWindowSize.Height
#$newsize.width = 130
$pswindow.windowtitle = "Removing VIBs on $VMHOST [$choice]"
#$pswindow.windowsize = $newsize
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

#List NIC VIBs on Host
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
"sfvmk",`
"ima-be2iscsi",`
"intelcim-provider",`
"hpnmi",`
"net-i40e",`
"net-igb",`
"net-ixgbe",`
"net-mst",`
"net-qlcnic",`
"net-bnx2",`
"net-bnx2x",`
"scsi-bnx2fc",`
"scsi-bnx2i",`
"scsi-hpsa",`
"scsi-lpfc820",`
"scsi-qla2xxx",`
"net-cnic",`
"misc-cnic-register",`
"scsi-bfa",`
"scsi-hpvsa",`
"hpe-nmi",`
"vr2c-firewall" #,`
#"epsec-mux" #Added this temporarily to clean off NSX-V from hosts in Trad

#Added vr2c-firewall for traditional hosts #vSphere Replication VIB is an old version
#List must Be in this order for VIBs to remove correctly due to dependencies

<#
Added list of VIBs to for removal on 12-11-2020 based on findings in TRAD E
Name               ID                                                                     Description                                               Version                             CreationDate
----               --                                                                     -----------                                               -------                             ------------
hpnmi              Hewlett-Packard_bootbank_hpnmi_550.2.3.5-1198610                       HP NMI Sourcing module for ESX 5.5                        550.2.3.5-1198610                   2013-10-31
misc-cnic-register QLogic_bootbank_misc-cnic-register_1.713.10.v55.1-1OEM.550.0.0.1331820 QLogic CNIC Registration Agent                            1.713.10.v55.1-1OEM.550.0.0.1331820 2015-09-28
net-bnx2           QLogic_bootbank_net-bnx2_2.2.6a.v55.4-1OEM.550.0.0.1331820             QLogic Gigabit Ethernet Driver                            2.2.6a.v55.4-1OEM.550.0.0.1331820   2016-02-29
net-bnx2x          QLogic_bootbank_net-bnx2x_2.713.10.v55.4-1OEM.550.0.0.1331820          QLogic QLE84xx/34xx/74xx 10G/20G Ethernet Driver          2.713.10.v55.4-1OEM.550.0.0.1331820 2016-02-08
net-cnic           QLogic_bootbank_net-cnic_2.713.20.v55.5-1OEM.550.0.0.1331820           QLogic CNIC Ethernet Driver                               2.713.20.v55.5-1OEM.550.0.0.1331820 2016-08-16
net-i40e           Intel_bootbank_net-i40e_1.3.45-1OEM.550.0.0.1331820                    Intel(R) Ethernet Connection XL710 Network Driver         1.3.45-1OEM.550.0.0.1331820         2015-09-29
net-igb            Intel_bootbank_net-igb_5.3.2-1OEM.550.0.0.1331820                      Intel(R) Gigabit Ethernet Network Driver                  5.3.2-1OEM.550.0.0.1331820          2016-01-26
net-ixgbe          Intel_bootbank_net-ixgbe_4.1.1.4-1OEM.550.0.0.1331820                  Intel(R) 10 Gigabit Ethernet Network Driver               4.1.1.4-1OEM.550.0.0.1331820        2016-02-09
net-mst            Mellanox_bootbank_net-mst_4.3.0.29-1OEM.550.0.0.1331820                MST MODULE                                                4.3.0.29-1OEM.550.0.0.1331820       2016-03-07
net-qlcnic         QLogic_bootbank_net-qlcnic_5.5.190-1OEM.550.0.0.1331820                QLogic 10G Ethernet Driver                                5.5.190-1OEM.550.0.0.1331820        2014-03-31
scsi-bnx2fc        QLogic_bootbank_scsi-bnx2fc_1.713.20.v55.4-1OEM.550.0.0.1331820        QLogic 10 Gigabit ESX Ethernet FCoE Offload Driver        1.713.20.v55.4-1OEM.550.0.0.1331820 2016-08-16
scsi-bnx2i         QLogic_bootbank_scsi-bnx2i_2.713.10.v55.3-1OEM.550.0.0.1331820         QLogic 1/10 Gigabit ESX Ethernet iSCSI HBA Driver         2.713.10.v55.3-1OEM.550.0.0.1331820 2016-03-04
scsi-hpsa          HPE_bootbank_scsi-hpsa_5.5.0.124-1OEM.550.0.0.1331820                  HPE Smart Array SCSI Driver                               5.5.0.124-1OEM.550.0.0.1331820      2016-11-17
scsi-lpfc820       VMware_bootbank_scsi-lpfc820_8.2.3.1-129vmw.550.0.0.1331820            Emulex HBA Driver                                         8.2.3.1-129vmw.550.0.0.1331820      2013-09-19
scsi-qla2xxx       VMware_bootbank_scsi-qla2xxx_902.k1.1-12vmw.550.3.68.3029944           see KB  http://kb.vmware.com/kb/2110239 for more details. 902.k1.1-12vmw.550.3.68.3029944     2015-08-31
#>

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
Write-Output $VIBLISTTOREMOVE | Sort | ft
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Remove VIBs from Host
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Starting VIB Removal for VMHost $VMHOST in Cluster $CLUSTER"
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
Write-Host "VMHost $VMHOST"
Write-Host "Cluster $CLUSTER"
Write-Host "Press Enter to close this PowerShell Script"
PAUSE
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
