﻿# Script to run VMware vsipioctl utility against all VMs / all hosts
# NOTE: Requires darkoperator PoshSSH for PowerShell
#
# To install PoshSSH:
# iex (New-Object Net.WebClient).DownloadString("https://gist.github.com/darkoperator/6152630/raw/c67de4f7cd780ba367cccbc2593f38d18ce6df89/instposhsshdev")

# Specify our vCenter instance FQDN or IP:
$vCenter = "<vcenter FQDN or IP address>"

# Prompt user for vCenter credentials if not known:
if ($credVCenter -eq $null) {
    $credVCenter = Get-Credential -Message "Authenticate to vCenter Server"
}

# Prompt user for ESXi host credentials if not known:
if ($credESXi -eq $null) {
    $credESXi = Get-Credential -Message "Provide ESXi root password" -UserName root
}

# Directory containing this script:
$scriptDir = Split-Path -Path $($global:MyInvocation.MyCommand.Path)

# Location to find the VMware vsipioctl binary:
$source_file = $scriptDir+"\vsipioctl"

$target_path = "/tmp/"

# Output CSV File in current (script) directory:
$csvOut = $scriptDir+"\fwexport.csv"

# Location to copy vsipioctl to on ESXi hosts:
$target_file = "/tmp/vsipioctl"

Connect-VIServer -Server $vCenter -Credential $credVCenter

# Define an output table object with required columns:
$table = New-Object System.Data.DataTable
$col1 = New-Object System.Data.DataColumn Host,([string])
$col2 = New-Object System.Data.DataColumn VMName,([string])
$col3 = New-Object System.Data.DataColumn NIC,([string])
$col4 = New-Object System.Data.DataColumn ExportVersion,([int])
$table.Columns.Add($col1)
$table.Columns.Add($col2)
$table.Columns.Add($col3)
$table.Columns.Add($col4)

Get-VMHost | Foreach {

    Write-Host "Starting processing for Host: $_" -ForegroundColor Green

    Write-Host "- Enabling SSH on Host" -ForegroundColor Green
    $start = Start-VMHostService -HostService ($_ | Get-VMHostService | Where { $_.Key -eq "TSM-SSH"} )

    $ssh = New-SSHSession -ComputerName $_ -Credential $credESXi -Port 22 -AcceptKey:$true

    if ($ssh.Connected -eq $true) {

        $return = Invoke-SSHCommand -SSHSession $ssh -Command "uname -a"
        Write-Host "Host ID: " + $return.Output -ForegroundColor Yellow

        # Copy the VMware vsipioctl utility to the host:
        Write-Host "- Copying binary file" -ForegroundColor Green
        $scp = Set-SCPFile -ComputerName $_ -Credential $credESXi -Port 22 -LocalFile $source_file -RemotePath $target_path

        # And flag it as executable:
        Write-Host "- Changing execute mode" -ForegroundColor Green
        Invoke-SSHCommand -SSHSession $ssh -Command "chmod 'u+x' $target_file" | Out-Null

        Write-Host "- Retrieving directory list:" -ForegroundColor Green
        $dirlist = Invoke-SSHCommand -SSHSession $ssh -Command "ls -l $target_file"
        Write-Host $dirlist.Output
        
        # Retrieve summarize-dvfilter output:
        Write-Host "- Getting full list of dvfilters" -ForegroundColor Green 
        $dvflist = Invoke-SSHCommand -SSHSession $ssh -Command "summarize-dvfilter"

        # Parse each line in the summarize-dvfilter output:
        ForEach ($item in $dvflist.Output) {

            # If we see a new VM identifier, update our current VMName setting:
            if ($item -match '(?<=vmm0:)(.*)(?= vcUuid:)') {
                $VMName = $matches[0]
            }
            # If we see a line that looks like a fw export, grab that and run vsipioctl on it:
            if ($item -match '(?<=name: )(.*sfw.2)') {
                $VMNic = $matches[0]
                
                $fwexport = Invoke-SSHCommand -SSHSession $ssh -Command "/tmp/vsipioctl getexportversion -f $VMnic"
            
                # Parse the returned 'Current Export Version' from vsipioctl:
                $exmatch = $fwexport.Output[0] -match '(?<=version: )(.*)'
                $exportVersion = $matches[0]

                # Add a table row that includes the VM name, NIC ID and exportversion:
                $row = $table.NewRow()
                $row.Host = $_
                $row.VMName = $VMName
                $row.NIC = $VMNic
                $row.ExportVersion = $exportVersion
                $table.Rows.Add($row)
            } # Line that looks like a fw export

        } # Foreach line in summarize-dvfilter output

        Remove-SSHSession -SSHSession $ssh | Out-Null

    } else {
        Write-Host "Error connecting to host $_, skipping." -ForegroundColor Red
    }

    Write-Host "- Disabling SSH on Host" -ForegroundColor Green
    $stop = Stop-VMHostService -HostService ($_ | Get-VMHostService | Where { $_.Key -eq "TSM-SSH"} ) -Confirm:$false
 
} # Foreach VMHost

$table | Format-Table -AutoSize
$table | Export-Csv $csvOut