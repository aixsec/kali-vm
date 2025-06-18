#Requires -RunAsAdministrator
#Requires -Modules Hyper-V

$Name = "%Name%"
$Description = "%Description%"
$SwitchName = "Default Switch"
$VHDPath = ".\%VHDPath%"

$ExistingSwitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if (-not $ExistingSwitch) {
    Write-Warning "Virtual switch '$SwitchName' not found. Creating one..."
    try {
        New-VMSwitch -Name $SwitchName -SwitchType Internal | Out-Null
        Write-Host "Created internal virtual switch '$SwitchName'"
    } catch {
        Write-Error "Failed to create virtual switch: $_"
        exit 1
    }
}

New-VM `
  -Generation 2 `
  -Name "$Name" `
  -MemoryStartupBytes 2048MB `
  -SwitchName $SwitchName `
  -VHDPath $VHDPath

Set-VM -Name "$Name" -Notes "$Description"
try {
    ## Windows 11+ Pro/Enterprise and Windows Server 2022+
    Set-VM -Name $Name -EnhancedSessionTransportType HVSocket #-ErrorAction Stop
} catch {
    Write-Warning "EnhancedSessionTransportType not supported on this system. Skipping..."
}
Set-VMFirmware -VMName "$Name" -EnableSecureBoot Off
Set-VMProcessor -VMName "$Name" -Count 2
Enable-VMIntegrationService -VMName "$Name" -Name "Guest Service Interface"

Write-Host ""
Write-Host "Your Kali Linux virtual machine is ready."
Write-Host "In order to use it, please start: Hyper-V Manager"
Write-Host "For more information please see:"
Write-Host "  https://www.kali.org/docs/virtualization/import-premade-hyper-v/"
Write-Host ""
