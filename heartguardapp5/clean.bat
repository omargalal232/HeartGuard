@echo off
echo Stopping any Flutter processes that might be running...
taskkill /f /im dart.exe
taskkill /f /im flutter.exe
taskkill /f /im java.exe
taskkill /f /im gradle.exe
taskkill /f /im adb.exe

echo Waiting for processes to fully terminate...
timeout /t 2 /nobreak

echo Removing build directories...
if exist build rmdir /s /q build
if exist .dart_tool rmdir /s /q .dart_tool
if exist .gradle rmdir /s /q .gradle
if exist android\.gradle rmdir /s /q android\.gradle
if exist android\app\build rmdir /s /q android\app\build

echo Running Flutter clean...
call flutter clean

echo Cleaning complete. Try running your app again.
pause 