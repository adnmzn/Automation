$scriptPath = Split-Path -parent $MyInvocation.MyCommand.Definition
$vCenterCredentialFileName = "vCenters-Logon.xml"
$LocalComputer = $Env:ComputerName

$NextvCenter = $false
$vCenterNo = 1

Function EncryptDataWithServiceAccount {

	param ([string]$InputString, [string]$ServiceAccount, $ServicePassword)
	
	$SplittedScriptPaths = ([string]$scriptPath).split("\")
	$QuotedScriptPath = ""
	ForEach ($SplittedScriptPath In $SplittedScriptPaths) {
		If ($SplittedScriptPath -match ' ') {
			$QuotedScriptPath += "`"" + $SplittedScriptPath + "`"\"
		}
		Else {
			$QuotedScriptPath += $SplittedScriptPath + '\'
		}
	}
	$QuotedScriptPath = $QuotedScriptPath.Replace('\"', '\\"')
	$QuotedTemporaryPSScript = $QuotedScriptPath + "temp.ps1"
	$QuotedTemporaryTXT = $QuotedScriptPath + "temp.txt"
	$TemporaryPSScript = $scriptPath + "\temp.ps1"
	$TemporaryTXT = $scriptPath + "\temp.txt"
	$NewPSInstanceArgument = "-File $QuotedTemporaryPSScript -PlainPassword $InputString -TXTFilePath $QuotedTemporaryTXT"
	$PowerShellExe = $pshome + "\powershell.exe"
	
	$ServiceUserPSInstanceCode = {
			param($PlainPassword, $TXTFilePath)
			$ReturnPassword = ConvertTo-SecureString $PlainPassword -AsPlainText -Force
			$ReturnPassword = ConvertFrom-SecureString $ReturnPassword
			Set-Content -Path $TXTFilePath -Value $ReturnPassword
	}
	
	Set-Content -Path $TemporaryPSScript -Value $ServiceUserPSInstanceCode

	$PSCredential = New-Object System.Management.Automation.PSCredential($ServiceAccount,$ServicePassword)
	Start-Process $PowerShellExe -Credential $PSCredential -NoNewWindow -Wait -ArgumentList $NewPSInstanceArgument
	
	$EncryptedString = Get-Content $TemporaryTXT
	
	Remove-Item -Path $TemporaryPSScript
	Remove-Item -Path $TemporaryTXT
	
	return $EncryptedString
	
}

Write-Host "Script for exporting encrypted credential file for automatic vCenter logon" -ForegroundColor White
Start-Sleep 1

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$RunInAdminMode = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

If (!$RunInAdminMode) {
	Write-Host "PowerShell/PowerCLI is not running in ""Run As Administrator"" mode." -ForegroundColor Red
	exit
}

$CustomerNameScriptBlock = {
	Write-Host "Please provide customer name: " -ForegroundColor Green
	$CustomerName = Read-Host
	
	If (!$CustomerName) {
		Write-Host "Customer name can't be empty" -ForegroundColor Red
		. $CustomerNameScriptBlock
	}
}

. $CustomerNameScriptBlock
	
$CurrentUser = $env:userdomain + "\" + $env:username
Write-Host ""
Write-Host "Notice: Only service account provided below will be able to decrypt passwords stored in output .xml file" -ForegroundColor Yellow
Write-Host "Password file must be generated on the same computer where script will be run or scheduled task created" -ForegroundColor Yellow
Write-Host ""
Write-Host "Please provide service user account, which will be used for scheduled task or script run (Enter to use current $CurrentUser):" -ForegroundColor Green
$ServiceUser = Read-Host

If ($ServiceUser -eq "") {
	$ServiceUser = $CurrentUser
}

$ServicePasswordScriptBlock = {
	Write-Host ("Please provide password for service account $ServiceUser" + ": ") -NoNewline -ForegroundColor Green
	$ServicePassword1 = Read-Host -AsSecureString
	Write-Host ("Please re-type password for service account $ServiceUser" + ": ") -NoNewline -ForegroundColor Green
	$ServicePassword2 = Read-Host -AsSecureString
	$ServicePlainPassword1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ServicePassword1))
	$ServicePlainPassword2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ServicePassword2))
	If ($ServicePlainPassword1 -ne $ServicePlainPassword2) {
		Write-Host "Passwords don't match" -ForegroundColor Red
		. $ServicePasswordScriptBlock
	}
}

. $ServicePasswordScriptBlock

Write-Host "Using service account $ServiceUser" -ForegroundColor White
Write-Host ""

$XMLFileScriptBlock = {
	Write-Host "Please provide credential .xml filename (Default=$vCenterCredentialFileName): " -NoNewline -ForegroundColor Green
	$CustomCredentialFileName = Read-Host
	
	If (!$CustomCredentialFileName -eq "") {
		If (!($CustomCredentialFileName.Substring($CustomCredentialFileName.Length - 4) -eq ".xml")) {
			Write-Host "Filename must end with .xml" -ForegroundColor Red
			. $XMLFileScriptBlock
		}
		Else {
			$vCenterCredentialFileName = $CustomCredentialFileName
		}
	}
}

. $XMLFileScriptBlock

Write-Host "Using xml filename $vCenterCredentialFileName for output" -ForegroundColor White

$XMLFullPath = $scriptPath + "\" + $vCenterCredentialFileName
([System.XML.XMLDocument]$XMLDocument = New-Object System.Xml.XmlDocument) | Out-Null
($XMLDocument.AppendChild($XMLDocument.CreateXmlDeclaration("1.0","UTF-8",$null))) | Out-Null
$XMLComment = "vCenter Credential File used by Global VMware Virtual Data Elements script"
($XMLDocument.AppendChild($XMLDocument.CreateComment($XMLComment))) | Out-Null
([System.XML.XMLElement]$XMLRoot = $XMLDocument.CreateElement("document")) | Out-Null
$XMLDocument.AppendChild($XMLRoot) | Out-Null
([System.XML.XMLElement]$XMLvCenters = $XMLDocument.CreateElement("vCenters")) | Out-Null
$XMLRoot.AppendChild($XMLvCenters) | Out-Null
([System.XML.XMLElement]$XMLEmail = $XMLDocument.CreateElement("Email")) | Out-Null
$XMLRoot.AppendChild($XMLEmail) | Out-Null
([System.XML.XMLElement]$XMLEncryption = $XMLDocument.CreateElement("Encryption")) | Out-Null
$XMLRoot.AppendChild($XMLEncryption) | Out-Null

[System.XML.XMLElement]$XMLEncryptedByUser = $XMLEncryption.AppendChild($XMLDocument.CreateElement("EncryptedByUser"))
[System.XML.XMLElement]$XMLEncryptedOnComputer = $XMLEncryption.AppendChild($XMLDocument.CreateElement("EncryptedOnComputer"))

$XMLDocument.document.Encryption.EncryptedByUser = $ServiceUser.ToString()
$XMLDocument.document.Encryption.EncryptedOnComputer = $LocalComputer.ToString()

Write-Host ""

$vCenterScriptBlock = {
	Do {
		If ($vCenterNo -eq 1) {
			$Message = "Please provide FQDN name of vCenter No. $vCenterNo" +  ": "
		}
		Else {
			$Message = "Please provide FQDN name of vCenter No. $vCenterNo (Enter to finish adding vCenters): "
		}
		Write-Host $Message -NoNewline -ForegroundColor Green
		$vCenterFQDN = Read-Host
		If ($vCenterFQDN -eq "" -And $vCenterNo -eq 1){
			Write-Host "You must provide at least one vCenter server" -ForegroundColor Red
			& $vCenterScriptBlock
		}
		If ($vCenterFQDN -ne "") {
			Write-Host ("Please provide IP of vCenter $vCenterFQDN" + ": ") -NoNewline -ForegroundColor Green
			$vCenterIP = Read-Host
			
			If ($vCenterNo -gt 1) {
				Write-Host ("Please provide service account for vCenter $vCenterFQDN logon (leave empty to use previous vCenter logon account $UserName)" + ": ") -NoNewline -ForegroundColor Green
				$TempUserName = Read-Host
				If ($TempUserName) {
					$UserName = $TempUserName
				}
			}
			Else {
				Write-Host ("Please provide service account for vCenter $vCenterFQDN logon (leave empty to use sched. task and script service account $ServiceUser)" + ": ") -NoNewline -ForegroundColor Green
				$TempUserName = Read-Host
				If ($TempUserName) {
					$UserName = $TempUserName
				}
				Else {
					$UserName = $ServiceUser
				}
			}
			
			$vCenterPasswordScriptBlock = {

				Write-Host ("Please provide password for user $UserName" + ": ") -NoNewline -ForegroundColor Green
				$Password1 = Read-Host -AsSecureString
				Write-Host ("Please re-type password for user $UserName" + ": ") -NoNewline -ForegroundColor Green
				$Password2 = Read-Host -AsSecureString
				$PlainPassword1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password1))
				$PlainPassword2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password2))
				If ($PlainPassword1 -ne $PlainPassword2) {
					Write-Host "Passwords don't match" -ForegroundColor Red
					. $vCenterPasswordScriptBlock
				}
			}
			
			If ($TempUserName) {
				. $vCenterPasswordScriptBlock
			}
			ElseIf ($vCenterNo -eq 1) {
				$Password1 = $ServicePassword2
				$Password2 = $ServicePassword2
				$PlainPassword1 = $ServicePlainPassword2
				$PlainPassword2 = $ServicePlainPassword2
			}

			If ($ServiceUser -match '\\') {
				$FullServiceUser = $ServiceUser
			}
			ElseIf ($ServiceUser -match "@") {
				$FullServiceUser = ($ServiceUser.Split("@"))[1] + "\" + ($ServiceUser.Split("@"))[0]
			}
			Else {
				$FullServiceUser = $LocalComputer + "\" + $ServiceUser
			}
			
			Write-Host "Adding encrypted credentials for user $UserName to $XMLFullPath" -ForegroundColor White
			Write-Host ""
			
			$Password2 = EncryptDataWithServiceAccount -InputString $PlainPassword2 -ServiceAccount $FullServiceUser -ServicePassword $ServicePassword2
			
			$CurrentvCenter = "vCenter" + $vCenterNo
			[System.XML.XMLElement]$XMLvCenter = $XMLvCenters.AppendChild($XMLDocument.CreateElement($CurrentvCenter))
				
			[System.XML.XMLElement]$XMLvCenterFQDN = $XMLvCenter.AppendChild($XMLDocument.CreateElement("FQDN"))
			[System.XML.XMLElement]$XMLvCenterIP = $XMLvCenter.AppendChild($XMLDocument.CreateElement("IP"))
			[System.XML.XMLElement]$XMLvCenterUser = $XMLvCenter.AppendChild($XMLDocument.CreateElement("User"))
			[System.XML.XMLElement]$XMLvCenterPassword = $XMLvCenter.AppendChild($XMLDocument.CreateElement("Password"))
				
			$XMLDocument.document.vCenters.$CurrentvCenter.FQDN = $vCenterFQDN.ToString()
			$XMLDocument.document.vCenters.$CurrentvCenter.IP = $vCenterIP.ToString()
			$XMLDocument.document.vCenters.$CurrentvCenter.User = $UserName.ToString()
			$XMLDocument.document.vCenters.$CurrentvCenter.Password = $Password2.ToString()
			$vCenterNo++
			$NextvCenter = $true
		}
		Else {
			$NextvCenter = $false
		}
	} While ($NextvCenter)
}

. $vCenterScriptBlock

$XMLDocument.Save($XMLFullPath)

Write-Host ""

$SchTaskConfirmationScriptBlock = {
	Write-Host ("Would you like to create a scheduled task on this computer running under $ServiceUser" + "? (y/n) ") -NoNewline -ForegroundColor Green
	$CreateScheduledTask = Read-Host
		
	If ($CreateScheduledTask -ne "y" -And $CreateScheduledTask -ne "n") {
		Write-Host "Not a valid option, please use (y/n)" -ForegroundColor Red
		. $SchTaskConfirmationScriptBlock
	}
}

. $SchTaskConfirmationScriptBlock

Write-Host ""

If ($CreateScheduledTask -eq "y") {
	$ScriptBlock5 = {
		$VDEScriptPath = $scriptPath + "\VirtualDataElements*.ps1"
		$VDEScriptExists = Test-Path -Path $VDEScriptPath
		If (!$VDEScriptExists) {
			Write-Host "Cannot find VirtualDataElements script in current folder $scriptPath" -ForegroundColor Red
			Write-Host "Please copy VirtualDataElements to folder $scriptPath and press Enter" -ForegroundColor Yellow
			Read-Host | Out-Null
			. $ScriptBlock5
		}
	}
	. $ScriptBlock5
	$VDEScriptFileName = (Get-ChildItem -Path $scriptPath | Where {$_.Name -like "VirtualDataElements*.ps1"})[-1].Name
	$VDEScriptPath = $scriptPath + "\" + $VDEScriptFileName
	
	$SMTPScriptBlock = {
		Write-Host "Please specify smtp server:port for automated e-mail reports (leave empty to just store results locally): " -NoNewline -ForegroundColor Green
		$SMTPInput = Read-Host
		If ($SMTPInput -and !($SMTPInput -match ":")) {
			Write-Host "SMTP server must be in server:port format" -ForegroundColor Red
			. $SMTPScriptBlock
		}
	}
	. $SMTPScriptBlock
	
	If ($SMTPInput) {
		$SMTPInputSplitted = $SMTPInput.Split(":")
		$SMTPServer = $SMTPInputSplitted[0]
		$SMTPPort = $SMTPInputSplitted[1]
		
		$EmailCCScriptBlock = {
			Write-Host "Please specify the cc e-mail address, which will receive automated report (leave empty to send just to the requesting team): " -NoNewline -ForegroundColor Green
			$EmailCC = Read-Host
			If ($EmailCC -and !($EmailCC -match "@") -and !($EmailCC -match ".")) {
				Write-Host "Not a correct e-mail addresss format" -ForegroundColor Red
				. $EmailCCScriptBlock
			}
		}
		. $EmailCCScriptBlock
		
		$EmailSenderScriptBlock = {
			Write-Host "Please specify the sender of the e-mail - for cases when smtp server allows only some domains (leave empty to use $CustomerName@donotreply.com): " -NoNewline -ForegroundColor Green
			$EmailSender = Read-Host
			If ($EmailSender -and !($EmailSender -match "@") -and !($EmailSender -match ".")) {
				Write-Host "Not a correct e-mail addresss format" -ForegroundColor Red
				. $EmailSenderScriptBlock
			}
		}
		. $EmailSenderScriptBlock
		
		If ($EmailSender -eq "") {
			$EmailSender = $CustomerName + "@donotreply.com"
		}		
		
		$STMPSSLConfirmationScriptBlock = {
			Write-Host ("Use SSL for SMTP server $SMTPServer" + "? (y/n) ") -NoNewline -ForegroundColor Green
			$UseSSLForSMTP = Read-Host
		
			If ($UseSSLForSMTP -ne "y" -And $UseSSLForSMTP -ne "n") {
			Write-Host "Not a valid option, please use (y/n)" -ForegroundColor Red
			. $STMPSSLConfirmationScriptBlock
			}
			Else {
				If ($UseSSLForSMTP -eq "y") {
					$UseSSLForSMTP = "Yes" }
				If ($UseSSLForSMTP -eq "n") {
					$UseSSLForSMTP = "No" }
			}
		}

		. $STMPSSLConfirmationScriptBlock
		
		Write-Host "Please specify the user for SMTP Server (leave empty if no authentication is required): " -NoNewline -ForegroundColor Green
		$SMTPUser = Read-Host
		
		If ($SMTPUser) {
			$SMTPasswordBlock = {
				
				Write-Host ("Please provide password for SMTP user $SMTPUser" + ": ") -NoNewline -ForegroundColor Green
				$SMTPPassword1 = Read-Host -AsSecureString
				Write-Host ("Please re-type password for SMTP user $SMTPUser" + ": ") -NoNewline -ForegroundColor Green
				$SMTPPassword2 = Read-Host -AsSecureString
				$SMTPPlainPassword1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SMTPPassword1))
				$SMTPPlainPassword2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SMTPPassword2))
				If ($SMTPPlainPassword1 -ne $SMTPPlainPassword2) {
					Write-Host "Passwords don't match" -ForegroundColor Red
					. $SMTPasswordBlock
				}			
			}
			. $SMTPasswordBlock
			Write-Host "Adding SMTP email configuration to $XMLFullPath" -ForegroundColor White
			$SMTPEncryptedPassword = EncryptDataWithServiceAccount -InputString $SMTPPlainPassword2 -ServiceAccount $FullServiceUser -ServicePassword $ServicePassword2
		}
		Else {
			$SMTPEncryptedPassword = ""
		}
		
		[System.XML.XMLElement]$XMLSMTPServer = $XMLEmail.AppendChild($XMLDocument.CreateElement("SMTPServer"))
		[System.XML.XMLElement]$XMLSMTPPort = $XMLEmail.AppendChild($XMLDocument.CreateElement("SMTPPort"))
		[System.XML.XMLElement]$XMLSMTPPort = $XMLEmail.AppendChild($XMLDocument.CreateElement("UseSSL"))
		[System.XML.XMLElement]$XMLSMTPUser = $XMLEmail.AppendChild($XMLDocument.CreateElement("SMTPUser"))
		[System.XML.XMLElement]$XMLSMTPPassword = $XMLEmail.AppendChild($XMLDocument.CreateElement("SMTPPassword"))
		[System.XML.XMLElement]$XMLSMTPEmailCC = $XMLEmail.AppendChild($XMLDocument.CreateElement("EmailCC"))
		[System.XML.XMLElement]$XMLSMTPSender = $XMLEmail.AppendChild($XMLDocument.CreateElement("Sender"))
		[System.XML.XMLElement]$XMLCustomerName = $XMLEmail.AppendChild($XMLDocument.CreateElement("Customer"))
		
		$XMLDocument.document.Email.SMTPServer = $SMTPServer.ToString()
		$XMLDocument.document.Email.SMTPPort = $SMTPPort.ToString()
		$XMLDocument.document.Email.UseSSL = $UseSSLForSMTP.ToString()
		$XMLDocument.document.Email.SMTPUser = $SMTPUser.ToString()
		$XMLDocument.document.Email.SMTPPassword = $SMTPEncryptedPassword.ToString()
		$XMLDocument.document.Email.EmailCC = $EmailCC.ToString()
		$XMLDocument.document.Email.Sender = $EmailSender.ToString()
		$XMLDocument.document.Email.Customer = $CustomerName.ToString()
		
		$XMLDocument.Save($XMLFullPath)
		
	}
	
	Write-Host ""
	
	$TargetFolderBlock = {
		Write-Host "Please provide full path to folder (including drive letter), where you would like to store the VirtualDataElements script & credential file used for scheduled task runs: (leave empty to use default C:\IBM\Scripts\VirtualDataElements): " -NoNewline -ForegroundColor Green
		$TargetFolder = Read-Host
		
		If (!$TargetFolder) {
		$TargetFolder = "C:\IBM\Scripts\VirtualDataElements"
		}
		
		If (!(Test-Path -Path $TargetFolder)) {
			New-Item $TargetFolder -ItemType Directory
		}
		Else {
			Write-Host "Folder $TargetFolder already exists, keeping the existing" -ForegroundColor Yellow
		}
		
		$TargetXMLFullPath = $TargetFolder + "\" + $vCenterCredentialFileName
		
		If (!(Test-Path -Path $TargetXMLFullPath)) {
			Copy-Item $XMLFullPath -Destination $TargetFolder
		}
		Else {
			$XMLFileOverwriteBlock = {
				Write-Host "XML file $TargetXMLFullPath already exists, do you want to overwrite it? (y/n): " -ForegroundColor Yellow
				$RewriteOption = Read-Host
				If ($RewriteOption -eq "y") {
					Copy-Item $XMLFullPath -Destination $TargetFolder -Force
					Write-Host "Overwriting the file $TargetXMLFullPath" -ForegroundColor Yellow
				}
				ElseIf ($RewriteOption -eq "n") {
					Write-Host "Cannot overwrite file $TargetXMLFullPath - please specify new folder" -ForegroundColor Red
					. $TargetFolderBlock
				}
				Else {
					Write-Host "Incorrect answer, please use (y/n)" -ForegroundColor Red
					. $XMLFileOverwriteBlock
				}
				
			}
			
			. $XMLFileOverwriteBlock
		}
		
		$ScheduledTaskFile = $TargetFolder + "\" + $VDEScriptFileName
		
		If (!(Test-Path -Path $ScheduledTaskFile)) {
			Copy-Item $VDEScriptPath -Destination $TargetFolder
		}
		Else {
		
				Write-Host "File $ScheduledTaskFile already exists, overwriting the file" -ForegroundColor Yellow
				Copy-Item $VDEScriptPath -Destination $TargetFolder -Force
		
		}
	}
	
	. $TargetFolderBlock
	
	$ScheduledTaskName = "VMware VirtualDataElemts Automated Report"
	$ScheduledTaskDescription = "Runs VMware VirtualDataElements PowerCLI script on vCenters provided in the .xml credential file"
	$ScheduledTaskCommand = $pshome + "\" + "powershell.exe"
	$ScheduledTaskArguments = "-WindowStyle Hidden -NonInteractive -Executionpolicy unrestricted -Command `"& $ScheduledTaskFile `" `"-CredentialFile $TargetXMLFullPath`" "
	$CurrentDate = Get-Date
	$Day = 4
	If ($CurrentDate.Day -le 4) {
		$Month = $CurrentDate.Month
	}
	Else {
		$Month = $CurrentDate.Month + 1
	}
	$Year = $CurrentDate.Year
	$Hour = 20
	$Minute = 0
	$ScheduledTaskStartTime = Get-Date -Minute $Minute -Hour $Hour -Day $Day -Month $Month -Year $Year
	$SchedulerService = New-Object -ComObject("Schedule.Service")
	$SchedulerService.Connect()
	$SchedulesRootFolder = $SchedulerService.GetFolder("\")
	$ScheduledTask = $SchedulerService.NewTask(0)
	$ScheduledTask.RegistrationInfo.Description = $ScheduledTaskDescription
	$ScheduledTask.Settings.Enabled = $true
	$ScheduledTask.Settings.AllowDemandStart = $true
	$TaskTriggers = $ScheduledTask.Triggers
	$TaskTrigger = $TaskTriggers.Create(4)
	$TaskTrigger.StartBoundary = $ScheduledTaskStartTime.ToString("yyyy-MM-dd'T'HH:mm:ss")
	$TaskTrigger.DaysOfMonth = 8
	$TaskTrigger.Enabled = $true
	$ScheduledTaskAction = $ScheduledTask.Actions.Create(0)
	$ScheduledTaskAction.Path = "$ScheduledTaskCommand"
	$ScheduledTaskAction.Arguments = "$ScheduledTaskArguments"
	$SchedulesRootFolder.RegisterTaskDefinition("$ScheduledTaskName",$ScheduledTask,6,$ServiceUser,$ServicePlainPassword2,1) | Out-Null
	If (!$?) {
		Write-Host "Registering Scheduled Task under account $ServiceUser failed" -ForegroundColor Red
	}
}

Write-Host "Finished" -ForegroundColor Yellow