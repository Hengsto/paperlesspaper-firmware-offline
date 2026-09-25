@echo off
setlocal
rem Run manually: flash-windows.cmd COM5
rem Find the port in Windows Device Manager under Ports (COM and LPT).
if "%~1"=="" (
  echo Usage: flash-windows.cmd COM5
  echo Replace COM5 with the ESP32-C6 port from Windows Device Manager.
  exit /b 2
)
set "PORT=%~1"
powershell -NoProfile -Command "if ($env:PORT -notmatch '^COM[0-9]+$') { exit 1 }"
if errorlevel 1 (
  echo Invalid port. Expected COM followed by a number, for example COM5.
  exit /b 2
)
pushd "%~dp0"
py -m esptool version >nul 2>&1
if errorlevel 1 (
  echo Install Python 3 with the Python launcher, then run:
  echo py -m pip install esptool==5.1.2
  popd
  exit /b 2
)
powershell -NoProfile -Command "$ErrorActionPreference='Stop'; Get-Content SHA256SUMS | ForEach-Object { $p = $_ -split '  ',2; if ((Get-FileHash -Algorithm SHA256 -LiteralPath $p[1]).Hash -ne $p[0]) { throw ('SHA256 mismatch: '+$p[1]) } }"
if errorlevel 1 (
  echo Package checksum verification failed. No flash performed.
  popd
  exit /b 1
)
py -m esptool --chip esp32c6 --port "%PORT%" --baud 460800 --before default-reset --after hard-reset write-flash --flash-mode dio --flash-freq 80m --flash-size 4MB 0x0000 bootloader.bin 0x8000 partitions.bin 0xe000 boot_app0.bin 0x10000 firmware.bin
if errorlevel 1 (
  popd
  exit /b 1
)
py -m esptool --chip esp32c6 --port "%PORT%" --baud 460800 verify-flash 0x0000 bootloader.bin 0x8000 partitions.bin 0xe000 boot_app0.bin 0x10000 firmware.bin
set "RESULT=%ERRORLEVEL%"
popd
exit /b %RESULT%
