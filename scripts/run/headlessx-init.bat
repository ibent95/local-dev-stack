@echo off
REM Ensure the HeadlessX source checkout exists (clone on first run, fast-forward
REM update afterwards) so the headlessx-* compose services can build from it.
REM Idempotent; auto-run by `lds up` for the headlessx/all profile.
REM   lds headlessx init     (same as the up auto-run)
REM   lds headlessx update   (explicit fetch + fast-forward)
setlocal
pushd "%~dp0..\.."

REM Load the relevant .env values (fall back to defaults).
if exist ".env" for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do (
  if /I "%%a"=="HEADLESSX_REPO_URL" set "HEADLESSX_REPO_URL=%%b"
  if /I "%%a"=="HEADLESSX_REPO_REF" set "HEADLESSX_REPO_REF=%%b"
  if /I "%%a"=="HEADLESSX_REPO_PATH" set "HEADLESSX_REPO_PATH=%%b"
)
if "%HEADLESSX_REPO_URL%"=="" set "HEADLESSX_REPO_URL=https://github.com/saifyxpro/HeadlessX"
if "%HEADLESSX_REPO_REF%"=="" set "HEADLESSX_REPO_REF=main"
if "%HEADLESSX_REPO_PATH%"=="" set "HEADLESSX_REPO_PATH=.\data\headlessx"

set "DIR=%HEADLESSX_REPO_PATH:/=\%"
REM If it's a relative path, resolve it against the stack root.
if not "%DIR:~0,1%"=="\" if not "%DIR:~1,1%"==":" set "DIR=%CD%\%DIR%"

if exist "%DIR%\.git" goto update

echo Cloning HeadlessX (%HEADLESSX_REPO_URL% @ %HEADLESSX_REPO_REF%) into %DIR% ...
git clone --depth 1 --branch "%HEADLESSX_REPO_REF%" "%HEADLESSX_REPO_URL%" "%DIR%"
if errorlevel 1 ( echo Clone failed. & popd & endlocal & exit /b 1 )
echo HeadlessX checkout ready at %DIR%
goto normalize

:update
echo Updating HeadlessX checkout at %DIR% (ref: %HEADLESSX_REPO_REF%) ...
pushd "%DIR%"
git fetch --depth 1 origin "%HEADLESSX_REPO_REF%" >nul 2>&1
if errorlevel 1 git fetch origin "%HEADLESSX_REPO_REF%" >nul 2>&1
git merge --ff-only FETCH_HEAD
if errorlevel 1 (
  echo Local checkout diverged - skipping auto-update.
  echo Resolve or reset it, then run: lds headlessx update
)
popd

:normalize
REM Windows git (core.autocrlf=true) checks this repo's LF files out as CRLF
REM because it ships no .gitattributes. A CRLF shebang (#!/bin/sh<CR>) inside
REM the container makes exec fail with "not found" (exit 127), crash-looping
REM the headlessx-api/worker containers. Force the checkout to keep upstream's
REM LF endings for the infra scripts that are baked into the images.
pushd "%DIR%"
git config core.autocrlf false
for /f "delims=" %%f in ('dir /b /s "infra\*.sh" 2^>nul') do del /q "%%f"
git checkout -- infra
popd

:done
popd
endlocal
exit /b 0
