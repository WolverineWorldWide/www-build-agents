@ECHO OFF
echo Starting the CQL Scheduler on DEV IIS 7 if it isn't already running.

echo Sleep for a few seconds before we try starting it.
ping -n 5 127.0.0.1 >NUL

echo Calling sc.exe to start things up
sc.exe \\172.100.8.10 start CQLScheduler

echo All done
