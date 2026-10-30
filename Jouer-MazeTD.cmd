@echo off
setlocal
rem Le script voisin charge .env, puis .env.local, avant de lancer Godot.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\lancer-jeu.ps1" %*
set "MAZE_EXIT=%ERRORLEVEL%"
if not "%MAZE_EXIT%"=="0" pause
endlocal & exit /b %MAZE_EXIT%
