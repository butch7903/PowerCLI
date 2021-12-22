<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			August 4, 2021
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script will connect to a VCSA and import a VM Customization to it.
		The script will then update the VM Customization with the local DNS Servers
		that are specified in the VAMI interface.

	.DESCRIPTION
		Use this script to import VM Customization Specifications.
		
	.NOTES
		This script requires a VMware PowerCLI minimum version 11.4 or greater. 
		
		This script takes into account that you have already configured a VMHost with 
		the proper networking configuration prior to generating the Host Profile from 
		it.

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

Function Get-VAMIServiceAPI {
<#
    .NOTES
    ===========================================================================
     Inspired by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
     Created by:    Michael Dunsdon
     Twitter:      @MJDunsdon
     Date:         September 21, 2020
    ===========================================================================
    .SYNOPSIS
        This function returns the Service Api Based on a String of Service Name.
    .DESCRIPTION
        Function to find and get service api based on service name string
    .EXAMPLE
        Connect-CisServer -Server 192.168.1.51 -User administrator@vsphere.local -Password VMware1!
        Get-VAMIUser -NameFilter "accounts"
    .NOTES
        Script supports 6.5 and 6.7 VCSAs.
        Function Gets all Service Api Names and filters the list based on NameFilter
        If Multiple Serivces are returned it takes the Top one.
#>
    param(
        [Parameter(Mandatory=$true)]
        [String]$NameFilter
    )

    $ServiceAPI = Get-CisService | Where-Object {$_.name -like "*$($NameFilter)*"}
    if (($ServiceAPI.count -gt 1) -and $NameFilter) {
        $ServiceAPI = ($ServiceAPI | Sort-Object -Property Name)[0]
    }
    return $ServiceAPI
}

Function Get-VAMINetwork {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
     Modifed by:    Michael Dunsdon
     Twitter:      @MJDunsdon
     Date:         September 21, 2020
	===========================================================================
    .SYNOPSIS
        This function retrieves network information from VAMI interface (5480)
        for a VCSA node which can be an Embedded VCSA, External PSC or External VCSA.
    .DESCRIPTION
        Function to return networking information including details for each interface
    .EXAMPLE
        Connect-CisServer -Server 192.168.1.51 -User administrator@vsphere.local -Password VMware1!
        Get-VAMINetwork
    .NOTES
        Modified script to account for Newer VCSA. Script supports 6.5 and 6.7 VCSAs
#>
    $netResults = @()

    $Hostname = ( Get-VAMIServiceAPI -NameFilter "dns.hostname").get()
    $dns = (Get-VAMIServiceAPI -NameFilter "dns.servers").get()

    #Write-Host "Hostname: " $hostname
    #Write-Host "DNS Servers: " $dns.servers

    $interfaces = (Get-VAMIServiceAPI -NameFilter "interfaces").list()
    foreach ($interface in $interfaces) {
        $ipv4API = (Get-VAMIServiceAPI -NameFilter "ipv4")
        if ($ipv4API.help.get.psobject.properties.name -like "*_*") {
            $ipv4result = $ipv4API.get($interface.Name)
            $Updateable = $ipv4result.configurable
        } else {
            $ipv4result = $ipv4API.get(@($interface.Name))
            $Updateable = $ipv4result.updateable
        }
        $interfaceResult = [pscustomobject] @{
            Inteface =  $interface.name;
            MAC = $interface.mac;
			DNS = $dns.servers
            Status = $interface.status;
            Mode = $ipv4result.mode;
            IP = $ipv4result.address;
            Prefix = $ipv4result.prefix;
            Gateway = $ipv4result.default_gateway;
            Updateable = $Updateable
        }
        $netResults += $interfaceResult
    }
    $netResults
}

#Reference: http://aroundtheweb.com/using-powercli-to-export-and-import-os-customization-specs/
Function Import-OSCustomizationSpec {
    param (
        [string]$importFile,
        [string]$specName #Use to change the spec name from that defined in the file
    )
    $specXml = Get-Content $importFile
    $csmgr = Get-View CustomizationSpecManager
    $spec = $csmgr.XmlToCustomizationSpecItem($specXml)
     # Change the name if a new one was given.
    if ($specName) {
        $spec.Info.Name = $specName
    }
     if ($csmgr.DoesCustomizationSpecExist($spec.Info.Name)) {
        throw "Spec $specName already exists."
    }
    else {
        $csmgr.CreateCustomizationSpec($spec)
    }
}

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

##Get Current Path
$pwd = pwd

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + $LOGDATE + ".txt"
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

<#
##Provide VCSA
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
$VCSA = Read-Host "Please Provide FQDN of VCSA
"
Write-Host "VCSA input is $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
#>

#if vcenter.csv exists, import it 
$AnswerFile = $pwd.path+"\"+"vcenters.csv"
If (Test-Path $AnswerFile){
Write-Host "Answer file found, importing answer file"$AnswerFile
$VCSALIST = Get-Content -Path $AnswerFile | Sort
}Else{
$Answers_List = @()
$Answers="" | Select VCSAList
$VCSALIST = Read-Host "Please input the FQDN or IP of your VCSA
Note: If you wish to do multiple VCSAs, edit the CSV to include many
Example 1: hamvc01.hamker.local
Example 2: 
hamvc01.hamker.local
hamvc02.hamker.local
hamvc03.hamker.local
"
$Answers.VCSALIST = $VCSALIST
$Answers_List += $Answers
$Answers_List | Format-Table -AutoSize
Write-Host "Exporting Information to File"$AnswerFile
$Answers_List | Export-CSV -NoTypeInformation $AnswerFile
}

#Check for OS Customization CSV
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Checking/Importing OSCustomization.csv"
$OSCUSTOMIZATIONCSVFILENAME = "OSCustomization.csv"
$LOCALPATH = $pwd.path
$OSCUSTOMIZATIONCSVFILEGET = Get-Item "$LOCALPATH\$OSCUSTOMIZATIONCSVFILENAME" -ErrorAction SilentlyContinue
$OSCUSTOMIZATIONCSVFILE = "$LOCALPATH\$OSCUSTOMIZATIONCSVFILENAME"
$OSCUSTOMIZATIONNAMELIST = @()
If(!$OSCUSTOMIZATIONCSVFILEGET)
{
	CLS
	Write-Host "OS Customization CSV File not found"
	$OSCUSTOMIZATIONLIST = @()
	$CREATENEWRECORD = "" | Select Path
	$CREATENEWRECORD.Path = "Please add OS Customization full file path" 
	$OSCUSTOMIZATIONLIST += $CREATENEWRECORD
	$OSCUSTOMIZATIONLIST | Export-CSV -NoTypeInformation -PATH $OSCUSTOMIZATIONCSVFILE
	Write-Host "OS Customization CSV Created, Continuing"
}
If($OSCUSTOMIZATIONCSVFILEGET)
{
	Write-Host "OS Customizations CSV File Found. Importing..."
	$OSCUSTOMIZATIONLIST = Import-CSV -PATH $OSCUSTOMIZATIONCSVFILE
}
Write-Host "Completed Checking/Importing OSCustomization.csv"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Create Secure AES Keys for User and Password Management
$KeyFile = $pwd.path+"\"+"OSCustomizationAES.key"
If (Test-Path $KeyFile){
	Write-Host "AES File Exists"
	$Key = Get-Content $KeyFile
	Write-Host "Continuing..."
}
Else {
	$Key = New-Object Byte[] 16   # You can use 16, 24, or 32 for AES
	[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
	$Key | out-file $KeyFile
}

##Create Secure XML Credential File for vCenter
$LocalAdmin = $pwd.path+"\"+"OSCustomizationLocalAdmin.xml"
If (Test-Path $LocalAdmin){
	Write-Host "LocalAdmin.xml file found"
	Write-Host "Continuing..."
	$ImportObject = Import-Clixml $LocalAdmin
	$SecureString = ConvertTo-SecureString -String $ImportObject.Password -Key $Key
	$LocalAdminCredential = New-Object System.Management.Automation.PSCredential($ImportObject.UserName, $SecureString)
	$LOCALADMINUSER = $LocalAdminCredential.UserName
	$LOCALADMINSecurePassword = $LocalAdminCredential.Password
	$LOCALADMINUnsecurePassword = (New-Object PSCredential "user",$LOCALADMINSecurePassword).GetNetworkCredential().Password
}
Else {
	$newPScreds = Get-Credential -message "Enter Windows Local Administrator Password"
	#$rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
	#$rng.GetBytes($Key)
	$exportObject = New-Object psobject -Property @{
		UserName = $newPScreds.UserName
		Password = ConvertFrom-SecureString -SecureString $newPScreds.Password -Key $Key
	}
	$exportObject | Export-Clixml LocalAdmin.xml
	$LocalAdminCredential = $newPScreds
	$LOCALADMINUSER = $LocalAdminCredential.UserName
	$LOCALADMINSecurePassword = $LocalAdminCredential.Password
	$LOCALADMINUnsecurePassword = (New-Object PSCredential "user",$LOCALADMINSecurePassword).GetNetworkCredential().Password
}

##Create Secure XML Credential File for vCenter
$DomainUser = $pwd.path+"\"+"OSCustomizationDomainUser.xml"
If (Test-Path $DomainUser){
	Write-Host "DomainUser.xml file found"
	Write-Host "Continuing..."
	$ImportObject = Import-Clixml $DomainUser
	$SecureString = ConvertTo-SecureString -String $ImportObject.Password -Key $Key
	$DomainUserCredential = New-Object System.Management.Automation.PSCredential($ImportObject.UserName, $SecureString)
	$DOMAINUSER = $DomainUserCredential.UserName
	$DOMAINUSERSecurePassword = $DomainUserCredential.Password
	$DOMAINUSERUnsecurePassword = (New-Object PSCredential "user",$DOMAINUSERSecurePassword).GetNetworkCredential().Password
}
Else {
	$newPScreds = Get-Credential -message "Enter Windows Domain User add Password"
	#$rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
	#$rng.GetBytes($Key)
	$exportObject = New-Object psobject -Property @{
		UserName = $newPScreds.UserName
		Password = ConvertFrom-SecureString -SecureString $newPScreds.Password -Key $Key
	}
	$exportObject | Export-Clixml DomainUser.xml
	$DomainUserCredential = $newPScreds
	$DOMAINUSER = $DomainUserCredential.UserName
	$DOMAINUSERSecurePassword = $DomainUserCredential.Password
	$DOMAINUSERUnsecurePassword = (New-Object PSCredential "user",$DOMAINUSERSecurePassword).GetNetworkCredential().Password
}

##Provide Credentials
CLS
##Create Secure XML Credential File for vCenter
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Creating/Importing VCSA User Credentials"
$MgrCreds = $pwd.path+"\"+"OSCustomizationMgrCreds.xml"
If (Test-Path $MgrCreds){
	Write-Host "MgrCreds.xml file found"
	Write-Host "Continuing..."
	$ImportObject = Import-Clixml $MgrCreds
	$SecureString = ConvertTo-SecureString -String $ImportObject.Password -Key $Key
	$MyCredential = New-Object System.Management.Automation.PSCredential($ImportObject.UserName, $SecureString)
}
Else {
	$newPScreds = Get-Credential -message "Enter vCenter admin creds here"
	#$rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
	#$rng.GetBytes($Key)
	$exportObject = New-Object psobject -Property @{
		UserName = $newPScreds.UserName
		Password = ConvertFrom-SecureString -SecureString $newPScreds.Password -Key $Key
	}
	$exportObject | Export-Clixml MgrCreds.xml
	$MyCredential = $newPScreds
}
Write-Host "Completed Creating/Importing VCSA User Credentials"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Do this for all VCSAs in the VCSA List
ForEach($VCSA in $VCSALIST)
{
CLS
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
$VAMISERVER = Connect-CisServer -Server $VCSA -Credential $MyCredential
Write-Host "Connected to vCenter "
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Get VAMI DNS Server List
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Getting VAMI Network Info"
$VCSANET = Get-VAMINetwork
$DNSLIST = $VCSANET.DNS
Write-Host "VCSA $VCSA"
Write-Host "VCSA DNS List includes"
ForEach($DNS in $DNSLIST)
{Write-Host "$DNS"}
Write-Host "Completed getting VAMI Network Info"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

ForEach($OSCUSTOMIZATIONITEM in $OSCUSTOMIZATIONLIST)
{
#Get File Path Info
$FILEPATH = $OSCUSTOMIZATIONITEM.Path
$FILE = Get-ChildItem $FILEPATH
$SPECNAME = $FILE.BaseName

##Remove Old Versions of the VM Customization Spec 
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Removing any old versions of VM Customization Spec $SPECNAME"
TRY
{Get-OSCustomizationSpec $SPECNAME | Remove-OSCustomizationSpec -confirm:$false -ErrorAction SilentlyContinue }
CATCH
{Write-Host "OS Customization $SPECNAME Not found, continuing..."}
Write-Host "Completed removing any old versions of VM Customization Spec $SPECNAME"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Import VM Customization Spec
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Importing VM Customization Spec $SPECNAME"
Import-OSCustomizationSpec -importFile $FILEPATH -specName $SPECNAME
Write-Host "Completed importing VM Customization Spec $SPECNAME"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Modify VM Customization Spec DNS Servers Based on what VCSA uses
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Modifiy VM Customization Spec $SPECNAME to use VAMI's DNS Server List"
$OSCUSTOMIZATION = Get-OSCustomizationSpec $SPECNAME
$DNS1 = $DNSLIST[0]
$DNS2 = $DNSLIST[1]
If($OSCUSTOMIZATION.OSType -eq "Windows")
{
	$nicMapping = Get-OSCustomizationNicMapping -OSCustomizationSpec $OSCUSTOMIZATION
	Write-Host "Setting DNS Servers to $DNS1 and $DNS2"
	$nicMapping | Set-OSCustomizationNicMapping -DNS $DNS1,$DNS2 #-IpAddress $IP -SubnetMask $SUBNET -DefaultGateway $DG -DNS $DNS1,$DNS2
}
If($OSCUSTOMIZATION.OSType -eq "Linux")
{
	$OSCUSTOMIZATION | Set-OSCustomizationSpec -DnsServer $DNS1,$DNS2
}
Write-Host "Completed modifiy VM Customization Spec $SPECNAME to use VAMI's DNS Server List"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Update Windows Update Customization Passwords
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Updating VM Customization Spec $SPECNAME Local Admin and Domain Passwords"
If($SPECNAME -eq "Windows")
{
	Set-OSCustomizationSpec -OSCustomizationSpec $OSCUSTOMIZATION -AdminPassword $LOCALADMINUnsecurePassword -DomainPassword $DOMAINUSERUnsecurePassword
	Write-Host "Running Command 2nd Time due to VCSA $VCSA Encryption Key Difference"
	Set-OSCustomizationSpec -OSCustomizationSpec $OSCUSTOMIZATION -AdminPassword $LOCALADMINUnsecurePassword -DomainPassword $DOMAINUSERUnsecurePassword ## Running command a second time due to VCSA Encryption Key Difference
}
Write-Host "Completed updating VM Customization Spec $SPECNAME Local Admin and Domain Passwords"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

}

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
#PAUSE
} #End of VCSA Run

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
Write-Host "Script Completed for $VCSA"
Write-Host "Press Enter to close this PowerShell Script"
PAUSE
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

