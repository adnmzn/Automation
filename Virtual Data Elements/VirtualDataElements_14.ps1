<# DETAILS
=======================================
SCRIPT:      VirtualDataElements_13.ps1
AUTHOR:      V.M. (left IBM)
VERSION:     v.13
=======================================
\
   NOTES
   ======
   1. Local Mode:
   Run this script locally on a vCenter Server no user input is required.
		USAGE:
		------
   a) Start PowerCLI, change to script directory
   b) Invoke the script. ex:"PS C:\temp\virtualDataElements> .\VirtualDataElements_13.ps1
  
  2. Remote Mode
   In case there script detects no local vCenter Server it will ask for remote server.
		USAGE:
		------
   a) Start PowerCLI, change to script directory
   b) Invoke the script. ex:"PS C:\temp\virtualDataElements> .\VirtualDataElements_13.ps1 -remote
#>

#-----------
# Parameters
#-----------
Param(
	[parameter(Mandatory=$false)]
	[string]$CredentialFile
)
Clear-Host

#-----------------
# Static Variables
#-----------------
$StartDate = Get-Date
$date2s = $StartDate.ToString("yyyy-M-d-h.m.s.ms")
$scriptName = "VirtualDataElements"
$scriptVer = "14"
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$logDir = $scriptDir + "\VirtualDataElements_Logs\"
If (!(Test-Path $logDir)) {New-Item -ItemType directory -Path $logDir | Out-Null}
$logfile = $logDir + $scriptName + "_" + (Get-Date -uformat %m-%d-%Y_%I-%M-%S) + "_" + $env:username + ".txt"
$ClusterHashTable = @{}
$pTSVArray = @()

#-----------
# Functions
#-----------

Function Out-Log 
    {
	Param([Parameter(Mandatory=$true)][string]$LineValue,[Parameter(Mandatory=$false)][string]$fcolor = "White")
	Add-Content -Path $logfile -Value $LineValue
	Write-Host $LineValue -ForegroundColor $fcolor
    }

Function Get-VMDRSGroup 
    {
	Param (
		$ClusterObject, $VMId
	)
	
	If ($ClusterObject.Name -ne 'host') {
	
	
		If (!$ClusterHashTable[$ClusterObject.Name]) {
			$TempCluster = $ClusterObject
			
			If ($TempCluster) {
			
				$TempCluster.ExtensionData.UpdateViewData("ConfigurationEx")
				$ClusterDRSGroups = $TempCluster.ExtensionData.ConfigurationEx.Group
				$DRSVMGroups = $ClusterDRSGroups | Where {$_.VM}
				#$DRSHostGroups = $ClusterDRSGroups | Where {$_.Host}
				#$ClusterDRSRules = $TempCluster.ExtensionData.ConfigurationEx.Rule | Where-Object -FilterScript {$_ -is [VMware.Vim.ClusterVmHostRuleInfo]}
				#$ClusterData = @{DRSVMGroups = $DRSVMGroups, DRSHostGroups = $DRSHostGroups, HostToVMRule = $ClusterDRSRules}
				#$ClusterHashTable.Add($ClusterObject.Name, $ClusterData)
				$ClusterHashTable.Add($ClusterObject.Name, $DRSVMGroups)
			}
		}
		
		$TempHash = $ClusterHashTable[$ClusterObject.Name]
		$DRSVMGroupName = ($TempHash | Where {$_.VM -contains $VMId}).Name
		If ($DRSVMGroupName) {
			
			Return "VM is a part of the ""$DRSVMGroupName"" VM DRS Group"
		}
		Else {
			Return "OK"
		}
	
	}
	
}

Function send_email 
    {
	$Error.Clear()
	$MailMessage = New-Object System.Net.Mail.Mailmessage
	$MailMessage.from = ($EmailFrom)
	$MailMessage.To.add($EmailTo)
	#$MailMessage.IsBodyHTML = $true
	#$MailMessage.BodyEncoding = [system.Text.Encoding]::Unicode 
	#$MailMessage.SubjectEncoding = [system.Text.Encoding]::Unicode 
	$MailMessage.Subject = $EmailSubject
	$MailMessage.Body = $emailbody
	$Attachment = New-Object System.Net.Mail.Attachment($EmailAttachment, 'text/plain')
	$MailMessage.Attachments.Add($Attachment)

	$SMTPClient = New-Object Net.Mail.SmtpClient($XMLSMTPServer, $XMLSMTPPort)
	If ($XMLSMTPUseSSL -eq "Yes") {
		$SMTPClient.EnableSsl = $true
	}
	Else {
		$SMTPClient.EnableSsl = $false
	}
	
	If ($XMLSMTPUser) {
		$SMTPClient.Credentials = New-Object System.Net.NetworkCredential($XMLSMTPUser, $PlainSMTPPassword);
	}
	
	$SMTPClient.Send($MailMessage)
	
	If (!$?) {
			$EmailErrorMessage = $error
			Out-Log "$EmailErrorMessage" "Red"
			Out-Log "Automated e-mail send function failed, please check your smtp server connection & configuration" "Red"
		}
	
}

#------------------------------------
# Checks if script is running in an administrator mode
#------------------------------------

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$RunInAdminMode = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

If (!$RunInAdminMode -And !$CredentialFile) {
	Out-Log "PowerShell/PowerCLI is not running in ""Run As Administrator"" mode." "Red"
	exit
}

#------------------------------------
# Load Snap-in or Module if required
#------------------------------------
If(!(Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue)){
	$Error.Clear()
	Out-Log "Loading VMWare PowerCli.." "Yellow"
   	Add-PSSnapin VMware.VimAutomation.Core	-ErrorAction SilentlyContinue
	If (!$?) {
		$Error.Clear()
		Get-Module -Name VMware* -ListAvailable | Import-Module -ErrorAction SilentlyContinue
		If (!$?) {
			Out-Log "`nCannot load VMWare PowerCli.." "Red"
			Out-Log "$Error.Exception" "Red"
			Out-Log "Exiting..." "Red"
			Exit
		}
	}	
}

#Hardware serial number double check except Service Tag property
New-VIProperty -ObjectType VMHost -Name SerialNumber -Value {(Get-EsxCli -VMHost $Args[0]).hardware.platform.get().SerialNumber} | Out-Null

#--------------
# Start Logging
#--------------
Clear-Host
Out-Log "************************************************************************************************"
Out-Log "`t$scriptName`tVer:$scriptVer`tStart Time:`t$date2s"
Out-Log "`tThis screen is for your attention only and not part of the results"
Out-Log "`tFor troubleshooting see logdir: $logDir"
Out-Log "*************************************************************************************************`n"

#--------------------------------------------------------------------
# Check to ensure PowerCLI is at least version 5.5 R2 (Build 1649237)
#--------------------------------------------------------------------
If ((Get-PowerCLIVersion).Build -lt 1649237) {
	Out-Log "Error: vCenters script requires PowerCLI version 5.5 R2 (Build 1649237) or later" "Red"
	Out-Log "PowerCLI Version Detected: $((Get-PowerCLIVersion).UserFriendlyVersion)" "Red"
	Out-Log "Exiting...`n`n" "Red"
	Exit
}

If ($CredentialFile) {
	Out-Log "Running script in a xml credential file input mode" "Cyan"
}

Else {

	If ($global:defaultVIServers.Count -lt 1){#Case:0.1
		#-------------------------------------------------
		#Check how the script is ran:Localy or Remote Mode
		#-------------------------------------------------------
		#Checking if the script runs locally on a vCenter Server
		#-------------------------------------------------------
		

			Out-Log "Running script in manual input mode`n" "Yellow"
			$vCSrvFQDN = Read-Host "Please specify vCenter Server FQDN Name"
			Out-Log "You have chosen the following: $vCSrvFQDN`n" "Yellow"
			$ErrorActionPreference = "SilentlyContinue"
			$DNSTest = [System.Net.Dns]::GetHostByName("$vCSrvFQDN").AddressList.IpAddressToString
			
			If (!$?){#Case:1.2.1
				Out-Log "#Case:1.2.1 Unable to lookup name of the $vCSrvFQDN" "Yellow"
				#Out-Log "$Error" "Red"
				$vCSrvIP = Read-Host "Please specify vCenter Server IP Address"
				$vCSrv = $vCSrvIP
				Out-Log "Using IP $vCSrv for vCenter connection`n" "Yellow"
				$Error.Clear()
			}
			Else {
				$vCSrvIP = Read-Host "Please specify vCenter Server IP Address (Keep empty to use $DNSTest)"
				
				If (!$vCSrvIP) {
					$vCSrvIP = $DNSTest
				}
				
				$vCSrv = $vCSrvFQDN
				Out-Log "Using Hostname $vCSrv for vCenter connection`n" "Yellow"
			}
				
	}
	Else {#Case:0.2
		$ErrorActionPreference = "SilentlyContinue"
		$DNSTest = [System.Net.Dns]::GetHostByName("$global:defaultVIServer").AddressList.IpAddressToString
		If (!$?){
			$vCSrv = [System.Net.Dns]::GetHostByAddress("$global:defaultVIServer").HostName
			$vCSrvFQDN = $vCSrv
			$vCSrvIP = $global:defaultVIServer
		}
		Else {
			$vCSrv = ($global:defaultVIServer).Name
			$vCSrvFQDN = ($global:defaultVIServer).Name
			$vCSrvIP = $DNSTest
		}
		Out-Log "Case:0.2 You are already connected to the vCenter Server: $vCSrv `n" "Yellow"
	}

	Out-Log "Connecting to vCenter - $vCSrv`n" "White"
	$Error.Clear()
	$ErrorActionPreference = "SilentlyContinue"
	Set-PowerCLIConfiguration -DefaultVIServerMode Single -InvalidCertificateAction Ignore -Scope Session -Confirm:$false  | Out-Null
	Connect-VIServer $vCSrv |  Out-Null
	If (!$?){
		Out-Log "Unable to connect to $vCSrv" "Red"
		Out-Log "$Error.Exception" "Red"
		Out-Log "`nYou are not connected to any vCenter Server" "Red"
		Out-Log "Exiting..." "Red"
		Exit
	}

}

$MainScriptBlock = {

	$myCol = @()
	$allVMHosts = Get-VMHost | Sort
	#ForEach ($vmhost in (Get-VMHost | Sort)){
	ForEach ($vmhost in $allVMHosts){
		Out-Log "Checking $vmhost" "Cyan"
		
		#$xVMs = Get-VMHost $vmhost | get-vm | Measure-Object | Select Count -ExpandProperty Count
		
		#Capture all VMs on the $vmhost
		$hostVMs = $vmhost | get-vm
		
		#Count number of VMs on the $vmhost
		$xVMs = $hostVMs.count
		
		If (($xVMs -like "0") -or ($xVMs -like $NULL)) {
		Out-Log "There are no VMs on this ESXi host: $vmhost`n" "Yellow"
			$ghs 	= Get-vmhost $vmhost
			$hsView = $ghs | Get-View
			$hsMoRef = $ghs.ExtensionData.MoRef
			$cluster =	$ghs.Parent.Name
			$gclu 	= Get-cluster "$cluster"
			$clView = $gclu | Get-View
			$mgtSrvIP = $vCSrvIP
			$mgtSrvName = $vCSrvFQDN

			$vmSummary = "" | Select vmName,vmUniqID,vmPowerState,vmUptimeDays,vmOS,vmCPU,vmCorePerSckt,vmCPUSkts,hsName,hsUniqID,hsStatus,hsManufacturer,hsHWType,hsSerial,hsOS,hsOSver,hsOSbld, `
			hsMemorySizeGB,cluName,cluHAEnabled,vmHAprot,cluDrsEnabled,cluDrsAutoLvl,vmDRSprot,vmCanMigrate,vmMigInf,vmAutovMotion,hsCPUModel,hsCPUSockets,hsCPUCores,hsCPUThreads,hsCPUHyperThreading, `
			gTimeStamp,vmName2,vmState,vmTools,vmToolsVer,vmOSSource,vCenterName
		
			$vmSummary.vmName = "No_VMs"
			$vmSummary.vmUniqID = "$Null"
			$vmSummary.vmPowerstate	= "$Null"
			$vmSummary.vmUptimeDays = "$Null"
			$vmSummary.vmOS = "$Null"
			$vmSummary.vmCpu = "$Null"
			$vmSummary.vmCorePerSckt = "$Null"
			$vmSummary.vmCPUSkts = "$Null"
			$vmSummary.hsName = $ghs.Name
			$vmSummary.hsUniqID = $hsMoRef
			$vmSummary.hsStatus = $ghs.ConnectionState
			$vmSummary.hsManufacturer = $hsView.Summary.Hardware.Vendor
			$vmSummary.hsHWType = $hsView.Summary.Hardware.Model
			$vmSummary.hsSerial = $ghs.SerialNumber
			$vmSummary.hsOS = $hsView.Summary.config.product.Name
			$vmSummary.hsOSver = $hsView.Summary.config.product.Version
			$vmSummary.hsOSbld = $hsView.Summary.config.product.Build
			$vmSummary.hsMemorySizeGB = $hsView.hardware.memorysize / 1024Mb
			$vmSummary.hsCPUModel = $hsView.Summary.Hardware.CpuModel
			$vmSummary.hsCPUSockets = $hsView.Summary.Hardware.NumCpuPkgs
			$vmSummary.hsCPUCores = $hsView.Summary.Hardware.NumCpuCores
			$vmSummary.hsCPUThreads = $hsView.Summary.Hardware.NumCpuThreads
			$vmSummary.hsCPUHyperThreading = $ghs.HyperthreadingActive
			$vmSummary.cluName = $gclu.Name
			$vmSummary.cluHAEnabled = $gclu.HAEnabled
			$vmSummary.vmHAprot = "$Null"
			$vmSummary.cluDrsEnabled = $gclu.DrsEnabled
			$vmSummary.cluDrsAutoLvl = $gclu.DrsAutomationLevel
			$vmSummary.vmDRSprot =  "$Null"
			$vmSummary.vmCanMigrate = "$Null"
			$vmSummary.vmMigInf = "$Null"
			$vmSummary.vmAutovMotion = "$Null"
			$vmSummary.gTimeStamp = $date2s
			$vmSummary.vmName2 = "$Null"
			$vmSummary.vmState = "$Null"
			$vmSummary.vmTools = "$Null"
			$vmSummary.vmToolsVer = "$Null"
			$vmSummary.vmOSSource = "$Null"
			$vmSummary.vCenterName = $mgtSrvName

			
			$myCol += $vmSummary
		}
		Else { #Do normal query all the VMs in the Host
			ForEach ($sgvm in ($hostVMs)){

				#$ghs 	= Get-vmhost $vmhost
				$ghs 	= $vmhost
				#$hsView = Get-vmhost $vmhost | Get-View
				$hsView = $ghs | Get-View
				$hsMoRef = $ghs.ExtensionData.MoRef
				$cluster =	$ghs.Parent.Name
				$gclu 	= Get-cluster "$cluster"
				
				#$clView = Get-cluster "$cluster" | Get-View
				$clView = $gclu | Get-View
				
				#$gvm 	= Get-vmhost $vmhost | Get-vm $sgvm
				$gvm 	= $sgvm
				
				#$vmView = Get-vmhost $vmhost | Get-vm $sgvm  | Get-View
				$vmView = $sgvm  | Get-View
				
				$vmMoRef = $gvm.ExtensionData.MoRef
				$mgtSrvIP = $vCSrvIP				
				$mgtSrvName = $vCSrvFQDN


				$vmSummary = "" | Select vmName,vmUniqID,vmPowerState,vmUptimeDays,vmOS,vmCPU,vmCorePerSckt,vmCPUSkts,hsName,hsUniqID,hsStatus,hsManufacturer,hsHWType,hsSerial,hsOS,hsOSver,hsOSbld, `
				hsMemorySizeGB,cluName,cluHAEnabled,vmHAprot,cluDrsEnabled,cluDrsAutoLvl,vmDRSprot,vmCanMigrate,vmMigInf,vmAutovMotion,hsCPUModel,hsCPUSockets,hsCPUCores,hsCPUThreads,hsCPUHyperThreading, `
				gTimeStamp,vmName2,vmState,vmTools,vmToolsVer,vmOSSource,vCenterName
				
				$vmSummary.vmName = $gvm.Guest.HostName
				If ($gvm.Guest.HostName -eq $NULL -Or $gvm.Guest.HostName -eq ""){
					$vmSummary.vmName = $gvm.Name
				}
				$vmSummary.vmUniqID = $gvm.Id
				$vmSummary.vmPowerstate	= $gvm.Powerstate
				If ($gvm.Powerstate -eq "PoweredOff"){
					$vmOFF = Get-VIevent -Entity $sgvm -MaxSamples ([int]::MaxValue) | Where {$_ -is [VMware.Vim.VmPoweredOffEvent]}| Sort-Object -Property CreatedTime -Descending |  `
					Select -First 1 | Select CreatedTime -ExpandProperty CreatedTime
					If ($vmOFF -eq $NULL){
						$dVCSet = Get-AdvancedSetting -Entity $mgtSrvName -Name task.maxage
						If (!$?){
							$dVCSet = "90"
							$vmOFF = (Get-Date).AddDays(-($dVCSet))
							$Error.Clear()
						}
						Else {
						$vmOFF = (Get-Date).AddDays(-($dVCSet.Value))
						}
					}

					$tDiff = New-TimeSpan -start $(Get-date) -end $vmOFF | Select TotalHours -ExpandProperty TotalHours
					$vmSummary.vmUptimeDays = $tDiff/24
				} 
				Else {
					$vmSummary.vmUptimeDays = $vmView.Summary.QuickStats.UptimeSeconds/86400
				}
				
				$vmSummary.vmOS = $gvm.Guest.OSFullName
				
				#Limiting the number of the OS characters to 68 (ex: Linux 3.12.59-60.41-default SUSE Linux Enterprise Server 12 (x86_64)). For some types of RHEL the length is excessively long.
				#In case you are encountering errors please send an email the Asset Management team with details.
				If ($gvm.Guest.OSFullName -eq $Null){
					If ($gvm.ExtensionData.Summary.Config.GuestFullName.Length -gt 68){
						$pos = $gvm.ExtensionData.Summary.Config.GuestFullName.IndexOf(")")
						$vmSummary.vmOS = $gvm.ExtensionData.Summary.Config.GuestFullName.Substring(0, $pos+1)
					} Else {
					$vmSummary.vmOS = $gvm.ExtensionData.Summary.Config.GuestFullName
					}
					$vmSummary.vmOSSource = "vCenter"
				}
				Else {
					$vmSummary.vmOSSource = "VMTools/OS"
				}
				If ($gvm.Guest.OSFullName.Length -gt 68){
					$pos = $gvm.Guest.OSFullName.IndexOf(")")
					$vmSummary.vmOS = $gvm.Guest.OSFullName.Substring(0, $pos+1)
				}
				$vmSummary.vmCpu = $gvm.NumCpu
				$vmSummary.vmCorePerSckt = $gvm.ExtensionData.Config.Hardware.NumCoresPerSocket
				$vmSummary.vmCPUSkts = $vmSummary.vmCpu/$vmSummary.vmCorePerSckt
				$vmSummary.hsName = $ghs.Name
				$vmSummary.hsUniqID = $hsMoRef
				$vmSummary.hsStatus = $ghs.ConnectionState
				$vmSummary.hsManufacturer = $hsView.Summary.Hardware.Vendor
				$vmSummary.hsHWType = $hsView.Summary.Hardware.Model
				$vmSummary.hsSerial = $ghs.SerialNumber
				$vmSummary.hsOS = $hsView.Summary.config.product.Name
				$vmSummary.hsOSver = $hsView.Summary.config.product.Version
				$vmSummary.hsOSbld = $hsView.Summary.config.product.Build
				$vmSummary.hsMemorySizeGB = $hsView.hardware.memorysize / 1024Mb
				$vmSummary.hsCPUModel = $hsView.Summary.Hardware.CpuModel
				$vmSummary.hsCPUSockets = $hsView.Summary.Hardware.NumCpuPkgs
				$vmSummary.hsCPUCores = $hsView.Summary.Hardware.NumCpuCores
				$vmSummary.hsCPUThreads = $hsView.Summary.Hardware.NumCpuThreads
				$vmSummary.hsCPUHyperThreading = $ghs.HyperthreadingActive
				$vmSummary.cluName = $gclu.Name
				$vmSummary.cluHAEnabled = $gclu.HAEnabled
				$vmSummary.vmHAprot = $gvm.ExtensionData.Runtime.DasVmProtection.DasProtected
				$vmSummary.cluDrsEnabled = $gclu.DrsEnabled
				$vmSummary.cluDrsAutoLvl = $gclu.DrsAutomationLevel
				$vmSummary.vmDRSprot =  $gvm.DrsAutomationLevel
				
				If (($gclu.DrsEnabled -eq $False) -or ($gclu.DrsEnabled -eq $NULL)) { 
					$vmSummary.vmAutovMotion = $False 
					$vmSummary.vmCanMigrate = $True
					$vmSummary.vmMigInf = "DRSDisabled"
				}
				Else {
	
					$vmSummary.vmCanMigrate = $True
					If ($gclu) {
						$VMDRSGroupInfo = Get-VMDRSGroup -ClusterObject $gclu -VMId $sgvm.Id
						$vmSummary.vmMigInf = $VMDRSGroupInfo
						Out-Log "DRS for $gvm : $VMDRSGroupInfo `n" "Green"
					}
					Else {
						$vmSummary.vmMigInf = "OK"
						Out-Log "vMotion is OK for $gvm`n" "Green"

					}

					#Checking if the virtual machine will be automatically vMotion-ed by the DRS Cluster
					If (($gclu.DrsEnabled -eq $True) -and ($gclu.DrsAutomationLevel -ne "FullyAutomated")) {
						$vmSummary.vmAutovMotion = $False 
					} 
					ElseIf ((($gclu.DrsEnabled -eq $True) -and ($gclu.DrsAutomationLevel -eq "FullyAutomated")) -and (($gvm.DrsAutomationLevel -ne "FullyAutomated") -and  `
					($gvm.DrsAutomationLevel  -ne "AsSpecifiedByCluster"))) { 
						$vmSummary.vmAutovMotion = $False 
					}
					ElseIf ($vmSummary.vmCanMigrate -eq $False) {
						$vmSummary.vmAutovMotion = $False
					}
					Else {
						$vmSummary.vmAutovMotion = "TRUE"
					}
				}
				
				$vmSummary.gTimeStamp = $date2s
				$vmSummary.vmName2 = $gvm.Name
				$vmSummary.vmState = $vmView.Guest.GuestState
				$vmSummary.vmTools = $vmView.Guest.ToolsRunningStatus
				$vmSummary.vmToolsVer = $gvm.Guest.ToolsVersion #modified for the number not the build
				$vmSummary.vCenterName = $mgtSrvName #modified column to vCenterName
				$myCol += $vmSummary
			}
		}
	}
	# 	Report will be written on the same location from which the script is executed.
	$pCSV = "$ScriptDir"+"\"+"$vCSrvFQDN" + "_VMW.csv"
	$pTSV = "$ScriptDir"+"\"+"$vCSrvFQDN" + "_VMW.tsv"
	$pTSVArray += $pTSV
	Out-Log "Writing results in temporary file..." "Green"
	$myCol | Export-Csv -Delimiter "`t" -NoTypeInformation -Path "$pCSV"
	Get-Content -Path "$pCSV" | % { $_ -replace '"', ""} | out-file -FilePath "$pTSV" -fo -en ascii
	Out-Log "Results file is: $pTSV`n" "Green"
	Out-Log "Removing temporary file: $pCSV`n" "Yellow"
	Remove-Item -Path "$pCSV"
	Out-Log "Disconnecting VI... " "Cyan"
	DisConnect-VIServer * -Force -Confirm:$False | Out-Null
	
	$FinishDate = Get-Date
	$RunTimeInSeconds = (New-TimeSpan $StartDate $FinishDate).TotalSeconds
	Out-Log "Total script runtime: $RunTimeInSeconds s"

}

If (!$CredentialFile) {
	. $MainScriptBlock
}
Else {

	([System.XML.XMLDocument]$XMLDocument = New-Object System.Xml.XmlDocument) | Out-Null
	$XMLDocument.Load($CredentialFile)
	
	$XMLEncryptedByUser = $XMLDocument.document.Encryption.EncryptedByUser
	$XMLEncryptedOnComputer = $XMLDocument.document.Encryption.EncryptedOnComputer
	
	$CurrentUserRunningScript = $env:username
	$CurrentComputer = $Env:ComputerName
	
	If (!($XMLEncryptedByUser -match $CurrentUserRunningScript)) {
		Out-Log "The script is not running under account $XMLEncryptedByUser, which was used for encryption of passwords. Only this account can decrypt passwords inside .xml file" "Red"
		$ExitInNextStep = $true
	}
	
	If (!($XMLEncryptedOnComputer -match $CurrentComputer)) {
		Out-Log "The script is not running on computer $XMLEncryptedOnComputer, on which passwords were encrypted. Script must be run on a same computer to decrypt passwords inside .xml file" "Red"
		$ExitInNextStep = $true
	}
	
	$XMLvCenters = $XMLDocument.document.vCenters.ChildNodes
	
	$XMLSMTPServer = $XMLDocument.document.Email.SMTPServer
	$XMLSMTPPort = $XMLDocument.document.Email.SMTPPort
	$XMLSMTPUseSSL = $XMLDocument.document.Email.UseSSL
	$XMLSMTPUser = $XMLDocument.document.Email.SMTPUser
	$XMLSMTPPassword = $XMLDocument.document.Email.SMTPPassword
	$XMLEmailCC = $XMLDocument.document.Email.EmailCC
	$XMLEmailSender = $XMLDocument.document.Email.Sender
	$XMLCustomerName = $XMLDocument.document.Email.Customer
	
	If ($XMLSMTPPassword) {
		$EncryptedSMTPPassword = ConvertTo-SecureString $XMLSMTPPassword
		$PlainSMTPPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($EncryptedSMTPPassword))
	}

	Foreach ($XMLvCenter in $XMLvCenters) {

		$ErrorActionPreference = "SilentlyContinue"
		$vCSrvFQDN = $XMLvCenter.FQDN
		$vCSrvIP = $XMLvCenter.IP
		$vCSrv = [System.Net.Dns]::GetHostByName($vCSrvFQDN).Hostname
		If (!$?) {
			Out-Log "Unable to lookup name of the $vCSrvFQDN, using IP $vCSrvIP" "Yellow"
			$vCSrv = $vCSrvIP
		}
		$Error.Clear()
		$EncryptedvCenterPassword = ConvertTo-SecureString $XMLvCenter.Password
		$PlainvCenterPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($EncryptedvCenterPassword))
		Out-Log "Connecting to vCenter - $vCSrv`n" "White"
		Connect-VIServer -Server $vCSrv -User $XMLvCenter.User -Password $PlainvCenterPassword
		If (!$?){
			Out-Log "Unable to connect to $vCSrv" "Red"
			Out-Log "$Error.Exception" "Red"
		}
		Else {
			. $MainScriptBlock
		}
	}
	
	$EmailFrom = "<" + $XMLEmailSender + ">"
	If ($XMLEmailCC) {
			$EmailTo = "<SW.CoC.VMWARE.SCRIPT.MANAGEMENT@cz.ibm.com>, <" + $XMLEmailCC + ">"
			#$EmailTo = "<" + $XMLEmailCC + ">"
	}
	Else {
		$EmailTo = "<SW.CoC.VMWARE.SCRIPT.MANAGEMENT@cz.ibm.com>"
	}
	
	If ($XMLSMTPServer -And $XMLSMTPPort) {

		$TemporaryOutputFolder = $scriptDir + "\tempzipoutput"
		$ZipFullPath = $scriptDir + "\" + $XMLCustomerName + "-" + $date2s + ".zip"
		New-Item $TemporaryOutputFolder -ItemType Directory | Out-Null
		Copy-Item $pTSVArray -Destination $TemporaryOutputFolder | Out-Null
		Add-Type -A System.IO.Compression.FileSystem
		[IO.Compression.ZipFile]::CreateFromDirectory($TemporaryOutputFolder, $ZipFullPath)

		$EmailSubject = "<" + $XMLCustomerName + ">: VMware script output report" 
		$vCentersList = $XMLvCenters.FQDN -join "`n"
		$emailBody = "<" + $XMLCustomerName + ">: VMware script output report `nList of vCenters: `n" + $vCentersList
		$EmailAttachment = $ZipFullPath
		
		$TempFilesToDelete = $TemporaryOutputFolder + "\*"
		
		Remove-Item $TempFilesToDelete -Force -Recurse
		Remove-Item $TemporaryOutputFolder -Force
		
		Out-Log "Sending an automated e-mail with report" "Yellow"
		send_email

	}
	
}