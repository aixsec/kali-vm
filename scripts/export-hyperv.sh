#!/bin/sh

set -eu

SCRIPTSDIR=$RECIPEDIR/scripts
START_TIME=$(date +%s)

info() { echo "INFO:" "$@"; }

image=
keep=0
zip=0

while [ $# -gt 0 ]; do
    case $1 in
        -k) keep=1 ;;
        -z) zip=1 ;;
        *) image=$1 ;;
    esac
    shift
done

cd $ARTIFACTDIR

info "Generate $image.vhdx"
qemu-img convert -O vhdx $image.raw $image.vhdx

[ $keep -eq 1 ] || rm -f $image.raw

info "Create install-vm.bat"
cat << 'EOF' > install-vm.bat
@echo off

REM What happens in this script, stays in this script
setlocal


REM Check for administrative privileges
echo [i] Checking for administrative access
net file 1>nul 2>nul
if "%errorlevel%" == "0" (goto admin)


REM Generate UAC request & re-run self
:elevate
echo [-] This is a non-administrative prompt. Re-trying...
powershell.exe Start-Process %~s0 -Verb runAs
exit /B


REM Run when administrative
:admin
REM Check if Hyper-V is installed/enabled
echo [i] Looking for Hyper-V
for /f "usebackq delims=" %%a in (`PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$feature = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -eq 'Microsoft-Hyper-V' }; $feature.State.ToString().ToLower()"`) do (
    set "hvstatus=%%a"
)
if /i "%hvstatus%"=="enabled" (
  echo [i] Hyper-V is ENABLED
) else if /i "%hvstatus%"=="disabled" (
  echo [i] Hyper-V is DISABLED. Enabling...

  for /f "delims=" %%i in ('powershell -NoProfile -Command "if (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue) { 'FOUND' } else { 'NOT FOUND' }"') do set "result=%%i"
  if /i "%result%"=="FOUND" (
    echo [i] Likely on Windows Server
    PowerShell -NoProfile -ExecutionPolicy Bypass -Command "Install-WindowsFeature -Name Hyper-V -IncludeManagementTools"
  ) else (
    echo [i] Likely on Windows 10/11
    dism /Online /Enable-Feature /FeatureName:Microsoft-Hyper-V /All /LimitAccess /NoRestart
    dism /Online /Enable-Feature /FeatureName:Microsoft-Hyper-V-Management-PowerShell /All /LimitAccess /NoRestart
    REM PowerShell -NoProfile -ExecutionPolicy Bypass -Command "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell -All -LimitAccess -NoRestart"
  )
  echo.
  echo.
  echo [i] Now manually reboot/restart
  pause
  exit /B
) else (
  echo [-] Could not determine Hyper-V status: %hvstatus%
  pause
  REM exit /B
)

REM Install VM
:import
echo [i] Importing VM to Hyper-V
PowerShell -NoProfile -ExecutionPolicy Bypass -Command ""cd %~dp0; .\create-vm.ps1""

REM Open Hyper-V Manager
:open
echo [i] Opening Hyper-V Manager
virtmgmt.msc
pause
EOF

info "Generate create-vm.ps1"
$SCRIPTSDIR/generate-powershell.sh $image.vhdx create-vm.ps1

# Set Windows EOL (\r\n) to make notepad.exe happy
sed -i 's/\r*$/\r/g' install-vm.bat create-vm.ps1

if [ $zip -eq 1 ]; then
    info "Compress to $image.7z"
    mkdir $image
    mv $image.vhdx install-vm.bat create-vm.ps1 $image
    7zr a -sdel -mx=9 $image.7z $image
fi

for fn in create-vm.ps1 install-vm.bat $image.*; do
    [ -e $fn ] || continue
    [ $(stat -c %Y $fn) -ge $START_TIME ] && echo $fn || :
done > .artifacts
