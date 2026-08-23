@echo off
REM proj5.bat - jump into the claudetldr project
set "PROJ=C:\Users\Dell\Downloads\Projekte\claudetldr"

if not exist "%PROJ%" (
    echo Folder not found: %PROJ%
    echo Edit PROJ in this file to point at your repo.
    pause
    exit /b 1
)

cd /d "%PROJ%"
echo.
echo  claudetldr  -  %CD%
echo.
echo    python bridge.py --list       list recent Cowork sessions
echo    python bridge.py              watch the newest session
echo    python -m http.server 8000    serve the viewer (localhost:8000)
echo.
cmd /k
