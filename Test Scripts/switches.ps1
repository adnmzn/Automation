foreach ($VMHost in Get-VMHost){
    Write-Host "`n"$VMHost.Name
    foreach($vSwitch in $VMHost | Get-VirtualSwitch -Standard){
        Write-Host " "$vSwitch.Name
        Write-Host "`tPromiscuous mode enabled:" $vSwitch.ExtensionData.Spec.Policy.Security.AllowPromiscuous
        Write-Host "`tForged transmits enabled:" $vSwitch.ExtensionData.Spec.Policy.Security.ForgedTransmits
        Write-Host "`tMAC Changes enabled:" $vSwitch.ExtensionData.Spec.Policy.Security.MacChanges
        foreach($portgroup in ($VMHost.ExtensionData.Config.Network.Portgroup | where {$_.Vswitch -eq $vSwitch.Key})){
            Write-Host "`n`t`t"$portgroup.Spec.Name
            Write-Host "`t`t`tPromiscuous mode enabled: " -nonewline
            If ($portgroup.Spec.Policy.Security.AllowPromiscuous -eq $null) { Write-Host $vSwitch.ExtensionData.Spec.Policy.Security.AllowPromiscuous } Else { Write-Host $portgroup.Spec.Policy.Security.AllowPromiscuous }
            Write-Host "`t`t`tForged transmits enabled: " -nonewline
            If ($portgroup.Spec.Policy.Security.ForgedTransmits -eq $null) { Write-Host $vSwitch.ExtensionData.Spec.Policy.Security.ForgedTransmits } Else { Write-Host $portgroup.Spec.Policy.Security.ForgedTransmits }
            Write-Host "`t`t`tMAC Changes enabled: " -nonewline
            If ($portgroup.Spec.Policy.Security.MacChanges -eq $null) { Write-Host $vSwitch.ExtensionData.Spec.Policy.Security.MacChanges } Else { Write-Host $portgroup.Spec.Policy.Security.MacChanges }
        }
    }
    foreach($vSwitch in $VMHost | Get-VirtualSwitch -Distributed){
        Write-Host " "$vSwitch.Name
        Write-Host "`tPromiscuous mode enabled:" $vSwitch.Extensiondata.Config.DefaultPortConfig.SecurityPolicy.AllowPromiscuous.Value
        Write-Host "`tForged transmits enabled:" $vSwitch.Extensiondata.Config.DefaultPortConfig.SecurityPolicy.ForgedTransmits.Value
        Write-Host "`tMAC Changes enabled:" $vSwitch.Extensiondata.Config.DefaultPortConfig.SecurityPolicy.MacChanges.Value
        foreach($portgroup in (Get-VirtualPortGroup -Distributed -VirtualSwitch $vSwitch)){
            Write-Host "`n`t`t"$portgroup.Name
            Write-Host "`t`t`tPromiscuous mode enabled:" $portgroup.Extensiondata.Config.DefaultPortConfig.SecurityPolicy.AllowPromiscuous.Value
            Write-Host "`t`t`tForged transmits enabled:" $portgroup.Extensiondata.Config.DefaultPortConfig.SecurityPolicy.ForgedTransmits.Value
            Write-Host "`t`t`tMAC Changes enabled:" $portgroup.Extensiondata.Config.DefaultPortConfig.SecurityPolicy.MacChanges.Value
        }
    }
}