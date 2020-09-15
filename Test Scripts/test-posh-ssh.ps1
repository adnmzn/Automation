if ((Get-Module -Name Posh-SSH -ErrorAction SilentlyContinue) -eq $null ) { Import-Module "Posh-SSH" -Force:$true -WarningAction SilentlyContinue}
 
Function Get-SSHResult() {
Param (
    [PSCredential]$connectionCredentials,
    [string]$ESXiHost,
    [string]$sshCommand
)
 
#Start SSH Services
start-VMHostService -HostService (Get-VMHost "$ESXihost"| Get-VMHostService | Where { $_.Key -eq "TSM-SSH"} ) -Confirm:$false
 
$Session = New-SSHSession -ComputerName "$($ESXiHost)" -Credential $($connectionCredentials) -AcceptKey -ConnectionTimeout 90 -KeepAliveInterval 5
$returned = Invoke-SSHCommand -Command "$($sshCommand)" -SessionId $Session.SessionId 
if ($Session.SessionId) { $closed = Remove-SSHSession -SessionId $Session.SessionId }
 
#Stop ssh Services
Stop-VMHostService -HostService (Get-VMHost "$ESXihost" | Get-VMHostService | Where { $_.Key -eq "TSM-SSH"} ) -Confirm:$false 
  
return ($returned)  
 
}
 
#Connect to the vcenter first so we can enable ssh and disable ssh 
Connect-VIserver -server b02peivis001labvc.ciolab.ibm.com -user us\aemonzon -password Ozzy2015Riff2020 | out-null
 
#Get a set of credentials to connect with using posh-ssh
$credentials = Get-credential -Message "Enter Credentials to connect to host"
 
$returnedSSH = Get-SSHResult -connectionCredentials $credentials -EsxiHost "b02esx001.ciolab.ibm.com" -sshCommand "ls -al"
 
Write-Host "$($returnedSSH.output)"