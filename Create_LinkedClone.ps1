##Linked Clone Creation Script Created by Russell Hamker
##Import VMware PowerShell Modules
Import-Module VMware.PowerCLI
#Import Active Directory PowerShell Module 
import-module activedirectory

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
	$Domain = $Line.Domain
	Write-Host "Domain is:"$Domain
	$PARENT_VM_Name = $Line.ParentVMName
	Write-Host "Parent VM is:"$PARENT_VM_Name
	$LOCATION = $Line.CloneLocation
	Write-Host "Clone VM Location will be:"$LOCATION
	$OSSPECIFICATION = $Line.OSSpecification
	Write-Host "The OS Specification Customization will be:"$OSSPECIFICATION
	$TargetOU = $Line.TargetOU
	Write-Host "Target OU for Linked-Cloned VMs will be:" $TargetOU
	Write-Host "Continuing..."
	Start-Sleep -Seconds 2
}
}
Else {
$Answers_List = @()
$Answers="" | Select Version,SubVersion,vCenter,Domain,ParentVMName,CloneLocation,OSSpecification,TargetOU
Write-Host "Answer file NOT found. Please input information to continue."
$Version = "1"
$Answers.Version = $Version
$SubVersion = "0"
$Answers.SubVersion = $SubVersion
$vCenter = Read-Host "Input vCenter FQDN"
#$vCenter = "sandvcsa01.sandbox.local"
$Answers.vCenter = $vCenter
$Domain = Read-Host "Input domain that VMs will be placed in.
Example: Contoso.local"
#Domain = "sandbox.local"
$Answers.Domain = $Domain
$PARENT_VM_Name = Read-Host "Input Parent VM Name"
#$PARENT_VM_Name = "SANDSQL01"
$Answers.ParentVMName = $PARENT_VM_Name
$LOCATION = Read-Host "Input Location of where VMs should be placed in vCenter.
Example: DataCenter1/DEV/USA/SQL"
#$LOCATION = "DataCenter1/DEV/USA/SQL"
$Answers.CloneLocation = $LOCATION
$OSSPECIFICATION = Read-Host "Input OS Customization Template Name.
If you are unsure of the Template Name, run the command Get-OSCustomizationSpec"
#$OSSPECIFICATION = Get-OSCustomizationSpec -Name "US DEV"
$Answers.OSSpecification = $OSSPECIFICATION
#TargetOU = OU=SQL,OU=US,OU=Server_OU,DC=sandbox,DC=local
$TargetOU = Read-Host "Input Active Directory OU that VMs will be placed in.
Example: OU=SQL,OU=US,OU=Server_OU,DC=sandbox,DC=local"
$Answers.TargetOU = $TargetOU

$Answers_List += $Answers
$Answers_List | Format-Table -AutoSize
Write-Host "Exporting Information to File"$AnswerFile
$Answers_List | Export-CSV -NoTypeInformation $AnswerFile
}

##Specify CSV for name of Linked Clone Servers and MAC Addresses
##File Format is VM,Datastore,MacAddress
$FILENAME = "Linked_Clone_List.csv"
$FILE= $pwd.path+"\"+$FILENAME
If (Test-Path $File){
Write-Host "Linked Clone File Found" $File
Write-Host "Continuing..."
Start-Sleep -Seconds 2
}
Else {
Write-Host "Linked Clone File NOT Found!" $File
Write-Host "Please Create Clone File."
Write-Host "File Format is: VM,Datastore,MacAddress"
Write-Host "Exiting in 15 seconds"
Start-Sleep -Seconds 15
EXIT
}
Write-Host "Full CSV File and path is"$FILE

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


##Import CSV to Array
$CSV = Import-Csv $FILE

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

##Shutdown VM to prepare for new Linked-Clones
Write-Host "Shutting down for new Linked-Clone VMs"
foreach($VM in $CSV)
{
	Stop-VMGuest -VM $VM.Name -Confirm:$false
	Write-Host "Shutting Down VM"$VM.Name
}

##Clean up prior to Starting (incase their are old VMs out there)
##Delete Linked Clone VMs
Write-Host "Cleaning up old Linked-Clone VMs" 
foreach($VM in $CSV)
{
	Write-Host "Powering off VM"$VM.Name
	Stop-VM -KILL -VM $VM.Name -Confirm:$false
	Write-Host "Deleting VM"$VM.Name
	Remove-VM $VM.Name -DeletePermanently -Confirm:$false
}

##Remove Snapshot on parent VM
Write-Host "Removing Snapshots from parent VM" 
Get-Snapshot -VM $PARENT_VM -Name * | Remove-Snapshot -confirm:$False
##Consolidate Disks on PARENT VM
Write-Host "Consolidating Disks on Parent VM" 
(Get-VM -Name $PARENT_VM).ExtensionData.ConsolidateVMDisks()

##Reset Active Directory Computer Accounts for Reuse
Write-Host "Resetting Active Directory Computer Accounts for Reuse"
foreach($VM in $CSV)
{
	$VMName = $VM.Name
	Write-Host "Resetting AD Computer account for" $VM.Name
	If (@(Get-ADComputer $VMName -Server $Domain -Credential $MyCredential -ErrorAction SilentlyContinue).Count) 
	{
		Write-Host "AD Computer Object Exists for"$VMName
		$DN = Get-ADComputer $VMName -Server $Domain -Credential $MyCredential | Select DistinguishedName
		$DN1 = $DN.DistinguishedName
		#Generate Random new Password for Computer Account
		$NewPasswordPlainTXT = ([char[]](Get-Random -Input $(48..57 + 65..90 + 97..122) -Count 15)) -join ""
		#Convert Password to SecureString
		$NewPassword  = $NewPasswordPlainTXT | ConvertTo-SecureString -AsPlainText -Force
		#Set Password for Computer Account
		Set-ADAccountPassword $DN1 -Server $Domain -Credential $MyCredential -Reset -NewPassword $NewPassword
		$DN = ""
		$DN1 = ""
		$NewPasswordPlainTXT = ""
		$NewPassword = ""
		#Get Password Last Set Data
		Get-ADComputer -Identity $VMName -Server $Domain -Credential $MyCredential -Properties PasswordLastSet
		Write-Host "AD Computer Account reset for" $VMName "Completed"
	}
	Else
	{
		Write-Host "AD Account Not found for Computer Object"$VMName
	}
	$VMName = ""
}

##End of Clean up tasks##
Write-Host "Clean up tasks completed" 

##Remove IP address from Parent VM

##Shutdown Parent VM for Snapshot prepartion
Write-Host "Shutting down parent VM"$PARENT_VM
Stop-VMGuest -VM $PARENT_VM -confirm:$False

##Wait until Parent VM is Powered Off
Write-Host "Waiting until Parent VM is powered off. VM Name is"$Parent_VM_Name
Write-Host "Parent VM should remain in a shutdown state after this phase except to update the Parent VM"
Do 
	{
	$VirtualMachine = Get-VM -Name $Parent_VM_Name
	Write-Host "Power State of Parent VM" $VirtualMachine.Name "is now in the"$VirtualMachine.Powerstate "state" 
	Start-Sleep -Seconds 5
	} 
Until ($VirtualMachine.Powerstate -eq "PoweredOff")
Write-Host "Parent VM Successfully Powered Off"
$VirtualMachine = ""

##Snapshot PARENT VM
Write-Host "Creating Snapshot on Parent VM"$PARENT_VM
$CreationDATE = Get-Date -format "MMM-dd-yyyy_HH-mm-ss"
$SNAP = New-Snapshot -VM $PARENT_VM -Name Export_$CreationDATE -Quiesce -Description "Quiesced Snapshot of $PARENT_VM_Name on Date $CreationDATE"
Write-Host "Parent VM Snapshot Created on Parent VM"$Parent_VM
$CreationDATE = ""

##Create Linked Clone from parent VM using snapshot for place in time
#Uses Same host as parent VM to create Linked Clone on.
Write-Host "Creating linked-clones from parent VM snapshot" 
#$SNAP = Get-VM -Name $PARENT_VM | Get-Snapshot -name Export_$DATE
Foreach($VM in $CSV)
{
	$CreationDATE = Get-Date -format "MMM-dd-yyyy_HH-mm-ss"
	Write-Host "VM creation Process started for VM"$VM.Name 
	$Cluster = Get-VMHost $Parent_VM.VMHost | Get-Cluster
	New-VM -Name $VM.Name -VM $PARENT_VM -ResourcePool $Cluster -Datastore $VM.Datastore -Notes "Linked-Clone of $PARENT_VM. Created on $CreationDATE" -LinkedClone -ReferenceSnapshot $SNAP -Location (Get-FolderByPath -Path $LOCATION) -OSCustomizationSpec $OSSPECIFICATION
	Write-Host "VM creation process completed for"$VM.Name 
}
$CreationDATE = ""

##Set MAC Address Per CSV
##Check if MAC Address is specified. If not specified, skip this and update the CSV, if it is, update the MacAddress on the VM.
Write-Host "Setting MacAddresses of linked-clone VMs per documentation" 
$NewVM_List = @()
Foreach($VM in $CSV)
{
	$MacAddress = $VM.MacAddress
	$internal_counter = 0

	If ($MacAddress -ne "")
		{
			Write-Host "MacAddresses Found."
			Write-Host "Updating MacAddresses to Match Documentation for VM" $VM.Name
			##Reference https://communities.vmware.com/thread/319904?tstart=0
			$strCloneVMName = $VM.Name
			## get the .Net View object of the clone VM
			$viewCloneVM = Get-View -ViewType VirtualMachine -Property Name,Config.Hardware.Device -Filter @{"Name" = $strCloneVMName}
			## get the NIC device (further operations assume that this VM has only one NIC)
			$deviceNIC = $viewCloneVM.Config.Hardware.Device | ?{$_ -is [VMware.Vim.VirtualEthernetCard]}
			## set the MAC address to that of the original VM (also assumes that original VM has only one NIC)
			$deviceNIC.MacAddress = $VM.MacAddress
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
			Write-Host "MacAddress updated for VM" $VM.Name "with MacAddress" $VM.MacAddress
			$VMInfo="" | Select Name,Datastore,MacAddress
			$VMInfo.Name = $VM.Name
			$VMInfo.Datastore = $VM.Datastore
			$VMInfo.MacAddress = $MacAddress
			$NewVM_List += $VMInfo
		}
	If ($MacAddress -eq "")
		{
			Write-Host "MacAddresses not documented for VM" $VM.Name
			Write-Host "Updating CSV"$FILENAME
			$MAC = Get-VM -Name $VM.Name | Get-NetworkAdapter | Select MacAddress
			$MAC = $MAC.MacAddress
			##Recreate CSV File from Array with MacAddress Info
			$VMInfo="" | Select Name,Datastore,MacAddress
			$VMInfo.Name = $VM.Name
			$VMInfo.Datastore = $VM.Datastore
			$VMInfo.MacAddress = $MAC
			$NewVM_List += $VMInfo
			$Internal_counter++ ##Count increment tells script to update CSV
		}
	##Write List back to CSV if any VMs dont have MAC address specified in file
	If ($Internal_Counter -ne "0")
	{
		##Rename Original CSV
		Rename-Item $FILENAME $FILENAME-Original
		$NewVM_List | Format-Table -AutoSize
		$NewVM_List | Export-CSV -NoTypeInformation $FILENAME
	}
}
$NewVM_List = @()
Write-Host "MacAddress Changes Completed"

##Power On Linked Clones
Foreach($VM in $CSV)
{
Write-Host "Powering on Linked-Clone VM"$VM.Name 
Start-VM -VM $VM.Name -Confirm:$false
}

##Wait for VMs to complete sysprep/customization process
Write-Host "Waiting for VMs to Complete SysPrep/Customization Processes"
Foreach($VM in $CSV)
{
	$VMName = $VM.Name
	$FQDN = $VMName + "." + $Domain 
	Write-Host "Starting SysPrep/Customization process monitoring for VM:"$VMName
	Do     
		{
		$VirtualMachine = Get-VM -Name $VMName
		$GuestHostName = $VirtualMachine.ExtensionData.Guest.Hostname
		Write-Host "Waiting for VM named:" $VMName "to match guest named:" $GuestHostName
		Start-Sleep -Seconds 5
		} 
	Until ($GuestHostName -eq $FQDN)
	Write-Host "SysPrep/Customization process for" $VMName "is now completed" 
	$FQDN = ""
}
Write-Host "SysPrep process completed for all VMs"

##Move Active Directory Computer Accounts to Proper Organizational Unit
Write-Host "Moving VMs to Active Directory OU" $TargetOU
foreach($VM in $CSV)
{
	$VMName = $VM.Name
	Get-ADComputer $VMName -Server $Domain -Credential $MyCredential | Move-ADObject -TargetPath $TargetOU
	$NewLocation = Get-ADComputer $VMName -Server $Domain -Credential $MyCredential  | Select DistinguishedName
	Write-Host $VMName "AD Account has been moved to" $NewLocation
	$VMName = ""
	$NewLocation = ""
}
Write-Host "Completed moving Active Directory Computer Accounts to proper OU"

##Wait Extra time prior to Shutdown
Write-Host "Waiting 100 Seconds before proceeding to next steps" 
Start-Sleep -Seconds 100

##Shutdown For Snapshot Post SysPrep. This allows VMs to be reverted to Post SysPrep State at any time.
Write-Host "Shutting down new Linked-Clone VMs to create post SysPrep Snapshot"
foreach($VM in $CSV)
{
	Stop-VMGuest -VM $VM.Name -Confirm:$false
	Write-Host "Shutting Down VM"$VM.Name
}

##Verify that VMs are offline
Write-Host "Verifing that all Linked-Clones are shutdown"
Foreach($VM in $CSV)
{
	$VMName = $VM.Name
	Write-Host "Starting Shutdown monitoring for" $VMName 
	Do     
		{
		$VirtualMachine = Get-VM -Name $VMName
		Write-Host "Power State of VM" $VirtualMachine.Name "is now in the"$VirtualMachine.Powerstate "state" 
		Start-Sleep -Seconds 5
		} 
	Until ($VirtualMachine.Powerstate -eq "PoweredOff")
}
$VMName = ""
Write-Host "All Guest VMs now verifed as powered off" 

##Snapshot Linked-Clone VMs Post SysPrep
##Get Updated Date Info for naming of snapshot variable
Write-Host "Creating snapshots of Linked-Clones"
$DATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
Foreach($VM in $CSV)
{
	##Snapshot Linked Clone VMs
	$CreationDATE = Get-Date -format "MMM-dd-yyyy_HH-mm-ss"
	$VMName = $VM.Name
	Write-Host "Creating Snapshot of VM"$VMName
	New-Snapshot -VM $VMName -Name "Post SysPrep $CreationDATE" -Description "Post SysPrep Snapshot of VM $VMName. Created On Date: $CreationDATE"
}
$VMName = ""
$CreationDATE = ""
Write-Host "Snapshots Created"

##Power On Linked-Clones
Write-Host "Powering on Linked-Clone VMs"
Foreach($VM in $CSV)
{
Start-VM -VM $VM.Name -Confirm:$false
}

##Disconnect from vCenter
Write-Host "Disconnecting vCenter Session"
disconnect-viserver $vCenter -confirm:$false

##Stopping Logging
Stop-Transcript
