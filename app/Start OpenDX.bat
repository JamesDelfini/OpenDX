@echo off
setlocal
cd /d "%~dp0"
set "URL=http://localhost:8642"

rem The app needs Node.js for its small local server (Web Serial only works on localhost/https).
where node >nul 2>&1
if errorlevel 1 (
  echo Node.js was not found. Install it from https://nodejs.org and run this again.
  pause
  exit /b 1
)

rem DX Light keeps the controller's COM port open, so close it first.
taskkill /IM "DX Light.exe" /F >nul 2>&1

rem Start the server unless it is already running.
netstat -ano | findstr /R /C:"127.0.0.1:8642 .*LISTENING" >nul
if errorlevel 1 (
  start "OpenDX server" /min node serve.js
  ping -n 2 127.0.0.1 >nul
)

rem Open as an app window in Edge or Chrome (Web Serial needs a Chromium browser).
set "BROWSER="
for %%B in (
  "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
  "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
  "%ProgramFiles%\Google\Chrome\Application\chrome.exe"
  "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
  "%LocalAppData%\Google\Chrome\Application\chrome.exe"
) do if not defined BROWSER if exist %%B set "BROWSER=%%~B"

if defined BROWSER (
  start "" "%BROWSER%" --app=%URL%
) else (
  echo Edge or Chrome not found, opening the default browser. Web Serial needs Edge or Chrome.
  start "" %URL%
)
