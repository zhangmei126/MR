@echo off

if exist "%SystemRoot%\system32" path %path%;%windir%\SysNative;%SystemRoot%\system32;%~dp0
bcdedit >nul
if '%errorlevel%' NEQ '0' (goto UACPrompt) else (goto UACAdmin)
:UACPrompt
%1 start "" mshta vbscript:createobject("shell.application").shellexecute("""%~0""","::",,"runas",1)(window.close)&exit
exit /B
:UACAdmin
cd /d "%~dp0"

set user=%username%
PowerShell taskkill /f /im MixedRealityPortal.exe /t
ping 127.0.0.1 -n 1
PowerShell .\MRSpatialPackagerHelperScript.ps1 -AppName holoshell -UserName %user% -Mode import -MapxPath D:\SoRealGame\MapShare\Map\ -LockMap 0
ping 127.0.0.1 -n 1
PowerShell .\MRSpatialPackagerHelperScript.ps1 -AppName holoshell -UserName %user% -Mode import -MapxPath D:\SoRealGame\MapShare\Map\ -LockMap 1