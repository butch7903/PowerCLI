<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			June 22, 2020
	Version:		1.3
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script will generate a Host Profile from a Host, modify it to disconnect 
		physical storage and PCI configuration, set specific site settings for SysLog,
		NTP, DNS, enforce setting Services to specific settings, and add SATP Claimrules.

	.DESCRIPTION
		Use this script to create a Host profile for a CLUSTER of VMHosts. The only
		change this script makes to a host itself is to apply specific Power Policy
		configuration prior to configuring the Host Profile for optimal config. After
		the script completes it will apply the Host Profile to the cluster.
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

##Adding Function needed for manipulating Host Profiles
#Reference: https://code.vmware.com/forums/2530/vsphere-powercli#577076
function Copy-Property ($From, $To, $PropertyName ="*")
{
  foreach ($p in Get-Member -In $From -MemberType Property -Name $propertyName)
  {        trap {
      Add-Member -In $To -MemberType NoteProperty -Name $p.Name -Value $From.$($p.Name) -Force
      continue
    }
    $To.$($P.Name) = $From.$($P.Name)
  }
}

##Set PowerShell Window Settings
$pshost = get-host
$pswindow = $pshost.ui.rawui
$newsize = $pswindow.buffersize
$newsize.height = 30000
$newsize.width = 130
$pswindow.buffersize = $newsize
$newsize = $pswindow.windowsize
$newsize.height = (get-host).UI.RawUI.MaxWindowSize.Height
$newsize.width = 130
$pswindow.windowtitle = "vVMHostProfileBuilder"
$pswindow.windowsize = $newsize

##Maximize Current PowerShell Window
function Show-Process($Process, [Switch]$Maximize)
{
<#
	.NOTES
	Reference http://community.idera.com/powershell/powertips/b/tips/posts/bringing-window-in-the-foreground
#>
  $sig = '
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern int SetForegroundWindow(IntPtr hwnd);
  '
  
  if ($Maximize) { $Mode = 3 } else { $Mode = 4 }
  $type = Add-Type -MemberDefinition $sig -Name WindowAPI -PassThru
  $hwnd = $process.MainWindowHandle
  $null = $type::ShowWindowAsync($hwnd, $Mode)
  $null = $type::SetForegroundWindow($hwnd) 
}
Show-Process -Process (Get-Process -id $pid) -Maximize

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()

##Get Current Path
$pwd = pwd

##Setting CSV File Location 
$CSVFILELOCATION = $pwd.path

##Import Site File or Create 1
$SITECSVFILENAME = "SITEList.csv"
$SITECSVFILEGET = Get-Item "$CSVFILELOCATION\$SITECSVFILENAME" -ErrorAction SilentlyContinue
$SITECSVFILE = "$CSVFILELOCATION\$SITECSVFILENAME"
$SITENAMELIST = @()
If(!$SITECSVFILEGET)
{
	CLS
	Write-Host "Site List CSV File not found"
	$SITENAME = @()
	$CREATENEWRECORD = "" | Select Site
	$CREATENEWRECORD.Site = "Create New Record" 
	$SITENAME += $CREATENEWRECORD
	$SITETEMPLIST = "" | Select Site
	$SITETEMPLIST.Site = Read-Host "Please provide a Site Name
	Note: Do nost use the letters NA for this"
	$SITENAME += $SITETEMPLIST
	$SITENAMELIST = $SITENAME
	$SITENAME | Export-CSV -NoTypeInformation -PATH $SITECSVFILE
	$SITE = $SITETEMPLIST.Site
	Write-Host "Site Selected is $SITE"
}
If($SITECSVFILEGET)
{
	CLS
	Write-Host "Site List CSV File found. Importing file..."
	$IMPORTSITELIST = Import-CSV -PATH $SITECSVFILE
	$countCL = 0  
	foreach($oC in $IMPORTSITELIST)
	{   
		$NAME = $oC.Site
		Write-Output "[$countCL] $NAME" 
		$countCL = $countCL+1  
	}
	Write-Host " "  
	$choice = $null
	$choice = Read-Host "At Which Site do you wish to Work with Host Profiles"
	$CHOICEPICKED = ($IMPORTSITELIST[$choice]).Site
	If($CHOICEPICKED -eq "Create New Record")
	{
		$SITENAME = $IMPORTSITELIST
		Write-Host "Creating New Record Selected..."
		$SITETEMPLIST = "" | Select Site
		$SITETEMPLIST.Site = Read-Host "Please provide a Site Name"
		$SITENAME += $SITETEMPLIST
		$SITENAME | Export-CSV -NoTypeInformation -PATH $SITECSVFILE -Confirm:$false
		$SITENAMELIST = $SITENAME
		$SITE = $SITETEMPLIST.Site
		Write-Host "Site Selected is $SITE"
	}Else{
		$SITE = $CHOICEPICKED
		Write-Host "Site Selected is $SITE"
		$SITENAMELIST = $IMPORTSITELIST
	}
}

##Select VCSA
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
##Import VCSA File or Create 1
$VCSACSVFILENAME = "VCSAlist.csv"
$VCSACSVFILEGET = Get-Item "$CSVFILELOCATION\$VCSACSVFILENAME" -ErrorAction SilentlyContinue
$VCSACSVFILE = "$CSVFILELOCATION\$VCSACSVFILENAME"
If(!$VCSACSVFILEGET)
{
	CLS
	Write-Host "VCSA List CSV File not found"
	$VCSANAME = @()
	$CREATENEWRECORD = "" | Select VCSA, Site
	$CREATENEWRECORD.VCSA = "Create New Record" 
	$CREATENEWRECORD.Site = "NA" 
	$VCSANAME += $CREATENEWRECORD
	$VCSATEMPLIST = "" | Select VCSA, Site
	$VCSATEMPLIST.VCSA = Read-Host "Please provide a VCSA FQDN"
	$VCSATEMPLIST.Site = $SITE
	Write-Host "Site Selected is"($VCSATEMPLIST.Site)
	$VCSANAME += $VCSATEMPLIST
	$VCSANAME | Export-CSV -NoTypeInformation -PATH $VCSACSVFILE
	$VCSA = $VCSATEMPLIST.VCSA
	Write-Host "VCSA Selected is $VCSA"
}
If($VCSACSVFILEGET)
{
	CLS
	Write-Host "VCSA List CSV File found. Importing file..."
	$VCSALIST = Import-CSV -PATH $VCSACSVFILE
	$VCSASITELIST = $VCSALIST | Where {$_.Site -eq $SITE -or $_.Site -eq "NA"}
	$countCL = 0  
	foreach($oC in $VCSASITELIST)
	{   
		$NAME = $oC.VCSA
		Write-Output "[$countCL] $NAME" 
		$countCL = $countCL+1  
	}
	Write-Host " "  
	$choice = $null
	$choice = Read-Host "On which VCSA do you wish to work with Host Profiles for site $SITE"
	$CHOICEPICKED = ($VCSASITELIST[$choice]).VCSA
	If($CHOICEPICKED -eq "Create New Record")
	{
		$VCSANAME = $VCSALIST
		Write-Host "Creating New Record Selected..."
		$VCSATEMPLIST = "" | Select VCSA, Site
		$VCSATEMPLIST.VCSA = Read-Host "Please provide a VCSA FQDN"
		$VCSATEMPLIST.Site = $SITE 
		Write-Host "Site Selected is:"
		Write-Host $VCSATEMPLIST.Site
		$VCSANAME += $VCSATEMPLIST
		$VCSANAME | Export-CSV -NoTypeInformation -PATH $VCSACSVFILE -Confirm:$false
		$VCSA = $VCSATEMPLIST.VCSA
		Write-Host "VCSA Selected is $VCSA"
	}Else{
		$VCSA = $CHOICEPICKED
		Write-Host "VCSA Selected is $VCSA"
	}
}
Write-Host "VCSA Selected is $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select DNS
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
##Import DNS File or Create 1
$DNSCSVFILENAME = "DNSlist.csv"
$DNSCSVFILEGET = Get-Item "$CSVFILELOCATION\$DNSCSVFILENAME" -ErrorAction SilentlyContinue
$DNSCSVFILE = "$CSVFILELOCATION\$DNSCSVFILENAME"
If(!$DNSCSVFILEGET)
{
	CLS
	Write-Host "DNS List CSV File not found"
	$DNSNAME = @()
	$DNSTEMPLIST = "" | Select DNSServerList, Domain, SearchDomains, Site
	$DNSTEMPLIST.DNSServerList = Read-Host "Please provide a list of DNS servers for site $SITE in comma seperated format
	Example 8.8.8.8,8.4.4.4"
	$DNSTEMPLIST.Domain = Read-Host "Please provide the name of the Domain for these Hosts
	Example contso.com"
	$DNSTEMPLIST.SearchDomains = Read-Host "Please provide a list of Search Domains for site $SITE in comma seperated format
	Example contso.com,dmz.contso.com"
	$DNSTEMPLIST.Site = $SITE
	Write-Host "DNS Site Selected is"($DNSTEMPLIST.Site)
	$DNSNAME += $DNSTEMPLIST
	$DNSNAME | Export-CSV -NoTypeInformation -PATH $DNSCSVFILE
	$DNSSERVERLIST = $DNSTEMPLIST.DNSServerList
	$DNSDOMAIN = $DNSTEMPLIST.Domain
	$DNSSEARCHDOMAINS = $DNSTEMPLIST.SearchDomains
}
If($DNSCSVFILEGET)
{
	CLS
	Write-Host "DNS List CSV File found. Importing file..."
	$DNSLIST = Import-CSV -PATH $DNSCSVFILE
	If($DNSLIST.Site -Match $SITE)
	{
		Write-Host "Site $SITE DNS previously found, using DNS settings documented"
		$DNSSERVERLIST = ($DNSLIST | Where {$_.Site -Match $SITE}).DNSServerList
		$DNSDOMAIN = ($DNSLIST | Where {$_.Site -Match $SITE}).Domain
		$DNSSEARCHDOMAINS = ($DNSLIST | Where {$_.Site -Match $SITE}).SearchDomains
	}Else{
		$DNSARRAY = @()
		$DNSARRAY += $DNSLIST
		Write-Host "Site $SITE DNS Server not found"
		Write-Host "Creating New Record..."
		$DNSTEMPLIST = "" | Select DNSServerList, Domain, SearchDomains, Site
		$DNSTEMPLIST.DNSServerList = Read-Host "Please provide a list of DNS servers for site $SITE in comma seperated format
		Example 8.8.8.8,8.4.4.4"
		$DNSTEMPLIST.Domain = Read-Host "Please provide the name of the Domain for these Hosts
		Example contso.com"
		$DNSTEMPLIST.SearchDomains = Read-Host "Please provide a list of Search Domains for site $SITE in comma seperated format
		Example contso.com,dmz.contso.com"
		$DNSTEMPLIST.Site = $SITE
		Write-Host "DNS Site Selected is"($DNSTEMPLIST.Site)
		
		$DNSTEMPLIST | Export-CSV -NoTypeInformation -PATH $DNSCSVFILE -Confirm:$false -Append
		$DNSSERVERLIST = $DNSTEMPLIST.DNSServerList
		$DNSDOMAIN = $DNSTEMPLIST.Domain
		$DNSSEARCHDOMAINS = $DNSTEMPLIST.SearchDomains
		
	}
}
Write-Host "DNS Settings Include:"
Write-Host "DNS Server List"
Write-Host $DNSSERVERLIST
Write-Host "DNS Domain:"
Write-Host $DNSDOMAIN
Write-Host "DNS Search Domain(s):"
Write-Host $DNSSEARCHDOMAINS
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select NTP
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
##Import NTP File or Create 1
$NTPCSVFILENAME = "NTPlist.csv"
$NTPCSVFILEGET = Get-Item "$CSVFILELOCATION\$NTPCSVFILENAME" -ErrorAction SilentlyContinue
$NTPCSVFILE = "$CSVFILELOCATION\$NTPCSVFILENAME"
If(!$NTPCSVFILEGET)
{
	CLS
	Write-Host "NTP List CSV File not found"
	$NTPNAME = @()
	$NTPTEMPLIST = "" | Select NTP, Site
	$NTPTEMPLIST.NTP = Read-Host "Please provide a list of NTP servers for site $SITE in comma seperated format
	Example pool1.ntp.org, pool2.ntp.org"
	$NTPTEMPLIST.Site = $SITE
	Write-Host "NTP Site Selected is"($NTPTEMPLIST.Site)
	$NTPNAME += $NTPTEMPLIST
	$NTPNAME | Export-CSV -NoTypeInformation -PATH $NTPCSVFILE
	$NTP = $NTPTEMPLIST.NTP
}
If($NTPCSVFILEGET)
{
	CLS
	Write-Host "NTP List CSV File found. Importing file..."
	Write-Host "Checking CSV for Site $SITE Listing"
	$NTPLIST = Import-CSV -PATH $NTPCSVFILE
	If($NTPLIST.Site -Match $SITE)
	{
		$NTP = ($NTPLIST | Where {$_.Site -Match $SITE}).NTP
		Write-Host "Based on $SITE selected, NTP server will be $NTP"
	}Else{
		Write-Host "Site NTP Server not found"
		Write-Host "Creating New Record..."
		$NTPTEMPLIST = "" | Select NTP, Site
		$NTPTEMPLIST.NTP = Read-Host Read-Host "Please provide a list of NTP servers for site $SITE in comma seperated format
	Example pool1.ntp.org, pool2.ntp.org"
		$NTPTEMPLIST.Site = $SITE 
		Write-Host "Site Selected is:"
		Write-Host $NTPTEMPLIST.Site

		$NTPTEMPLIST | Export-CSV -NoTypeInformation -PATH $NTPCSVFILE -Confirm:$false -Append
		$NTP = $NTPTEMPLIST.NTP
		
	}
}
Write-Host "NTP Selected is $NTP"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select SYSLOG
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
##Import SYSLOG File or Create 1
$SYSLOGCSVFILENAME = "SYSLOGlist.csv"
$SYSLOGCSVFILEGET = Get-Item "$CSVFILELOCATION\$SYSLOGCSVFILENAME" -ErrorAction SilentlyContinue
$SYSLOGCSVFILE = "$CSVFILELOCATION\$SYSLOGCSVFILENAME"
If(!$SYSLOGCSVFILEGET)
{
	Write-Host "SYSLOG List CSV File not found"
	$SYSLOGNAME = @()
	$SYSLOGTEMPLIST = "" | Select SYSLOG, Site
	$SYSLOGTEMPLIST.SYSLOG = Read-Host "Please provide a SYSLOG FQDN or IP for site $SITE"
	$SYSLOGTEMPLIST.Site = $SITE
	Write-Host "Syslog Site Selected is"($SYSLOGTEMPLIST.Site)
	$SYSLOGNAME += $SYSLOGTEMPLIST
	$SYSLOGNAME | Export-CSV -NoTypeInformation -PATH $SYSLOGCSVFILE
	$SYSLOG = $SYSLOGTEMPLIST.SYSLOG
}
If($SYSLOGCSVFILEGET)
{
	CLS
	Write-Host "SYSLOG List CSV File found. Importing file..."
	$SYSLOGLIST = Import-CSV -PATH $SYSLOGCSVFILE
	If($SYSLOGLIST.Site -Match $SITE)
	{
		$SYSLOG = ($SYSLOGLIST | Where {$_.Site -Match $SITE}).SYSLOG
		Write-Host "Based on $SITE selected, SysLog server will be $SYSLOG"
	}Else{
		Write-Host "Site Syslog Server not found"
		Write-Host "Creating New Record..."
		$SYSLOGTEMPLIST = "" | Select SYSLOG, Site
		$SYSLOGTEMPLIST.SYSLOG = Read-Host "Please provide a SYSLOG FQDN or IP"
		$SYSLOGTEMPLIST.Site = $SITE 
		Write-Host "Site Selected is:"
		Write-Host $SYSLOGTEMPLIST.Site

		$SYSLOGTEMPLIST | Export-CSV -NoTypeInformation -PATH $SYSLOGCSVFILE -Confirm:$false -Append
		$SYSLOG = $SYSLOGTEMPLIST.SYSLOG
		
	}
}
Write-Host "SYSLOG Selected is $SYSLOG"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Select SATP Claim Rules
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
##Import SATP File or Create 1
$SATPCSVFILENAME = "SATPlist.csv"
$SATPCSVFILEGET = Get-Item "$CSVFILELOCATION\$SATPCSVFILENAME" -ErrorAction SilentlyContinue
$SATPCSVFILE = "$CSVFILELOCATION\$SATPCSVFILENAME"
If(!$SATPCSVFILEGET)
{
	CLS
	$CompleteSetting = $null
	$SATPNAME = @()
	DO{
		Write-Host "SATP List CSV File not found"
		$CorrectSetting = $null
			DO{
			$SATPTEMPLIST = "" | Select Vendor, Model, SATPname, ClaimOptions, Description, Options, PSPName, PSPOptions, Site
			$SATPTEMPLIST.Vendor = Read-Host "Please provide the Vendor Name
			Example: PURE"
			$SATPTEMPLIST.Model = Read-Host "Please provide the Model Name
			Example: FlashArray"
			$SATPTEMPLIST.SATPname = Read-Host "Please provide the SATP Name
			Example: VMW_SATP_ALUA"
			$SATPTEMPLIST.ClaimOptions = Read-Host "Please provide the Claim Options
			Example: tpgs_on
			Note: This can be left blank"
			$SATPTEMPLIST.Description = Read-Host "Please provide the Description
			Example: PURE FlashArray IO Operation Limit Rule
			Note: Please put something unique here"
			$SATPTEMPLIST.Options = Read-Host "Please provide the Options
			Example: ???
			Note: This can be left blank"
			$SATPTEMPLIST.PSPName = Read-Host "Please provide the PSPName
			Example: VMW_PSP_RR"
			$SATPTEMPLIST.PSPOptions = Read-Host "Please provide the PSPOptions
			Example: iops=1"
			$SATPTEMPLIST.Site = $SITE
			Write-Host "SATP Site Selected is"($SATPTEMPLIST.Site)
			CLS 
			Write-Host "Below is the details on the SATP you input:"
			$SATPTEMPLIST | Format-List
			
			Write-host "Is the SATP Claimrule Correct? (Default is Yes)" -ForegroundColor Yellow 
			$Readhost = Read-Host " ( y / n ) " 
			Switch ($ReadHost) 
			 { 
			   Y {Write-host "Yes selected, Continuing"; $CorrectSetting=$true} 
			   N {Write-Host "No selected, Recreate SATP Claim Rule"; $CorrectSetting=$false} 
			   Default {Write-Host "Default, Continuing"; $CorrectSetting=$true} 
			 } 
		}UNTIL($CorrectSetting -eq $true)
		$SATPNAME += $SATPTEMPLIST
		CLS
		Write-Host "Below is the details of all the SATP Claim Rules you have input:"
		$SATPNAME | Format-List
		Write-Host " "
		Write-host "Do You wish to add more SATP Claim Rule(s)" -ForegroundColor Yellow 
		$Readhost = Read-Host " ( y / n ) " 
		Switch ($ReadHost) 
		{ 
			Y {Write-host "Yes selected, Adding Another Record"; $CompleteSetting=$true} 
			N {Write-Host "No selected, All Records have been input"; $CompleteSetting=$false; $SATPTEMPLIST=$null} 
			Default {Write-Host "Default,  All Records have been input"; $CompleteSetting=$false} 
		} 
	}UNTIL(($CompleteSetting -eq $false))
	
	
	$SATPNAME | Export-CSV -NoTypeInformation -PATH $SATPCSVFILE
	$SATPARRAY = $SATPNAME
}
If($SATPCSVFILEGET)
{
	CLS
	Write-Host "SATP List CSV File found. Importing file..."
	$SATPLIST = Import-CSV -PATH $SATPCSVFILE
	If($SATPLIST.Site -Match $SITE)
	{
		$SATPARRAY = ($SATPLIST | Where {$_.Site -Match $SITE})
	}Else{
		$CompleteSetting = $null
		$SATPNAME = @()
		DO{
			Write-Host "SATP List for Site $SITE in CSV File not found"
			$CorrectSetting = $null
				DO{
				$SATPTEMPLIST = "" | Select Vendor, Model, SATPname, ClaimOptions, Description, Options, PSPName, PSPOptions, Site
				$SATPTEMPLIST.Vendor = Read-Host "Please provide the Vendor Name
				Example: PURE"
				$SATPTEMPLIST.Model = Read-Host "Please provide the Model Name
				Example: FlashArray"
				$SATPTEMPLIST.SATPname = Read-Host "Please provide the SATP Name
				Example: VMW_SATP_ALUA"
				$SATPTEMPLIST.ClaimOptions = Read-Host "Please provide the Claim Options
				Example: tpgs_on
				Note: This can be left blank"
				$SATPTEMPLIST.Description = Read-Host "Please provide the Description
				Example: PURE FlashArray IO Operation Limit Rule
				Note: Please put something unique here"
				$SATPTEMPLIST.Options = Read-Host "Please provide the Options
				Example: ???
				Note: This can be left blank"
				$SATPTEMPLIST.PSPName = Read-Host "Please provide the PSPName
				Example: VMW_PSP_RR"
				$SATPTEMPLIST.PSPOptions = Read-Host "Please provide the PSPOptions
				Example: iops=1"
				$SATPTEMPLIST.Site = $SITE
				Write-Host "SATP Site Selected is"($SATPTEMPLIST.Site)
				CLS 
				Write-Host "Below is the details on the SATP you input:"
				$SATPTEMPLIST | Format-List
				
				Write-host "Is the SATP Claimrule Correct? (Default is Yes)" -ForegroundColor Yellow 
				$Readhost = Read-Host " ( y / n ) " 
				Switch ($ReadHost) 
				 { 
				   Y {Write-host "Yes selected, Continuing"; $CorrectSetting=$true} 
				   N {Write-Host "No selected, Recreate SATP Claim Rule"; $CorrectSetting=$false} 
				   Default {Write-Host "Default, Continuing"; $CorrectSetting=$true} 
				 } 
			}UNTIL($CorrectSetting -eq $true)
			
			CLS
			Write-Host "Below is the details of all the SATP Claim Rules you have input:"
			$SATPTEMPLIST | Format-List
			Write-Host " "
			Write-host "Do You wish to add more SATP Claim Rule(s)" -ForegroundColor Yellow 
			$Readhost = Read-Host " ( y / n ) " 
			Switch ($ReadHost) 
			{ 
				Y {Write-host "Yes selected, Adding Another Record"; $CompleteSetting=$true} 
				N {Write-Host "No selected, All Records have been input"; $CompleteSetting=$false; $SATPTEMPLIST=$null} 
				Default {Write-Host "Default,  All Records have been input"; $CompleteSetting=$false} 
			} 
		}UNTIL(($CompleteSetting -eq $false))
		
		
		$SATPTEMPLIST | Export-CSV -NoTypeInformation -PATH $SATPCSVFILE -Confirm:$false -Append
		$SATPARRAY = $SATPTEMPLIST
	}
}
Write-Host "SATP Claim Rule(s) Selected Include:"
ForEach($SATP in $SATPARRAY)
{
	Write-Output $SATP | Format-List
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

##Document Selectsion
Do
{
CLS
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Documenting User Selections"
Write-Host "Site:               $SITE"
Write-Host "VCSA:               $VCSA"
Write-Host "DNS Server List:    $DNSSERVERLIST"
Write-Host "DNS Domain:         $DNSDOMAIN"
Write-Host "DNS Search Domains: $DNSSEARCHDOMAINS"
Write-Host "NTP List:           $NTP"
Write-Host "SysLog Server:      $SYSLOG"
Write-Host "SATP Claim Rule(s):"
ForEach($SATP in $SATPARRAY)
{
	Write-Output $SATP | Format-List
}

	Write-host "Are the Above Settings Correct?" -ForegroundColor Yellow 
	$Readhost = Read-Host " ( y / n ) " 
	Switch ($ReadHost) 
	{ 
			Y {Write-host "Yes selected"; $VERIFICATION=$true} 
			N {Write-Host "No selected, Please Close this Window to Stop this Script"; $VERIFICATION=$false; PAUSE; CLS} 
			Default {Write-Host "Default,  Yes"; $VERIFICATION=$true} 
	}
}Until($VERIFICATION -eq $true)
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Provide Credentials
CLS
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
$VISERVER = Connect-VIServer -server $VCSA -Credential $MyCredential
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
$choice = Read-Host "On which Cluster do you want to export the Host Profile from?"
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
$choice = Read-Host "Which VMHost do you wish to export the Host Profile from?"
$VMHOST = get-vmhost $VMHOST[$choice]
Write-Host "You have selected Cluster $CLUSTER on vCenter $VCSA"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Remove Host Profile with Cluster Name if it exists
CLS
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
$PROFILETEMPNAME = $CLUSTER.Name + "_temp"
Write-Host "Removing Any Previous Host Profiles with the Cluster name $PROFILETEMPNAME"
Get-VMHostProfile -Name (($CLUSTER.Name) + "_temp") -ErrorAction SilentlyContinue | Remove-VMHostProfile -Confirm:$false
Write-Host "Completed Removing Any Previous Host Profiles with the Cluster name $PROFILETEMPNAME"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Enforce setting VMHost to Power Management Policy to High Performance
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Setting Power Policy on VMHOST $VMHOST to High Performance"
Write-Host "Note: This code was added as a work around due to not being able ot manipulate the Power Settings on the Host Profile itself."
$VIEW = (Get-VMHost $VMHOST | Get-View)
<#
Reference: http://blog.johnwray.com/post/2017/03/10/esxi-change-power-policy-to-high-performance-powercli
1=HighPerformance
2=Balanced
3=LowPower
#>
(Get-View $VIEW.ConfigManager.PowerSystem).ConfigurePowerPolicy(1)
Write-Host "Completed setting Power Policy on VMHOST $VMHOST to High Performance"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Export VMHost Config to Profile
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Exporting VMHost profile from VMHost $VMHOST in CLUSTER $CLUSTER"
New-VMHostProfile -Name (($CLUSTER.Name) + "_temp") -ReferenceHost $VMHOST -Confirm:$false -Description "Automated Host Profile created for Cluster $CLUSTER, created from VMHost $VMHOST on Date $LOGDATE"
Write-Host "Completed exporting VMHost profile from VMHost $VMHOST in CLUSTER $CLUSTER"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Creates the spec where the cleanup is done
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Creating PowerShell Object SPEC and copy Host Profile Settings to it"
#Reference: https://www.retouw.nl/vsphere/generating-a-clean-host-profile-using-powercli/
$spec = New-Object VMware.Vim.HostProfileCompleteConfigSpec
#Get Host Profile that was generated previously
$hp = Get-VMHostProfile -Name (($CLUSTER.Name) + "_temp")
# Copies all properties of the new Host Profile to the spec
Copy-Property -From $hp.ExtensionData.Config -To $spec
Write-Host "Completed creating PowerShell Object SPEC and copy Host Profile Settings to it"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Disabling Physical Devices in Host Profile
CLS
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Removing Hardware specific references from SPEC Profile settings"
#$spec.ApplyProfile.Network.Vswitch=$null
#$spec.ApplyProfile.Network.VMportgroup=$null
#$spec.ApplyProfile.Network.HostPortGroup=$null
#Removing Physical Adapter from SPEC
Write-Host "Disabling Phyiscal Storage configuration from SPEC"
($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "iscsi_iscsiProfile_IscsiInitiatorProfile"}).Enabled=$false
($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "psa_psaProfile_PluggableStorageArchitectureProfile"}).Enabled=$True
##Disabling Pluggable Storage Architecture (PSA) Settings
Write-Host "Disabling Pluggable Storage Architecture (PSA) Settings"
Write-Host "Disabling PSA Device Sharing Profiles"
#How to List sub Profiles
#($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "psa_psaProfile_PluggableStorageArchitectureProfile"}).Property 
$PSADEVICESHARINGPROFILES = (($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "psa_psaProfile_PluggableStorageArchitectureProfile"}).Property |Where {$_.PropertyName -eq "psa_psaProfile_PsaDeviceSharingProfile"}).Profile
ForEach($o in $PSADEVICESHARINGPROFILES)
{
	$o.Enabled = $false
}
Write-Host "Disabling Boot Device Profiles"
$HOSTBOOTDEVICEPROFILES = ((($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "psa_psaProfile_PluggableStorageArchitectureProfile"}).Property |Where {$_.PropertyName -eq "psa_psaProfile_PsaBootDeviceProfile"})).Profile
ForEach($o in $HOSTBOOTDEVICEPROFILES)
{
	$o.Enabled = $false
}
Write-Host "Disabling PSA Device Setting Profiles"
$PSADEVICESETTINGPROFILES = ((($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "psa_psaProfile_PluggableStorageArchitectureProfile"}).Property |Where {$_.PropertyName -eq "psa_psaProfile_PsaDeviceSettingProfile"})).Profile
ForEach($o in $PSADEVICESETTINGPROFILES)
{
	$o.Enabled = $false
}
Write-Host "Disabling PSA Device Configuration Profiles"
$PsaDeviceConfigurationProfiles = ((($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "psa_psaProfile_PluggableStorageArchitectureProfile"}).Property |Where {$_.PropertyName -eq "psa_psaProfile_PsaDeviceConfigurationProfile"})).Profile
ForEach($o in $PsaDeviceConfigurationProfiles)
{
	$o.Enabled = $false
}
Write-Host "Disabling PSA device inquiry cache"
$PsaDeviceInquiryCacheProfiles = ((($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "psa_psaProfile_PluggableStorageArchitectureProfile"}).Property |Where {$_.PropertyName -eq "psa_psaProfile_PsaDeviceInquiryCacheProfile"})).Profile
ForEach($o in $PsaDeviceInquiryCacheProfiles)
{
	$o.Enabled = $false
}
##Disabling Native Multi-Pathing (NMP) Settings
Write-Host "Disabling Native Multi-Pathing (NMP) Settings"
#($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "nmp_nmpProfile_NativeMultiPathingProfile"}).Property
#(($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "nmp_nmpProfile_NativeMultiPathingProfile"}).Property |Where {$_.PropertyName -eq "nmp_nmpProfile_NmpDeviceProfile"}).Profile
Write-Host "Disabling PSP configuration for Device (NmpDeviceConfigurationProfiles)"
$NmpDeviceConfigurationProfiles = (((($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "nmp_nmpProfile_NativeMultiPathingProfile"}).Property |Where {$_.PropertyName -eq "nmp_nmpProfile_NmpDeviceProfile"}).Profile).Property | Where {$_.PropertyName -eq "nmp_nmpProfile_NmpDeviceConfigurationProfile"}).Profile
ForEach($o in $NmpDeviceConfigurationProfiles)
{
	$o.Enabled = $false
}
Write-Host "Disabling SATP configuration for Device (NmpProfile_SatpDeviceProfiles)"
$NmpProfile_SatpDeviceProfiles = (((($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "nmp_nmpProfile_NativeMultiPathingProfile"}).Property |Where {$_.PropertyName -eq "nmp_nmpProfile_NmpDeviceProfile"}).Profile).Property | Where {$_.PropertyName -eq "nmp_nmpProfile_SatpDeviceProfile"}).Profile
ForEach($o in $NmpProfile_SatpDeviceProfiles)
{
	$o.Enabled = $false
}
#nmp_nmpProfile_PathSelectionPolicyProfile
$nmpProfile_PathSelectionPolicyProfiles = (($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "nmp_nmpProfile_NativeMultiPathingProfile"}).Property |Where {$_.PropertyName -eq "nmp_nmpProfile_PathSelectionPolicyProfile"}).Profile
ForEach($o in $nmpProfile_PathSelectionPolicyProfiles)
{
	$o.Enabled = $false
}
##Disable vVOL
Write-Host "Disabling Storage Configuration>Virtual Volumes (VVOLS)"
ForEach ($p in ($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "vvol_vvolProfile_VirtualVolumesProfile"}))
{
    if ($p.Enabled){
        $p.Enabled=$False
    }
    foreach ($pa in $p.Property.Profile)
	{
		if ($pa.Enabled)
		{
			#$pa
			$pa.Enabled=$False
			#$pa
		}
        ForEach ($paa in $pa.Property.Profile)
		{
			If($paa.Enabled)
			{
				#$paa
				$paa.Enabled=$False
				#$paa
			}
        }
    }
}
##Disable NFS User Host Configuration
#nfs_nfsUser_NfsUserProfile
Write-Host "Disabling Storage Configuration>NFS User Host Configuration"
ForEach ($p in ($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "nfs_nfsUser_NfsUserProfile"}))
{
    if ($p.Enabled){
        $p.Enabled=$False
    }
    foreach ($pa in $p.Property.Profile)
	{
		if ($pa.Enabled)
		{
			#$pa
			$pa.Enabled=$False
			#$pa
		}
        ForEach ($paa in $pa.Property.Profile)
		{
			If($paa.Enabled)
			{
				#$paa
				$paa.Enabled=$False
				#$paa
			}
        }
    }
}
##Disable Software FCOE Configuration
#fcoe_fcoeProfiles_FCoEProfile
Write-Host "Disabling Storage Configuration>Software FCOE Configuration"
ForEach ($p in ($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "fcoe_fcoeProfiles_FCoEProfile"}))
{
    if ($p.Enabled){
        $p.Enabled=$False
    }
    foreach ($pa in $p.Property.Profile)
	{
		if ($pa.Enabled)
		{
			#$pa
			$pa.Enabled=$False
			#$pa
		}
        ForEach ($paa in $pa.Property.Profile)
		{
			If($paa.Enabled)
			{
				#$paa
				$paa.Enabled=$False
				#$paa
			}
        }
    }
}
##Disable vSAN Configuration
#vsan_vsanProfiles_VSANProfile
If($CLUSTER.VsanEnabled -eq $false)
{
	Write-Host "Disabling Storage Configuration>vSAN Configuration"
	ForEach ($p in ($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "vsan_vsanProfiles_VSANProfile"}))
	{
		if ($p.Enabled){
			$p.Enabled=$False
		}
		foreach ($pa in $p.Property.Profile)
		{
			if ($pa.Enabled)
			{
				#$pa
				$pa.Enabled=$False
				#$pa
			}
			ForEach ($paa in $pa.Property.Profile)
			{
				If($paa.Enabled)
				{
					#$paa
					$paa.Enabled=$False
					#$paa
				}
			}
		}
	}
}ELSE{
	Write-Host "vSAN Enabled Cluster Detected. Leaving vSAN configuration enabled in Host Profile."
	ForEach ($p in ($spec.ApplyProfile.Storage.Property.Profile | Where {$_.ProfileTypeName -eq "vsan_vsanProfiles_VSANProfile"}))
	{
		if ($p.Favorite){
			$p.Favorite=$True
		}
		foreach ($pa in $p.Property.Profile)
		{
			if ($pa.Favorite)
			{
				#$pa
				$pa.Favorite=$True
				#$pa
			}
			ForEach ($paa in $pa.Property.Profile)
			{
				If($paa.Favorite)
				{
					#$paa
					$paa.Enabled=$True
					#$paa
				}
			}
		}
	}
}
##Disable ESX Info
#info_esxInfo_EsxInfo
Write-Host "Disabling Other>ESX Info"
ForEach ($p in ($spec.ApplyProfile.Property.Profile |Where {$_.ProfileTypeName -eq "info_esxInfo_EsxInfo"}))
{
    if ($p.Enabled){
        $p.Enabled=$False
    }
    foreach ($pa in $p.Property.Profile)
	{
		if ($pa.Enabled)
		{
			#$pa
			$pa.Enabled=$False
			#$pa
		}
        ForEach ($paa in $pa.Property.Profile)
		{
			If($paa.Enabled)
			{
				#$paa
				$paa.Enabled=$False
				#$paa
			}
        }
    }
}
##Disable DirectPath I/O Configuration
#pciPassThru_pciPassThru_PciPassThroughProfile
Write-Host "Disabling Advanced Configuration Settings>DirectPath I/O Configuration"
ForEach ($p in ($spec.ApplyProfile.Property.Profile |Where {$_.ProfileTypeName -eq "pciPassThru_pciPassThru_PciPassThroughProfile"}))
{
    if ($p.Enabled){
        $p.Enabled=$False
    }
    foreach ($pa in $p.Property.Profile)
	{
		if ($pa.Enabled)
		{
			#$pa
			$pa.Enabled=$False
			#$pa
		}
        ForEach ($paa in $pa.Property.Profile)
		{
			If($paa.Enabled)
			{
				#$paa
				$paa.Enabled=$False
				#$paa
			}
        }
    }
}
##Disable Device Alias Configuration
#deviceAlias_deviceAlias_DeviceAliasProfile
Write-Host "Disabling General System Settings>Device Alias Configuration"
ForEach ($p in ($spec.ApplyProfile.Property.Profile |Where {$_.ProfileTypeName -eq "deviceAlias_deviceAlias_DeviceAliasProfile"}))
{
    if ($p.Enabled){
        $p.Enabled=$False
    }
    foreach ($pa in $p.Property.Profile)
	{
		if ($pa.Enabled)
		{
			#$pa
			$pa.Enabled=$False
			#$pa
		}
        ForEach ($paa in $pa.Property.Profile)
		{
			If($paa.Enabled)
			{
				#$paa
				$paa.Enabled=$False
				#$paa
			}
        }
    }
}
Write-Host "Completed removing Hardware specific references from SPEC Profile settings"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Adding Configuration For Best Practices
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Adding Best Practices Configuration"
##Set Scratch Disk Requirement
Write-Host "Checking if Scratch Disk is set as a requirement under Advanced Configuration Settings>Advanced Options>ScratchConfig"
#hostsFile_hostsFile_EtcHostsProfile
#Reference: https://communities.vmware.com/thread/341937
#Used VCSA Code Capture to create the Advanced Settings
$SCRATCHSTATUS = $spec.ApplyProfile.Option | where {$_.Key -eq "key-vim-profile-host-OptionProfile-ScratchConfig.ConfiguredScratchLocation"}
IF($SCRATCHSTATUS.count -eq 1)
{
	Write-Host "Scratch Disk Configuration already exists :)"
	Write-Host "Setting Scratch Disk as Favorite"
	($spec.ApplyProfile.Option | where {$_.Key -eq "key-vim-profile-host-OptionProfile-ScratchConfig.ConfiguredScratchLocation"}).Favorite = $true
	($spec.ApplyProfile.Option | where {$_.Key -eq "key-vim-profile-host-OptionProfile-ScratchConfig.ConfiguredScratchLocation"}).Favorite
}
If($SCRATCHSTATUS.count -eq 0)
{
	Write-Host "Scratch Disk Configuration not found. Adding Configuration"
	$configOption = $null
	$configOption = New-Object VMware.Vim.OptionProfile[] (10999)
	$configOption[0] = New-Object VMware.Vim.OptionProfile
	$configOption[0].ProfileTypeName = 'OptionProfile'
	$configOption[0].ProfileVersion = '6.7.0'
	$configOption[0].Enabled = $true
	$configOption[0].Favorite = $true
	$configOption[0].Key = 'key-vim-profile-host-OptionProfile-ScratchConfig.ConfiguredScratchLocation'
	$configOption[0].Policy = New-Object VMware.Vim.ProfilePolicy[] (1)
	$configOption[0].Policy[0] = New-Object VMware.Vim.ProfilePolicy
	$configOption[0].Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
	$configOption[0].Policy[0].PolicyOption.Parameter = New-Object VMware.Vim.KeyAnyValue[] (1)
	$configOption[0].Policy[0].PolicyOption.Parameter[0] = New-Object VMware.Vim.KeyAnyValue
	$configOption[0].Policy[0].PolicyOption.Parameter[0].Value = 'ScratchConfig.ConfiguredScratchLocation'
	$configOption[0].Policy[0].PolicyOption.Parameter[0].Key = 'key'
	$configOption[0].Policy[0].PolicyOption.Id = 'UserInputAdvancedConfigOption'
	$configOption[0].Policy[0].Id = 'ConfigOptionPolicy'
	
	##Add Options to SPEC
	Write-Host "Completed Scratch Disk Configuration."
	$spec.ApplyProfile.Option +=@($configOption)
}

##Set Keyboard Profile
#keyboardConfig_keyboardProfile_KeyboardProfile
Write-Host "Enforcing DCUI Keyboard Profile to US Default"
((($spec.ApplyProfile.Property.Profile |Where {$_.ProfileTypeName -eq "keyboardConfig_keyboardProfile_KeyboardProfile"}).Policy).PolicyOption).Parameter = $null

##Set SysLog for VMHost
Write-Host "Adding Syslog server for VMHost"
$GetSysLogSpec = (((($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Policy).PolicyOption).Parameter | where {$_.key -eq "value"}).Value
If($GetSysLogSpec)
{
	#Enforce syslog setting
	(((($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Policy).PolicyOption).Parameter | where {$_.key -eq "value"}).Value = "udp://"+$SYSLOG+":514"
	#Verify Syslog Setting
	Write-Host "SysLog has now been updated to:"
	(((($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Policy).PolicyOption).Parameter | where {$_.key -eq "value"}).Value
	#Set Syslog as a Favorite
	Write-Host "Setting SysLog setting as a Favorite"
	($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Favorite=$true
	($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Favorite
}
If(!$GetSysLogSpec)
{
	Write-Host "Syslog Settings not Found, adding Syslog settings."
	#Update Value to Fixed
	($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Policy[0].PolicyOption.Id = 'FixedConfigOption'
	#Create Parameters Array
	$TEMPARRAY = @()
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = 'key'
	$TEMP.Value = 'Syslog.global.logHost'
	$TEMPARRAY += $TEMP
	$TEMP = New-Object VMware.Vim.KeyAnyValue
	$TEMP.Key = 'value'
	$TEMP.Value = "udp://"+$SYSLOG+":514"
	$TEMPARRAY += $TEMP
	#Replace Default Parameters
	($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Policy[0].PolicyOption.Parameter = $TEMPARRAY 
	#Verify Syslog Setting
	Write-Host "SysLog has now been updated to:"
	(((($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Policy).PolicyOption).Parameter | where {$_.key -eq "value"}).Value
	#Set Syslog as a Favorite
	Write-Host "Setting SysLog setting as a Favorite"
	($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Favorite=$true
	($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-Syslog_global_logHost"}).Favorite
}

##Setting VMFS3_UseATSForHBOnVMFS5
$GetUseATSForHBOnVMFS5Spec = (($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-VMFS3_UseATSForHBOnVMFS5"}).Policy.PolicyOption.Parameter | Where {$_.Key -eq "value"}).Value
If($GetUseATSForHBOnVMFS5Spec.Count -gt 0)
{
	Write-Host "VMFS3_UseATSForHBOnVMFS5 Already Created"
	Write-Host "Setting VMFS3_UseATSForHBOnVMFS5 setting as a Favorite"
	($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-VMFS3_UseATSForHBOnVMFS5"}).Favorite=$true
	($spec.ApplyProfile.Option | where {$_.key -eq "key-vim-profile-host-OptionProfile-VMFS3_UseATSForHBOnVMFS5"}).Favorite
	
}
If($GetUseATSForHBOnVMFS5Spec.count -lt 1)
{
	Write-Host "VMFS3_UseATSForHBOnVMFS5 Not Created. Creating Item."
	$configOption = $null
	$configOption = New-Object VMware.Vim.OptionProfile[] (10999)
	$configOption[0] = New-Object VMware.Vim.OptionProfile
	$configOption[0].ProfileTypeName = 'OptionProfile'
	$configOption[0].ProfileVersion = '6.7.0'
	$configOption[0].Enabled = $true
	$configOption[0].Favorite = $true
	$configOption[0].Key = 'key-vim-profile-host-OptionProfile-'
	$configOption[0].Policy = New-Object VMware.Vim.ProfilePolicy[] (1)
	$configOption[0].Policy[0] = New-Object VMware.Vim.ProfilePolicy
	$configOption[0].Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
	$configOption[0].Policy[0].PolicyOption.Parameter = New-Object VMware.Vim.KeyAnyValue[] (2)
	$configOption[0].Policy[0].PolicyOption.Parameter[0] = New-Object VMware.Vim.KeyAnyValue
	$configOption[0].Policy[0].PolicyOption.Parameter[0].Value = 'VMFS3.UseATSForHBOnVMFS5'
	$configOption[0].Policy[0].PolicyOption.Parameter[0].Key = 'key'
	$configOption[0].Policy[0].PolicyOption.Parameter[1] = New-Object VMware.Vim.KeyAnyValue
	$configOption[0].Policy[0].PolicyOption.Parameter[1].Value = '0'
	$configOption[0].Policy[0].PolicyOption.Parameter[1].Key = 'value'
	$configOption[0].Policy[0].PolicyOption.Id = 'FixedConfigOption'
	$configOption[0].Policy[0].Id = 'ConfigOptionPolicy'
	
	##Add Options to SPEC
	Write-Host "Adding VMFS3_UseATSForHBOnVMFS5 to SPEC"
	$spec.ApplyProfile.Option +=@($configOption)
}

##Enforce vCenter agent (vpxa) configurations
#key-vim-profile-host-OptionProfile-Config_Etc_motd
Write-Host "Enforcing VPXA Log settings. Advanced Configuration Settings > vCenter Agent (vpxa) Configurations"
(((((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "vpxaConfig_vpxaConfig_VpxaConfigProfile"}).Profile) |where {$_.ProfileTypeName -eq "vpxaConfig_vpxaConfig_VpxaConfigProfile"}).Policy `
| Where {$_.Id -eq "vpxaConfig.vpxaConfig.VpxaConfigProfilePolicy"}).PolicyOption | `
Where {$_.Id -eq "vpxaConfig.vpxaConfig.VpxaConfigProfilePolicyOption"}).Parameter |Where {$_.Key -eq "logLevel"}).Value = "info"
Write-Host "Setting VPXA Log settings as Favorite"
(($spec.ApplyProfile.Property | where {$_.PropertyName -eq "vpxaConfig_vpxaConfig_VpxaConfigProfile"}).Profile | where {$_.ProfileTypeName -eq "vpxaConfig_vpxaConfig_VpxaConfigProfile"}).Favorite = $true
Write-Host "VPXA Logging set to :"
(((((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "vpxaConfig_vpxaConfig_VpxaConfigProfile"}).Profile) |where {$_.ProfileTypeName -eq "vpxaConfig_vpxaConfig_VpxaConfigProfile"}).Policy | Where {$_.Id -eq "vpxaConfig.vpxaConfig.VpxaConfigProfilePolicy"}).PolicyOption | Where {$_.Id -eq "vpxaConfig.vpxaConfig.VpxaConfigProfilePolicyOption"}).Parameter |Where {$_.Key -eq "logLevel"}).Value

##Enforce Graphics configuration
Write-Host "Enforcing Graphings Configuration. Advanced Configuration Settings > Graphics Configuration > Graphics Configuration "
((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "graphicsConfig_graphicsConfigProfile_GraphicsConfigProfile"}).Profile | Where {$_.ProfileTypeName -eq "graphicsConfig_graphicsConfigProfile_GraphicsConfigProfile"}).Policy.PolicyOption.Parameter | Where {$_.Key -eq "defaultGraphicsType"}).Value = "shared"
((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "graphicsConfig_graphicsConfigProfile_GraphicsConfigProfile"}).Profile | Where {$_.ProfileTypeName -eq "graphicsConfig_graphicsConfigProfile_GraphicsConfigProfile"}).Policy.PolicyOption.Parameter | Where {$_.Key -eq "sharedPassthruAssignmentPolicy"}).Value = "performance"
#(($spec.ApplyProfile.Property | where {$_.PropertyName -eq "graphicsConfig_graphicsConfigProfile_GraphicsConfigProfile"}).Profile | Where {$_.ProfileTypeName -eq "graphicsConfig_graphicsConfigProfile_GraphicsConfigProfile"}).Favorite = $true

##Enforce Host Profile Logging Level
Write-Host "Enforcing Host Profile Logging Level. Advanced Configuration Settings > Host Profile Log Configuration > Host Profile Log Configuration"
((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "hostprofileLogging_hpLogging_HPLoggingProfile"}).Profile | Where {$_.ProfileTypeName -eq "hostprofileLogging_hpLogging_HPLoggingProfile"}).Policy.PolicyOption.Parameter | Where {$_.Key -eq "traceEnabled"}).Value = $false
((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "hostprofileLogging_hpLogging_HPLoggingProfile"}).Profile | Where {$_.ProfileTypeName -eq "hostprofileLogging_hpLogging_HPLoggingProfile"}).Policy.PolicyOption.Parameter | Where {$_.Key -eq "logLevel"}).Value = "INFO"
(($spec.ApplyProfile.Property | where {$_.PropertyName -eq "hostprofileLogging_hpLogging_HPLoggingProfile"}).Profile | Where {$_.ProfileTypeName -eq "hostprofileLogging_hpLogging_HPLoggingProfile"}).Favorite = $true

##Enforce Power System Configuration
#powerSystem_powerSystem_PowerSystemProfile
Write-Host "Setting Power System Profile as a Favorite. Advanced Configuration Settings > Power System Configuration > Power System"
(($spec.ApplyProfile.Property | where {$_.PropertyName -eq "powerSystem_powerSystem_PowerSystemProfile"}).Profile | Where {$_.ProfileTypeName -eq "powerSystem_powerSystem_PowerSystemProfile"}).Favorite = $true
<#
#Non-Functional. Opened VMware Support case to troubleshoot. Support Case # 20130695506  
Write-Host "Setting Host Power System settings. Power System Configuration > Power System"
((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "powerSystem_powerSystem_PowerSystemProfile"}).Profile | Where {$_.ProfileTypeName -eq "powerSystem_powerSystem_PowerSystemProfile"}).Policy | where {$_.Id -eq "powerSystem.powerSystem.CpuPolicy"}).PolicyOption.Parameter = New-Object VMware.Vim.KeyAnyValue
((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "powerSystem_powerSystem_PowerSystemProfile"}).Profile | Where {$_.ProfileTypeName -eq "powerSystem_powerSystem_PowerSystemProfile"}).Policy | where {$_.Id -eq "powerSystem.powerSystem.CpuPolicy"}).PolicyOption.Parameter[0].Key = 'value'
((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "powerSystem_powerSystem_PowerSystemProfile"}).Profile | Where {$_.ProfileTypeName -eq "powerSystem_powerSystem_PowerSystemProfile"}).Policy | where {$_.Id -eq "powerSystem.powerSystem.CpuPolicy"}).PolicyOption.Parameter[0].Value = 'high_performance'

((($spec.ApplyProfile.Property | where {$_.PropertyName -eq "powerSystem_powerSystem_PowerSystemProfile"}).Profile | Where {$_.ProfileTypeName -eq "powerSystem_powerSystem_PowerSystemProfile"}).Policy | where {$_.Id -eq "powerSystem.powerSystem.CpuPolicy"}).PolicyOption.Parameter
#>

##Set NTP Settings
Write-Host "Setting NTP Settings"
$FIXEDNTPVERIFY = TRY{(($spec.ApplyProfile.Datetime.Policy | Where {$_.id -eq "NTPPolicy"}).PolicyOption | Where {$_.Id -eq "FixedNTPOption"})}CATCH{ }
If($FIXEDNTPVERIFY)
{
	$NTPARRAY = ($NTP.Split(',') | % { $_.Trim() })
	Write-Host "Setting NTP Server Setttings based on Site $SITE to $NTP"
	$spec.ApplyProfile.Datetime = New-Object VMware.Vim.DateTimeProfile
	$spec.ApplyProfile.Datetime.ProfileTypeName = 'DateTimeProfile'
	$spec.ApplyProfile.Datetime.ProfileVersion = '6.7.0'
	$spec.ApplyProfile.Datetime.Enabled = $true
	$spec.ApplyProfile.Datetime.Policy = New-Object VMware.Vim.ProfilePolicy[] (1)
	$spec.ApplyProfile.Datetime.Policy[0] = New-Object VMware.Vim.ProfilePolicy
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter = New-Object VMware.Vim.KeyAnyValue[] (1)
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter[0] = New-Object VMware.Vim.KeyAnyValue
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter[0].Value = New-Object String[] ($NTPARRAY.Count)
	$NTPCL = 0
	ForEach($NTPL in $NTPARRAY)
	{
		$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter[0].Value[$NTPCL] = $NTPL
		$NTPCL = $NTPCL+1
	}
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter[0].Key = 'server'
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Id = 'FixedNTPOption'
	$spec.ApplyProfile.Datetime.Policy[0].Id = 'NTPPolicy'
	Write-Host "Setting NTP Settings as a Favorite"
	$spec.ApplyProfile.Datetime.Favorite = $true
}ELSE{
	Write-Host "NTP NOT configured on Parent of Host Profile, configuring Host Profile for NTP"
	$NTPARRAY = ($NTP.Split(',') | % { $_.Trim() })
	$spec.ApplyProfile.Datetime = New-Object VMware.Vim.DateTimeProfile
	$spec.ApplyProfile.Datetime.ProfileTypeName = 'DateTimeProfile'
	$spec.ApplyProfile.Datetime.ProfileVersion = '6.7.0'
	$spec.ApplyProfile.Datetime.Enabled = $true
	$spec.ApplyProfile.Datetime.Policy = New-Object VMware.Vim.ProfilePolicy[] (1)
	$spec.ApplyProfile.Datetime.Policy[0] = New-Object VMware.Vim.ProfilePolicy
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter = New-Object VMware.Vim.KeyAnyValue[] (1)
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter[0] = New-Object VMware.Vim.KeyAnyValue
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter[0].Value = New-Object String[] ($NTPARRAY.Count)
	$NTPCL = 0
	ForEach($NTPL in $NTPARRAY)
	{
		$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter[0].Value[$NTPCL] = $NTPL
		$NTPCL = $NTPCL+1
	}
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Parameter[0].Key = 'server'
	$spec.ApplyProfile.Datetime.Policy[0].PolicyOption.Id = 'FixedNTPOption'
	$spec.ApplyProfile.Datetime.Policy[0].Id = 'NTPPolicy'
	Write-Host "NTP Servers for Host Profile are now set to"
	((($spec.ApplyProfile.Datetime.Policy | Where {$_.id -eq "NTPPolicy"}).PolicyOption | Where {$_.Id -eq "FixedNTPOption"}).Parameter |Where {$_.key -eq "server"}).Value
	Write-Host "Setting NTP Settings as a Favorite"
	$spec.ApplyProfile.Datetime.Favorite = $true
}
Write-Host "Completed setting NTP Settings"

##Set DNS Settings
Write-Host "Setting Host Profile DNS Settings Based on Site"$SITE
$DNSSERVERLISTARRAY = ($DNSSERVERLIST.Split(',') | % { $_.Trim() })
$DNSSEARCHDOMAINSARRAY = ($DNSSEARCHDOMAINS.Split(',') | % { $_.Trim() })
#Set Host Profile DNS List
Write-Host "Setting Host Profile DNS Server List to $DNSSERVERLIST"
#((((($spec.ApplyProfile.Network.Property | Where {$_.PropertyName -eq "GenericNetStackInstanceProfile"}).Profile | Where {$_.ProfileTypeName -eq "GenericNetStackInstanceProfile"}).Property | Where {$_.PropertyName -eq "GenericDnsConfigProfile"}).Profile.Policy | Where {$_.Id -eq "DnsConfigPolicy"}).PolicyOption.Parameter | Where {$_.Key -eq "address"}).Value = $DNSSERVERLISTARRAY
#$spec.ApplyProfile.Network.Property[0].Profile[0].Property[0].Profile.Policy[0].PolicyOption.Parameter[0].Value = New-Object String[] ($DNSSERVERLISTARRAY.Count)
(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'address'}).Value = New-Object String[] ($DNSSERVERLISTARRAY.Count)
$CL = $null
$CL = 0
ForEach($DNSSERVER in $DNSSERVERLISTARRAY)
{
	(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'address'}).Value[$CL] = $DNSSERVER
	$CL = $CL+1
}
Write-Host "Completed setting Host Profile DNS Server List is now set to:"
(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'address'}).Value
#Set Host Profile DNS list to False (Change this to True if using DHCP)
Write-Host "Setting Host Profile DNS Server List from DHCP to False"
(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'dhcp'}).Value = $False
(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'dhcp'}).Value
Write-Host "Setting Host Profile DNS Domain name to: $DNSDOMAIN"
(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'domainName'}).Value = $DNSDOMAIN
(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'domainName'}).Value
Write-Host "Setting Host Search Domain(s) to: $DNSSEARCHDOMAINS"
(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'searchDomain'}).Value = New-Object String[] ($DNSSEARCHDOMAINSARRAY.Count)
$CL = $null
$CL = 0
ForEach($DNSSEARCHDOMAIN in $DNSSEARCHDOMAINSARRAY)
{
	(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'searchDomain'}).Value[$CL] = $DNSSEARCHDOMAIN
	$CL = $CL+1
}
(((((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Policy | Where{$_.Id -eq 'DnsConfigPolicy'}).PolicyOption.Parameter | where {$_.Key -eq 'searchDomain'}).Value
Write-Host "Setting defaultTcpipStack > DNS Configuration as Favorite"
(((($spec.ApplyProfile.Network.Property[0].Profile | Where {$_.key -eq 'key-vim-profile-host-GenericNetStackInstanceProfile-defaultTcpipStack'}).Property) | Where {$_.PropertyName -eq 'GenericDnsConfigProfile'}).Profile | Where {$_.ProfileTypeName -eq 'GenericDnsConfigProfile'}).Favorite = $TRUE
Write-Host "Completed setting Host Profile DNS Settings Based on Site"$SITE

##Set FIPS Mode Service Configuration
#security_FipsProfile_FipsProfile
Write-Host "Enforcing FIPS Mode Configuration for Service(s). Security and Services > Service Configuration > FIPS mode configuraiton"
#Specify Array of Services
$FIPSARRAY = @()
$FIPSTEMP = "" | Select Name, Enablement
$FIPSTEMP.Name = 'rhttpproxy'
$FIPSTEMP.Enablement = $True
$FIPSARRAY += $FIPSTEMP
$FIPSTEMP = "" | Select Name, Enablement
$FIPSTEMP.Name = 'ssh'
$FIPSTEMP.Enablement = $True
$FIPSARRAY += $FIPSTEMP
$PROFILES = @()
IF($FIPSARRAY)
{
	ForEach($FIPS in $FIPSARRAY)
	{
		$FIPSNAME = $FIPS.NAME
		Write-Host "Enforcing FIPS Mode Configuration for Service $FIPSNAME"
		$PROFILE = New-Object VMware.Vim.ProfileApplyProfileElement
		$PROFILE.Key = $FIPS.NAME #$FIPS.Key 
		$PROFILE.Enabled = $True
		$PROFILE.ProfileTypeName = 'security_FipsProfile_FipsProfile'
		$PROFILE.ProfileVersion = '6.7.0'
		$PROFILE.Enabled = $True
		$PROFILE.Policy = New-Object VMware.Vim.ProfilePolicy
		$PROFILE.Policy[0].Id = 'security.FipsProfile.FipsProfilePolicy'
		$PROFILE.Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
		$PROFILE.Policy[0].PolicyOption[0].Id = 'security.FipsProfile.FipsProfilePolicyOption'	

		$TEMPARRAY = @()
		$TEMP = New-Object VMware.Vim.KeyAnyValue
		$TEMP.Key = 'service'
		$TEMP.Value = $FIPS.Name
		$TEMPARRAY += $TEMP
		$TEMP = New-Object VMware.Vim.KeyAnyValue
		$TEMP.Key = 'enabled'
		$TEMP.Value = $FIPS.Enablement
		$TEMPARRAY += $TEMP
		$PROFILE.Policy[0].PolicyOption[0].Parameter = New-Object VMware.Vim.KeyAnyValue[] (2)
		$PROFILE.Policy[0].PolicyOption[0].Parameter = $TEMPARRAY
		$PROFILES += $PROFILE
		Write-Host "Completed enforcing FIPS Mode Configuration for Service $FIPSNAME"
	}

	($spec.ApplyProfile.Property | Where {$_.PropertyName -eq 'security_FipsProfile_FipsProfile'}).Profile = $PROFILES
}

##Set Service Configurations
#Set Service Array for Service Configuration
#Based on Default Settings except ntpd https://docs.vmware.com/en/VMware-vSphere/6.7/com.vmware.vsphere.security.doc/GUID-37AB1F95-DDFD-4A5D-BD49-3249386FFADE.html
$SVCSARRAY = @()
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'DCUI'	#Direct Console UI
$SVCSTEMP.StartupPolicy = 'On' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $False
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'TSM'	#ESXi Shell
$SVCSTEMP.StartupPolicy = 'Off' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $False
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'TSM-SSH'	#SSH Service
$SVCSTEMP.StartupPolicy = 'Off' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $True
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'lbtd'	#Load-Based Teaming Daemon
$SVCSTEMP.StartupPolicy = 'On' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $False
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'ntpd'	#NTP Daemon
$SVCSTEMP.StartupPolicy = 'On' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $False
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'pcscd' #PC/SC Smart Card Daemon
$SVCSTEMP.StartupPolicy = 'Off' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $False
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'sfcbd-watchdog'	#CIM Agent
$SVCSTEMP.StartupPolicy = 'Off' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $False
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'snmpd' #SNMP Server
$SVCSTEMP.StartupPolicy = 'Off' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $False
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'vmsyslogd'	#Syslog Server
$SVCSTEMP.StartupPolicy = 'On' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $True
$SVCSARRAY += $SVCSTEMP
$SVCSTEMP = "" | Select Name, StartupPolicy, Favorite
$SVCSTEMP.Name = 'xorg'	#X.Org Server
$SVCSTEMP.StartupPolicy = 'Off' #Set to On, Off, or Automatic
$SVCSTEMP.Favorite = $False
$SVCSARRAY += $SVCSTEMP

$PROFILES = @()
IF($SVCSARRAY)
{
	ForEach($SVCS in $SVCSARRAY)
	{
		$SVCSNAME = $SVCS.NAME
		Write-Host "Enforcing SVCS Mode Configuration for Service $SVCSNAME"
		$PROFILE = New-Object VMware.Vim.ProfileApplyProfileElement
		$PROFILE.Key = $SVCSNAME #$SVCS.Key 
		$PROFILE.Enabled = $True
		$PROFILE.ProfileTypeName = 'service_serviceProfile_ServiceConfigProfile'
		$PROFILE.ProfileVersion = '6.7.0'
		$PROFILE.Enabled = $True
		$PROFILE.Favorite = $SVCS.Favorite 
		$PROFILE.Policy += New-Object VMware.Vim.ProfilePolicy -Property @{Id='service.serviceProfile.ServiceNamePolicy'} 
		$PROFILE.Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
		$PROFILE.Policy[0].PolicyOption[0].Id = 'service.serviceProfile.ServiceNamePolicyOption'	
		
		$TEMPARRAY = @()
		$TEMP = New-Object VMware.Vim.KeyAnyValue
		$TEMP.Key = 'serviceId'
		$TEMP.Value = $SVCS.Name
		$TEMPARRAY += $TEMP
		$PROFILE.Policy[0].PolicyOption[0].Parameter = New-Object VMware.Vim.KeyAnyValue[] (1)
		$PROFILE.Policy[0].PolicyOption[0].Parameter = $TEMPARRAY
		
		$PROFILE.Policy += New-Object VMware.Vim.ProfilePolicy -Property @{Id='service.serviceProfile.ServiceConfigPolicy'}
		$PROFILE.Policy[1].PolicyOption = New-Object VMware.Vim.PolicyOption
		If($SVCS.StartupPolicy -eq 'On')
		{
			$PROFILE.Policy[1].PolicyOption[0].Id = 'service.serviceProfile.StartupPolicyOn'
		}
		If($SVCS.StartupPolicy -eq 'Off')
		{
			$PROFILE.Policy[1].PolicyOption[0].Id = 'service.serviceProfile.StartupPolicyOff'
			$TEMPARRAY = @()
			$TEMP = New-Object VMware.Vim.KeyAnyValue
			$TEMP.Key = 'status'
			$TEMP.Value = $False #Turn on Service Check box
			$TEMPARRAY += $TEMP
			$PROFILE.Policy[1].PolicyOption[0].Parameter = New-Object VMware.Vim.KeyAnyValue[] (1)
			$PROFILE.Policy[1].PolicyOption[0].Parameter = $TEMPARRAY
		}
		If($SVCS.StartupPolicy -eq 'Automatic')
		{
			$PROFILE.Policy[1].PolicyOption[0].Id = 'service.serviceProfile.StartupPolicyAutomatic'
			$TEMPARRAY = @()
			$TEMP = New-Object VMware.Vim.KeyAnyValue
			$TEMP.Key = 'status'
			$TEMP.Value = $False #Turn on Service Check box
			$TEMPARRAY += $TEMP
			$PROFILE.Policy[1].PolicyOption[0].Parameter = New-Object VMware.Vim.KeyAnyValue[] (1)
			$PROFILE.Policy[1].PolicyOption[0].Parameter = $TEMPARRAY
		}
		
		$PROFILES += $PROFILE
		Write-Host "Completed enforcing SVCS Mode Configuration for Service $SVCSNAME"
	}

	($spec.ApplyProfile.Property | Where {$_.PropertyName -eq 'service_serviceProfile_ServiceConfigProfile'}).Profile = $PROFILES
}

##Enforing SATP Claimrule(s)
Write-Host "Enforcing/Setting SATP Claimrule(s)"
$CL = 0
($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile = New-Object VMware.Vim.ProfileApplyProfileElement[] ($SATPARRAY.count)
ForEach($SATP in $SATPARRAY)
{	
	Write-Host "Adding SATP Claimrule for"$SATP.Vendor
	Write-Output $SATP
	#($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile = New-Object VMware.Vim.ProfileApplyProfileElement
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL] = New-Object VMware.Vim.ProfileApplyProfileElement
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Key = $SATP.Vendor #'602486e6af0ae99dd02ebd6fd2ddf8c40e57eba85891cf64bb2864bf2e21c535'
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Enabled = $True
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].ProfileTypeName = 'nmp_nmpProfile_SatpClaimrulesProfile'
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].ProfileVersion = '6.7.0'
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Favorite = $true
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy = New-Object VMware.Vim.ProfilePolicy[] (2)
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[0] = New-Object VMware.Vim.ProfilePolicy
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[0].Id = 'nmp.nmpProfile.SatpClaimInformationPolicy'
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[0].PolicyOption = New-Object VMware.Vim.PolicyOption
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[0].PolicyOption[0].Id = 'nmp.nmpProfile.SatpClaimInformationPolicyOption'

	$SATPCLAIMARRAY = $null
	$SATPCLAIMARRAY = @()
	$SATPCLAIMTEMP = "" | Select Key, Value
	$SATPCLAIMTEMP.Key = 'satpName'
	$SATPCLAIMTEMP.Value = $SATP.SATPname
	$SATPCLAIMARRAY += $SATPCLAIMTEMP
	$SATPCLAIMTEMP = "" | Select Key, Value
	$SATPCLAIMTEMP.Key = 'claimOptions'
	$SATPCLAIMTEMP.Value = $SATP.ClaimOptions
	$SATPCLAIMARRAY += $SATPCLAIMTEMP
	$SATPCLAIMTEMP = "" | Select Key, Value
	$SATPCLAIMTEMP.Key = 'description'
	$SATPCLAIMTEMP.Value = $SATP.Description
	$SATPCLAIMARRAY += $SATPCLAIMTEMP
	$SATPCLAIMTEMP = "" | Select Key, Value
	$SATPCLAIMTEMP.Key = 'options'
	$SATPCLAIMTEMP.Value = $SATP.Options
	$SATPCLAIMARRAY += $SATPCLAIMTEMP
	$SATPCLAIMTEMP = "" | Select Key, Value
	$SATPCLAIMTEMP.Key = 'pspName'
	$SATPCLAIMTEMP.Value = $SATP.PSPName
	$SATPCLAIMARRAY += $SATPCLAIMTEMP
	$SATPCLAIMTEMP = "" | Select Key, Value
	$SATPCLAIMTEMP.Key = 'pspOptions'
	$SATPCLAIMTEMP.Value = $SATP.PSPOptions
	$SATPCLAIMARRAY += $SATPCLAIMTEMP

	$TEMPARRAY = @()
	ForEach($SATPCLAIM in $SATPCLAIMARRAY)
	{
		$TEMP = New-Object VMware.Vim.KeyAnyValue
		$TEMP.Key = $SATPCLAIM.Key
		$TEMP.Value = $SATPCLAIM.Value
		$TEMPARRAY += $TEMP
	}
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[0].PolicyOption[0].Parameter = $TEMPARRAY
	
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[1] = New-Object VMware.Vim.ProfilePolicy
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[1].Id = 'nmp.nmpProfile.SatpClaimTypePolicy'
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[1].PolicyOption = New-Object VMware.Vim.PolicyOption
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[1].PolicyOption[0].Id = 'psa.common.VendorModelPolicyOption'
	
	#Select Vendor, Model, SATPname, ClaimOptions, Description, Options, PSPName, PSPOptions
	$SATPCLAIMARRAY = $null
	$SATPCLAIMARRAY = @()
	$SATPCLAIMTEMP = "" | Select Key, Value
	$SATPCLAIMTEMP.Key = 'vendorName'
	$SATPCLAIMTEMP.Value = $SATP.Vendor
	$SATPCLAIMARRAY += $SATPCLAIMTEMP
	$SATPCLAIMTEMP = "" | Select Key, Value
	$SATPCLAIMTEMP.Key = 'model'
	$SATPCLAIMTEMP.Value = $SATP.Model
	$SATPCLAIMARRAY += $SATPCLAIMTEMP
	$TEMPARRAY = @()
	ForEach($SATPCLAIM in $SATPCLAIMARRAY)
	{
		$TEMP = New-Object VMware.Vim.KeyAnyValue
		$TEMP.Key = $SATPCLAIM.Key
		$TEMP.Value = $SATPCLAIM.Value
		$TEMPARRAY += $TEMP
	}
	($spec.ApplyProfile.Storage.Property | where {$_.PropertyName -eq 'nmp_nmpProfile_NativeMultiPathingProfile'}).Profile[0].Property[0].Profile[0].Property[0].Profile[$CL].Policy[1].PolicyOption[0].Parameter = $TEMPARRAY
	$CL = $CL+1
	Write-Host "Completed adding SATP Claimrule for"$SATP.Vendor
}
Write-Host "Completed adding Best Practices Configuration"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

###Write SPEC back to Host Profile
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Writing updated Host Profile SPEC back to Host Profile"
$hp.ExtensionData.UpdateHostProfile($spec)
Write-Host "Completed writing updated Host Profile SPEC back to Host Profile"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Update Name of Host Profile
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Renaming Host Profile post Creation/Configuration"
$PROFILEDATE = (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Get-VMHostProfile -Name (($CLUSTER.Name) + "_temp") | Set-VMHostProfile -Name (($CLUSTER.Name) + "_Cluster_" + $PROFILEDATE)
Write-Host "Completed tenaming Host Profile post Creation/Configuration"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Apply Host Profile to Cluster
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Applying All VMHosts in Cluster $CLUSTER to Host Profile"(($CLUSTER.Name) + "_Cluster_" + $PROFILEDATE) 
$HOSTPROFILE = Get-VMHostProfile -Name (($CLUSTER.Name) + "_Cluster_" + $PROFILEDATE)
Apply-VMHostProfile -AssociateOnly -Entity $CLUSTER -Profile $HOSTPROFILE -Confirm:$false
Write-Host "Completed applying All VMHosts in Cluster $CLUSTER to Host Profile"(($CLUSTER.Name) + "_Cluster_" + $PROFILEDATE) 
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Export Host Profile to VPF File
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Exporting Host Profile to VPF File"
##Specify Export File Info
$EXPORTFILENAME = (($CLUSTER.Name) + "_Cluster_" + $PROFILEDATE) + "_host_profile.vpf"
#Create Export Folder
$ExportFolder = $pwd.path+"\Export"
If (Test-Path $ExportFolder){
	Write-Host "Export Directory Created. Continuing..."
}Else{
	New-Item $ExportFolder -type directory
}
#Specify Log File
$EXPORTFILE = $pwd.path+"\Export\"+$EXPORTFILENAME
Write-Host "Exporting Host Profile to VPF File to $EXPORTFILE"
Export-VMHostProfile -FilePath $EXPORTFILE -Profile $HOSTPROFILE
Write-Host "Completed exporting Host Profile to VPF File to $EXPORTFILE"
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
