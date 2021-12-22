Function Disconnect-VMSerialPort($VMLIST)
{
	IF($VMLIST.Count -gt 1)
	{
		ForEach($VMName in $VMLIST)
		{	
			$VM = Get-VM $VMName
			$DEVICES = $VM.ExtensionData.Config.Hardware.Device
			FOREACH($DEVICE in $DEVICES)
			{
				IF($DEVICE.GetType().Name -eq "VirtualSerialPort")
				{
					IF($DEVICE.Connectable.Connected -eq $true)
					{
						Write-Host "Serial Device Found Connected on VM: $VM, Disconnecting..."
						$DEV = New-Object VMware.Vim.VirtualDeviceConfigSpec
						#add edit remove
						$DEV.Operation = "edit"
						$DEV.Device = New-Object VMware.Vim.VirtualSerialPort
						$DEV.Device.Key = $DEVICE.Key
						$DEV.Device.ControllerKey = $DEVICE.ControllerKey
						$DEV.Device.UnitNumber += $DEVICE.UnitNumber
						$DEV.Device.DeviceInfo += $DEVICE.DeviceInfo
						$DEV.Device.Backing += $DEVICE.Backing
						$DEV.Device.Connectable += $DEVICE.Connectable
						$DEV.Device.Connectable.Connected = $false
						$DEV.Device.Connectable.StartConnected = $false
						$SPEC = New-Object VMware.Vim.VirtualMachineConfigSpec
						$SPEC.DeviceChange += $DEV
						$VM.ExtensionData.ReconfigVM($SPEC)
						$DEVICEUpdated = $VM.ExtensionData.Config.Hardware.Device | Where {$_.Key -eq $DEVICE.Key}
						#Write-Output $DEVICEUpdated
						Write-Output $DEVICEUpdated.Connectable
					}Else{
						Write-Host "No Serial Device Found Connected on VM: $VM"
					}
				}
			}
		}
	}
	IF($VMLIST.Count -eq 1)
	{	
		$VM = Get-VM $VMLIST
		$DEVICES = $VM.ExtensionData.Config.Hardware.Device
		FOREACH($DEVICE in $DEVICES)
		{
			IF($DEVICE.GetType().Name -eq "VirtualSerialPort")
			{
				IF($DEVICE.Connectable.Connected -eq $true)
				{
					Write-Host "Serial Device Found Connected on VM: $VM, Disconnecting..."
					$DEV = New-Object VMware.Vim.VirtualDeviceConfigSpec
					#add edit remove
					$DEV.Operation = "edit"
					$DEV.Device = New-Object VMware.Vim.VirtualSerialPort
					$DEV.Device.Key = $DEVICE.Key
					$DEV.Device.ControllerKey = $DEVICE.ControllerKey
					$DEV.Device.UnitNumber += $DEVICE.UnitNumber
					$DEV.Device.DeviceInfo += $DEVICE.DeviceInfo
					$DEV.Device.Backing += $DEVICE.Backing
					$DEV.Device.Connectable += $DEVICE.Connectable
					$DEV.Device.Connectable.Connected = $false
					$DEV.Device.Connectable.StartConnected = $false
					$SPEC = New-Object VMware.Vim.VirtualMachineConfigSpec
					$SPEC.DeviceChange += $DEV
					$VM.ExtensionData.ReconfigVM($SPEC)
					$DEVICEUpdated = $VM.ExtensionData.Config.Hardware.Device | Where {$_.Key -eq $DEVICE.Key}
					#Write-Output $DEVICEUpdated
					Write-Output $DEVICEUpdated.Connectable
				}Else{
					Write-Host "No Serial Device Found Connected on VM: $VM"
				}
			}
		}
	}
}

#Examples
#$VMLIST = Get-VM
#Disconnect-VMSerialPort $VMLIST
#Disconnect-VMSerialPort (Get-VM $VMNAMEHERE)
#Disconnect-VMSerialPort (Get-VMHost $VMHOSTHERE | Get-VM $VMNAMEHERE)

