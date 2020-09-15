<#------------------------------------------------------------------------------------------
RvTools for Multiple vCenters - Author: aemonzon@ar.ibm.com - v1
<#----------------------------------------------------------------------------------------#>

#region variables

    #us user (encrypt password with RVToolsPasswordEncryption.exe)
    $us_user = ''
    $us_secpwd = ''
    #cpcad user (encrypt password with RVToolsPasswordEncryption.exe)
    $cpc_user = ''
    $cpc_secpwd = ''

    #csv file with list of vcenters and box addresses
    [string] $vcListPath = "C:\Users\aemonzon\desktop\RVTOOLS\vclist.csv"

    #folder for rvtools exports
    [string] $XlsxDir = "C:\Users\aemonzon\desktop\RVTOOLS\Reports"

    #variable to hold the contents of the vclist file
    $vclist = Import-Csv -Path $vcListPath

    $date = get-date -Format 'ddMMMMyyyy'

    #Save current directory
    $SaveCurrentDir = (get-location).Path

    #Set RVTools path
    [string] $RVToolsPath = "C:\Program Files (x86)\Robware\RVTools"

    #cd to RVTools directory
    set-location $RVToolsPath

    #mailserver parameters
    [string] $SMTPserver = "na.relay.ibm.com"
    [string] $SMTPport = "25"
    #[string] $Mailto = "pcs_x86@wwpdl.vnet.ibm.com"
    [string] $MailFrom = "pcs_x86@donotreply.com"
    [string] $MailSubject = "PCS_X86 - RvTools Report for all vCenters"

#endregion

foreach ($vc in $vclist) {

    [string] $VCServer = $vc.vcenter  
    [string] $VCBoxAddress = $vc.boxfoldermail
    [string] $VCHostname = $VCServer.split(".")[0]                                                
    [string] $XlsxFile = "$VCHostname-$date.xlsx"
    [string] $User = $us_user
    [string] $EncryptedPassword = $us_secpwd
    [string] $Attachment = $XlsxDir + "\$XlsxFile"

    if ($VCServer -like "*.ash.cpc.ibm.com")
        {$User = $cpc_user 
        $EncryptedPassword = $cpc_secpwd}
    
    if ($VCServer -like "*.dal.cpc.ibm.com")
        {$User = $cpc_user
        $EncryptedPassword = $cpc_secpwd}

    #1) Ejecuto el CLI de RvTools
    Write-Host "Start export for vCenter $VCServer" -ForegroundColor DarkYellow
    $Arguments = "-u $User -p $EncryptedPassword -s $VCServer -c ExportAll2xlsx -d $XlsxDir -f $XlsxFile"

    Write-Host $Arguments

    $Process = Start-Process -FilePath ".\RVTools.exe" -ArgumentList $Arguments -NoNewWindow -Wait -PassThru

    if($Process.ExitCode -eq -1)
    {
        Write-Host "Error: Export failed! RVTools returned exitcode -1, probably a connection error! Script is stopped" -ForegroundColor Red
        exit 1
    }

    #2) Subo el reporte del vCenter a su carpeta en Box
    Write-Host "Send output file by mail" -ForegroundColor DarkYellow
    $Arguments = "/SMTPserver $SMTPserver /smtpport $SMTPport /mailto $VCBoxAddress /mailfrom $Mailfrom /mailsubject $Mailsubject /attachment $Attachment"
    Write-Host $Arguments
    Start-Process -FilePath ".\RVToolsSendmail.exe" -ArgumentList $Arguments -NoNewWindow -Wait
    
}

Set-Location $SaveCurrentDir