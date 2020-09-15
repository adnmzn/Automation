#region funciones

Function Get-ComplianceStatus{

    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $command,

        [Parameter()]
        [string]
        $expected,

        [Parameter()]
        [string]
        $ctlname
      
    )

    switch ($ctlname) {

        'Managed Object Browser' {

            $detected = Invoke-Expression -Command $command

            if (!$detected) {

                $compliance = 'COMPLIANT'
                $detected   = 'Disabled'
                
            }
            else {

                $compliance = 'UNCOMPLIANT'
                $detected   = 'Enabled' 

            }

        }

        'DVFilter API Bind' {

            $detected = Invoke-Expression -Command $command

            if ($detected -eq '') {
                
                $compliance = 'COMPLIANT'
                $detected   = 'Disabled'

            }
            else {

                $compliance = 'UNCOMPLIANT'
                $detected   = 'Enabled'
                
            }
            
        }

        'Global Log Dir' {

            $detected = Invoke-Expression -Command $command

            if ($detected -eq '[] /scratch/log') {
                
                $compliance = 'COMPLIANT'
                
            }

            elseif ($detected -eq '') {
                
                $compliance = 'UNCOMPLIANT'
                $detected = 'No Logging Directory Set'

            }

            else {
                
                $compliance = 'COMPLIANT'

            }

        }

        'VIB Acceptance Level' {

            $detected = Invoke-Expression -Command $command

            if ($detected -eq 'CommunitySupported') {
                
                $compliance = 'UNCOMPLIANT'
                
            }

            else {
                
                $compliance = 'COMPLIANT'

            }

        }

        Default {

            $detected = Invoke-Expression -Command $command

            if ($detected -eq $expected) {
                
                $compliance = 'COMPLIANT'

            }

            else {

                $compliance = 'UNCOMPLIANT'

            }

        }

    }     

    $row = [PSCustomObject]@{

        'vCenter'           = $vc
        'ESXi Hostname'     = $esx
        'Control Name'      = $ctlname
        'Detected Value'    = $detected
        'Compliance'        = $compliance

    }

    return $row

}

Function Get-ESXPwdComplexity([ref]$esxreport){

    $ctlname    = 'Password Complexity'
    $command    = '($esx | Get-AdvancedSetting -Name Security.PasswordQualityControl).Value'
    $expected   = 'min=disabled,disabled,15,15,15 passphrase=0 random=0'

    $esxreport.value += Get-ComplianceStatus -command $command -expected $expected -ctlname $ctlname  

}

Function Get-ESXAccountLockout([ref]$esxreport){

    $ctlname    = 'Account Lockout'
    $command    = '($esx | Get-AdvancedSetting -Name Security.AccountLockFailures).Value'    
    $expected   = '3'

    $esxreport.value += Get-ComplianceStatus -command $command -expected $expected -ctlname $ctlname 

}

Function Get-ESXAccountUnlock([ref]$esxreport){

    $ctlname    = 'Account Unlock Time'
    $command    = '($esx | Get-AdvancedSetting -Name Security.AccountUnlockTime).Value'    
    $expected   = '900'

    $esxreport.value += Get-ComplianceStatus -command $command -expected $expected -ctlname $ctlname  

}

Function Get-ESXMobStatus([ref]$esxreport){
    
    $ctlname    = 'Managed Object Browser'
    $command    = '($esx | Get-AdvancedSetting -Name Config.HostAgent.plugins.solo.enableMob).Value'    
    
    $esxreport.value += Get-ComplianceStatus -command $command -ctlname $ctlname

}

Function Get-ESXDVFilterBind([ref]$esxreport){

    $ctlname    = 'DVFilter API Bind'
    $command    = '($esx | Get-AdvancedSetting -Name Net.DVFilterBindIpAddress).Value'    
    
    $esxreport.value += Get-ComplianceStatus -command $command -ctlname $ctlname
    
}

Function Get-ESXGlobalLogDir([ref]$esxreport){
  
    $ctlname    = 'Global Log Dir'
    $command    = '($esx | Get-AdvancedSetting -Name Syslog.global.logDir).Value'    
    
    $esxreport.value += Get-ComplianceStatus -command $command -ctlname $ctlname

}

Function Get-VIBAcceptanceLevel([ref]$esxreport){
  
    $ctlname    = 'VIB Acceptance Level'
    $esxcli     = get-esxcli -VMHost $esx -V2    
    $command    = '$esxcli.software.acceptance.get.Invoke()'

    $esxreport.value += Get-ComplianceStatus -command $command -ctlname $ctlname

}

Function Get-ESXShellIdleTimeout([ref]$esxreport){

    $ctlname    = 'ESXi Shell Idle Timeout'
    $command    = '($esx | Get-AdvancedSetting -Name UserVars.ESXiShellInteractiveTimeOut).Value'    
    $expected   = '900'

    $esxreport.value += Get-ComplianceStatus -command $command -expected $expected -ctlname $ctlname

}

Function Get-ESXShellInteractiveTimeout([ref]$esxreport){

    $ctlname    = 'ESXi Shell Interactive Timeout'
    $command    = '($esx | Get-AdvancedSetting -Name UserVars.ESXiShellTimeOut).Value'    
    $expected   = '900'

    $esxreport.value += Get-ComplianceStatus -command $command -expected $expected -ctlname $ctlname

}

Function Get-ESXTLSDisabledVersions([ref]$esxreport){

    $ctlname    = 'SSL/TLS Disabled Versions'
    $command    = '($esx | Get-AdvancedSetting -Name UserVars.ESXiVPsDisabledProtocols).Value'    
    $expected   = 'sslv3,tlsv1.1,tlsv1.0'

    $esxreport.value += Get-ComplianceStatus -command $command -expected $expected -ctlname $ctlname

}

Function Start-ESXHC{

    Get-ESXPwdComplexity([ref]$esxreport)  
    Get-ESXAccountLockout([ref]$esxreport)   
    Get-ESXAccountUnlock([ref]$esxreport) 
    Get-ESXMobStatus([ref]$esxreport)
    Get-ESXDVFilterBind([ref]$esxreport)
    Get-ESXGlobalLogDir([ref]$esxreport)
    Get-VIBAcceptanceLevel([ref]$esxreport)
    Get-ESXShellIdleTimeout([ref]$esxreport)
    Get-ESXShellInteractiveTimeout([ref]$esxreport)
    Get-ESXTLSDisabledVersions([ref]$esxreport)

}

#endregion funciones

$vclist  = @('')

$user    = ''
$pass    = ''

$fullreport = @()

foreach ($vc in $vclist) {

    $vcreport = @()

    connect-viserver -server $vc -User $user -Password $pass | out-null

    $esxlist = Get-VMHost | Where-Object {($_.ConnectionState -eq 'Connected' -or 'Maintenance') -and ($_.ConnectionState -ne 'NotResponding')} | Sort-Object -Property Name

    foreach ($esx in $esxlist) {
        
        $esxreport = @()

        Start-ESXHC
        
        $vcreport += $esxreport   

    }

    Disconnect-VIServer -Confirm:$false

    $fullreport += $vcreport
    
}

$fullreport | Format-Table -AutoSize #| export-csv -path '.\full-hc-report.csv' -NoTypeInformation