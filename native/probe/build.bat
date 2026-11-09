@echo off
rem Builds deskbuddy_probe.exe with MinGW gcc (must be on PATH).
cd /d "%~dp0"
if not exist ..in mkdir ..in
gcc -O2 -s -Wall -o ..in\deskbuddy_probe.exe deskbuddy_probe.c
if errorlevel 1 exit /b 1
echo OK: ..in\deskbuddy_probe.exe
