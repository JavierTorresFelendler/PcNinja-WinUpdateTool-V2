@echo off
setlocal
set "MSI=%~dp0..\WinUpdate.Tool.by.PcNinja.msi"
msiexec /i "%MSI%" /qn /norestart
exit /b %ERRORLEVEL%
