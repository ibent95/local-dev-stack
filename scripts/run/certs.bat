@echo off
REM Generate a wildcard dev TLS cert for the .test hosts into configs\proxy\certs\.
REM Prefers mkcert (trusted local CA -> no browser warnings); falls back to a
REM self-signed openssl cert.   certs.bat  |  certs.bat --force
setlocal
pushd "%~dp0..\.."
set "CERT_DIR=%CD%\configs\proxy\certs"
REM Named after the TLD: nginx-proxy matches vhost <name>.test to test.crt by
REM stripping the leftmost label. The php container also sets CERT_NAME=test
REM (in docker-compose.https.yml) so its localhost + regex *.test vhosts use it.
set "CRT=%CERT_DIR%\test.crt"
set "KEY=%CERT_DIR%\test.key"
if not exist "%CERT_DIR%" mkdir "%CERT_DIR%"

if /I "%~1"=="--force" del /q "%CRT%" "%KEY%" 2>nul

if exist "%CRT%" if exist "%KEY%" (
  echo Cert already present: %CRT%  ^(use --force to regenerate^)
  popd & endlocal & exit /b 0
)

where mkcert >nul 2>&1
if %errorlevel%==0 (
  echo Generating cert with mkcert ^(trusted local CA^)...
  mkcert -install
  mkcert -cert-file "%CRT%" -key-file "%KEY%" *.test test localhost 127.0.0.1 ::1
  echo Done - browsers will trust https://*.test
  goto reload
)

where openssl >nul 2>&1
if %errorlevel%==0 (
  echo mkcert not found - falling back to a self-signed openssl cert.
  echo   ^(the browser will warn until you trust it; install mkcert for a clean cert:
  echo    https://github.com/FiloSottile/mkcert ^)
  openssl req -x509 -newkey rsa:2048 -nodes -days 825 -keyout "%KEY%" -out "%CRT%" -subj "/CN=*.test/O=local-dev-stack" -addext "subjectAltName=DNS:*.test,DNS:test,DNS:localhost,IP:127.0.0.1,IP:0:0:0:0:0:0:0:1"
  echo Done ^(self-signed^): %CRT%
  goto reload
)

echo ERROR: neither mkcert nor openssl is installed.
echo Install mkcert ^(recommended^): https://github.com/FiloSottile/mkcert
popd & endlocal & exit /b 1

:reload
REM nginx re-reads cert files on reload, but a bind-mounted cert change does NOT
REM restart the container - a running proxy keeps serving the OLD cert (stale-cert
REM ERR_CERT_AUTHORITY_INVALID) until told to reload.
docker ps --format "{{.Names}}" 2>nul | findstr /x "lds-proxy" >nul && (
  echo Reloading lds-proxy to apply the new cert...
  docker exec lds-proxy nginx -s reload >nul 2>&1 || docker restart lds-proxy >nul 2>&1
)
popd & endlocal & exit /b 0
