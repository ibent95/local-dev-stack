@echo off
REM Write each PHP project + stack web UI into the Windows hosts file as
REM <name>.test -> 127.0.0.1. The script re-launches itself elevated (UAC) when
REM needed, because %WINDIR%\System32\drivers\etc\hosts is Administrator-only.
setlocal enabledelayedexpansion

REM --- Elevation: writing the hosts file needs Administrator -------------------
REM LDS_HOSTS_NO_ELEV=1 skips the UAC re-launch (elevated callers and tests).
if not defined LDS_HOSTS_NO_ELEV (
  net session >nul 2>&1
  if errorlevel 1 (
    echo.
    echo   hosts-sync needs Administrator rights - requesting elevation...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '/elevated' -Verb RunAs"
    exit /b
  )
)

pushd "%~dp0..\.."

REM Load .env for PHP_PROJECTS_PATH + web-UI hostnames.
if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do if not defined %%a set "%%a=%%b"
if "%PHP_PROJECTS_PATH%"=="" set "PHP_PROJECTS_PATH=./www"
if "%CACHE_ADMIN_HOST%"=="" set "CACHE_ADMIN_HOST=cache.test"
if "%DB_ADMIN_HOST%"=="" set "DB_ADMIN_HOST=db.test"
if "%CENTRIFUGO_HOST%"=="" set "CENTRIFUGO_HOST=centrifugo.test"
if "%MQTT_HOST%"=="" set "MQTT_HOST=mqtt.test"
if "%SOKETI_HOST%"=="" set "SOKETI_HOST=ws.test"
if "%DRAWDB_HOST%"=="" set "DRAWDB_HOST=drawdb.test"
if "%HOP_HOST%"=="" set "HOP_HOST=hop.test"
if "%SUPERSET_HOST%"=="" set "SUPERSET_HOST=superset.test"
if "%METABASE_HOST%"=="" set "METABASE_HOST=metabase.test"
if "%HOPPSCOTCH_HOST%"=="" set "HOPPSCOTCH_HOST=hoppscotch.test"
if "%PLANE_HOST%"=="" set "PLANE_HOST=plane.test"
if "%SEMGREP_HOST%"=="" set "SEMGREP_HOST=semgrep.test"
if "%SONARQUBE_HOST%"=="" set "SONARQUBE_HOST=sonarqube.test"
if "%PLAYWRIGHT_REPORT_HOST%"=="" set "PLAYWRIGHT_REPORT_HOST=playwright.test"
if "%TRIVY_HOST%"=="" set "TRIVY_HOST=trivy.test"
if "%ZAP_HOST%"=="" set "ZAP_HOST=zap.test"
if "%OPENVAS_HOST%"=="" set "OPENVAS_HOST=openvas.test"
if "%MAIL_HOST%"=="" set "MAIL_HOST=mail.test"
if "%PENPOT_HOST%"=="" set "PENPOT_HOST=penpot.test"
if "%ANALYTICS_HOST%"=="" set "ANALYTICS_HOST=lds-analytics.test"
if "%VAULTWARDEN_HOST%"=="" set "VAULTWARDEN_HOST=vaultwarden.test"
if "%KEYCLOAK_HOST%"=="" set "KEYCLOAK_HOST=auth.test"
if "%TASKS_HOST%"=="" set "TASKS_HOST=lds-tasks.test"
if "%WIKI_HOST%"=="" set "WIKI_HOST=lds-wiki.test"
if "%OPENWA_HOST%"=="" set "OPENWA_HOST=openwa.test"
if "%HEADLESSX_HOST%"=="" set "HEADLESSX_HOST=headlessx.test"
if "%HEADLESSX_API_HOST%"=="" set "HEADLESSX_API_HOST=headlessx-api.test"
if "%RUSTFS_HOST%"=="" set "RUSTFS_HOST=rustfs.test"
if "%DUCKDB_HOST%"=="" set "DUCKDB_HOST=duckdb.test"
if "%CRG_HOST%"=="" set "CRG_HOST=crg.test"
if "%INSTATIC_HOST%"=="" set "INSTATIC_HOST=instatic.test"
if "%ERPNEXT_HOST%"=="" set "ERPNEXT_HOST=erpnext.test"
if "%DRAWIO_HOST%"=="" set "DRAWIO_HOST=drawio.test"
if "%SNAPOTTER_HOST%"=="" set "SNAPOTTER_HOST=snapotter.test"
if "%IMGCOMPRESS_HOST%"=="" set "IMGCOMPRESS_HOST=imgcompress.test"
if "%MEILISEARCH_HOST%"=="" set "MEILISEARCH_HOST=meili.test"
if "%PROMETHEUS_HOST%"=="" set "PROMETHEUS_HOST=prometheus.test"
if "%GRAFANA_HOST%"=="" set "GRAFANA_HOST=grafana.test"
if "%LOKI_HOST%"=="" set "LOKI_HOST=loki.test"
if "%TEMPO_HOST%"=="" set "TEMPO_HOST=tempo.test"
set "PROJDIR=%PHP_PROJECTS_PATH:/=\%"

set "HOSTS=%WINDIR%\System32\drivers\etc\hosts"
REM Custom target (tests / unusual installs) - mirrors LDS_HOSTS_FILE in the .sh.
if defined LDS_HOSTS_FILE set "HOSTS=%LDS_HOSTS_FILE%"
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
call :sec "Admin tools"
call :add %CACHE_ADMIN_HOST%
call :add %DB_ADMIN_HOST%
call :sec "Auth"
call :add %VAULTWARDEN_HOST%
call :add %KEYCLOAK_HOST% "(OIDC/OAuth2 - issuer /realms/lds - admin/admin)"
call :sec "Communication tools"
call :add %MAIL_HOST%
call :add %OPENWA_HOST%
call :sec "Browser automation"
call :add %HEADLESSX_HOST%
call :add %HEADLESSX_API_HOST% "(MCP + API - headlessx-api.test)"
call :sec "Designers"
call :add %PENPOT_HOST%
call :add %DRAWDB_HOST% "(open via http://localhost:4502 - needs a secure context)"
call :add %DRAWIO_HOST% "(self-hosted diagrams - use ?offline=1&https=0)"
call :sec "File conversion"
call :add %SNAPOTTER_HOST% "(file platform - convert / OCR / AI)"
call :add %IMGCOMPRESS_HOST% "(image toolbox - 70+ formats)"
call :sec "Data tools"
call :add %SUPERSET_HOST%
call :add %METABASE_HOST%
call :add %HOP_HOST%
call :sec "API & project management"
call :add %HOPPSCOTCH_HOST% "(API client - Postman alternative)"
call :add %PLANE_HOST% "(project management - Jira/Linear alternative)"
call :sec "Code quality"
call :add %SEMGREP_HOST%
call :add %SONARQUBE_HOST% "(code quality - bugs / coverage / quality gates)"
call :add %CRG_HOST% "(code-review-graph - AI code graph / blast-radius)"
call :sec "Testing tools"
call :add %PLAYWRIGHT_REPORT_HOST% "(Playwright E2E report viewer)"
call :sec "Security tools"
call :add %TRIVY_HOST%
call :add %ZAP_HOST%
call :add %OPENVAS_HOST% "(OpenVAS/Greenbone companion - start with 'lds openvas start')"
call :sec "LDS apps"
call :add %ANALYTICS_HOST%
call :add %TASKS_HOST%
call :add %WIKI_HOST%
call :sec "Analytical query engines"
call :add %DUCKDB_HOST%
call :sec "Search"
call :add %MEILISEARCH_HOST% "(API-only, no web UI, development mode)"
call :sec "Monitoring"
call :add %PROMETHEUS_HOST% "(metrics TSDB)"
call :add %GRAFANA_HOST% "(dashboards - admin/admin)"
call :add %LOKI_HOST% "(log store - API only; root opens Grafana Explore)"
call :add %TEMPO_HOST% "(trace store - OTLP in; root opens Grafana Explore)"
call :sec "Realtime dashboards"
call :add %SOKETI_HOST%
call :add %CENTRIFUGO_HOST%
call :add %MQTT_HOST%
call :sec "Storage tools"
call :add %RUSTFS_HOST%
call :sec "Websites & CMS"
call :add %INSTATIC_HOST% "(visual CMS - admin at /admin)"
call :sec "ERP & business"
call :add %ERPNEXT_HOST% "(accounting / CRM / HR - admin/admin)"

>> "%TMP%" echo # ===== end local-dev-stack =====   %MARKER%

copy /y "%TMP%" "%HOSTS%" >nul
if errorlevel 1 (
  echo.
  echo   ERROR: could not write %HOSTS%
  echo   Re-run from an ADMINISTRATOR command prompt.
  del "%TMP%" >nul 2>&1
  popd
  endlocal
  exit /b 1
)
del "%TMP%" >nul 2>&1

REM Windows caches failed lookups; flush so the new *.test names resolve now.
ipconfig /flushdns >nul 2>&1

echo.
echo   ---- hosts-sync: done (!TOTAL! host(s) synced to %HOSTS%) ----
echo   The control panel lives at http://localhost (no hosts entry needed).
if /I "%~1"=="/elevated" pause
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
