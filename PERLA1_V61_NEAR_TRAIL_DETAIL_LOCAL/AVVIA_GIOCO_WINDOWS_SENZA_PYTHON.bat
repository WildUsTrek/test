@echo off
setlocal
title PERLA1 V61 - PowerShell Server
cd /d "%~dp0"

echo ============================================================
echo  PERLA1 V61 - AVVIO SENZA PYTHON
echo ============================================================
echo.
echo Uso PowerShell integrato in Windows.
echo Se Windows chiede conferma di sicurezza, consenti l'esecuzione.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0AVVIA_GIOCO_SERVER_POWERSHELL.ps1" -Port 8000

echo.
echo Il server si e' fermato.
echo Se vedi errori, mandami il file AVVIO_GIOCO_POWERSHELL_LOG.txt
echo.
pause
endlocal
