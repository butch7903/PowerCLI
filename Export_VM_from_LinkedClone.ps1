##Export VM from Linked Clone Script Created by Russell Hamker
##Import VMware PowerShell Modules
Import-Module VMware.PowerCLI

##Set Variables
##Script Version 1.0
##Get Current Path
$pwd = pwd
##If answerfile exists, Import it for use or create one.
$AnswerFile = $pwd.path+"\"+"AnswerFile.csv"
If (Test-Path $AnswerFile){
##Import File
Write-Host "Answer file found, importing answer file"$AnswerFile
$Answer = Import-Csv $AnswerFile
ForEach($Line in $Answer)
{
	$Version = $Line.Version
	Write-Host "Version specified in file is:"$Version
	$SubVersion = $Line.SubVersion
	Write-Host "SubVersion specified in file is:"$SubVersion
	$vCenter = $Line.vCenter
	Write-Host "vCenter specified in file is:"$vCenter
	$PARENT_VM_Name = $Line.ParentVMName
	Write-Host "Parent VM is:"$PARENT_VM_Name
	$LOCATION = $Line.CloneLocation
	Write-Host "Clone VM Location will be:"$LOCATION
	$CLONENAME = $Line.CloneName
	Write-Host "Clone VM Location will be:"$CLONENAME
	$CLONEEXPORTLOCATION = $Line.CloneExportLocation
	Write-Host "Clone Export Location will be:"$CLONEEXPORTLOCATION
	Write-Host "Continuing..."
	Start-Sleep -Seconds 2
}
}
Else {
$Answers_List = @()
$Answers="" | Select Version,SubVersion,vCenter,ParentVMName,CloneLocation,CloneName,CloneExportLocation
Write-Host "Answer file NOT found. Please input information to continue."
$Version = "1"
$Answers.Version = $Version
$SubVersion = "0"
$Answers.SubVersion = $SubVersion
$vCenter = Read-Host "Input vCenter FQDN"
#$vCenter = "sandvcsa01.sandbox.local"
$Answers.vCenter = $vCenter
$PARENT_VM_Name = Read-Host "Input Parent VM Name"
#$PARENT_VM_Name = "SANDSQL01"
$Answers.ParentVMName = $PARENT_VM_Name
$LOCATION = Read-Host "Input Location of where VMs should be placed in vCenter.
Example: DataCenter1/DEV/USA/SQL"
#$LOCATION = "DataCenter1/DEV/USA/SQL"
$Answers.CloneLocation = $LOCATION
$CLONENAME = Read-Host "Type Name of Clone
Example: VMName-Clone"
#$CLONENAME = "VMName-Clone"
$Answers.CloneName = $CLONENAME
$CLONEEXPORTLOCATION = Read-Host "Select Export Location
FQDN Domain Share
Example: \\servername.domain.local\backup\vcenter\production"
#$LOCATION = "\\servername.domain.local\backup\vcenter\production"
$Answers.CloneExportLocation = $CLONEEXPORTLOCATION

$Answers_List += $Answers
$Answers_List | Format-Table -AutoSize
Write-Host "Exporting Information to File"$AnswerFile
$Answers_List | Export-CSV -NoTypeInformation $AnswerFile
}

##Create Secure AES Keys for User and Password Management
$KeyFile = $pwd.path+"\"+"AES.key"
If (Test-Path $KeyFile){
Write-Host "AES File Exists"
Write-Host "Continuing..."
}
Else {
$Key = New-Object Byte[] 16   # You can use 16, 24, or 32 for AES
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
$Key | out-file $KeyFile
}

##Create Secure User Account file
#Specify vCenter Login info
#$vCenter_Login = "sandbox\svc_vmautomation"
$UserFile = $pwd.path+"\"+"User.txt"
If (Test-Path $UserFile){
Write-Host "User File Exists"
Write-Host "Continuing..."
}
Else{
$Key = Get-Content $KeyFile
$vCenter_Login =  Read-Host -AsSecureString "Enter vCenter User Account.
Please Note, this account must have Full control of the OU that VMs are created in (Computer OU Typically) and whatever OU they should be moved to.
Example: Contoso\svc_UserName"
$vCenter_Login | ConvertFrom-SecureString -key $Key | Out-File $UserFile
}

##Create Secure Password file
$PasswordFile = $pwd.path+"\"+"Password.txt"
If (Test-Path $PasswordFile){
Write-Host "Password File Exists"
Write-Host "Continuing"
}
Else{
$Key = Get-Content $KeyFile
$Password = Read-Host -AsSecureString "Enter Password for vCenter Serviec Account"
$Password | ConvertFrom-SecureString -key $Key | Out-File $PasswordFile
}

## Create MyCredential for access vCenter.
##Reference http://www.adminarsenal.com/admin-arsenal-blog/secure-password-with-powershell-encrypting-credentials-part-2/
$Key = Get-Content $KeyFile
$SecureUserName = Get-Content $UserFile | ConvertTo-SecureString -Key $Key
$UnsecureUserName = (New-Object PSCredential "user",$SecureUserName).GetNetworkCredential().Password
$MyCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UnsecureUserName, (Get-Content $PasswordFile | ConvertTo-SecureString -Key $Key)
$UnsecureUserName = "0"
##Linked Clone VM Folder Location (in vCenter)


##Get Date Info for naming of snapshot variable
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + $LOGDATE + ".txt"
#Create Log Folder
$LogFolder = $pwd.path+"\Log"
If (Test-Path $LogFolder){
	Write-Host "Log Directory Created. Continuing..."
}
Else{
	New-Item $LogFolder -type directory
}
#Specify Log File
$LOGFILE = $pwd.path+"\Log\"+$LOGFILENAME

##Create Function Get-FolderByPath
##Reference http://www.lucd.info/2012/05/18/folder-by-path/
##Thank you LUCD!
function Get-FolderByPath{
  <# .SYNOPSIS Retrieve folders by giving a path .DESCRIPTION The function will retrieve a folder by it's path. The path can contain any type of leave (folder or datacenter). .NOTES Author: Luc Dekens .PARAMETER Path The path to the folder. This is a required parameter. .PARAMETER Path The path to the folder. This is a required parameter. .PARAMETER Separator The character that is used to separate the leaves in the path. The default is '/' .EXAMPLE PS> Get-FolderByPath -Path "Folder1/Datacenter/Folder2"
.EXAMPLE
  PS> Get-FolderByPath -Path "Folder1>Folder2" -Separator '>'
#>
 
  param(
  [CmdletBinding()]
  [parameter(Mandatory = $true)]
  [System.String[]]${Path},
  [char]${Separator} = '/'
  )
 
  process{
    if((Get-PowerCLIConfiguration).DefaultVIServerMode -eq "Multiple"){
      $vcs = $defaultVIServers
    }
    else{
      $vcs = $defaultVIServers[0]
    }
 
    foreach($vc in $vcs){
      foreach($strPath in $Path){
        $root = Get-Folder -Name Datacenters -Server $vc
        $strPath.Split($Separator) | %{
          $root = Get-Inventory -Name $_ -Location $root -Server $vc -NoRecursion
          if((Get-Inventory -Location $root -NoRecursion | Select -ExpandProperty Name) -contains "vm"){
            $root = Get-Inventory -Name "vm" -Location $root -Server $vc -NoRecursion
          }
        }
        $root | where {$_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]}|%{
          Get-Folder -Name $_.Name -Location $root.Parent -NoRecursion -Server $vc
        }
      }
    }
  }
}


##################################Start of Scritp#########################################################

##Starting Logging
Start-Transcript -path $LOGFILE -Append

##Disconnect from any open vCenter Sessions,
#This can cause problems if there are any
Write-Host "Disconnecting from any Open vCenter Sessions"
disconnect-viserver * -Confirm:$false

##Connect to vCenter Server
Write-Host "Connecting to vCenter"$vCenter
Connect-VIServer -server $vCenter -Credential $MyCredential
Write-Host "Connected to vCenter"$vCenter
Start-Sleep -Seconds 10 

##Clearing Credentials out of memory
#$MyCredential = ""

##Set Variable Parent_VM, must be connected to vCenter for this
$PARENT_VM = Get-VM $PARENT_VM_Name ##name of Parent VM
Write-Host $PARENT_VM

##Remove Snapshot on parent VM
Write-Host "Removing Snapshots from parent VM" 
Get-Snapshot -VM $PARENT_VM -Name * | Remove-Snapshot -confirm:$False
##Consolidate Disks on PARENT VM
Write-Host "Consolidating Disks on Parent VM" 
(Get-VM -Name $PARENT_VM).ExtensionData.ConsolidateVMDisks()

##End of Clean up tasks##
Write-Host "Clean up tasks completed" 

##Snapshot PARENT VM
Write-Host "Creating Snapshot on Parent VM"$PARENT_VM
$CreationDATE = Get-Date -format "MMM-dd-yyyy_HH-mm-ss"
$SNAP = New-Snapshot -VM $PARENT_VM -Name Export_$CreationDATE -Quiesce -Description "Quiesced Snapshot of $PARENT_VM_Name on Date $CreationDATE"
Write-Host "Parent VM Snapshot Created on Parent VM"$Parent_VM
$CreationDATE = ""

##Create Linked Clone from parent VM using snapshot for place in time
#Uses Same host as parent VM to create Linked Clone on.
Write-Host "Creating linked-clone from parent VM snapshot" 
#$SNAP = Get-VM -Name $PARENT_VM | Get-Snapshot -name Export_$DATE
$CreationDATE = Get-Date -format "MMM-dd-yyyy_HH-mm-ss"
Write-Host "VM creation Process started for VM"$PARENT_VM_Name 
$Cluster = Get-VMHost $Parent_VM.VMHost | Get-Cluster
$Datastore = $Parent_VM | Get-Datastore
New-VM -Name $CLONENAME -VM $PARENT_VM -ResourcePool $Cluster -Datastore $Datastore -Notes "Linked-Clone of $PARENT_VM. Created on $CreationDATE" -LinkedClone -ReferenceSnapshot $SNAP -Location (Get-FolderByPath -Path $LOCATION)
Write-Host "VM creation process completed for"$VM.Name 
#$CreationDATE = ""

##Updating Clone VM to have original VM MAC Address
Write-Host "Updating Mac Address(es) to Match Parent VM" $PARENT_VM
##Reference https://communities.vmware.com/thread/319904?tstart=0
## the name of the "original" VM
$strOrigVMName = $PARENT_VM
## the name of the "clone" VM
$strCloneVMName = $CLONENAME
## get the .Net View object of the clone VM
$viewCloneVM = Get-View -ViewType VirtualMachine -Property Name,Config.Hardware.Device -Filter @{"Name" = $strCloneVMName}
## get the NIC device (further operations assume that this VM has only one NIC)
$deviceNIC = $viewCloneVM.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualEthernetCard]}
## set the MAC address to that of the original VM (also assumes that original VM has only one NIC)
$deviceNIC.MacAddress = (Get-VM $strOrigVMName | Get-NetworkAdapter).MacAddress
## set the MAC address type to manual
$deviceNIC.addressType = "Manual"

## create the new ConfigSpec
$specNewSpecification = New-Object VMware.Vim.VirtualMachineConfigSpec -Property @{
	## setup the deviceChange object
	deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec -Property @{
		## the kind of operation, from the given enumeration
		operation = "edit"
		## the device to change, with the desired settings
		device = $deviceNIC
	} ## end New-Object
} ## end New-Object

## reconfigure the "clone" VM
$viewCloneVM.ReconfigVM($specNewSpecification)
Write-Host "MacAddress Changes Completed"

##Export VM
Write-Host "Exporting Linked Clone to:" $CLONEEXPORTLOCATION
#https://www.vmware.com/support/developer/PowerCLI/PowerCLI51/html/Export-VApp.html
#Export-VApp [[-Destination] <String>] [-VApp] <VApp[]> [-Name <String>] [-Force] [-Format <VAppStorageFormat>] [-CreateSeparateFolder] [-Description <String>] [-Server <VIServer[]>] [-RunAsync] [-WhatIf] [-Confirm] [<CommonParameters>] 
#Export-VApp [[-Destination] <String>] -VM <VirtualMachine[]> [-Name <String>] [-Force] [-Format <VAppStorageFormat>] [-CreateSeparateFolder] [-Description <String>] [-Server <VIServer[]>] [-RunAsync] [-WhatIf] [-Confirm] [<CommonParameters>]
Get-VM -Name $CLONENAME | Export-VApp -Destination $CLONEEXPORTLOCATION -Format OVA -Description "Linked-Clone of $PARENT_VM. Created on $CreationDATE" -Confirm:$False
Write-Host "Export Completed Successfully"

Write-Host "Beginning Clean Up Phase"
##Delete Linked Clone VM
Write-Host "Deleting Linked Clone VM"
Remove-VM -VM $CLONENAME -DeletePermanently -Confirm:$False

##Remove Snapshot on parent VM
Write-Host "Removing Snapshots from parent VM" 
Get-Snapshot -VM $PARENT_VM -Name * | Remove-Snapshot -confirm:$False
##Consolidate Disks on PARENT VM
Write-Host "Consolidating Disks on Parent VM" 
(Get-VM -Name $PARENT_VM).ExtensionData.ConsolidateVMDisks()

##Disconnect from vCenter
Write-Host "Disconnecting vCenter Session"
disconnect-viserver $vCenter -confirm:$false

##Stopping Logging
Stop-Transcript
