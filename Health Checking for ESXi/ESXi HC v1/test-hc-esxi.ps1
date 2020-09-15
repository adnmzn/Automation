<#------------------------------------------------------------------------------------------
HealthChecking Script for ESXi - Author: aemonzon@ar.ibm.com - v1
<#----------------------------------------------------------------------------------------#>

#region variables de uid

$credential = ""

#US domain id

$us_user = "us\aemonzon"
$us_pwd = Get-Content ".\secured-us-pwd.txt" | ConvertTo-SecureString
$us_cred = New-Object System.Management.Automation.PsCredential($us_user, $us_pwd)

#CPCAD domain id

$cpcad_user = "cpcad\aemonzon"
$cpcad_pwd = Get-Content ".\secured-cpcad-pwd.txt" | ConvertTo-SecureString
$cpcad_cred = New-Object System.Management.Automation.PsCredential($cpcad_user, $cpcad_pwd)

#endregion

#region variables de script

$scriptName = "hc-esxi"
$mainpath = "."
$scriptPath = $mainpath + "\" + $scriptname + ".ps1"
$vCenterList = $mainpath + "\vCenterList.txt”
$logDir = $mainpath + "\logs\"
$outDir = $mainpath + "\output\”
$logfilename = $logDir + $scriptName + "_" + (Get-Date -uformat %m-%d-%Y_%I-%M-%S) + ".txt"
$outfilename = $outDir + $scriptName + "_" + (Get-Date -uformat %m-%d-%Y_%I-%M-%S) + ".csv"
$attachment = @($logfilename,$outfilename)
$csvheader = "vCenter;ESXiHost;ScannedParameter;DetectedValue;ExpectedValue;Result"

$vcSuccessConnectCount = 0
$vcFailedConnectCount = 0
$esxiSuccessConnectCount = 0
$esxiFailedConnectCount = 0

#endregion variables de script

#region variables box/mail
$boxfolder = "HC_evid.qnp4gi175ol0z8v3@u.box.com"
$smtpserver = "na.relay.ibm.com"
$smtpport = "25"
$from = "aemonzon@ar.ibm.com"
$cc = "PCS_x86@wwpdl.vnet.ibm.com"
$subject = "PCS_x86 - ESXi HealthChecking"
$body = "<h2 style=""color:Tomato;"">PCS_x86 - ESXi HealthChecking</h2>" 
$body += “This is an automated script generated e-mail sent from BLD Windows Jump Host. Please see attachments!`
Output file with results and log file were uploaded to https://ibm.box.com/s/f7u4t40vgs6wi2xap6d7jqk2vdx8wdyj”
#endregion variables box/mail

#region funciones helper
function show-banner{
    clear-host

    write-host "`n:::[" -NoNewline -ForegroundColor Green
    write-host "ESXi Host HealthChecking" -NoNewline -ForegroundColor Magenta
    write-host "]:::`n" -ForegroundColor Green
}

function get-now{
    Get-Date -format "dd-MMM-yyyy-hh.mm.ss"
}

function out-log{
    Param([Parameter(Mandatory=$false)][string]$LineValue,[Parameter(Mandatory=$false)][string]$fcolor = "White")
    $LineValueWithDate = "$(get-now) - $LineValue"
	Add-Content -Path $logfilename -Value $LineValueWithDate
	Write-Host $LineValueWithDate -ForegroundColor $fcolor
}

function upload-results{
    Send-MailMessage `
    -From $from `
    -To $boxfolder `
    -Cc $cc `
    -Subject $subject `
    -Body $body `
    -BodyAsHtml `
    -SmtpServer $smtpserver `
    -Port $smtpport `
    -Attachments $attachment    
}
#endregion funciones helper

#region funciones healthchecking

function esx-hc{

    Param([Parameter(Mandatory=$true)]$esxHost,[Parameter(Mandatory=$true)]$vCenter)
    
    out-log "Checking ESXi Host $($esxHost.Name) connection status"

    if($esxHost.ConnectionState -eq "Connected" -OR $esxHost.ConnectionState -eq "Maintenance"){
    
        out-log "ESXi Host $($esxHost.Name) is ready for HealthChecking" "Green"

        out-log "ESXi Host $($esxHost.Name) HealthChecking STARTED!" "Green" 
        
        #######################Acá van las llamadas a los controles      
                
        control-passwordquality -esxHost $esxHost -vCenter $vCenter

        control-accountunlocktime -esxHost $esxHost -vCenter $vCenter

        control-accountlockoutfailures -esxHost $esxHost -vCenter $vCenter

        control-stdswitch -esxHost $esxHost -vCenter $vCenter              
        
        out-log "ESXi Host $($esxHost.Name) HealthChecking FINISHED!" "Yellow"

        #######################Fin de las llamadas a los controles 

    }
    else{

        out-log "ESXi Host $($esxHost.Name) HealthChecking SKIPPED! - Host Not Responding" "Red"
            
    }

}

#endregion funciones healthchecking

#region funciones de control

#######Control de pwd complexity (nivel ESXi)
function control-passwordquality{  

    Param([Parameter(Mandatory=$true)]$esxHost,[Parameter(Mandatory=$true)]$vCenter)

    out-log "Control (1) - Checking: PasswordQualityControl on ESXi Host $($esxHost.Name)" "Magenta"

    if($($esxHost.Version) -like "6.*"){

        $scannedValue = $($esxHost | Get-AdvancedSetting -Name "Security.PasswordQualityControl").Value
        $expectedValue = "min=disabled,disabled,15,15,15 passphrase=0 random=0"
        out-log "ESXi Host $($esxHost.Name) - PasswordQualityControl Detected Value: $scannedValue"
        out-log "ESXi Host $($esxHost.Name) - PasswordQualityControl Expected Value: $expectedValue"

            if ([string]$scannedValue -eq $expectedValue){
                    out-log "ESXi Host $($esxHost.Name) - PasswordQualityControl Check: PASSED"
                    $result = "PASSED"
                    $csvrow = "$($vCenter);$($esxHost.Name);PasswordQualityControl;$($scannedValue);$($expectedValue);$($result)"
                    }   	 
                                    
            else{out-log "ESXi Host $($esxHost.Name) - PasswordQualityControl Check: FAILED"
                    out-log "ESXi Host $($esxHost.Name) - Fixing PasswordQualityControl..."
                    $esxHost | Get-AdvancedSetting -Name "Security.PasswordQualityControl" | Set-AdvancedSetting -Value $expectedValue -Confirm:$false | out-null
                    out-log "ESXi Host $($esxHost.Name) - Checking again PasswordQualityControl..."
                    $fixedValue = $($esxHost | Get-AdvancedSetting -Name "Security.PasswordQualityControl").Value
                    out-log "ESXi Host $($esxHost.Name) - PasswordQualityControl Detected Value: $fixedValue"

                        if([string]$fixedValue -eq $expectedValue){
                            out-log "ESXi Host $($esxHost.Name) - PasswordQualityControl Check: PASSED - Value Fixed"
                            $result = "PASSED - Value Fixed"
                            $csvrow = "$($vCenter);$($esxHost.Name);PasswordQualityControl;$($scannedValue);$($expectedValue);$($result)"
                            }
                     
                        else{out-log "ESXi Host $($esxHost.Name) - PasswordQualityControl Check: FAILED - Value Could not be fixed"
                            $result = "FAILED - Value Could not be fixed"
                            $csvrow = "$($vCenter);$($esxHost.Name);PasswordQualityControl;$($scannedValue);$($expectedValue);$($result)"
                            } 
                    }                                   
         
        add-content -path $outfilename -value $csvrow
        $csvrow = ""
        $result = ""
        $scannedValue = ""
        $expectedValue = ""
        $fixedValue = "" 
                                                                     
        }
                
    else{out-log "ESXi Host $($esxHost.Name) -PasswordQualityControl Parameter Checking/Configuration SKIPPED! Not Supported on ESXi $($esxHost.Version)"
        $result = "SKIPPED - Not supported on ESXi $($esxi.Version)"
        $csvrow = "$($vCenter);$($esxHost.Name);PasswordQualityControl;Undetected;$($expectedValue);$($result)"   
        add-content -path $outfilename -value $csvrow
        }  
}

#######Control de unlock time (nivel ESXi)
function control-accountunlocktime{

    Param([Parameter(Mandatory=$true)]$esxHost,[Parameter(Mandatory=$true)]$vCenter)

    out-log "Control (2) - Checking: AccountUnlockTime on ESXi Host $($esxHost.Name)" "Magenta"
    
    if($($esxHost.Version) -like "6.*"){

        $scannedValue = $($esxHost | Get-AdvancedSetting -Name "Security.AccountUnlockTime").Value
        $expectedValue = "900"
        out-log "ESXi Host $($esxHost.Name) - AccountUnlockTime Detected Value: $scannedValue"
        out-log "ESXi Host $($esxHost.Name) - AccountUnlockTime Expected Value: $expectedValue"

            if ([string]$scannedValue -eq $expectedValue){
                    out-log "ESXi Host $($esxHost.Name) - AccountUnlockTime Check: PASSED"
                    $result = "PASSED"
                    $csvrow = "$($vCenter);$($esxHost.Name);AccountUnlockTime;$($scannedValue);$($expectedValue);$($result)"
                    }   	 
                                    
            else{out-log "ESXi Host $($esxHost.Name) - AccountUnlockTime Check: FAILED"
                    out-log "ESXi Host $($esxHost.Name) - Fixing AccountUnlockTime..."
                    $esxHost | Get-AdvancedSetting -Name "Security.AccountUnlockTime" | Set-AdvancedSetting -Value $expectedValue -Confirm:$false | out-null
                    out-log "ESXi Host $($esxHost.Name) - Checking again AccountUnlockTime..."
                    $fixedValue = $($esxHost | Get-AdvancedSetting -Name "Security.AccountUnlockTime").Value
                    out-log "ESXi Host $($esxHost.Name) - AccountUnlockTime Detected Value: $fixedValue"

                        if([string]$fixedValue -eq $expectedValue){
                            out-log "ESXi Host $($esxHost.Name) - AccountUnlockTime Check: PASSED - Value Fixed"
                            $result = "PASSED - Value Fixed"
                            $csvrow = "$($vCenter);$($esxHost.Name);AccountUnlockTime;$($scannedValue);$($expectedValue);$($result)"
                            }
                     
                        else{out-log "ESXi Host $($esxHost.Name) - AccountUnlockTime Check: FAILED - Value Could not be fixed"
                            $result = "FAILED - Value Could not be fixed"
                            $csvrow = "$($vCenter);$($esxHost.Name);AccountUnlockTime;$($scannedValue);$($expectedValue);$($result)"
                            } 
                    }  
                    
        add-content -path $outfilename -value $csvrow
        $csvrow = ""
        $result = ""
        $scannedValue = ""
        $expectedValue = ""
        $fixedValue = ""                                 
                                                                     
        }
                
    else{out-log "ESXi Host $($esxHost.Name) -AccountUnlockTime Parameter Checking/Configuration SKIPPED! Not Supported on ESXi $($esxHost.Version)"
        $result = "SKIPPED - Not supported on ESXi $($esxi.Version)"
        $csvrow = "$($vCenter);$($esxi.Name);AccountUnlockTime;Undetected;$($expectedValue);$($result)"   
        add-content -path $outfilename -value $csvrow
        }

}

#######Control de lockout failures (nivel ESXi)
function control-accountlockoutfailures{

    Param([Parameter(Mandatory=$true)]$esxHost,[Parameter(Mandatory=$true)]$vCenter)

    out-log "Control (3) - Checking: AccountLockFailures on ESXi Host $($esxHost.Name)" "Magenta"

    if($($esxHost.Version) -like "6.*"){

        $scannedValue = $($esxHost | Get-AdvancedSetting -Name "Security.AccountLockFailures").Value
        $expectedValue = "3"
        out-log "ESXi Host $($esxHost.Name) - AccountLockFailures Detected Value: $scannedValue"
        out-log "ESXi Host $($esxHost.Name) - AccountLockFailures Expected Value: $expectedValue"

            if ([string]$scannedValue -eq $expectedValue){
                    out-log "ESXi Host $($esxHost.Name) - AccountLockFailures Check: PASSED"
                    $result = "PASSED"
                    $csvrow = "$($vCenter);$($esxHost.Name);AccountLockFailures;$($scannedValue);$($expectedValue);$($result)"
                    }   	 
                                    
            else{out-log "ESXi Host $($esxHost.Name) - AccountLockFailures Check: FAILED"
                    out-log "ESXi Host $($esxHost.Name) - Fixing AccountLockFailures..."
                    $esxHost | Get-AdvancedSetting -Name "Security.AccountLockFailures" | Set-AdvancedSetting -Value $expectedValue -Confirm:$false | out-null
                    out-log "ESXi Host $($esxHost.Name) - Checking again AccountLockFailures..."
                    $fixedValue = $($esxHost | Get-AdvancedSetting -Name "Security.AccountLockFailures").Value
                    out-log "ESXi Host $($esxHost.Name) - AccountLockFailures Detected Value: $fixedValue"

                        if([string]$fixedValue -eq $expectedValue){
                            out-log "ESXi Host $($esxHost.Name) - AccountLockFailures Check: PASSED - Value Fixed"
                            $result = "PASSED - Value Fixed"
                            $csvrow = "$($vCenter);$($esxHost.Name);AccountLockFailures;$($scannedValue);$($expectedValue);$($result)"
                            }
                     
                        else{out-log "ESXi Host $($esxHost.Name) - AccountLockFailures Check: FAILED - Value Could not be fixed"
                            $result = "FAILED - Value Could not be fixed"
                            $csvrow = "$($vCenter);$($esxHost.Name);AccountLockFailures;$($scannedValue);$($expectedValue);$($result)"
                            } 
                    } 
                    
        add-content -path $outfilename -value $csvrow
        $csvrow = ""
        $result = ""
        $scannedValue = ""
        $expectedValue = ""
        $fixedValue = ""                                  
                                                                     
        }
                
    else{out-log "ESXi Host $($esxHost.Name) -AccountLockFailures Parameter Checking/Configuration SKIPPED! Not Supported on ESXi $($esxHost.Version)"
        $result = "SKIPPED - Not supported on ESXi $($esxi.Version)"
        $csvrow = "$($vCenter);$($esxi.Name);AccountLockFailures;Undetected;$($expectedValue);$($result)"   
        add-content -path $outfilename -value $csvrow
        }

}

#######Control de std switch y portgroups (nivel ESXi)
function control-stdswitch{
    
    Param([Parameter(Mandatory=$true)]$esxHost,[Parameter(Mandatory=$true)]$vCenter)

    out-log "Control (4) - Checking: Standard Virtual Switches Security Policies on ESXi Host $($esxHost.Name)" "Magenta"     

    #region standard switch level variables

    $promiscuousModeScannedValue = ""
    $promiscuousModeExpectedValue = ""
    $promiscuousModeFixedValue = ""
    $promiscuousModePolicy = ""

    $forgedTransmitsScannedValue = ""
    $forgedTransmitsExpectedValue = ""
    $forgedTransmitsFixedValue = ""
    $forgedTransmitsPolicy = ""

    $macAddressChangesScannedValue = ""
    $macAddressChangesExpectedValue = ""
    $macAddressChangesFixedValue = ""
    $macAddressChangesPolicy = ""

    #endregion standard switch level variables
    
    #region standard virtual switch level control
    $svSwitches = Get-VirtualSwitch -VMHost $esxHost -Standard

    ForEach($svSwitch in $svSwitches){

        $svSwitchName = $svSwitch.Name            
                                      
        out-log "ESXi Host $($esxHost.Name) - Standard Switch Name: $svSwitchName"

        #region standard switch promiscuous mode control

        $promiscuousModeScannedValue = $($svSwitch | Get-SecurityPolicy).AllowPromiscuous
        $promiscuousModeExpectedValue = $false

        out-log "ESXi Host $($esxHost.Name) - $svSwitchName Promiscuous Mode Detected Value: $promiscuousModeScannedValue"
        out-log "ESXi Host $($esxHost.Name) - $svSwitchName Promiscuous Mode Expected Value: $promiscuousModeExpectedValue"

            if ($promiscuousModeScannedValue -eq $promiscuousModeExpectedValue){
                out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Promiscuous Mode Check: PASSED"
                $result = "PASSED"
                $promiscuousModeCSV = "VSS.$($svSwitchName).PromiscuousMode"
                $csvrow = "$($vCenter);$($esxHost.Name);$($promiscuousModeCSV);$($promiscuousModeScannedValue);$($promiscuousModeExpectedValue);$($result)"
                }   	 
                                    
            else{out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Promiscuous Mode Check: FAILED"
                out-log "ESXi Host $($esxHost.Name) - Fixing Promiscuous Mode on $svSwitchName..."
                Get-VirtualSwitch -name $svSwitchName -standard | Get-SecurityPolicy | Set-SecurityPolicy -AllowPromiscuous $promiscuousModeExpectedValue | out-null
                out-log "ESXi Host $($esxHost.Name) - Checking again Promiscuous Mode on $svSwitchName..."
                $promiscuousModeFixedValue = $($svSwitch | Get-SecurityPolicy).AllowPromiscuous
                out-log "ESXi Host $($esxHost.Name) - $svSwitchName Promiscuous Mode Detected Value: $promiscuousModeFixedValue"
                    
                if($promiscuousModefixedValue -eq $promiscuousModeExpectedValue){
                    out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Promiscuous Mode Check: PASSED - Value Fixed"
                    $result = "PASSED - Value Fixed"
                    $promiscuousModeCSV = "VSS.$($svSwitchName).PromiscuousMode"
                    $csvrow = "$($vCenter);$($esxHost.Name);$($promiscuousModeCSV);$($promiscuousModeScannedValue);$($promiscuousModeExpectedValue);$($result)"
                    }
                     
                else{out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Promiscuous Mode Check: FAILED - Value Could not be fixed"
                    $result = "FAILED - Value Could not be fixed"
                    $promiscuousModeCSV = "VSS.$($svSwitchName).PromiscuousMode"
                    $csvrow = "$($vCenter);$($esxHost.Name);$($promiscuousModeCSV);$($promiscuousModeScannedValue);$($promiscuousModeExpectedValue);$($result)"
                    } 
                }  
                             
            add-content -path $outfilename -value $csvrow
            $csvrow = ""
            $result = ""
            $promiscuousModeCSV = ""
            $promiscuousModeScannedValue = ""
            $promiscuousModeExpectedValue = ""
            $promiscuousModeFixedValue = "" 
            #$promiscuousModePolicy = ""

        #endregion standard switch promiscuous mode control

        #region standard switch forged transmits control

        $forgedTransmitsScannedValue = $($svSwitch | Get-SecurityPolicy).ForgedTransmits
        $forgedTransmitsExpectedValue = $false

        out-log "ESXi Host $($esxHost.Name) - $svSwitchName Forged Transmits Detected Value: $forgedTransmitsScannedValue"
        out-log "ESXi Host $($esxHost.Name) - $svSwitchName Forged Transmits Expected Value: $forgedTransmitsExpectedValue"
                    
            if ($forgedTransmitsScannedValue -eq $forgedTransmitsExpectedValue){
                out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Forged Transmits Check: PASSED"
                $result = "PASSED"
                $forgedTransmitsCSV = "VSS.$($svSwitchName).ForgedTransmits"
                $csvrow = "$($vCenter);$($esxHost.Name);$($forgedTransmitsCSV);$($forgedTransmitsScannedValue);$($forgedTransmitsExpectedValue);$($result)"
                }  
 	                                     
            else{out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Forged Transmits Check: FAILED"
                out-log "ESXi Host $($esxHost.Name) - Fixing Forged Transmits on $svSwitchName..."
                Get-VirtualSwitch -name $svSwitchName -standard | Get-SecurityPolicy | Set-SecurityPolicy -ForgedTransmits $forgedTransmitsExpectedValue | out-null
                out-log "ESXi Host $($esxHost.Name) - Checking again Forged Transmits on $svSwitchName..."
                $forgedTransmitsPolicy = Get-VirtualSwitch -name $svSwitchName -standard
                $forgedTransmitsFixedValue = $forgedTransmitsPolicy.ExtensionData.Spec.Policy.Security.ForgedTransmits
                out-log "ESXi Host $($esxHost.Name) - $svSwitchName Forged Transmits Detected Value: $forgedTransmitsFixedValue"
                    
                    if($forgedTransmitsFixedValue -eq $forgedTransmitsExpectedValue){
                        out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Forged Transmits Check: PASSED - Value Fixed"
                        $result = "PASSED - Value Fixed"
                        $forgedTransmitsCSV = "VSS.$($svSwitchName).ForgedTransmits"
                        $csvrow = "$($vCenter);$($esxHost.Name);$($forgedTransmitsCSV);$($forgedTransmitsScannedValue);$($forgedTransmitsExpectedValue);$($result)"
                        }
                     
                    else{out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Forged Transmits Check: FAILED - Value Could not be fixed"
                        $result = "FAILED - Value Could not be fixed"
                        $forgedTransmitsCSV = "VSS.$($svSwitchName).ForgedTransmits"
                        $csvrow = "$($vCenter);$($esxHost.Name);$($forgedTransmitsCSV);$($forgedTransmitsScannedValue);$($forgedTransmitsExpectedValue);$($result)"
                        }

                }  
                             
            add-content -path $outfilename -value $csvrow
            $csvrow = ""
            $result = ""
            $forgedTransmitsCSV = ""
            $forgedTransmitsScannedValue = ""
            $forgedTransmitsExpectedValue = ""
            $forgedTransmitsFixedValue = ""
            #$forgedTransmitsPolicy = ""

        #endregion standard switch forged transmits control

        #region standard switch mac address changes control
        
        $macAddressChangesScannedValue = $($svSwitch | Get-SecurityPolicy).MacChanges
        $macAddressChangesExpectedValue = $false

        out-log "ESXi Host $($esxHost.Name) - $svSwitchName MAC Address Changes Detected Value: $macAddressChangesScannedValue"
        out-log "ESXi Host $($esxHost.Name) - $svSwitchName MAC Address Changes Detected Value: $macAddressChangesExpectedValue"
                    
        if ($macAddressChangesScannedValue -eq $macAddressChangesExpectedValue){
            out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - MAC Address Changes Check: PASSED"
            $result = "PASSED"
            $macAddressChangesCSV = "VSS.$($svSwitchName).MACAddressChanges"
            $csvrow = "$($vCenter);$($esxHost.Name);$($macAddressChangesCSV);$($macAddressChangesScannedValue);$($macAddressChangesExpectedValue);$($result)"
            }   	 
                                    
        else{out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - MAC Address Changes Check: FAILED"
            out-log "ESXi Host $($esxHost.Name) - Fixing MAC Address Changes on $svSwitchName..."
            Get-VirtualSwitch -name $svSwitchName -standard | Get-SecurityPolicy | Set-SecurityPolicy -MacChanges $macAddressChangesExpectedValue | out-null
            out-log "ESXi Host $($esxHost.Name) - Checking again MAC Address Changes on $svSwitchName..."
            $macAddressChangesPolicy = Get-VirtualSwitch -name $svSwitchName -standard
            $macAddressChangesFixedValue = $macAddressChangesPolicy.ExtensionData.Spec.Policy.Security.MacChanges
            out-log "ESXi Host $($esxHost.Name) - $svSwitchName MAC Address Changes Detected Value: $macAddressChangesFixedValue"
                    
            if($macAddressChangesFixedValue -eq $macAddressChangesExpectedValue){
                out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - MAC Address Changes Check: PASSED - Value Fixed"
                $result = "PASSED - Value Fixed"
                $macAddressChangesCSV = "VSS.$($svSwitchName).MACAddressChanges"
                $csvrow = "$($vCenter);$($esxHost.Name);$($macAddressChangesCSV);$($macAddressChangesScannedValue);$($macAddressChangesExpectedValue);$($result)"
                }
                     
            else{out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - MAC Address Changes Check: FAILED - Value Could not be fixed"
                $result = "FAILED - Value Could not be fixed"
                $macAddressChangesCSV = "VSS.$($svSwitchName).MACAddressChanges"
                $csvrow = "$($vCenter);$($esxHost.Name);$($macAddressChangesCSV);$($macAddressChangesScannedValue);$($macAddressChangesExpectedValue);$($result)"
                } 
            }  
                             
        add-content -path $outfilename -value $csvrow
        $csvrow = ""
        $result = ""
        $macAddressChangesCSV = ""
        $macAddressChangesScannedValue = ""
        $macAddressChangesExpectedValue = ""
        $macAddressChangesFixedValue = ""
        #$macAddressChangesPolicy = ""
                                             
        #endregion standard switch mac address changes control

        #region standard switch portgroup level control

        #region standard switch portgroup level variables

        $PGpromiscuousModeScannedValue = ""
        $PGpromiscuousModeExpectedValue = ""
        $PGpromiscuousModeFixedValue = ""
        $PGpromiscuousModePolicy = ""

        $PGforgedTransmitsScannedValue = ""
        $PGforgedTransmitsExpectedValue = ""
        $PGforgedTransmitsFixedValue = ""
        $PGforgedTransmitsPolicy = ""

        $PGmacAddressChangesScannedValue = ""
        $PGmacAddressChangesExpectedValue = ""
        $PGmacAddressChangesFixedValue = ""
        $PGmacAddressChangesPolicy = ""

        #endregion

        out-log "ESXi Host $($esxHost.Name) - Checking Standard Switch $svSwitchName Portgroups"

        $svSwitchPGs = Get-VirtualPortGroup -VMHost $esxHost -VirtualSwitch $svSwitchName -Standard

        ForEach($svSwitchPG in $svSwitchPGs){

        $svSwitchPGName = $svSwitchPG.Name                    

        out-log "ESXi Host $($esxHost.Name) - Standard Switch $svSwitchName - Portgroup: $svSwitchPGName"

        #region standard switch - portgroup level - promiscuous mode control     
                    
        $PGpromiscuousModeScannedValue = $($svSwitchPG | Get-SecurityPolicy).AllowPromiscuous
        $PGpromiscuousModeExpectedValue = $false               

        out-log "ESXi Host $($esxHost.Name) - Portgroup: $svSwitchPGName - Promiscuous Mode Detected Value: $PGpromiscuousModeScannedValue"
        out-log "ESXi Host $($esxHost.Name) - Portgroup: $svSwitchPGName - Promiscuous Mode Expected Value: $PGpromiscuousModeExpectedValue"

        if ($PGpromiscuousModeScannedValue -eq $PGpromiscuousModeExpectedValue){
            out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Portgroup: $svSwitchPGName - Promiscuous Mode Check: PASSED"
            $result = "PASSED"
            $PGpromiscuousModeCSV = "VSS.$($svSwitchName).$($svSwitchPGName).PromiscuousMode"
            $csvrow = "$($vCenter);$($esxHost.Name);$($PGpromiscuousModeCSV);$($PGpromiscuousModeScannedValue);$($PGpromiscuousModeExpectedValue);$($result)"
            }   	 
                                    
        else{out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Portgroup: $svSwitchPGName - Promiscuous Mode Check: FAILED"
            out-log "ESXi Host $($esxHost.Name) - Fixing Promiscuous Mode on Portgroup: $svSwitchPGName..."
            $svSwitchPG | Get-SecurityPolicy | Set-SecurityPolicy -AllowPromiscuous $PGpromiscuousModeExpectedValue -confirm:$false | out-null
            out-log "ESXi Host $($esxHost.Name) - Checking again Promiscuous Mode on Portgroup: $svSwitchPGName..."
            $PGpromiscuousModeFixedValue = $($svSwitchPG | Get-SecurityPolicy).AllowPromiscuous
            out-log "ESXi Host $($esxHost.Name) - Portgroup: $svSwitchPGName - Promiscuous Mode Expected Value: $PGpromiscuousModeFixedValue"
                    
                if($PGpromiscuousModeFixedValue -eq $PGpromiscuousModeExpectedValue){
                    out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Portgroup: $svSwitchPGName - Promiscuous Mode Check: PASSED - Value Fixed"
                    $result = "PASSED - Value Fixed"
                    $PGpromiscuousModeCSV = "VSS.$($svSwitchName).$($svSwitchPGName).PromiscuousMode"
                    $csvrow = "$($vCenter);$($esxHost.Name);$($PGpromiscuousModeCSV);$($PGpromiscuousModeScannedValue);$($PGpromiscuousModeExpectedValue);$($result)"
                    }
                     
                else{out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Portgroup: $svSwitchPGName - Promiscuous Mode Check: FAILED - Value Could not be fixed"
                    $result = "FAILED - Value Could not be fixed"
                    $PGpromiscuousModeCSV = "VSS.$($svSwitchName).$($svSwitchPGName).PromiscuousMode"
                    $csvrow = "$($vCenter);$($esxHost.Name);$($PGpromiscuousModeCSV);$($PGpromiscuousModeScannedValue);$($PGpromiscuousModeExpectedValue);$($result)"
                    }
            }  
                             
        add-content -path $outfilename -value $csvrow
        $csvrow = ""
        $result = ""
        $PGpromiscuousModeCSV = ""
        $PGpromiscuousModeScannedValue = ""
        $PGpromiscuousModeExpectedValue = ""
        $PGpromiscuousModeFixedValue = "" 
        #$PGpromiscuousModePolicy = ""

        #endregion standard switch - portgroup level - promiscuous mode control  
                    
        #region standard switch - portgroup level - forged transmits

        $PGforgedTransmitsScannedValue = $($svSwitchPG | Get-SecurityPolicy).ForgedTransmits
        $PGforgedTransmitsExpectedValue = $false     

        out-log "ESXi Host $($esxHost.Name) - Portgroup: $svSwitchPGName - Forged Transmits Mode Detected Value: $PGforgedTransmitsScannedValue"
        out-log "ESXi Host $($esxHost.Name) - Portgroup: $svSwitchPGName - Forged Transmits Expected Value: $PGforgedTransmitsExpectedValue"

        if ($PGforgedTransmitsScannedValue -eq $PGforgedTransmitsExpectedValue){
            out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Portgroup: $svSwitchPGName - Forged Transmits Check: PASSED"
            $result = "PASSED"
            $PGforgedTransmitsCSV = "VSS.$($svSwitchName).$($svSwitchPGName).ForgedTransmits"
            $csvrow = "$($vCenter);$($esxHost.Name);$($PGforgedTransmitsCSV);$($PGforgedTransmitsScannedValue);$($PGforgedTransmitsExpectedValue);$($result)"
            }   	 
                                    
        else{out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Portgroup: $svSwitchPGName - Forged Transmits Check: FAILED"
            out-log "ESXi Host $($esxHost.Name) - Fixing Forged Transmits on Portgroup: $svSwitchPGName..."
            $svSwitchPG | Get-SecurityPolicy | Set-SecurityPolicy -ForgedTransmits $PGforgedTransmitsExpectedValue -confirm:$false | out-null
            out-log "ESXi Host $($esxHost.Name) - Checking again Forged Transmits on Portgroup: $svSwitchPGName..."            
            $PGforgedTransmitsFixedValue = $($svSwitchPG | Get-SecurityPolicy).ForgedTransmits
            out-log "ESXi Host $($esxHost.Name) - Portgroup: $svSwitchPGName - Forged Transmits Expected Value: $PGforgedTransmitsFixedValue"
                    
            if($PGforgedTransmitsFixedValue -eq $PGforgedTransmitsExpectedValue){
                out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Portgroup: $svSwitchPGName - Forged Transmits Check: PASSED - Value Fixed"
                $result = "PASSED - Value Fixed"
                $PGforgedTransmitsCSV = "VSS.$($svSwitchName).$($svSwitchPGName).ForgedTransmits"
                $csvrow = "$($vCenter);$($esxHost.Name);$($PGforgedTransmitsCSV);$($PGforgedTransmitsScannedValue);$($PGforgedTransmitsExpectedValue);$($result)"
                }
                     
            else{out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Portgroup: $svSwitchPGName - Forged Transmits Check: FAILED - Value Could not be fixed"
                $result = "FAILED - Value Could not be fixed"
                $PGforgedTransmitsCSV = "VSS.$($svSwitchName).$($svSwitchPGName).ForgedTransmits"
                $csvrow = "$($vCenter);$($esxHost.Name);$($PGforgedTransmitsCSV);$($PGforgedTransmitsScannedValue);$($PGforgedTransmitsExpectedValue);$($result)"
                }

            }  
                             
        add-content -path $outfilename -value $csvrow
        $csvrow = ""
        $result = ""
        $PGforgedTransmitsCSV = ""
        $PGforgedTransmitsScannedValue = ""
        $PGforgedTransmitsExpectedValue = ""
        $PGforgedTransmitsFixedValue = "" 
        #$PGforgedTransmitsPolicy = ""
                    
        #endregion  standard switch - portgroup level - forged transmits
                    
        #region standard switch - portgroup level - mac address changes

        $PGmacAddressChangesScannedValue = $($svSwitchPG | Get-SecurityPolicy).MacChanges
        $PGmacAddressChangesExpectedValue = $false

        out-log "ESXi Host $($esxHost.Name) - Portgroup: $svSwitchPGName - MAC Address Changes Mode Detected Value: $PGmacAddressChangesScannedValue"
        out-log "ESXi Host $($esxHost.Name) - Portgroup: $svSwitchPGName - MAC Address Changes Expected Value: $PGmacAddressChangesExpectedValue"

        if ($PGmacAddressChangesScannedValue -eq $PGmacAddressChangesExpectedValue){
            out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Portgroup: $svSwitchPGName - MAC Address Changes Check: PASSED"
            $result = "PASSED"
            $PGmacAddressChangesCSV = "VSS.$($svSwitchName).$($svSwitchPGName).MACAddressChanges"
            $csvrow = "$($vCenter);$($esxHost.Name);$($PGmacAddressChangesCSV);$($PGmacAddressChangesScannedValue);$($PGmacAddressChangesExpectedValue);$($result)"
            }   	 
                                    
        else{out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Portgroup: $svSwitchPGName - MAC Address Changes Check: FAILED"
            out-log "ESXi Host $($esxHost.Name) - Fixing MAC Address Changes on Portgroup: $svSwitchPGName..."
            $svSwitchPG | Get-SecurityPolicy | Set-SecurityPolicy -MacChanges $PGmacAddressChangesExpectedValue -confirm:$false | out-null
            out-log "ESXi Host $($esxHost.Name) - Checking again MAC Address Changes on Portgroup: $svSwitchPGName..."
            $PGmacAddressChangesFixedValue = $($svSwitchPG | Get-SecurityPolicy).MacChanges
            out-log "ESXi Host $($esxHost.Name) - Portgroup: $svSwitchPGName - MAC Address Changes Expected Value: $PGmacAddressChangesFixedValue"
                    
            if($PGmacAddressChangesFixedValue -eq $PGmacAddressChangesExpectedValue){
                out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Portgroup: $svSwitchPGName - MAC Address Changes Check: PASSED - Value Fixed"
                $result = "PASSED - Value Fixed"
                $PGmacAddressChangesCSV = "VSS.$($svSwitchName).$($svSwitchPGName).MACAddressChanges"
                $csvrow = "$($vCenter);$($esxHost.Name);$($PGmacAddressChangesCSV);$($PGmacAddressChangesScannedValue);$($PGmacAddressChangesExpectedValue);$($result)"
                }
                     
            else{out-log "ESXi Host $($esxHost.Name) - Standard Switch: $svSwitchName - Portgroup: $svSwitchPGName - MAC Address Changes Check: FAILED - Value Could not be fixed"
                $result = "FAILED - Value Could not be fixed"
                $PGmacAddressChangesCSV = "VSS.$($svSwitchName).$($svSwitchPGName).MACAddressChanges"
                $csvrow = "$($vCenter);$($esxHost.Name);$($PGmacAddressChangesCSV);$($PGmacAddressChangesScannedValue);$($PGmacAddressChangesExpectedValue);$($result)"
                }

            }  
                             
        add-content -path $outfilename -value $csvrow
        $csvrow = ""
        $result = ""
        $PGmacAddressChangesCSV = ""
        $PGmacAddressChangesScannedValue = ""
        $PGmacAddressChangesExpectedValue = ""
        $PGmacAddressChangesFixedValue = "" 
        #$PGmacAddressChangesPolicy = ""
                    
        #endregion standard switch - portgroup level - mac address changes         
                    
            }

        }

        #endregion standard switch portgroup level control      
        
    #endregion standard virtual switch level control

} 

#######Control de dvs switch y portgroups (nivel vCenter - llamo a este control desde main)
function control-dvsswitch{

    Param([Parameter(Mandatory=$true)]$vCenter)

    out-log "Control (5) - Checking: Distributed Virtual Switches Security Policies - vCenter Level" "Magenta" 

    #region distributed switch level variables

    $DVSpromiscuousModeScannedValue = ""
    $DVSpromiscuousModeExpectedValue = ""
    $DVSpromiscuousModeFixedValue = ""
    $DVSpromiscuousModePolicy = ""

    $DVSforgedTransmitsScannedValue = ""
    $DVSforgedTransmitsExpectedValue = ""
    $DVSforgedTransmitsFixedValue = ""
    $DVSforgedTransmitsPolicy = ""

    $DVSmacAddressChangesScannedValue = ""
    $DVSmacAddressChangesExpectedValue = ""
    $DVSmacAddressChangesFixedValue = ""
    $DVSmacAddressChangesPolicy = ""

    #endregion distributed switch level variables

    #region distributed virtual switch level control
    $dvSwitches = Get-VDSwitch

    if($dvSwitches -ne $null){

    ForEach($dvSwitch in $dvSwitches){

        $dvSwitchName = $dvSwitch.Name            
                                      
        out-log "Distributed Switch Name: $dvSwitchName"

        out-log "Getting list of Portgroups on $dvSwitchName"

        $dvPGs = $dvSwitch | Get-VDPortgroup | Where {$($_ | Get-View).Tag.Key -ne "SYSTEM/DVS.UPLINKPG"}

        if($dvPGs -ne $null){

            ForEach($dvPG in $dvPGs){
                    
                    $dvSwitchPGName = $dvPG.Name                    

                    out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName"

                    #region distributed switch - portgroup level - promiscuous mode

                        $DVSpromiscuousModeScannedValue = $($dvPG | Get-VDSecurityPolicy).AllowPromiscuous
                        $DVSpromiscuousModeExpectedValue = $false

                        out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - Promiscuous Mode Detected Value: $DVSpromiscuousModeScannedValue"
                        out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - Promiscuous Mode Expected Value: $DVSpromiscuousModeExpectedValue"

                        if ($DVSpromiscuousModeScannedValue -eq $DVSpromiscuousModeExpectedValue){
                        out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - Promiscuous Mode Check: PASSED"
                        $result = "PASSED"
                        $DVSpromiscuousModeCSV = "DVS.$($dvSwitchName).$($dvSwitchPGName).PromiscuousMode"
                        $csvrow = "$($vCenter);DatacenterLevelObject;$($DVSpromiscuousModeCSV);$($DVSpromiscuousModeScannedValue);$($DVSpromiscuousModeExpectedValue);$($result)"
                        }  

                        else{out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - Promiscuous Mode Check: FAILED"
                        out-log "Distributed Switch $dvSwitchName - Fixing Promiscuous Mode on Portgroup: $dvSwitchPGName..."
                        $dvPG | Get-VDSecurityPolicy | Set-VDSecurityPolicy -AllowPromiscuous $DVSpromiscuousModeExpectedValue -confirm:$false | out-null
                        out-log "Distributed Switch $dvSwitchName - Checking again Promiscuous Mode on Portgroup: $dvSwitchPGName..."
                        $DVSpromiscuousModeFixedValue = $($dvPG | Get-VDSecurityPolicy).AllowPromiscuous
                        out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - Promiscuous Mode Expected Value: $DVSpromiscuousModeFixedValue"
                    
                            if($DVSpromiscuousModeFixedValue -eq $DVSpromiscuousModeExpectedValue){
                                out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - Promiscuous Mode Check: PASSED - Value Fixed"
                                $result = "PASSED"
                                $DVSpromiscuousModeCSV = "DVS.$($dvSwitchName).$($dvSwitchPGName).PromiscuousMode"
                                $csvrow = "$($vCenter);DatacenterLevelObject;$($DVSpromiscuousModeCSV);$($DVSpromiscuousModeScannedValue);$($DVSpromiscuousModeExpectedValue);$($result)"
                                }
                     
                            else{out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - Promiscuous Mode Check: FAILED - Value Could not be fixed"
                                $result = "FAILED - Value Could not be fixed"
                                $DVSpromiscuousModeCSV = "DVS.$($dvSwitchName).$($dvSwitchPGName).PromiscuousMode"
                                $csvrow = "$($vCenter);DatacenterLevelObject;$($DVSpromiscuousModeCSV);$($DVSpromiscuousModeScannedValue);$($DVSpromiscuousModeExpectedValue);$($result)"
                                }

                        }                   

                        add-content -path $outfilename -value $csvrow
                        $csvrow = ""
                        $result = ""
                        $DVSpromiscuousModeCSV = ""
                        $DVSpromiscuousModeScannedValue = ""
                        $DVSpromiscuousModeExpectedValue = ""
                        $DVSpromiscuousModeFixedValue = ""
                        #$DVSpromiscuousModePolicy = ""

                    #endregion distributed switch - portgroup level - promiscuous mode

                    #region distributed switch - portgroup level - forged transmits

                        $DVSforgedTransmitsScannedValue = $($dvPG | Get-VDSecurityPolicy).ForgedTransmits
                        $DVSforgedTransmitsExpectedValue = $false

                        out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - Forged Transmits Detected Value: $DVSforgedTransmitsScannedValue"
                        out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - Forged Transmits Expected Value: $DVSforgedTransmitsExpectedValue"

                        if ($DVSforgedTransmitsScannedValue -eq $DVSforgedTransmitsExpectedValue){
                        out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - Forged Transmits Check: PASSED"
                        $result = "PASSED"
                        $DVSforgedTransmitsCSV = "DVS.$($dvSwitchName).$($dvSwitchPGName).ForgedTransmits"
                        $csvrow = "$($vCenter);DatacenterLevelObject;$($DVSforgedTransmitsCSV);$($DVSforgedTransmitsScannedValue);$($DVSforgedTransmitsExpectedValue);$($result)"
                        }  

                        else{out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - Forged Transmits Check: FAILED"
                        out-log "Distributed Switch $dvSwitchName - Fixing Forged Transmits on Portgroup: $dvSwitchPGName..."
                        $dvPG | Get-VDSecurityPolicy | Set-VDSecurityPolicy -ForgedTransmits $DVSforgedTransmitsExpectedValue -confirm:$false | out-null
                        out-log "Distributed Switch $dvSwitchName - Checking again Forged Transmits on Portgroup: $dvSwitchPGName..."
                        $DVSForgedTransmitsFixedValue = $($dvSwitchPG | Get-VDSecurityPolicy).ForgedTransmits
                        out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - Forged Transmits Expected Value: $DVSForgedTransmitsFixedValue"
                    
                            if($DVSForgedTransmitsFixedValue -eq $DVSforgedTransmitsExpectedValue){
                                out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - Forged Transmits Check: PASSED - Value Fixed"
                                $result = "PASSED"
                                $DVSforgedTransmitsCSV = "DVS.$($dvSwitchName).$($dvSwitchPGName).ForgedTransmits"
                                $csvrow = "$($vCenter);DatacenterLevelObject;$($DVSforgedTransmitsCSV);$($DVSforgedTransmitsScannedValue);$($DVSforgedTransmitsExpectedValue);$($result)"
                                }
                     
                            else{out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - Forged Transmits Check: FAILED - Value Could not be fixed"
                                $result = "FAILED - Value Could not be fixed"
                                $DVSforgedTransmitsCSV = "DVS.$($dvSwitchName).$($dvSwitchPGName).ForgedTransmits"
                                $csvrow = "$($vCenter);DatacenterLevelObject;$($DVSforgedTransmitsCSV);$($DVSforgedTransmitsScannedValue);$($DVSforgedTransmitsExpectedValue);$($result)"
                                }

                        }                    

                        add-content -path $outfilename -value $csvrow
                        $csvrow = ""
                        $result = ""
                        $DVSforgedTransmitsCSV = ""
                        $DVSforgedTransmitsScannedValue = ""
                        $DVSforgedTransmitsExpectedValue = ""
                        $DVSForgedTransmitsFixedValue = ""
                        #$DVSForgedTransmitsPolicy = ""

                    #endregion distributed switch - portgroup level - forged transmits

                    #region distributed switch - portgroup level - mac address changes

                        $DVSmacAddressChangesScannedValue = $($dvPG | Get-VDSecurityPolicy).MacChanges
                        $DVSmacAddressChangesExpectedValue = $false

                        out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - MAC Address Changes Detected Value: $DVSmacAddressChangesScannedValue"
                        out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - MAC Address Changes Expected Value: $DVSmacAddressChangesExpectedValue"

                        if ($DVSmacAddressChangesScannedValue -eq $DVSmacAddressChangesExpectedValue){
                        out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - MAC Address Changes Check: PASSED"
                        $result = "PASSED"
                        $DVSmacAddressChangesCSV = "DVS.$($dvSwitchName).$($dvSwitchPGName).MACAddressChanges"
                        $csvrow = "$($vCenter);DatacenterLevelObject;$($DVSmacAddressChangesCSV);$($DVSmacAddressChangesScannedValue);$($DVSmacAddressChangesExpectedValue);$($result)"
                        }  

                        else{out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - MAC Address Changes Check: FAILED"
                        out-log "Distributed Switch $dvSwitchName - Fixing MAC Address Changes on Portgroup: $dvSwitchPGName..."
                        $dvPG | Get-VDSecurityPolicy | Set-VDSecurityPolicy -MacChanges $DVSmacAddressChangesExpectedValue -confirm:$false | out-null
                        out-log "Distributed Switch $dvSwitchName - Checking again MAC Address Changes on Portgroup: $dvSwitchPGName..."
                        $DVSmacAddressChangesExpectedValue = $($dvSwitchPG | Get-VDSecurityPolicy).MacChanges
                        out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - MAC Address Changes Expected Value: $DVSmacAddressChangesExpectedValue"
                    
                            if($DVSmacAddressChangesExpectedValue -eq $DVSmacAddressChangesExpectedValue){
                            out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - MAC Address Changes Check: PASSED - Value Fixed"
                            $result = "PASSED"
                            $DVSmacAddressChangesCSV = "DVS.$($dvSwitchName).$($dvSwitchPGName).MACAddressChanges"
                            $csvrow = "$($vCenter);DatacenterLevelObject;$($DVSmacAddressChangesCSV);$($DVSmacAddressChangesScannedValue);$($DVSmacAddressChangesExpectedValue);$($result)"
                            }
                     
                            else{out-log "Distributed Switch $dvSwitchName - Portgroup: $dvSwitchPGName - MAC Address Changes Check: FAILED - Value Could not be fixed"
                            $result = "FAILED - Value Could not be fixed"
                            $DVSmacAddressChangesCSV = "DVS.$($dvSwitchName).$($dvSwitchPGName).MACAddressChanges"
                            $csvrow = "$($vCenter);DatacenterLevelObject;$($DVSmacAddressChangesCSV);$($DVSmacAddressChangesScannedValue);$($DVSmacAddressChangesExpectedValue);$($result)"
                            }

                        }                    

                        add-content -path $outfilename -value $csvrow
                        $csvrow = ""
                        $result = ""
                        $DVSmacAddressChangesCSV = ""
                        $DVSmacAddressChangesScannedValue = ""
                        $DVSmacAddressChangesExpectedValue = ""
                        $DVSmacAddressChangesExpectedValue = ""
                        #$DVSMACAddressChangesPolicy = ""

                    #endregion distributed switch - portgroup level - mac address changes
                                
                }                    	 
                                                       
                   
            }
        
        else{out-log "No Portgroups were found on DVS $dvSwitchName " "Red"}                              

        }

    }

    else{out-log "No DVS were found on this vCenter" "Red"}    
        
    #endregion distributed virtual switch level control
        
}

#endregion

#region main

show-banner

add-content -path $outfilename -value $csvheader

out-log "Reading list of vCenters to connect from vCenterList.txt file"

$vcListBool = $false

    try{
    
        $vcList = get-content $vCenterList
        out-log "List of vCenters that will be connected for ESXi Host Healthchecking"
        ForEach($vc in $vcList){out-log "$vc"}
        out-log "List of vCenters read successfully"
        $vcListBool = $true
        
    }

    catch{

        out-log "$($error[0].exception.message)"
        out-log "Execution halted. Exiting"
        exit

    }   


if($vcListBool){

    ForEach($vc in $vcList){

        $credential = $us_cred

        if($vc -like "*.ash.cpc.ibm.com"){
            $credential = $cpcad_cred       
        }
        if($vc -like "*.dal.cpc.ibm.com"){
            $credential = $cpcad_cred
        }

        out-log "Connecting to vCenter $vc"
        $vcConnectionOK = $false

        try{

            connect-viserver -server $vc -Credential $credential -ErrorAction Stop | out-null
            $vcConnectionOK = $true
            out-log "Connection to $vc Successful"
            $vcSuccessConnectCount += 1
                    
        }

        catch{
            
            if($error[0].exception.message -like "*incorrect*"){
            
                out-log "Connection to vCenter failed: incorrect username or password" "Red"

            }
            
            if($error[0].exception.message -like "*Could not resolve*"){
            
                out-log "Connection to vCenter failed: unable to resolve the vCenter FQDN/Hostname" "Red"
            
            }

            $vcFailedConnectCount += 1
                    
        }

        if($vcConnectionOK){

            out-log "Getting list of ESXi Hosts connected to this vCenter"
            $esxList = get-vmhost
            out-log "List of ESXi Hosts that will be Healthchecked"

            ForEach($esx in $esxList){out-log "$($esx.Name)"}

            #####################################################
            ###########ESX HEALTHCHECK STARTS HERE!!!############

            ForEach($esx in $esxList){esx-hc -esxHost $esx -vCenter $vc}

            ############ESX HEALTHCHECK ENDS HERE!!!#############
            #####################################################

            #####################################################
            ###########DVS HEALTHCHECK STARTS HERE!!!############

            control-dvsswitch -vCenter $vc

            ############DVS HEALTHCHECK ENDS HERE!!!#############
            #####################################################

            out-log "Disconnecting from vCenter $vc"
            disconnect-viserver -confirm:$false
                                
        }
        
    }

    out-log "Reached end of vCenter List. No more vCenters to connect"
    out-log "Number of successful vCenter connections: $vcSuccessConnectCount"
    out-log "Number of failed vCenter connections: $vcFailedConnectCount"
    out-log "Script execution finished"
    out-log "Sending results to pcs_x86 and Box"
    upload-results

}

else{

    out-log "CSV File couldn't be read" "Red"

}

#endregion main