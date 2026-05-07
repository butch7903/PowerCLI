<#
.NOTES
	Created by:		Russell Hamker
	Date:			May 7, 2026
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903

.SYNOPSIS
	This script will audit SecureBoot configuration for a ESXi Host

.DESCRIPTION
	Use this script to audit SecureBoot configuration for a ESXi Host

	Reference: VMW-ESXI-01125
	https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-5-2-and-earlier/4-5/security-and-compliance-configuration-for-vmware-cloud-foundation-4-5/securing-esxi-hosts/configure-security-setting-using-powercli-1.html#:~:text=You%20must%20evacuate%20the%20host%20and%20gracefully%20reboot%20for%20changes%20to%20take%20effect.%20VMW%2DESXI%2D01125.

.EXAMPLE
	#Example - Single Host - direct to VMHost
	$VMHost = "hamesxi01.hamker.local"
	If(!$Credential){
		$Credential = Get-Credential -Username "root" -Message "Please Provide the root esxi password:"
	}
	$ValidationTimeout = 30 #Note this is in Minutes
	./audit-secureboot-enforced-on-vmhost.ps1 `
	-VMHost $VMHost `
	-Credential $Credential `
	-ValidationTimeout $ValidationTimeout

.EXAMPLE
	#Example - Single Host - Via VCSA to VMHost
	$VCSA = "hamvc01.hamker.local"
	$VMHost = "hamesxi01.hamker.local"
	If(!$Credential){
		$Credential = Get-Credential -Username "administrator@vsphere.local" -Message "Please Provide the VCSA administrator@vsphere.local password:"
	}
	./audit-secureboot-enforced-on-vmhost.ps1 `
	-VCSA $VCSA `
	-VMHost $VMHost `
	-Credential $Credential

.EXAMPLE
	#Example - Cluster - Via VCSA
	$VCSA = "hamvc01.hamker.local"
	$Cluster = "MyCluster"
	If(!$Credential){
		$Credential = Get-Credential -Username "administrator@vsphere.local" -Message "Please Provide the VCSA administrator@vsphere.local password:"
	}
	./audit-secureboot-enforced-on-vmhost.ps1 `
	-VCSA $VCSA `
	-Cluster $Cluster `
	-Credential $Credential

.EXAMPLE
	#Example - All VMHosts - Via VCSA
	$VCSA = "hamvc01.hamker.local"
	If(!$Credential){
		$Credential = Get-Credential -Username "administrator@vsphere.local" -Message "Please Provide the VCSA administrator@vsphere.local password:"
	}
	./audit-secureboot-enforced-on-vmhost.ps1 `
	-VCSA $VCSA `
	-Credential $Credential

#>

param(
	[Parameter(Mandatory=$false)][String]$VCSA,
	[Parameter(Mandatory=$false)][String]$VMHost,
	[Parameter(Mandatory=$false)][String]$Cluster,
	[Parameter(Mandatory=$true)][System.Management.Automation.PSCredential]$Credential,
	[Parameter(Mandatory=$false)][Int]$ValidationTimeout
)

# Set Default of 30 minutes for Validation Time Out if not set
If($ValidationTime -lt 1){
	$ValidationTimeout = 30
}

If($VCSA -And !$VMHost -And !$Cluster){
	Write-Warning "You have specified a VCSA, but no VMHost or Cluster. Auditing All VMHosts - $VCSA"
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

#VMHost Direct Audit
If($VMHost -and !$VCSA){
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
	$VMHOSTLIST = $VMHost

	$OUTPUTARRAY = @()
	ForEach($VMHost in $VMHOSTLIST){
		# Connect to ESXCLI
		$esxcli = $null
		$esxcli = Get-EsxCli -VMHost $VMHOST -V2

		# Validate System Encryption Mode is set to TPM
		Write-Host "Validating System Encryption Mode is set to TPM - $($VMHOST)"
		$MODECHECK = $esxcli.system.settings.encryption.get.Invoke() | Select-Object Mode

		# Validate SecureBoot is Required
		Write-Host "Validating RequireSecureBoot is Enforced - $($VMHOST)"
		$SecureBootRequired = $esxcli.system.settings.encryption.get.Invoke() | Select-Object RequireSecureBoot
		
		#Document Output to Array
		$TEMPARRAY = "" | Select-Object VMHost, HostEncryptionMode, RequireSecureBoot
		$TEMPARRAY.VMHost = $VMHost
		$TEMPARRAY.HostEncryptionMode = $MODECHECK.Mode
		$TEMPARRAY.RequireSecureBoot = $SecureBootRequired.RequireSecureBoot
		$OUTPUTARRAY += $TEMPARRAY
	}

	#Output Data
	Write-Output $OUTPUTARRAY

	##Disconnect from vCenter
	Write-Host "Disconnecting from VMHost - $($VMHOST)"
	Disconnect-VIServer $VMHOST -Confirm:$false -ErrorAction SilentlyContinue
}Else{
	#VCSA Single VMHost Audit
	If($VCSA -And $VMHost){
		##Connect to VMware Resource
		$COUNT = 0
		Do{
			Write-Host "Connecting to VCSA - $($VCSA)"
			$VISERVER = Connect-VIServer -server $VCSA -Credential $Credential -ErrorAction SilentlyContinue
			If(!$VISERVER.Name){
				Write-Host "Could NOT Connect to VCSA - $VCSA"
				$WaitSeconds = 60
				$Activity = "Waiting for $($WaitSeconds) Seconds"
				1..$WaitSeconds | ForEach-Object { $percent = $_ * 100 / $WaitSeconds 
					Write-Progress -Activity $Activity -Status "$($WaitSeconds - $_) Seconds remaining..." -PercentComplete $percent 
					Start-Sleep -Seconds 1
				}
				$COUNT ++
				Write-Host "Could Not Connect to VCSA - $($VCSA)" -Foregroundcolor Red
				Write-Host "Count - $COUNT"
			}
		}Until($VISERVER.Name -Or $COUNT -eq $ValidationTimeout)
		If($COUNT -eq $ValidationTimeout){
			Write-Error "Could not connect to VCSA - $($VCSA), Please check Network and DNS Resolution." -ErrorAction Stop
		}
		Write-Progress -Completed -Activity "make progress bar disappear" -ErrorAction SilentlyContinue
		$VMHOSTLIST = $VMHost

		$OUTPUTARRAY = @()
		ForEach($VMHost in $VMHOSTLIST){
			# Connect to ESXCLI
			$esxcli = $null
			$esxcli = Get-EsxCli -VMHost $VMHOST -V2

			# Validate System Encryption Mode is set to TPM
			Write-Host "Validating System Encryption Mode is set to TPM - $($VMHOST)"
			$MODECHECK = $esxcli.system.settings.encryption.get.Invoke() | Select-Object Mode

			# Validate SecureBoot is Required
			Write-Host "Validating RequireSecureBoot is Enforced - $($VMHOST)"
			$SecureBootRequired = $esxcli.system.settings.encryption.get.Invoke() | Select-Object RequireSecureBoot
			
			#Document Output to Array
			$TEMPARRAY = "" | Select-Object VMHost, HostEncryptionMode, RequireSecureBoot, Cluster
			$TEMPARRAY.VMHost = $VMHost
			$TEMPARRAY.HostEncryptionMode = $MODECHECK.Mode
			$TEMPARRAY.RequireSecureBoot = $SecureBootRequired.RequireSecureBoot
			$TEMPARRAY.Cluster = (Get-VMHost $VMHost | Select-Object Parent).Parent
			$OUTPUTARRAY += $TEMPARRAY
		}

		#Output Data
		Write-Output $OUTPUTARRAY

		##Disconnect from vCenter
		Write-Host "Disconnecting from VCSA - $($VCSA)"
		Disconnect-VIServer $VCSA -Confirm:$false -ErrorAction SilentlyContinue
	}
	#VCSA Cluster VMHost Audit
	If($VCSA -And $Cluster){
		##Connect to VMware Resource
		$COUNT = 0
		Do{
			Write-Host "Connecting to VCSA - $($VCSA)"
			$VISERVER = Connect-VIServer -server $VCSA -Credential $Credential -ErrorAction SilentlyContinue
			If(!$VISERVER.Name){
				Write-Host "Could NOT Connect to VCSA - $VCSA"
				$WaitSeconds = 60
				$Activity = "Waiting for $($WaitSeconds) Seconds"
				1..$WaitSeconds | ForEach-Object { $percent = $_ * 100 / $WaitSeconds 
					Write-Progress -Activity $Activity -Status "$($WaitSeconds - $_) Seconds remaining..." -PercentComplete $percent 
					Start-Sleep -Seconds 1
				}
				$COUNT ++
				Write-Host "Could Not Connect to VCSA - $($VCSA)" -Foregroundcolor Red
				Write-Host "Count - $COUNT"
			}
		}Until($VISERVER.Name -Or $COUNT -eq $ValidationTimeout)
		If($COUNT -eq $ValidationTimeout){
			Write-Error "Could not connect to VCSA - $($VCSA), Please check Network and DNS Resolution."
		}
		Write-Progress -Completed -Activity "make progress bar disappear" -ErrorAction SilentlyContinue

		#Get VMHost List for Cluster
		$VMHOSTLIST = (Get-Cluster $Cluster | Get-VMHost | Where-Object {$_.PowerState -eq "PoweredOn" -And $_.ConnectionState -eq "Connected"} | Sort-Object Name | Select-Object Name).Name

		$OUTPUTARRAY = @()
		ForEach($VMHost in $VMHOSTLIST){
			# Connect to ESXCLI
			$esxcli = $null
			$esxcli = Get-EsxCli -VMHost $VMHOST -V2

			# Validate System Encryption Mode is set to TPM
			Write-Host "Validating System Encryption Mode is set to TPM - $($VMHOST)"
			$MODECHECK = $esxcli.system.settings.encryption.get.Invoke() | Select-Object Mode

			# Validate SecureBoot is Required
			Write-Host "Validating RequireSecureBoot is Enforced - $($VMHOST)"
			$SecureBootRequired = $esxcli.system.settings.encryption.get.Invoke() | Select-Object RequireSecureBoot
			
			#Document Output to Array
			$TEMPARRAY = "" | Select-Object VMHost, HostEncryptionMode, RequireSecureBoot, Cluster
			$TEMPARRAY.VMHost = $VMHost
			$TEMPARRAY.HostEncryptionMode = $MODECHECK.Mode
			$TEMPARRAY.RequireSecureBoot = $SecureBootRequired.RequireSecureBoot
			$TEMPARRAY.Cluster = $Cluster
			$OUTPUTARRAY += $TEMPARRAY
		}

		#Output Data
		Write-Output $OUTPUTARRAY

		##Disconnect from vCenter
		Write-Host "Disconnecting from VCSA - $($VCSA)"
		Disconnect-VIServer $VCSA -Confirm:$false -ErrorAction SilentlyContinue
	}
	If($VCSA -And !$VMHost -And !$Cluster){
		##Connect to VMware Resource
		$COUNT = 0
		Do{
			Write-Host "Connecting to VCSA - $($VCSA)"
			$VISERVER = Connect-VIServer -server $VCSA -Credential $Credential -ErrorAction SilentlyContinue
			If(!$VISERVER.Name){
				Write-Host "Could NOT Connect to VCSA - $VCSA"
				$WaitSeconds = 60
				$Activity = "Waiting for $($WaitSeconds) Seconds"
				1..$WaitSeconds | ForEach-Object { $percent = $_ * 100 / $WaitSeconds 
					Write-Progress -Activity $Activity -Status "$($WaitSeconds - $_) Seconds remaining..." -PercentComplete $percent 
					Start-Sleep -Seconds 1
				}
				$COUNT ++
				Write-Host "Could Not Connect to VCSA - $($VCSA)" -Foregroundcolor Red
				Write-Host "Count - $COUNT"
			}
		}Until($VISERVER.Name -Or $COUNT -eq $ValidationTimeout)
		If($COUNT -eq $ValidationTimeout){
			Write-Error "Could not connect to VCSA - $($VCSA), Please check Network and DNS Resolution."
		}
		Write-Progress -Completed -Activity "make progress bar disappear" -ErrorAction SilentlyContinue

		#Get VMHost List for Cluster
		$VMHOSTLIST = (Get-VMHost | Where-Object {$_.PowerState -eq "PoweredOn" -And $_.ConnectionState -eq "Connected"} | Sort-Object Name | Select-Object Name).Name

		$OUTPUTARRAY = @()
		ForEach($VMHost in $VMHOSTLIST){
			# Connect to ESXCLI
			$esxcli = $null
			$esxcli = Get-EsxCli -VMHost $VMHOST -V2

			# Validate System Encryption Mode is set to TPM
			Write-Host "Validating System Encryption Mode is set to TPM - $($VMHOST)"
			$MODECHECK = $esxcli.system.settings.encryption.get.Invoke() | Select-Object Mode

			# Validate SecureBoot is Required
			Write-Host "Validating RequireSecureBoot is Enforced - $($VMHOST)"
			$SecureBootRequired = $esxcli.system.settings.encryption.get.Invoke() | Select-Object RequireSecureBoot
			
			#Document Output to Array
			$TEMPARRAY = "" | Select-Object VMHost, HostEncryptionMode, RequireSecureBoot, Cluster
			$TEMPARRAY.VMHost = $VMHost
			$TEMPARRAY.HostEncryptionMode = $MODECHECK.Mode
			$TEMPARRAY.RequireSecureBoot = $SecureBootRequired.RequireSecureBoot
			$TEMPARRAY.Cluster = (Get-VMHost $VMHost | Select-Object Parent).Parent
			$OUTPUTARRAY += $TEMPARRAY
		}

		#Output Data
		Write-Output $OUTPUTARRAY

		##Disconnect from vCenter
		Write-Host "Disconnecting from VCSA - $($VCSA)"
		Disconnect-VIServer $VCSA -Confirm:$false -ErrorAction SilentlyContinue
	}
}
