<#
.NOTES
	Created by:		Russell Hamker
	Date:			April 1, 2026
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903

.SYNOPSIS
	This script will enforce SecureBoot on all Server Reboots

.DESCRIPTION
	Use this script to enforce SecureBoot on all Server Reboots

	Note:
	A TPM Chip is required for this to be installed in your VMHost.
	VMHost BIOS must be have SecureBoot Enabled prior to running this operation.
	HowTo: 
	https://www.dell.com/support/kbdoc/en-us/000158364/vxrail-how-do-enable-and-disable-uefi-secure-boot

	Reference: VMW-ESXI-01125
	https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-5-2-and-earlier/4-5/security-and-compliance-configuration-for-vmware-cloud-foundation-4-5/securing-esxi-hosts/configure-security-setting-using-powercli-1.html#:~:text=You%20must%20evacuate%20the%20host%20and%20gracefully%20reboot%20for%20changes%20to%20take%20effect.%20VMW%2DESXI%2D01125.

.EXAMPLE
	#Example - With Validation Time Out Set
	$VMHost = "hamesxi01.hamker.local"
	If(!$Credential){
		$Credential = Get-Credential -Username "root" -Message "Please Provide the root esxi password:"
	}
	$ValidationTimeout = 30 #Note this is in Minutes
	./set-secureboot-enforced-on-vmhost.ps1 -VMHost $VMHost -Credential $Credential -ValidationTimeout $ValidationTimeout

.EXAMPLE
	#Example - Without Validation Time Out Set
	$VMHost = "hamesxi01.hamker.local"
	If(!$Credential){
		$Credential = Get-Credential -Username "root" -Message "Please Provide the root esxi password:"
	}
	./set-secureboot-enforced-on-vmhost.ps1 -VMHost $VMHost -Credential $Credential

#>

param(
	[Parameter(Mandatory=$true)][String]$VMHost,
	[Parameter(Mandatory=$true)][System.Management.Automation.PSCredential]$Credential,
	[Parameter(Mandatory=$false)][Int]$ValidationTimeout
)

# Set Default of 30 minutes for Validation Time Out if not set
If($ValidationTime -lt 1){
	$ValidationTimeout = 30
}

#Import Module
Write-Host "Validating Installed PowerShell Modules needed for this process..."
$ModuleList = Get-InstalledModule | Where-Object {$_.Name -match "PowerVCF|VMware.PowerCLI"}
If($ModuleList.Name -contains "PowerVCF"){
	Write-Host "Importing PowerShell Module PowerVCF"
	Import-Module -Name PowerVCF # -Verbose
}Else{
	Write-Host "Importing PowerShell Module VMware.PowerCLI"
	Import-Module -Name VMware.PowerCLI # -Verbose
}
If($ModuleList.Name -notmatch "PowerVCF|VMware.PowerCLI"){
	Write-Warning "PowerShell Module PowerVCF or VMware.PowerCLI not found"
	Write-Error "Install VMware PowerCLI or PowerVCF Module" -ErrorAction Stop
}

#Validate that the Self Signed VCSA Certificates do not cause an issue with PowerCLI Connecting to the VCSA
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope User -Confirm:$false | Out-Null

##Disconnect from any open VMware Sessions,
#This can cause problems if there are any
Write-Host "Disconnecting from any Open VMHost Sessions"
TRY
{Disconnect-VIServer * -Confirm:$false | Out-Null}
CATCH
{Write-Host "No Open VMHost Sessions found"}

##Connect to VMware Resource
$COUNT = 0
Do{
	Write-Host "Connecting to VMHost - $($VMHOST)"
	$VISERVER = Connect-VIServer -server $VMHOST -Credential $Credential -ErrorAction SilentlyContinue
	If(!$VISERVER.Name){
		Write-Host "Could NOT Connect to VMHost - $VMHOST"
		$WaitSeconds = 60
		$Activity = "Waiting for $($WaitSeconds) Seconds"
		1..$WaitSeconds | ForEach-Object { $percent = $_ * 100 / $WaitSeconds 
			Write-Progress -Activity $Activity -Status "$($WaitSeconds - $_) Seconds remaining..." -PercentComplete $percent 
			Start-Sleep -Seconds 1
		}
		$COUNT ++
		Write-Host "Could Not Connect to VMHost - $($VMHOST)" -Foregroundcolor Red
		Write-Host "Count - $COUNT"
	}
}Until($VISERVER.Name -Or $COUNT -eq $ValidationTimeout)
If($COUNT -eq $ValidationTimeout){
	Write-Error "Could not connect to VMHost - $($VMHOST), Please check Network and DNS Resolution." -ErrorAction Stop
}
Write-Progress -Completed -Activity "make progress bar disappear" -ErrorAction SilentlyContinue

# Set Host into Maintenance Mode
Write-Host "Enabling Maintenance Mode on Server - $($VMHOST)"
Set-VMHost -VMHost $VMHOST -State "Maintenance" | Out-Null

# Check Current ESXi VIB Signature Verification Status
Write-Host "Checking ESXI VIB Signatures - $($VMHOST)"
$esxcli = Get-EsxCli -VMHost $VMHOST -V2
$SignatureList = $esxcli.software.vib.signature.verify.Invoke()
If($SignatureList.SignatureVerification -notmatch "Succeeded|Not Applicable"){
	$SignatureVerificationFailed = $SignatureList | Where-Object {$_.SignatureVerification -notmatch "Succeeded|Not Applicable"}
	Write-Output $SignatureVerificationFailed
	Write-Error "VIB Signature Verification Failure has occured. Please review above VIBs before implementing SecureBoot - $($VMHOST)" -ErrorAction Stop
}Else{
	Write-Host "All ESXi VIB Signature Verification has completed. All VIBs are SignatureVerification Succeeded (healthy) - $($VMHOST)" -ForegroundColor Green
}

# Validate TPM is present
Write-Host "Validating TPM Module is Present - $($VMHost)"
$esxcli = Get-EsxCli -VMHost $VMHOST -V2
$TPMCHECK = $esxcli.hardware.trustedboot.get.invoke()
If($TPMCHECK.TpmPresent -ne "true"){
	Write-Output $TPMCHECK
	Write-Host "Check BIOS/Hardware and ensure: TPMSecurity is Enabled, SecureBoot is Enabled, and TPM2 Algorithm is set to SHA256"
	Write-Error "TPM Module not Present - $($VMHost)" -ErrorAction Stop
}Else{
	Write-Host "Completed validating TPM Module is Present - $($VMHost)" -ForegroundColor Green
}

# Enforce SecureBoot as required at all Boots
Write-Host "Enforcing SecureBoot - $($VMHOST)"
$esxcli = Get-EsxCli -VMHost $VMHOST -V2
$arguments = $esxcli.system.settings.encryption.set.CreateArgs()
# Note: Must Set Encryption Mode to TPM
Write-Host "Setting System Encryption Mode to TPM - $($VMHOST)"
$arguments.mode = "TPM"
$OUTPUT = $null
$OUTPUT = $esxcli.system.settings.encryption.set.Invoke($arguments)
If($OUTPUT -ne "true"){
	Write-Host "Check BIOS Settings and ensure: SecureBoot is Enabled and TPM2 Algorithm is set to SHA256"
	Write-Error "Could NOT Set Encryption Mode to TPM - $($VMHOST)" -ErrorAction Stop
}Else{
	Write-Host "Completed setting System Encryption Mode to TPM - $($VMHOST)" -ForegroundColor Green
}
Write-Host "Enforcing RequireSecureBoot on all Reboots - $($VMHOST)"
$arguments = $esxcli.system.settings.encryption.set.CreateArgs()
$arguments.requiresecureboot = $true
$OUTPUT = $null
$OUTPUT = $esxcli.system.settings.encryption.set.Invoke($arguments)
If($OUTPUT -ne "true"){
	Write-Error "Could NOT Enforce RequireSecureBoot on all Reboots - $($VMHOST)" -ErrorAction Stop
}Else{
	Write-Host "Completed enforcing RequireSecureBoot on all Reboots - $($VMHOST)" -ForegroundColor Green
}

# Validate System Encryption Mode is set to TPM
Write-Host "Validating System Encryption Mode is set to TPM - $($VMHOST)"
$MODECHECK = $esxcli.system.settings.encryption.get.Invoke() | Select-Object Mode
If($MODECHECK.Mode -ne "TPM"){
	$MODECHECK | Out-Host
	Write-Error "System Encryption Mode is NOT set to TPM. Please check System Encryption Mode $esxcli.system.settings.encryption.get.Invoke() - $($VMHOST)" -ErrorAction Stop
}Else{
	#$MODECHECK | Out-Host
	Write-Host "Validated that System Encryption Mode is set to TPM - $($VMHOST)" -ForegroundColor Green
}

# Validate SecureBoot is Required
Write-Host "Validating RequireSecureBoot is Enforced - $($VMHOST)"
$SecureBootRequired = $esxcli.system.settings.encryption.get.Invoke() | Select-Object RequireSecureBoot
If($SecureBootRequired.RequireSecureBoot -eq "false"){
	$SecureBootRequired | Out-Host
	Write-Error "RequireSecureBoot is set to False. Please check RequireSecureBoot Enforcement - $($VMHOST)" -ErrorAction Stop
}Else{
	#$SecureBootRequired | Out-Host
	Write-Host "RequireSecureBoot is set to True (Enforced) for all Server boots - $($VMHOST)" -ForegroundColor Green
}

# Bring Server out of Maintenance Mode
Write-Host "Exiting Maintenance Mode - $($VMHOST)"
Set-VMHost -VMHost $VMHOST -State "Connected" | Out-Null

# Restart Host
Write-Host "Restarting VMHost to Complete Enforcement of SecureBoot - $($VMHOST)"
Restart-VMHost -VMHost $VMHOST -Force -Confirm:$false

##Disconnect from vCenter
Write-Host "Disconnecting from VMHost - $($VMHOST)"
Disconnect-VIServer $VMHOST -Confirm:$false -ErrorAction SilentlyContinue
