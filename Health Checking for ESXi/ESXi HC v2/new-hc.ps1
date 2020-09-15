<#------------------------------------------------------------------------------------------
New HealthChecking Script for ESXi - Author: aemonzon@ar.ibm.com - v1
<#----------------------------------------------------------------------------------------#>

#region variables
    
    $ctlresult = @{}
    $ctlresult.success = 0
    $ctlresult.failed = 0
    $ctlname = ""
    $successCount = 0
    $failedCount = 0
    $scannedvalue = ""
    $expectedvalue = ""
    $global:reportArray = @()
    
#endregion

#region funciones helper

function clear-scan-values{
    $scannedvalue = ""
    $expectedvalue = ""
    $esxcli = ""
    $sshService = ""
    $esxiShellService = ""
    $esxiNTPService = ""
    $esxiNTPServer = ""
    $ctlname = ""
} 

function clear-ctl-values{
    $ctlresult.success = 0
    $ctlresult.failed = 0
}   

function get-idpass{
    write-host "getting credentials for vcenter access"

    [hashtable]$uid = @{}

    #US domain id

        $us_cred = Import-Clixml -Path .\secured-us-cred.xml

    #CPCAD domain id

        $cpcad_cred = Import-Clixml -Path .\secured-cpcad-cred.xml

    $uid.usid = $us_cred
    $uid.cpcid = $cpcad_cred

    return $uid
}

function get-vclist{
    write-host "getting list of vcenters"
    $vclist = get-content -path .\vclist.txt
    return $vclist
}

function connect-vcenter{

    $vcconnection = $false

    $logincred = $vccred.usid
    
    if ($vc -like "*.ash.cpc.ibm.com"){$logincred = $vccred.cpcid}
    
    if ($vc -like "*.dal.cpc.ibm.com"){$logincred = $vccred.cpcid}
    
    try{
        write-host "`ntesting connection to $vc"
        Connect-VIServer -server $vc -credential $logincred -ErrorAction Stop | out-null
        write-host "connection to $vc successful"
        $vcconnection = $true        
    }

    catch{
        write-host $error[0].exception.message
        write-host "connection to $vc failed"
        $vcconnection = $false
    }

    return $vcconnection
}

function get-esxi{

    write-host "getting list of esxi hosts managed by this vcenter"
    
    $esxlist = Get-VMHost | Sort-Object -Property Name

    write-host "there are $($esxlist.Count) esxi hosts managed by this vcenter"

    return $esxlist

}

function start-healthcheck{
    
    write-host "`nhealthcheck on $esxi started" -ForegroundColor Green

    control-ad-domainauth
    control-pwdcomplexity
    control-lockoutduration
    control-accountlockout
    control-globallogdir
    control-remotesyslog
    control-mob
    control-dvfilter
    control-vib-acceptancelevel
    control-ssh
    control-esxishell
    control-ntp
    control-shell-idletimeout
    control-shell-timeout
    control-dcuitimeout

    write-host "healthcheck on $esxi finished" -ForegroundColor Green

    write-host "healthcheck summary for $esxi - PASSED: $($ctlresult.success) - FAILED: $($ctlresult.failed)" -ForegroundColor Yellow       

    clear-ctl-values

}

function disconnect-vcenter{
    disconnect-viserver -confirm:$false
    write-host "`ndisconnecting from vcenter $vc"
}

function write-report{
    write-host "`nwriting results to csv report"
    $date = Get-Date -Format ddMMyy
    $csvfile = "$vc-$date-esxi-hc-report.csv"
    $global:reportArray | export-csv -Path .\$csvfile -NoTypeInformation
    $global:reportArray = @()    
}

function send-results{}

#endregion

#region funciones healthcheck

    #region password requirements

        function control-ad-domainauth{
            $ctlname = "GN.1.1.12 - AD Domain Authentication"
            $scannedvalue = $($esxi | Get-VMHostAuthentication).Domain
            $usdomain = "us.americas.ad.ibm.com"
            $apdomain = "ap.ad.ibm.com"
            $wssdomain = "wssdom.can.ibm.com"
            $cpcdomain = "cpcad.cpc.ibm.com"
            if($scannedvalue -eq $usdomain -or $wssdomain -or $apdomain -or $cpcdomain){
                $result = "PASSED"
                $successCount += 1
            }
            else{
                $result = "FAILED"
                $failedCount += 1
            }
            $global:reportArray += new-object psobject -Property ([ordered]@{"vCenter" = $vc; "ESXi" = $esxi; "Control ID & Name" = $ctlname; "Result" = $result})
            #"AD Domain Authentication Configured: $result"   
            $ctlresult.success += $successCount
            $ctlresult.failed += $failedCount               
            clear-scan-values            
        } #GN.1.1.12

        #function control-authproxy{} #GN.1.1.13 (applies only if host profiles are used to join the host to ad domain)
          
        function control-pwdcomplexity{
            $ctlname = "GN.1.1.5 - Password Complexity"
            $scannedvalue = $($esxi | Get-AdvancedSetting -Name Security.PasswordQualityControl).value
            $expectedvalue = "min=disabled,disabled,15,15,15 passphrase=0 random=0"
            if($scannedvalue -eq $expectedvalue){
                $result = "PASSED"
                $successCount += 1
            }
            else{
                $result = "FAILED"
                $failedCount += 1
            }
            $global:reportArray += new-object psobject -Property ([ordered]@{"vCenter" = $vc; "ESXi" = $esxi; "Control ID & Name" = $ctlname; "Result" = $result})
            #"Password Complexity: $result"
            $ctlresult.success += $successCount
            $ctlresult.failed += $failedCount 
            clear-scan-values
        } #GN.1.1.5

        function control-lockoutduration{
            $ctlname = "GN.1.1.7 - Account Lockout Duration"
            $scannedvalue = $($esxi | Get-AdvancedSetting -Name Security.AccountUnlockTime).Value
            $expectedvalue = "900"
            if($scannedvalue -eq $expectedvalue){
                $result = "PASSED"
                $successCount += 1
            }
            else{
                $result = "FAILED"
                $failedCount += 1
            }
            $global:reportArray += new-object psobject -Property ([ordered]@{"vCenter" = $vc; "ESXi" = $esxi; "Control ID & Name" = $ctlname; "Result" = $result})
            #"Account Lockout Duration Time: $result"  
            $ctlresult.success += $successCount
            $ctlresult.failed += $failedCount         
            clear-scan-values
        } #GN.1.1.7

        function control-accountlockout{
            $ctlname = "GN.1.1.8 - Account Lockout Failures"
            $scannedvalue = $($esxi | Get-AdvancedSetting -Name Security.AccountLockFailures).Value
            $expectedvalue = "3"
            if($scannedvalue -eq $expectedvalue){
                $result = "PASSED"
                $successCount += 1
            }
            else{
                $result = "FAILED"
                $failedCount += 1
            }
            $global:reportArray += new-object psobject -Property ([ordered]@{"vCenter" = $vc; "ESXi" = $esxi; "Control ID & Name" = $ctlname; "Result" = $result})
            #"Account Lockout Failures Count: $result" 
            $ctlresult.success += $successCount
            $ctlresult.failed += $failedCount          
            clear-scan-values
        } #GN.1.1.8
    
    #endregion

    #region logging

        function control-globallogdir{
            $ctlname = 'GN.1.2.1 - Persistent Logging'
            $scannedvalue = $($esxi | Get-AdvancedSetting -Name Syslog.global.logDir).Value
            #$expectedvalue = ""
            if($scannedvalue -eq "" -or "[] /scratch/log"){
                $result = "FAILED"
                $failedCount += 1
            }
            else{
                $result = "PASSED"
                $successCount += 1
            }
            $global:reportArray += new-object psobject -Property ([ordered]@{"vCenter" = $vc; "ESXi" = $esxi; "Control ID & Name" = $ctlname; "Result" = $result})
            #"Persistent Logging Configured: $result" 
            $ctlresult.success += $successCount
            $ctlresult.failed += $failedCount          
            clear-scan-values
        } #GN.1.2.1

        function control-remotesyslog{  
            $ctlname = 'GN.1.2.5 - Remote SysLog'      
            $scannedvalue = $($esxi | Get-AdvancedSetting -Name Syslog.global.logHost).Value
            #$expectedvalue = ""
            if($scannedvalue -eq ""){
                $result = "FAILED"
                $failedCount += 1
            }
            else{
                $result = "PASSED"
                $successCount += 1
            }
            $global:reportArray += new-object psobject -Property ([ordered]@{"vCenter" = $vc; "ESXi" = $esxi; "Control ID & Name" = $ctlname; "Result" = $result})
            #"Remote SysLog Configured: $result" 
            $ctlresult.success += $successCount
            $ctlresult.failed += $failedCount          
            clear-scan-values
        } #GN.1.2.5

    #endregion

    #region system settings

        #function control-switches-tenants{} #GN.1.4.1 (applies to multitenant environment only)

        function control-mob{
            $ctlname = 'GN.1.4.10 - MOB Disabled'
            $scannedvalue = $($esxi | Get-AdvancedSetting -Name Config.HostAgent.plugins.solo.enableMob).Value
            #$expectedvalue = ""
            if(!($scannedvalue)){
                $result = "PASSED"
                $successCount += 1
            }
            else{
                $result = "FAILED"
                $failedCount += 1
            }
            $global:reportArray += new-object psobject -Property ([ordered]@{"vCenter" = $vc; "ESXi" = $esxi; "Control ID & Name" = $ctlname; "Result" = $result})
            #"MOB Disabled: $result" 
            $ctlresult.success += $successCount
            $ctlresult.failed += $failedCount          
            clear-scan-values   
        } #GN.1.4.10

        function control-dvfilter{
            $ctlname = 'GN.1.4.11 - DVFilter API Bind Disabled'
            $scannedvalue = $($esxi | Get-AdvancedSetting -Name Net.DVFilterBindIpAddress).Value
            #$expectedvalue = ""
            if($scannedvalue -eq ""){
                $result = "PASSED"
                $successCount += 1
            }
            else{
                $result = "FAILED"
                $failedCount += 1
            }
            $global:reportArray += new-object psobject -Property ([ordered]@{"vCenter" = $vc; "ESXi" = $esxi; "Control ID & Name" = $ctlname; "Result" = $result})
            #"DVFilter API Bind Disabled: $result" 
            $ctlresult.success += $successCount
            $ctlresult.failed += $failedCount          
            clear-scan-values      
        } #GN.1.4.11

        #function control-switches-exception{} #GN.1.4.2 (applies to multitenant environment only)

        function control-vss-forgedtransmits{} #GN.1.4.3.1

        function control-vds-pg-forgedtransmits{} #GN.1.4.3.2

        function control-vss-pg-forgedtransmits{} #GN.1.4.3.3

        function control-vss-promiscuousmode{} #GN.1.4.4.1

        function control-vds-pg-promiscuousmode{} #GN.1.4.4.2

        function control-vss-pg-promiscuousmode{} #GN.1.4.4.3

        function control-vss-macaddresschanges{} #GN.1.4.5.1

        function control-vds-pg-macaddresschanges{} #GN.1.4.5.2

        function control-vss-pg-macaddresschanges{} #GN.1.4.5.3

        function control-vds-pg-policyoverride{} #GN.1.4.5.4

        #function control-vlan-customer{} #GN.1.4.7 (applies to multitenant environment only)

        function control-vib-acceptancelevel{   
            $ctlname = 'GN.1.4.9 - VIB Acceptance Level'    
            $esxcli = get-esxcli -VMHost $esxi -V2
            $scannedvalue = $esxcli.software.acceptance.get.Invoke()            
            if($scannedvalue -eq "CommunitySupported"){
                $result = "FAILED"
                $failedCount += 1
            }
            else{
                $result = "PASSED"
                $successCount += 1
            }
            $global:reportArray += new-object psobject -Property ([ordered]@{"vCenter" = $vc; "ESXi" = $esxi; "Control ID & Name" = $ctlname; "Result" = $result})
            #"VIB Acceptance Level: $result" 
            $ctlresult.success += $successCount
            $ctlresult.failed += $failedCount          
            clear-scan-values           
        } #GN.1.4.9

    #endregion

    #region network settings

        function control-ssh{
            $ctlname = 'GN.1.5.10 - SSH Service Disabled'      
            $sshService = Get-VMHostService -VMHost $esxi | Where-Object {$_.Key -eq "TSM-SSH"}
            if ($sshService.Running -eq $true){
                $result = "FAILED"
                $failedCount += 1
            }
            else{
                $result = "PASSED"
                $successCount += 1
            }
            $global:reportArray += new-object psobject -Property ([ordered]@{"vCenter" = $vc; "ESXi" = $esxi; "Control ID & Name" = $ctlname; "Result" = $result})
            #"SSH Service Disabled: $result"
            $ctlresult.success += $successCount
            $ctlresult.failed += $failedCount          
            clear-scan-values
        } #GN.1.5.10

        function control-esxishell{
            $ctlname = 'GN.1.5.11 - ESXi Shell Service Disabled'
            $esxiShellService = Get-VMHostService -VMHost $esxi | Where-Object {$_.Key -eq "TSM"}
            if ($esxiShellService.Running -eq $true){
                $result = "FAILED"
                $failedCount += 1
            }
            else{
                $result = "PASSED"
                $successCount += 1
            }
            $global:reportArray += new-object psobject -Property ([ordered]@{"vCenter" = $vc; "ESXi" = $esxi; "Control ID & Name" = $ctlname; "Result" = $result})
            #"ESXi Shell Service Disabled: $result" 
            $ctlresult.success += $successCount
            $ctlresult.failed += $failedCount          
            clear-scan-values
        } #GN.1.5.11

        function control-ntp{
            $ctlname = 'GN.1.5.12 - NTP Server Configured'
            $esxiNTPService = Get-VMHostService -VMHost $esxi | Where-Object {$_.Key -eq "ntpd"}
            $esxiNTPServer = $esxi | Get-VMHostNtpServer
            if ($esxiNTPService.Running -eq $false -or $esxiNTPServer -eq "" ){
                $result = "FAILED"
                $failedCount += 1
            }
            else{
                $result = "PASSED"
                $successCount += 1
            }
            $global:reportArray += new-object psobject -Property ([ordered]@{"vCenter" = $vc; "ESXi" = $esxi; "Control ID & Name" = $ctlname; "Result" = $result})
            #"NTP Server Configured: $result" 
            $ctlresult.success += $successCount
            $ctlresult.failed += $failedCount          
            clear-scan-values
        
        } #GN.1.5.12

        function control-shell-idletimeout{
            $ctlname = "GN.1.5.13 - ESXi Shell Idle Timeout"
            $scannedvalue = $($esxi | Get-AdvancedSetting -Name UserVars.ESXiShellInteractiveTimeOut).value
            $expectedvalue = "900"
            if($scannedvalue -eq $expectedvalue){
                $result = "PASSED"
                $successCount += 1
            }
            else{
                $result = "FAILED"
                $failedCount += 1
            }
            $global:reportArray += new-object psobject -Property ([ordered]@{"vCenter" = $vc; "ESXi" = $esxi; "Control ID & Name" = $ctlname; "Result" = $result})
            #"ESXi Shell Idle Timeout: $result"
            $ctlresult.success += $successCount
            $ctlresult.failed += $failedCount 
            clear-scan-values      
        } #GN.1.5.13

        function control-shell-timeout{
            $ctlname = "GN.1.5.14 - ESXi Shell Timeout"
            $scannedvalue = $($esxi | Get-AdvancedSetting -Name UserVars.ESXiShellTimeOut).value
            $expectedvalue = "900"
            if($scannedvalue -eq $expectedvalue){
                $result = "PASSED"
                $successCount += 1
            }
            else{
                $result = "FAILED"
                $failedCount += 1
            }
            $global:reportArray += new-object psobject -Property ([ordered]@{"vCenter" = $vc; "ESXi" = $esxi; "Control ID & Name" = $ctlname; "Result" = $result})
            #"ESXi Shell Idle Timeout: $result"
            $ctlresult.success += $successCount
            $ctlresult.failed += $failedCount 
            clear-scan-values
        } #GN.1.5.14

        function control-fw-allowed{} #GN.1.5.2

        function control-snmp{} #GN.1.5.3
        
    #endregion     

    #region identify and authenticate users

        function control-dcui{} #GN.1.7.1

        function control-dcuitimeout{
            $ctlname = "GN.1.7.2 - DCUI Access Idle Timeout"
            $scannedvalue = $($esxi | Get-AdvancedSetting -Name UserVars.DcuiTimeOut).value
            $expectedvalue = "600"
            if($scannedvalue -eq $expectedvalue){
                $result = "PASSED"
                $successCount += 1
            }
            else{
                $result = "FAILED"
                $failedCount += 1
            }
            $global:reportArray += new-object psobject -Property ([ordered]@{"vCenter" = $vc; "ESXi" = $esxi; "Control ID & Name" = $ctlname; "Result" = $result})
            #"DCUI Access Idle Timeout: $result"
            $ctlresult.success += $successCount
            $ctlresult.failed += $failedCount 
            clear-scan-values
        } #GN.1.7.2

        function control-lockdownmode{} #GN.1.7.3
    
    #endregion

    #region business use notice

        function control-bunotice{} #GN.2.0.0 & GN.2.0.1

    #endregion

    #region encryption

        function control-certificates{} #GN.2.1.11

        function control-keysize{} #GN.2.1.3

        function control-sslauth{} #GN.2.1.8

        function control-tlssupport{} #GN.2.1.9  

    #endregion

#endregion

#region main

    write-host "`nESXi Health Check Started`n" -ForegroundColor Cyan

    #1)obtengo credenciales para conexión a vcenter
    $vccred = get-idpass

    #2)obtengo la lista de vcenters
    $vclist = get-vclist

    #3)recorro la lista de vcenters y voy uno x uno
    foreach($vc in $vclist){

        #4)me conecto a vcenter
        $vcconnection = connect-vcenter

        if($vcconnection){

            #5)obtengo los esxi que están conectados y listos para healthcheck
            $esxlist = get-esxi

            #6)recorro la lista de esxi y por cada uno realizo el healthcheck
            foreach ($esxi in $esxlist){ start-healthcheck }

            #7)genero reporte de esxi revisados en este vcenter
            write-report

            #8)termino, desconecto del vcenter y continuo con el próximo en la lista
            disconnect-vcenter
    
        }     

    }

    #9)envío resultados
    send-results

    write-host "`nESXi Health Check Finished" -ForegroundColor Cyan

#endregion
