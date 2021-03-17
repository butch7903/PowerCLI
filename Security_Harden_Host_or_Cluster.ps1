#Import needed PowerShell Modules
Import-Module VMware.PowerCLI

##Specify Variables
$vCenter = Read-Host "Please Provide FQDN of your VCSA:"
$HOSTLIST = Read-Host "Please Enter VMHost FQDN Name:"
IF(!$CREDS)
{
	$CREDS = Get-Credential -Message "Provide vCenter Administrative User Account Login Password"
}

#$CLUSTERNAME = "Production"
$DOMAIN = $HOSTLIST.Substring($HOSTLIST.IndexOf(".") + 1)
$JOINDOMAIN = $true #Toggles whether a VMHost is joined to a domain or not. Best practices state to enable this.
$ENABLELOCKDOWN = $false #Configures VMHosts for LockDown Mode. Best practices state to enable this.
$SNMP = $false #Configures SNMP for VMHosts
$SNMPSTRING = "secret"
$NTPCLIENT = $false #If set to True, ESXi host becomes a NTP Server for clients on the network
$NTPCLIENTIPs = "" #This would be IPs that you want to allow a host to be able to connect with so that the client IPs can 
$NTPServers = "time-a-g.nist.gov", "time-b-wwv.nist.gov", "time-c-b.nist.gov", "utcnist.colorado.edu", "10.1.1.64", "10.2.1.64" #list of NTP Servers for VMHosts to use

##Disconnect any previous vCenter sessions
disconnect-viserver * -confirm:$false -ErrorAction SilentlyContinue
##Connect to vCenter
connect-viserver $VCENTER -credential $CREDS

Start-Sleep -s 10 

##Get Cluster Info
$CLUSTER = Get-VMHost -Location $CLUSTERNAME | Sort Name

##Get Hosts
$SWITCHLIST = Get-VDSwitch | Sort Name

IF($CLUSTERNAME)
{
	foreach ($VMHOST in $CLUSTER)
	{
		Write-Host "Starting Hardening for"$VMHOST.NAME  -ForegroundColor Green
		
		#Get VDS Info on Host
		Write-Host "Getting Switch Info from VMHost"
		$VMHOSTVDSLIST = Get-VMHost $VMHOST | Get-VDSwitch | Sort Name #Virtual Distributed Switch List
		$VMHOSTSWLIST = Get-VMHOST $VMHOST |  Get-VirtualSwitch | Sort Name #Standard Switch List
		
		#Set Shell Settings
		Write-Host "Setting Shell Settings"
		Get-VMHost $VMHOST | Get-AdvancedSetting -Name 'UserVars.SuppressShellWarning' | Set-AdvancedSetting -Value "1" -Confirm:$false
		Get-VMHost $VMHOST | Get-AdvancedSetting -Name 'UserVars.ESXiShellInteractiveTimeOut' | Set-AdvancedSetting -Value "600" -Confirm:$false
		Get-VMHost $VMHOST | Get-AdvancedSetting -Name 'UserVars.ESXiShellTimeOut' | Set-AdvancedSetting -Value "600" -Confirm:$false
		
		#Enable LDAP Authentication
		IF ($JOINDOMAIN -eq $true)
		{
			Write-Host "Setting LDAP Authentication"
			Get-VMHost $VMHOST | Get-VMHostAuthentication | Set-VMHostAuthentication -JoinDomain -Domain $DOMAIN -Credential $CREDS -Confirm:$false
		} ELSE{
			Get-VMHost $VMHOST | Get-VMHostAuthentication | Set-VMHostAuthentication -LeaveDomain -Force -Confirm:$false
		}
		
		#Set Standard Switch Security Settings
		IF ($VMHOSTSWLIST)
		{
			Write-Host "Setting Standard Switch Security Settings"
			foreach($SWITCH in $VMHOSTSWLIST)
			{
				#Check Security Policy Settings
				$SWPOLICY = $null
				Write-Host "Getting Virtual Switch Configuration on"$VMHOST
				$SWPOLICY = Get-VMHost $VMHOST | Get-VirtualSwitch -Name $SWITCH | Get-SecurityPolicy
				Write-Host "Listing Existing Policy Results"
				$SWPOLICY
				IF($SWPOLICY.AllowPromiscuous -eq $true)
				{
					Write-Host "Updating Virtual Switch"$SWITCH.NAME"Configuration to set the Security Policy to Not Allow Promiscuous Mode"
					Get-VMHost $VMHOST | Get-VirtualSwitch -Name $SWITCH | Get-SecurityPolicy | Set-SecurityPolicy -AllowPromiscuous $false #Specify on which vSwitch (Standard) this script will make changes
				} ELSE{
					Write-Host "Virtual Switch"$SWITCH.NAME" Configuration is already correctly set to the Security Policy to Not Allow Promiscuous Mode" -foregroundcolor Blue
				}
				IF ($SWPOLICY.ForgedTransmits -eq $true)
				{
					Write-Host "Updating Virtual Switch"$SWITCH.NAME"Configuration to set the Security Policy to Not Allow Forged Transmits"
					Get-VMHost $VMHOST | Get-VirtualSwitch -Name $SWITCH | Get-SecurityPolicy | Set-SecurityPolicy -ForgedTransmits $false #Specify on which vSwitch (Standard) this script will make changes
				} ELSE{
					Write-Host "Virtual Switch"$SWITCH.NAME" Configuration is already correctly set to the Security Policy to Not Allow Forged Transmits" -foregroundcolor Blue
				}
				IF ($SWPOLICY.MacChanges -eq $true)
				{
					Write-Host "Updating Virtual Switch"$SWITCH.NAME"Configuration to set the Security Policy to Not Allow MAC Changes"
					Get-VMHost $VMHOST | Get-VirtualSwitch -Name $SWITCH | Get-SecurityPolicy | Set-SecurityPolicy -MacChanges $false #Specify on which vSwitch (Standard) this script will make changes
				} ELSE{
					Write-Host "Virtual Switch"$SWITCH.NAME" Configuration is already correctly set to the Security Policy to Not Allow MAC Changes" -foregroundcolor Blue
				}
				#List Results
				Write-Host "Listing Switch Policy Results for"$SWITCH.NAME
				Get-VMHost $VMHOST | Get-VirtualSwitch -Name $SWITCH | Get-SecurityPolicy
			}
		}
		
		#Set Virtual Distributed Switch Security Settings
		IF ($VMHOSTVDSLIST)
		{
			Write-Host "Setting Virtual Distributed Switch Security Settings"
			foreach($VDS in $VMHOSTVDSLIST)
			{
				#Check Security Policy Settings
				$VDSPOLICY = $null
				Write-Host "Getting Virtual Switch Configuration on"$VMHOST
				$VDSPOLICY = Get-VMHost $VMHOST | Get-VDSwitch $VDS | Get-VDSecurityPolicy
				Write-Host "Listing Existing Policy Results"
				$VDSPOLICY
				IF($VDSPOLICY.AllowPromiscuous -eq $true)
				{
					Write-Host "Updating Virtual Switch"$VDS.NAME"Configuration to set to the Security Policy to Not Allow Promiscuous Mode"
					Get-VMHost $VMHOST | Get-VDSwitch -Name $VDS | Get-VDSecurityPolicy | Set-VDSecurityPolicy -AllowPromiscuous $false #Specify on which VDSwitch this script will make changes
				} ELSE{
					Write-Host "Virtual Switch"$VDS.NAME" Configuration is already correctly set to the Security Policy to Not Allow Promiscuous Mode" -foregroundcolor Blue
				}
				IF($VDSPOLICY.ForgedTransmits -eq $true)
				{
					Write-Host "Updating Virtual Switch"$VDS.NAME"Configuration to set to the Security Policy to Not Allow Forged Transmits"
					Get-VMHost $VMHOST | Get-VDSwitch -Name $VDS | Get-VDSecurityPolicy | Set-VDSecurityPolicy -ForgedTransmits $false #Specify on which VDSwitch this script will make changes
				} ELSE{
					Write-Host "Virtual Switch"$VDS.NAME" Configuration is already correctly set to the Security Policy to Not Allow Forged Transmits" -foregroundcolor Blue
				}
				IF($VDSPOLICY.MacChanges -eq $true)
				{
					Write-Host "Updating Virtual Switch"$VDS.NAME"Configuration to set to the Security Policy to Not Allow MAC Changes"
					Get-VMHost $VMHOST | Get-VDSwitch -Name $VDS | Get-VDSecurityPolicy | Set-VDSecurityPolicy -MacChanges $false #Specify on which VDSwitch this script will make changes
				} ELSE{
					Write-Host "Virtual Switch"$VDS.NAME" Configuration is already correctly set to the Security Policy to Not Allow MAC Changes" -foregroundcolor Blue
				}
				#List Results
				Write-Host "Listing Switch Policy Results for"$VDS.NAME
				Get-VMHost $VMHOST | Get-VDSwitch $VDS | Get-VDSecurityPolicy
			}
		}
		
		#Set NTP Daemon Policy to Enabled
		Write-Host "Setting NTPd Policy to On"
		Get-VMHost $VMHOST | Get-VMHostService | where {$_.Key -eq "ntpd"} | Set-VMHostService -Policy On
		
		#Set BDPU Filter
		#Reference: https://kb.vmware.com/s/article/2047822
		Write-Host "Setting the BPDU filter to Enabled"
		Get-VMHOST $VMHOST | Get-AdvancedSetting -Name 'Net.BlockGuestBPDU' | Set-AdvancedSetting -Value "1" -Confirm:$false
		
		#Set DCUI Settings
		Write-Host "Setting DCUI Service Policy to Off"
		Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "DCUI"} | Set-VMHostService -policy "off" -Confirm:$false 
		Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "DCUI"} | Stop-VMHostService -Confirm:$false          #Replace with Start-VMHostService to start service via script
		
		#Set TSM/ESXi Shell Settings
		Write-Host "Setting TSM(ESXi Shell) Service Policy to Off"
		Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "TSM"} | Set-VMHostService -policy "off" -Confirm:$false
		Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "TSM"} | Stop-VMHostService -Confirm:$false          #Replace with Start-VMHostService to start service via script
		
		#Set TSM SSH Settings
		Write-Host "Setting TSM-SSH Service Policy to Off"
		Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "TSM-SSH"} | Set-VMHostService -policy "off" -Confirm:$false 
		Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "TSM-SSH"} | Stop-VMHostService -Confirm:$false #Replace with Start-VMHostService to start service via script
		
		#Set SNMP Settings
		IF ($SNMP -eq $false)
		{
			Write-Host "Setting SNMP to Disabled"
			Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "snmpd"} | Set-VMHostService -policy "off" -Confirm:$false
			Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "snmpd"} | Stop-VMHostService -Confirm:$false #Replace with Start-VMHostService to start service via script
		}
		IF ($SNMP -eq $true)
		{
			Write-Host "Setting SNMP to Enabled"
			Set-VMHostSNMP $VMHOST -Enabled:$true -ReadOnlyCommunity $SNMPSTRING
			Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "snmpd"} | Set-VMHostService -policy "on" -Confirm:$false
			Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "snmpd"} | Start-VMHostService -Confirm:$false #Replace with Start-VMHostService to start service via script
		}
		
		#Remove any NTP Time Servers that were previously set
		$NTPSERVERLIST = Get-VMHost $VMHOST |  Get-VMHostNtpServer
		foreach($NTPSRVR in $NTPSERVERLIST) 
		{
			Get-VMHost $VMHOST | Remove-VMHostNtpServer $NTPSRVR -confirm:$false
		}
		
		#Add NTP Time Servers from list
		Get-VMHost $VMHOST | Add-VmHostNtpServer $NTPServers -Confirm:$false
		Get-VmHostService -VMHost $VMHOST | Where-Object {$_.key -eq "ntpd"} | Stop-VMHostService -Confirm:$false
		Get-VmHostService -VMHost $VMHOST | Where-Object {$_.key -eq "ntpd"} | Start-VMHostService -Confirm:$false
		Get-VMHost $VMHOST | Get-VmHostNtpServer
		
		#Set NTP Client Settings
		IF ($NTPCLIENT -eq $false)
		{
			Write-Host "Setting NTP Client to only 127.0.0.1"
			#reference https://www.altaro.com/vmware/managing-esxi-firewall/
			$esxcli = (Get-EsxCli -VMHost $VMHOST -V2).network.firewall
			#List Prior to changes
			Write-Host "Checking NTP Client Allowed IP Settings"
			$esxcli.ruleset.list.invoke() | where {$_.Name -eq "ntpClient"}
			$esxcli.ruleset.allowedip.list.invoke() | where {$_.Ruleset -eq "ntpClient"}
			#Setting Changes to NTP Client
			#Note This prevents other servers from getting NTP time from a VMHost
			Write-Host "Disabling NTP Client to allow All IPs"
			$esxcli.ruleset.set.invoke(@{enabled="true"; allowedall="false"; rulesetid="ntpClient"})
			Write-Host "Adding NTP Client IP 127.0.0.1"
			$esxcli.ruleset.allowedip.add.Invoke(@{rulesetid="ntpClient"; ipaddress="127.0.0.1"})
			#Write-Host "Removing NTP Client IP 127.0.0.1"
			#$esxcli.ruleset.allowedip.remove.Invoke(@{rulesetid="ntpClient"; ipaddress="127.0.0.1"})
			#Verifying IP Changes
			Write-Host "Verifiying NTP Client IP Settings"
			$esxcli.ruleset.allowedip.list.invoke() | where {$_.Ruleset -eq "ntpClient"}
			
			#$esxcli.ruleset.set($false, $true, "ntpd")
			
			#Setting Policies for NTP
			Write-Host "Setting NTP Policy Settings"
			Get-VMHost $VMHOST | Get-VMHostFirewallException | where {$_.Name -eq "NTP client"} | Set-VMHostFirewallException -Enabled $true -Confirm:$false
			Get-VmHostService -VMHost $VMHOST | Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -policy "on" -Confirm:$false
			Get-VmHostService -VMHost $VMHOST | Where-Object {$_.key -eq "ntpd"} | Stop-VMHostService -Confirm:$false
			Get-VmHostService -VMHost $VMHOST | Where-Object {$_.key -eq "ntpd"} | Start-VMHostService -Confirm:$false
			Get-VMHost $VMHOST | Get-VMHostFirewallException | where {$_.Name -eq "NTP client"} #Verify
		}
		IF ($NTPCLIENT -eq $true)
		{
			foreach ($IP in $NTPCLIENTIPs)
			{
				Write-Host "Setting NTP Client to only 127.0.0.1"
				#reference https://www.altaro.com/vmware/managing-esxi-firewall/
				$esxcli = (Get-EsxCli -VMHost $VMHOST -V2).network.firewall
				#List Prior to changes
				Write-Host "Checking NTP Client Allowed IP Settings"
				$esxcli.ruleset.list.invoke() | where {$_.Name -eq "ntpClient"}
				$esxcli.ruleset.allowedip.list.invoke() | where {$_.Ruleset -eq "ntpClient"}
				#Setting Changes to NTP Client
				#Note This prevents other servers from getting NTP time from a VMHost
				Write-Host "Disabling NTP Client to allow All IPs"
				$esxcli.ruleset.set.invoke(@{enabled="true"; allowedall="false"; rulesetid="ntpClient"})
				Write-Host "Adding NTP Client IP 127.0.0.1"
				$esxcli.ruleset.allowedip.add.Invoke(@{rulesetid="ntpClient"; ipaddress=$IP})
				#Verifying IP Changes
				Write-Host "Verifiying NTP Client IP Settings"
				$esxcli.ruleset.allowedip.list.invoke() | where {$_.Ruleset -eq "ntpClient"}
				
				#$esxcli.ruleset.set($false, $true, "ntpd")
				
			}
			
			#Setting Policies for NTP
			Write-Host "Setting NTP Policy Settings"
			Get-VMHost $VMHOST | Get-VMHostFirewallException | where {$_.Name -eq "NTP client"} | Set-VMHostFirewallException -Enabled $true -Confirm:$false
			Get-VmHostService -VMHost $VMHOST | Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -policy "on" -Confirm:$false
			Get-VmHostService -VMHost $VMHOST | Where-Object {$_.key -eq "ntpd"} | Stop-VMHostService -Confirm:$false
			Get-VmHostService -VMHost $VMHOST | Where-Object {$_.key -eq "ntpd"} | Start-VMHostService -Confirm:$false
			Get-VMHost $VMHOST | Get-VMHostFirewallException | where {$_.Name -eq "NTP client"} #Verify
		}
		
		
		#Set Lock Down Mode
		IF($ENABLELOCKDOWN -eq $true)
		{
			Write-Host "Setting Host Lock Down Mode to Enabled"
			(Get-VMHost $VMHOST | Get-View).EnterLockdownMode() #Replace with .ExitLockdownMode() if you wish this script to disable lockdown mode
		}

		Write-Host "Completed Hardening for"$VMHOST.name -ForegroundColor Green
	}
}

IF($HOSTLIST)
{
	foreach ($VMHOST in $HOSTLIST)
	{
		Write-Host "Starting Hardening for"$VMHOST  -ForegroundColor Green
		
		#Get VDS Info on Host
		Write-Host "Getting Switch Info from VMHost"
		$VMHOSTVDSLIST = Get-VMHost $VMHOST | Get-VDSwitch | Sort Name #Virtual Distributed Switch List
		$VMHOSTSWLIST = Get-VMHOST $VMHOST |  Get-VirtualSwitch | Sort Name #Standard Switch List
		
		#Set Shell Settings
		Write-Host "Setting Shell Settings"
		Get-VMHost $VMHOST | Get-AdvancedSetting -Name 'UserVars.SuppressShellWarning' | Set-AdvancedSetting -Value "1" -Confirm:$false
		Get-VMHost $VMHOST | Get-AdvancedSetting -Name 'UserVars.ESXiShellInteractiveTimeOut' | Set-AdvancedSetting -Value "600" -Confirm:$false
		Get-VMHost $VMHOST | Get-AdvancedSetting -Name 'UserVars.ESXiShellTimeOut' | Set-AdvancedSetting -Value "600" -Confirm:$false
		
		#Enable LDAP Authentication
		IF ($JOINDOMAIN -eq $true)
		{
			Write-Host "Setting LDAP Authentication"
			Get-VMHost $VMHOST | Get-VMHostAuthentication | Set-VMHostAuthentication -JoinDomain -Domain $DOMAIN -Credential $CREDS -Confirm:$false
		} ELSE{
			Get-VMHost $VMHOST | Get-VMHostAuthentication | Set-VMHostAuthentication -LeaveDomain -Force -Confirm:$false
		}
		
		#Set Standard Switch Security Settings
		IF ($VMHOSTSWLIST)
		{
			Write-Host "Setting Standard Switch Security Settings"
			foreach($SWITCH in $VMHOSTSWLIST)
			{
				#Check Security Policy Settings
				$SWPOLICY = $null
				Write-Host "Getting Virtual Switch Configuration on"$VMHOST
				$SWPOLICY = Get-VMHost $VMHOST | Get-VirtualSwitch -Name $SWITCH | Get-SecurityPolicy
				Write-Host "Listing Existing Policy Results"
				$SWPOLICY
				IF($SWPOLICY.AllowPromiscuous -eq $true)
				{
					Write-Host "Updating Virtual Switch"$SWITCH.NAME"Configuration to set the Security Policy to Not Allow Promiscuous Mode"
					Get-VMHost $VMHOST | Get-VirtualSwitch -Name $SWITCH | Get-SecurityPolicy | Set-SecurityPolicy -AllowPromiscuous $false #Specify on which vSwitch (Standard) this script will make changes
				} ELSE{
					Write-Host "Virtual Switch"$SWITCH.NAME" Configuration is already correctly set to the Security Policy to Not Allow Promiscuous Mode" -foregroundcolor Blue
				}
				IF ($SWPOLICY.ForgedTransmits -eq $true)
				{
					Write-Host "Updating Virtual Switch"$SWITCH.NAME"Configuration to set the Security Policy to Not Allow Forged Transmits"
					Get-VMHost $VMHOST | Get-VirtualSwitch -Name $SWITCH | Get-SecurityPolicy | Set-SecurityPolicy -ForgedTransmits $false #Specify on which vSwitch (Standard) this script will make changes
				} ELSE{
					Write-Host "Virtual Switch"$SWITCH.NAME" Configuration is already correctly set to the Security Policy to Not Allow Forged Transmits" -foregroundcolor Blue
				}
				IF ($SWPOLICY.MacChanges -eq $true)
				{
					Write-Host "Updating Virtual Switch"$SWITCH.NAME"Configuration to set the Security Policy to Not Allow MAC Changes"
					Get-VMHost $VMHOST | Get-VirtualSwitch -Name $SWITCH | Get-SecurityPolicy | Set-SecurityPolicy -MacChanges $false #Specify on which vSwitch (Standard) this script will make changes
				} ELSE{
					Write-Host "Virtual Switch"$SWITCH.NAME" Configuration is already correctly set to the Security Policy to Not Allow MAC Changes" -foregroundcolor Blue
				}
				#List Results
				Write-Host "Listing Switch Policy Results for"$SWITCH.NAME
				Get-VMHost $VMHOST | Get-VirtualSwitch -Name $SWITCH | Get-SecurityPolicy
			}
		}
		
		#Set Virtual Distributed Switch Security Settings
		IF ($VMHOSTVDSLIST)
		{
			Write-Host "Setting Virtual Distributed Switch Security Settings"
			foreach($VDS in $VMHOSTVDSLIST)
			{
				#Check Security Policy Settings
				$VDSPOLICY = $null
				Write-Host "Getting Virtual Switch Configuration on"$VMHOST
				$VDSPOLICY = Get-VMHost $VMHOST | Get-VDSwitch $VDS | Get-VDSecurityPolicy
				Write-Host "Listing Existing Policy Results"
				$VDSPOLICY
				IF($VDSPOLICY.AllowPromiscuous -eq $true)
				{
					Write-Host "Updating Virtual Switch"$VDS.NAME"Configuration to set to the Security Policy to Not Allow Promiscuous Mode"
					Get-VMHost $VMHOST | Get-VDSwitch -Name $VDS | Get-VDSecurityPolicy | Set-VDSecurityPolicy -AllowPromiscuous $false #Specify on which VDSwitch this script will make changes
				} ELSE{
					Write-Host "Virtual Switch"$VDS.NAME" Configuration is already correctly set to the Security Policy to Not Allow Promiscuous Mode" -foregroundcolor Blue
				}
				IF($VDSPOLICY.ForgedTransmits -eq $true)
				{
					Write-Host "Updating Virtual Switch"$VDS.NAME"Configuration to set to the Security Policy to Not Allow Forged Transmits"
					Get-VMHost $VMHOST | Get-VDSwitch -Name $VDS | Get-VDSecurityPolicy | Set-VDSecurityPolicy -ForgedTransmits $false #Specify on which VDSwitch this script will make changes
				} ELSE{
					Write-Host "Virtual Switch"$VDS.NAME" Configuration is already correctly set to the Security Policy to Not Allow Forged Transmits" -foregroundcolor Blue
				}
				IF($VDSPOLICY.MacChanges -eq $true)
				{
					Write-Host "Updating Virtual Switch"$VDS.NAME"Configuration to set to the Security Policy to Not Allow MAC Changes"
					Get-VMHost $VMHOST | Get-VDSwitch -Name $VDS | Get-VDSecurityPolicy | Set-VDSecurityPolicy -MacChanges $false #Specify on which VDSwitch this script will make changes
				} ELSE{
					Write-Host "Virtual Switch"$VDS.NAME" Configuration is already correctly set to the Security Policy to Not Allow MAC Changes" -foregroundcolor Blue
				}
				#List Results
				Write-Host "Listing Switch Policy Results for"$VDS.NAME
				Get-VMHost $VMHOST | Get-VDSwitch $VDS | Get-VDSecurityPolicy
			}
		}
		
		#Set NTP Daemon Policy to Enabled
		Write-Host "Setting NTPd Policy to On"
		Get-VMHost $VMHOST | Get-VMHostService | where {$_.Key -eq "ntpd"} | Set-VMHostService -Policy On
		
		#Set BDPU Filter
		#Reference: https://kb.vmware.com/s/article/2047822
		Write-Host "Setting the BPDU filter to Enabled"
		Get-VMHOST $VMHOST | Get-AdvancedSetting -Name 'Net.BlockGuestBPDU' | Set-AdvancedSetting -Value "1" -Confirm:$false
		
		#Set DCUI Settings
		Write-Host "Setting DCUI Service Policy to Off"
		Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "DCUI"} | Set-VMHostService -policy "off" -Confirm:$false 
		Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "DCUI"} | Stop-VMHostService -Confirm:$false          #Replace with Start-VMHostService to start service via script
		
		#Set TSM/ESXi Shell Settings
		Write-Host "Setting TSM(ESXi Shell) Service Policy to Off"
		Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "TSM"} | Set-VMHostService -policy "off" -Confirm:$false
		Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "TSM"} | Stop-VMHostService -Confirm:$false          #Replace with Start-VMHostService to start service via script
		
		#Set TSM SSH Settings
		Write-Host "Setting TSM-SSH Service Policy to Off"
		Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "TSM-SSH"} | Set-VMHostService -policy "off" -Confirm:$false 
		Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "TSM-SSH"} | Stop-VMHostService -Confirm:$false #Replace with Start-VMHostService to start service via script
		
		#Set SNMP Settings
		IF ($SNMP -eq $false)
		{
			Write-Host "Setting SNMP to Disabled"
			Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "snmpd"} | Set-VMHostService -policy "off" -Confirm:$false
			Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "snmpd"} | Stop-VMHostService -Confirm:$false #Replace with Start-VMHostService to start service via script
		}
		IF ($SNMP -eq $true)
		{
			Write-Host "Setting SNMP to Enabled"
			Set-VMHostSNMP $VMHOST -Enabled:$true -ReadOnlyCommunity $SNMPSTRING
			Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "snmpd"} | Set-VMHostService -policy "on" -Confirm:$false
			Get-VMHostService -VMHost $VMHOST | Where-Object {$_.Key -eq "snmpd"} | Start-VMHostService -Confirm:$false #Replace with Start-VMHostService to start service via script
		}
		
		#Remove any NTP Time Servers that were previously set
		$NTPSERVERLIST = Get-VMHost $VMHOST |  Get-VMHostNtpServer
		foreach($NTPSRVR in $NTPSERVERLIST) 
		{
			Get-VMHost $VMHOST | Remove-VMHostNtpServer $NTPSRVR -confirm:$false
		}
		
		#Add NTP Time Servers from list
		Get-VMHost $VMHOST | Add-VmHostNtpServer $NTPServers -Confirm:$false
		Get-VmHostService -VMHost $VMHOST | Where-Object {$_.key -eq "ntpd"} | Stop-VMHostService -Confirm:$false
		Get-VmHostService -VMHost $VMHOST | Where-Object {$_.key -eq "ntpd"} | Start-VMHostService -Confirm:$false
		Get-VMHost $VMHOST | Get-VmHostNtpServer
		
		#Set NTP Client Settings
		IF ($NTPCLIENT -eq $false)
		{
			Write-Host "Setting NTP Client to only 127.0.0.1"
			#reference https://www.altaro.com/vmware/managing-esxi-firewall/
			$esxcli = (Get-EsxCli -VMHost $VMHOST -V2).network.firewall
			#List Prior to changes
			Write-Host "Checking NTP Client Allowed IP Settings"
			$esxcli.ruleset.list.invoke() | where {$_.Name -eq "ntpClient"}
			$esxcli.ruleset.allowedip.list.invoke() | where {$_.Ruleset -eq "ntpClient"}
			#Setting Changes to NTP Client
			#Note This prevents other servers from getting NTP time from a VMHost
			Write-Host "Disabling NTP Client to allow All IPs"
			$esxcli.ruleset.set.invoke(@{enabled="true"; allowedall="false"; rulesetid="ntpClient"})
			Write-Host "Adding NTP Client IP 127.0.0.1"
			$esxcli.ruleset.allowedip.add.Invoke(@{rulesetid="ntpClient"; ipaddress="127.0.0.1"})
			#Write-Host "Removing NTP Client IP 127.0.0.1"
			#$esxcli.ruleset.allowedip.remove.Invoke(@{rulesetid="ntpClient"; ipaddress="127.0.0.1"})
			#Verifying IP Changes
			Write-Host "Verifiying NTP Client IP Settings"
			$esxcli.ruleset.allowedip.list.invoke() | where {$_.Ruleset -eq "ntpClient"}
			
			#$esxcli.ruleset.set($false, $true, "ntpd")
			
			#Setting Policies for NTP
			Write-Host "Setting NTP Policy Settings"
			Get-VMHost $VMHOST | Get-VMHostFirewallException | where {$_.Name -eq "NTP client"} | Set-VMHostFirewallException -Enabled $true -Confirm:$false
			Get-VmHostService -VMHost $VMHOST | Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -policy "on" -Confirm:$false
			Get-VmHostService -VMHost $VMHOST | Where-Object {$_.key -eq "ntpd"} | Stop-VMHostService -Confirm:$false
			Get-VmHostService -VMHost $VMHOST | Where-Object {$_.key -eq "ntpd"} | Start-VMHostService -Confirm:$false
			Get-VMHost $VMHOST | Get-VMHostFirewallException | where {$_.Name -eq "NTP client"} #Verify
		}
		IF ($NTPCLIENT -eq $true)
		{
			foreach ($IP in $NTPCLIENTIPs)
			{
				Write-Host "Setting NTP Client to only 127.0.0.1"
				#reference https://www.altaro.com/vmware/managing-esxi-firewall/
				$esxcli = (Get-EsxCli -VMHost $VMHOST -V2).network.firewall
				#List Prior to changes
				Write-Host "Checking NTP Client Allowed IP Settings"
				$esxcli.ruleset.list.invoke() | where {$_.Name -eq "ntpClient"}
				$esxcli.ruleset.allowedip.list.invoke() | where {$_.Ruleset -eq "ntpClient"}
				#Setting Changes to NTP Client
				#Note This prevents other servers from getting NTP time from a VMHost
				Write-Host "Disabling NTP Client to allow All IPs"
				$esxcli.ruleset.set.invoke(@{enabled="true"; allowedall="false"; rulesetid="ntpClient"})
				Write-Host "Adding NTP Client IP 127.0.0.1"
				$esxcli.ruleset.allowedip.add.Invoke(@{rulesetid="ntpClient"; ipaddress=$IP})
				#Verifying IP Changes
				Write-Host "Verifiying NTP Client IP Settings"
				$esxcli.ruleset.allowedip.list.invoke() | where {$_.Ruleset -eq "ntpClient"}
				
				#$esxcli.ruleset.set($false, $true, "ntpd")
				
			}
			
			#Setting Policies for NTP
			Write-Host "Setting NTP Policy Settings"
			Get-VMHost $VMHOST | Get-VMHostFirewallException | where {$_.Name -eq "NTP client"} | Set-VMHostFirewallException -Enabled $true -Confirm:$false
			Get-VmHostService -VMHost $VMHOST | Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -policy "on" -Confirm:$false
			Get-VmHostService -VMHost $VMHOST | Where-Object {$_.key -eq "ntpd"} | Stop-VMHostService -Confirm:$false
			Get-VmHostService -VMHost $VMHOST | Where-Object {$_.key -eq "ntpd"} | Start-VMHostService -Confirm:$false
			Get-VMHost $VMHOST | Get-VMHostFirewallException | where {$_.Name -eq "NTP client"} #Verify
		}
		
		
		#Set Lock Down Mode
		IF($ENABLELOCKDOWN -eq $true)
		{
			Write-Host "Setting Host Lock Down Mode to Enabled"
			(Get-VMHost $VMHOST | Get-View).EnterLockdownMode() #Replace with .ExitLockdownMode() if you wish this script to disable lockdown mode
		}

		Write-Host "Completed Hardening for"$VMHOST -ForegroundColor Green
	}
}
