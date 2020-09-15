$vclist     = Get-Content -Path '.\vclist.txt'
$outputFile = ".\all-rdm-report-" + (get-date -Format yyyy-MM-dd-HHmm) + ".csv"
 
$ususer        = ''
$uspass        = ''

$cpcuser       = ''
$cpcpass       = ''

$report = @()

foreach ($vc in $vclist) {

     $user     = $ususer
     $pass     = $uspass

     if ($vc -like "*.ash.cpc.ibm.com"){$user = $cpcuser
                                        $pass = $cpcpass}
    
     if ($vc -like "*.dal.cpc.ibm.com"){$user = $cpcuser
                                        $pass = $cpcpass}

    "Connecting vCenter servers ..."
     Connect-VIServer -server $vc -User $user -Password $pass | out-null
    
     $luns = @{}
     
    "Getting VM(s). Be patient, this can take up to an hour ..."
     
    $vms = Get-VM | Get-View
    ("Got " + $vms.Count + " VMs ...")
     
    foreach($vm in $vms) {
    
         ("Processing VM " + $vm.Name + " ...")
    
         $ctl   = $null
         $esx   = $null
                  
         write-host -NoNewLine "   Scanning VM's devices for RDMs ..."
         
         foreach($dev in $vm.Config.Hardware.Device){
    
              if(($dev.gettype()).Name -eq "VirtualDisk"){
    
                   if(($dev.Backing.CompatibilityMode -eq "physicalMode") -or ($dev.Backing.CompatibilityMode -eq "virtualMode")){
    
                        if ($null -eq $ctl) {
                           " Found at least one ..."
                           "   Getting VM's SCSI controllers ..."
                           $ctl = Get-ScsiController -VM ($vm).Name
                        }
    
                        if ($null -eq $esx) {
                            write-host -NoNewLine "   Getting VM's host ..."
                            $esx = (Get-View $vm.Runtime.Host).Name
                            write-host (": " + $esx)
                        }
    
                        if ($null -eq $luns[$esx]) {
                            ("   Getting SCSI LUNs of host " + $esx + " ...")
                            $luns[$esx] = Get-ScsiLun -VmHost $esx -luntype disk
                        }
    
                        $row                = "" | Select-Object VMName, Guest, GuestDevName, GuestDevID, VMHost, HDFileName, HDMode, HDsize, RuntimeName, CanonicalName
    
                        $row.VMName         = $vm.Name
                        $row.Guest          = $vm.Guest.GuestFullName
                        $row.GuestDevName   = $dev.DeviceInfo.Label
                        $SCSIBus            = ($ctl | Where-Object {$_.ExtensionData.Key -eq $dev.ControllerKey}).ExtensionData.BusNumber
                        $SCSIID             = $dev.UnitNumber
                        $row.GuestDevID     = "scsi" + $SCSIBus + ":" + $SCSIID
                        $row.VMHost         = $esx
                        $row.HDFileName     = $dev.Backing.FileName
                        $row.HDMode         = $dev.Backing.CompatibilityMode
                        $row.HDSize         = $dev.CapacityInKB
                        $lun                = ($luns[$esx] | Where-Object {$_.ExtensionData.Uuid -eq $dev.Backing.LunUuid})
                        $row.CanonicalName  = $lun.CanonicalName
                        $row.RuntimeName    = $lun.RuntimeName
    
                        $row | Add-Member -NotePropertyName 'vCenter' -NotePropertyValue $vc
                        
                        $report            += $row

                   }
              }
         }
    
         if ($null -eq $ctl) { " None found." }
    
    }
         
    "Disconnecting vCenter Server..."
    Disconnect-Viserver -confirm:$false    

}

"Exporting report data to $outputFile ..."
$report | Export-CSV -Path $outputFile -NoTypeInformation
"All done."