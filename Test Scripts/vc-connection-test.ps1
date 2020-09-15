#region variables
$vclist = @("b02peivis001labvc.ciolab.ibm.com","b02peivis002labvc.ciolab.ibm.com")
$user = "us\aemonzon"
$pass = "Ozzy2015Riff2020"
$connected = $false
#endregion

#region main

clear-host

foreach($vc in $vclist){
    try {
        write-host "...connecting to vcenter $vc..." -ForegroundColor Yellow
        connect-viserver -server $vc -user $user -pass $pass -ErrorAction stop | out-null 
        write-host "...connected..." -ForegroundColor green
        $connected = $true
    }
    catch {
        $error[0].exception.message
        write-host "...connection failed..." -ForegroundColor red
        $connected = $false
    }

    if($connected){
        disconnect-viserver -confirm:$false
        write-host "...disconnected from vcenter $vc..." -foregroundcolor yellow
    }
}

#endregion