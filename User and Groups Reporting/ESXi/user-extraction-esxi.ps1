# UID extraction script for use with VMware ESXi Server systems# Script to gather UID data from ESXi using PowerCLI
# Owner: UID Subsystem Extractor/UK/IBM
# Author: Siarhei Korkhau

# Revision History
# Initial Author: Andy King/UK/IBM - start
#
# v1.0 - 160410 - Original Version
# v1.1 - 220910 - Removed surplus delimeter character
# v1.2 - 220910 - Removed first header line of output mef3 file to allow proper URT load
# v1.3 - 051110 - Added NOTaRealID signature record Vadim Ivanov/Germany/Contr/IBM
# v1.4 - 051110 - Altered positioning of signature line addition within script
# v1.5 - 051110 - Added disconnect-viserver to close all connections after script has gathered data
# v1.6 - 061110 - Altered foreach construct to allow generation of individual mef3 files
# v1.7 - 081110 - Set DefaultVIServerMode to Single, then back to original state at process end
# v1.8 - 091210 - Altered $csvpath to use current directory
# v1.9 - 091210 - Introduced check to scan ESXi hosts only where a vCenter server also manages 'Classic' ESX hosts
# v2.0 - 161210 - Error and logon checking added, some code reordering, thanks to Jorgen Paludan Bentsen
# v2.1 - User label parameter was added. -FQDN option for shortnames.
# v2.2 - output filename was changed  customer+date+host.mef3
#
# Initial Author: Andy King/UK/IBM - end
#
# Starting from this: 
#     Owner: UID Subsystem Extractor/UK/IBM
#     Author: Siarhei Korkhau
#
# v2.3 - Update existing ESXi extractor to report ROLE information - V5.x only
# v2.4 - Removed last field separator symbol for V5.x only
# v2.5 - Changing the fill fields GROUP and PRIV
# v2.6 - Change the host type in mef3 file
# v2.7 - Privs added
# v2.8 - New parameter "-debug" was added. The "Wrong number of pipes" problem was fixed.
# v2.9 - Added the choice of credentials to use (domain or root)
#		 R000-829 Modification of ESXi extractor - PART2 - Performance and usability

param ( [switch]$fqdn = $false, [switch]$debug = $false )

#New parameter -getpriv was added
#param ( [switch]$fqdn = $false, [switch]$getpriv = $false)

[console]::ForegroundColor = "cyan"

$ErrorActionPreference = "SilentlyContinue"

$CurrentVIMode = Get-PowerCLIConfiguration
Set-PowerCLIConfiguration -DefaultVIServerMode Single -confirm:$false > $NULL 2>&1
$selection = read-host "If you are using same account to scan all hosts, enter 'Y'. Otherwise enter 'N':"
if (($selection -eq "Y") -or ($selection -eq "y")) {$esxiCreds = Get-Credential}
$customer = Read-Host "Please enter the customer code"
$label = $(
 $selection = read-host "Please enter user label (if not need press Enter):"
 if ($selection) {$selection} else {0}
)
$vcenter = Read-Host "Please enter the hostname of your vCenter Server or standalone ESXi Server"

$vi = Connect-VIServer -Server $vcenter -ErrorAction $ErrorActionPreference
if (!$?) {
	Write-Host -ForegroundColor Red "Logon failure: $($Error[0])"
	[console]::ResetColor()
	exit
}

$csvpath = "."

if ($debug) {
Remove-Item ./output.txt
$param = ""
if ($debug) {
   $param += "DEBUG "
}
if ($fqdn) {
   $param += "FQDN "
}
"EXTRACTION PROCESS-Started" | Out-File ./output.txt -Append;

$start_time = Get-Date -format F
"START TIME:" + $start_time | Out-File ./output.txt -Append;

"Following parameters will be processed: " + $param | Out-File ./output.txt -Append;

"SCRIPT VERSION: 2.9" | Out-File ./output.txt -Append;
}

#$customer = Read-Host "Please enter the customer code"

#$label = $(
# $selection = read-host "Please enter user label (if not need press Enter):"
# if ($selection) {$selection} else {0}
#)

$hosttype = "VMWARE ESXI"
$date = Get-Date -format "dMMMyyyy"
$signature_date = Get-Date -format "yyyy-MM-dd-HH.mm.ss"

$hostESXlist = Get-VMHost | where {$_.ConnectionState -ne "Disconnected"} | where {($_ | get-view).Config.Product.ProductLineId -eq "embeddedESX"} | sort-object -Property Name

foreach ($row in $hostESXlist){

if ($fqdn) {
	$ShortHostNameArray = $row.Name.split(".")
	$HostName = $ShortHostNameArray[0]
}else 
{
	$HostName = $row.Name
}

Read more at Suite101: Using PowerShell User Parameters and Prompts: How to Obtain Information from the Users of PowerShell Scripts | Suite101.com http://markalexanderbain.suite101.com/using-powershell-user-parameters-and-prompts-a122225#ixzz1uZcseuiE

	$csvname = $customer + "_" + $date + "_" + $HostName + ".mef3"
	Remove-Item -Path $csvpath\$csvname -Force -Confirm:$false

	if (!($vi.name -eq $row.name)) {
		if ($esxiCreds) {
			$login = Connect-VIServer -Server $row.Name -Credential $esxiCreds
		} else {
			Write-Host "Please provide logon credentials for" $row.Name -foregroundcolor "white"
			$login = Connect-VIServer -Server $row.Name
		}

		if (!$?) {
			Write-Host -ForegroundColor Red "Could not create MEF file for $($row.name)."
			Write-Host -ForegroundColor Red "   $($Error[0])"
			continue
		}
	}

	$accounts = Get-VMHostAccount -Server $row.name
    $queryRolePermission = Get-VIPermission -Server $row.name | Where {$_.IsGroup -eq $false -and $_.Entity -eq (Get-Folder -Name ha-folder-root) } | Select Principal, Role, Entity, IsGroup
        if ($debug) {
          $queryRolePermission | Out-File "./output.txt" -Append;
        }
	$signature = $customer + "|S|" + $HostName + "|" + $hosttype + "|NOTaRealID||000/V///" + $signature_date + ":FN=esxi_urt_extractor.ps1:VER=2.9:CKSUM=NA||||"

	$report = @()
        $version = Get-Vmhost | Get-View | Select @{N='Version';E={$_.Config.Product.Version}}
        if ($version.Count -gt 1) 
        {
            $ver = $version[0].Version.split(".");
        }else
        {
            $ver = $version.Version.split(".");
        }
       if ($debug) {
          "ESXI VERSION: " + $ver | Out-File "./output.txt" -Append;
        }
     
	foreach($user in $accounts){
        if ($debug) {
          $user | Out-File "./output.txt" -Append;
        }

        if ( (($ver[0] -eq 5) -and ($ver[1] -ge 1)) -or ($ver[0] -gt 5) )
        {
            # ESXi 5.1 and above
            $esxi51above = $true
    		$array = "" | Select-Object Hostname, User, Description, Group_membership
        }else
        {
            # ESXi 5.0 and below
            $esxi51above = $false
            # Ticket 81
    		# $array = "" | Select-Object Hostname, User, Description, Group_membership, priv_groups
    		$array = "" | Select-Object Hostname, User, Description, Group_membership
        }

		$array.Hostname = $customer + "|S|" + $HostName + "|$hosttype"
		$array.User = $user.Id + "|"
		if ($label -eq 0) {$array.Description = $user.Description + "|" + "|"}
        else {$array.Description = $label + "|" + "|"}
        if ($debug) {
          "array before processing:" | Out-File "./output.txt" -Append;
          $array | Out-File "./output.txt" -Append;
        }

        if ( $esxi51above )
        {
            # ESXi 5.1 and above
            $queryPermissionPrincipal = $queryRolePermission | Where {$_.Principal -eq $user.Id}

            #Specify the privileges of role you want to retrieve.
            #$queryPrivilege = Get-VIPrivilege -Role $queryPermissionPrincipal.Role
    	    # Converts array of privilegs onto a list -- Delimited by commma
            #if ($getpriv) {
            #   $strPrivilege = ($queryPrivilege | select -uniq) -join ","
            #}else 
            #{
            #   $strPrivilege = ""
            #}

            if ($queryPermissionPrincipal.Role -eq "Admin")
            {
               $strGroup = "ROLE(Admin)"
               $strPrivilege = "ROLE(Admin)"
            }else 
            {
               $strGroup = "ROLE(" + $queryPermissionPrincipal.Role + ")"
               $strPrivilege = ""
            }
            if ($user.Id -eq "root")
            {
               $strGroup = ""
               $strPrivilege = "ROLE(" + $queryPermissionPrincipal.Role + "),root"
            }
            $array.Group_membership = $strGroup + "|" + $strPrivilege
            
        }else
        {
            # ESXi 5.0 and below
            $array.Group_membership = $user.Groups[0] + "|"
            if ($debug) {
              "user.Groups:" | Out-File "./output.txt" -Append;
              $user.Groups | Out-File "./output.txt" -Append;
            }
               
            # Ticket 81
            #foreach ($group in $user.Groups)
            #{
            #    if(($group -eq "root") -or ($group -eq "nobody") -or ($group -eq "daemon"))
            #    {
            #        $array.priv_groups += $group + "|"
            #    }
            #}
        }

            if ($debug) {
              "array after processing:" | Out-File "./output.txt" -Append;
              $array | Out-File "./output.txt" -Append;
            }
 	    $report += $array
	}

	Write-Host "Gathering output and writing to a csv file...please wait" -foregroundcolor "green"
	$report | Export-Csv $csvpath\temp.csv -Delimiter "|" -NoTypeInformation
	Add-Content $csvpath\temp.csv -value $signature
	start-sleep -second 2
	Write-Host "Reformatting the csv file...please wait" -foregroundcolor "green"
	Get-Content $csvpath\temp.csv | Foreach-Object {$_ -replace '"', ""} | select -skip 1 | Set-Content $csvpath\$csvname
	start-sleep -second 5
	Write-Host "Removing temporary files" -foregroundcolor "green"
	Remove-Item $csvpath\temp.csv
	start-sleep -second 2
	Write-Host "Creation of output file $csvname complete" -foregroundcolor "magenta"
        if ($debug) {
           $path = split-path -parent $MyInvocation.MyCommand.Definition
          "Was created the output file " + $path + "\" + $csvname | Out-File ./output.txt -Append;
        }
    Disconnect-VIServer -Server $row.name -force -confirm:$false
}
if ($debug) {
"UID EXTRACTOR EXECUTION-Finished" | Out-File ./output.txt -Append;
}
Write-Host "Script run completed, disconnecting from all sessions"
disconnect-viserver -server * -force -confirm:$false
Set-PowerCLIConfiguration -DefaultVIServerMode $CurrentVIMode.DefaultVIServerMode -confirm:$false > $NULL 2>&1
[console]::ResetColor()