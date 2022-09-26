@ECHO OFF
REM Starts the CQL Scheduler on DEV IIS 7 if it isn't already running.

REM Sleep for a few seconds before we try starting it.
timeout /t 5 /nobreak > NUL

sc.exe \\172.100.8.10 start CQLScheduler obj= cqladmin password= "PASSWORD"

