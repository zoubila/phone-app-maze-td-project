@echo off
rem Reutilise le lanceur normal en autorisant toutes les grilles pour les essais.
call "%~dp0Jouer-MazeTD.cmd" -Dev
exit /b %ERRORLEVEL%
