@echo off
cd /d "%~dp0"
set "PATH=D:\FYP\tools\flutter\bin;%PATH%"
curl.exe --fail --silent --max-time 3 http://127.0.0.1:8765/ -o NUL
if not errorlevel 1 (
  start "" "http://localhost:8765"
  exit /b 0
)
call flutter --no-version-check pub get
if errorlevel 1 (
  pause
  exit /b 1
)
call flutter --no-version-check run -d edge --web-port 8765 --dart-define-from-file=.env
pause
