@echo off
REM Write each PHP project + stack web UI into the Windows hosts file as
REM <name>.test -> 127.0.0.1. Run in an ADMINISTRATOR command prompt. Only needed
REM if you DON'T point your DNS at the dns container (it wildcard-resolves *.test).
setlocal enabledelayedexpansion
pushd "%~dp0..\.."

REM Load .env for PHP_PROJECTS_PATH + web-UI hostnames.
if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"
if "%PHP_PROJECTS_PATH%"=="" set "PHP_PROJECTS_PATH=./www"
if "%CACHE_ADMIN_HOST%"=="" set "CACHE_ADMIN_HOST=cache.test"
if "%DB_ADMIN_HOST%"=="" set "DB_ADMIN_HOST=db.test"
if "%CENTRIFUGO_HOST%"=="" set "CENTRIFUGO_HOST=centrifugo.test"
if "%EMQX_DASHBOARD_HOST%"=="" set "EMQX_DASHBOARD_HOST=mqtt.test"
if "%SOKETI_HOST%"=="" set "SOKETI_HOST=ws.test"
if "%DRAWDB_HOST%"=="" set "DRAWDB_HOST=drawdb.test"
if "%HOP_HOST%"=="" set "HOP_HOST=hop.test"
if "%SUPERSET_HOST%"=="" set "SUPERSET_HOST=superset.test"
if "%SEMGREP_HOST%"=="" set "SEMGREP_HOST=semgrep.test"
set "PROJDIR=%PHP_PROJECTS_PATH:/=\%"

set "HOSTS=%WINDIR%\System32\drivers\etc\hosts"
set "MARKER=# local-dev-stack"
set "TMP=%TEMP%\lds-hosts.tmp"

echo.
echo ========================================================
echo   hosts-sync - writing *.test entries into %HOSTS%
echo ========================================================

REM Strip the previous managed block: every line we write carries %MARKER% (the
REM BEGIN/END banners and per-category sub-headers too), so one filter removes
REM the whole grouped block and any legacy entries in a single pass.
findstr /v /c:"%MARKER%" "%HOSTS%" > "%TMP%"
set "TOTAL=0"

REM Open the grouped block with a banner so it's distinct from other hosts entries.
>> "%TMP%" echo # ===== local-dev-stack - managed by 'lds hosts-sync' (do not edit below) =====   %MARKER%

REM --- Projects: every folder under PHP_PROJECTS_PATH is served at <name>.test ---
call :sec "Projects (%PROJDIR%)"
set "PROJ=0"
for /d %%d in ("%PROJDIR%\*") do (
  >> "%TMP%" echo 127.0.0.1 %%~nxd.test %MARKER%
  echo     http://%%~nxd.test
  set /a PROJ+=1
  set /a TOTAL+=1
)
if "!PROJ!"=="0" (
  >> "%TMP%" echo #   ^(no project folders yet^)   %MARKER%
  echo     ^(none yet - drop a folder into %PROJDIR%^)
)

REM --- Tools & UIs: stack services routed by VIRTUAL_HOST (not folders). Grouped
REM to mirror the localhost control panel. Harmless when the profile is off. ---
call :sec "Data tools"
call :add %CACHE_ADMIN_HOST%
call :add %DB_ADMIN_HOST%
call :sec "Database design"
call :add %DRAWDB_HOST% "(open via http://localhost:4423 - needs a secure context)"
call :sec "Data warehouse & BI"
call :add %SUPERSET_HOST%
call :add %HOP_HOST%
call :sec "Code quality"
call :add %SEMGREP_HOST%
call :sec "Realtime & messaging"
call :add %SOKETI_HOST%
call :add %CENTRIFUGO_HOST%
call :add %EMQX_DASHBOARD_HOST%

>> "%TMP%" echo # ===== end local-dev-stack =====   %MARKER%

copy /y "%TMP%" "%HOSTS%" >nul
del "%TMP%"
echo.
echo   ---- hosts-sync: done (!TOTAL! host(s) synced to %HOSTS%) ----
echo   The control panel lives at http://localhost (no hosts entry needed).
popd
endlocal
goto :eof

REM --- helper: write a grouped sub-header (file comment + console) -------------
:sec
set "S=%~1"
>> "%TMP%" echo # --- !S! ---   %MARKER%
echo.
echo   !S!
goto :eof

REM --- helper: write one host entry + echo it (arg2 = optional note) ----------
:add
if "%~1"=="" goto :eof
>> "%TMP%" echo 127.0.0.1 %~1 %MARKER%
echo     http://%~1 %~2
set /a TOTAL+=1
goto :eof
