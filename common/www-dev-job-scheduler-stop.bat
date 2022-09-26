@ECHO OFF
REM Stops the CQL Scheduler on DEV IIS 7 if it is running.
taskkill /s 172.100.8.10 /FI "IMAGENAME eq Cql.ProcessScheduler.exe" /u ".\cqladmin" /p "PASSWORD"

REM sc \\172.100.8.10 stop CQLScheduler

@ECHO OFF
REM KNOWN ERROR LEVELS
REM 1062 - Service already stopped
REM 1061 - Service not accepting control messages.
IF ERRORLEVEL 1063 GOTO :Error
IF ERRORLEVEL 1062 GOTO :Done
IF ERRORLEVEL 1061 GOTO :NoControl
IF ERRORLEVEL 1 GOTO :Error
GOTO :Done

:Done
echo Pause for 15 seconds to give the scheduler time to actually shut down.
ping 127.0.0.1 -n 16 > nul
EXIT /B 0

:NoControl
ECHO.
ECHO.
ECHO The CQLScheduler Service is not accepting start/stop commands right now.
ECHO.
ECHO In the past, Christopher has fixed this by uninstalling, reinstalling, and
ECHO reapplying the security settings.
ECHO.
ECHO.
ECHO.
GOTO :Error

:Error
EXIT /B 1
