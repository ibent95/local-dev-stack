@echo off
REM ===========================================================================
REM Build the LDS Desktop apps. Mirrors desktop/build.sh.
REM
REM   desktop\build.bat                     all variants, containerized (Linux)
REM   desktop\build.bat tauri               one variant
REM   desktop\build.bat javafx --os linux   explicit OS (same as default)
REM   desktop\build.bat all --os win        host Windows build (needs toolchain)
REM   desktop\build.bat tauri --os win --container   Windows .exe cross-compiled
REM                                         in lds/tauri-win-dev (Tauri only)
REM   desktop\build.bat dioxus               Dioxus spike: cargo build in lds/tauri-dev
REM   desktop\build.bat dioxus --os win --container   Dioxus .exe (tauri-win-dev)
REM   desktop\build.bat all --os mac        ERROR - macOS artifacts need a Mac
REM                                         (use the GitHub Actions matrix)
REM
REM Windows + Linux + macOS in one go: .github/workflows/desktop-build.yml
REM (3 runners x 3 variants, installers uploaded as artifacts).
REM ===========================================================================
setlocal enabledelayedexpansion
pushd "%~dp0.."

set "RUST_VERSION=1.96"
set "JAVA_VERSION=25"
set "PHP_VERSION=8.4"
if exist .env for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do (
  if /I "%%a"=="RUST_VERSION" set "RUST_VERSION=%%b"
  if /I "%%a"=="JAVA_VERSION" set "JAVA_VERSION=%%b"
  if /I "%%a"=="PHP_VERSION" set "PHP_VERSION=%%b"
)

set "WANT=%1"
if "%WANT%"=="" set "WANT=all"
if not "%WANT%"=="all" if not "%WANT%"=="tauri" if not "%WANT%"=="javafx" if not "%WANT%"=="nativephp" if not "%WANT%"=="dioxus" (
  echo usage: build.bat [all^|tauri^|javafx^|nativephp^|dioxus] [--os linux^|win^|mac^|auto]
  exit /b 1
)

set "OS_ARG=linux"
if "%2"=="--os" set "OS_ARG=%3"
if "%3"=="--os" set "OS_ARG=%4"
if "%OS_ARG%"=="auto" set "OS_ARG=win"

set "CONTAINER=0"
for %%a in (%*) do if /I "%%a"=="--container" set "CONTAINER=1"

set "ROOT=%CD%"

if "%OS_ARG%"=="win" (
  if "%CONTAINER%"=="1" goto win_container
  goto host_win
)
if "%OS_ARG%"=="mac" goto host_mac

REM ---------------------------------------------------------------- linux (container)
if "%WANT%"=="tauri" goto tauri
if "%WANT%"=="javafx" goto javafx
if "%WANT%"=="nativephp" goto nativephp
if "%WANT%"=="dioxus" goto dioxus

:tauri
docker image inspect lds/tauri-dev:%RUST_VERSION% >nul 2>&1 || (
  echo ==^> building base image lds/tauri-dev:%RUST_VERSION% ...
  docker buildx bake -f "%ROOT%\docker-bake.hcl" --load tauri-dev || exit /b 1
)
echo ==^> [tauri] cargo check + build ^(Linux^)
docker run --rm -v "%ROOT%:/app" -w /app/desktop/tauri/src-tauri ^
  lds/tauri-dev:%RUST_VERSION% sh -c "cargo check 2>&1 | tail -5; echo ---; cargo build 2>&1 | tail -5"
if "%WANT%"=="tauri" goto end

:javafx
docker image inspect lds/javafx-dev:%JAVA_VERSION% >nul 2>&1 || (
  echo ==^> building base image lds/javafx-dev:%JAVA_VERSION% ...
  docker buildx bake -f "%ROOT%\docker-bake.hcl" --load javafx-dev || exit /b 1
)
echo ==^> [javafx] mvn package + jpackage app-image
docker run --rm -v "%ROOT%:/app" -w /app/desktop/javafx ^
  lds/javafx-dev:%JAVA_VERSION% sh -c "bash package.sh"
if "%WANT%"=="javafx" goto end

:nativephp
docker image inspect lds/nativephp-dev:%PHP_VERSION% >nul 2>&1 || (
  echo ==^> building base image lds/nativephp-dev:%PHP_VERSION% ...
  docker buildx bake -f "%ROOT%\docker-bake.hcl" --load nativephp-dev || exit /b 1
)
echo ==^> [nativephp] composer install + vite build + artisan check
docker run --rm -v "%ROOT%:/app" -w /app/desktop/nativephp ^
  lds/nativephp-dev:%PHP_VERSION% sh -c "composer install --no-interaction --no-progress 2>&1 | tail -5; echo ---; npm install --no-audit --no-fund 2>&1 | tail -3; npm run build 2>&1 | tail -5; echo ---; php artisan list >/dev/null 2>&1 && echo artisan list OK || echo artisan list FAILED"
if "%WANT%"=="nativephp" goto end

:dioxus
docker image inspect lds/tauri-dev:%RUST_VERSION% >nul 2>&1 || (
  echo ==^> building base image lds/tauri-dev:%RUST_VERSION% ...
  docker buildx bake -f "%ROOT%\docker-bake.hcl" --load tauri-dev || exit /b 1
)
echo ==^> [dioxus] cargo build ^(Linux compile-check^) - reuses lds/tauri-dev
docker run --rm -v "%ROOT%:/app" -w /app/desktop/dioxus ^
  lds/tauri-dev:%RUST_VERSION% sh -c "cargo build 2>&1 | tail -10; echo ---; file target/debug/lds-desktop-dioxus"
goto end

REM ------------------------------------------------ Windows .exe cross-compile (container)
:win_container
echo ==^> [container:win] cross-compiling the Windows .exe ^(mingw-w64^)
docker image inspect lds/tauri-win-dev:%RUST_VERSION% >nul 2>&1 || (
  echo ==^> building base image lds/tauri-win-dev:%RUST_VERSION% ...
  docker buildx bake -f "%ROOT%\docker-bake.hcl" --load tauri-win-dev || exit /b 1
)
if "%WANT%"=="tauri" goto win_c_tauri
if "%WANT%"=="dioxus" goto win_c_dioxus
if "%WANT%"=="all" goto win_c_tauri
goto win_c_note

:win_c_tauri
echo ==^> [tauri] cargo build --target x86_64-pc-windows-gnu
docker run --rm -v "%ROOT%:/app" -w /app/desktop/tauri/src-tauri ^
  lds/tauri-win-dev:%RUST_VERSION% sh -c "cargo build --target x86_64-pc-windows-gnu 2>&1 | tail -10; echo ---; file target/x86_64-pc-windows-gnu/debug/lds-desktop.exe"
if "%WANT%"=="tauri" goto end
if "%WANT%"=="all" goto win_c_dioxus

:win_c_dioxus
echo ==^> [dioxus] cargo build --target x86_64-pc-windows-gnu
docker run --rm -v "%ROOT%:/app" -w /app/desktop/dioxus ^
  lds/tauri-win-dev:%RUST_VERSION% sh -c "cargo build --target x86_64-pc-windows-gnu 2>&1 | tail -10; echo ---; file target/x86_64-pc-windows-gnu/debug/lds-desktop-dioxus.exe"
if "%WANT%"=="dioxus" goto end

:win_c_note
echo NOTE: JavaFX/NativePHP have no containerized Windows build:
echo       JavaFX jar ^(target\*.jar^) is cross-platform; exe/msi need jpackage on Windows.
echo       NativePHP exe needs a Windows host ^(or the CI matrix^).
goto end

REM ---------------------------------------------------------------- host Windows build
:host_win
echo ==^> [host:win] building on the host ^(Windows^)
if "%WANT%"=="tauri" goto win_tauri
if "%WANT%"=="javafx" goto win_javafx
if "%WANT%"=="nativephp" goto win_nativephp
if "%WANT%"=="dioxus" goto win_dioxus

:win_tauri
where cargo >nul 2>&1 || (echo   missing: cargo ^(rustup^). Install Rust, then: cargo install tauri-cli --locked & goto end)
echo ==^> [tauri] cargo tauri build
pushd desktop\tauri\src-tauri
call cargo tauri build
popd
if "%WANT%"=="tauri" goto end

:win_javafx
where mvn >nul 2>&1 || (echo   missing: mvn ^(Maven 3.9+ with JDK 21+^). See desktop\javafx\README.md & goto end)
echo ==^> [javafx] jpackage via package.sh
bash desktop\javafx\package.sh
if "%WANT%"=="javafx" goto end

:win_nativephp
where php >nul 2>&1 || (echo   missing: php ^(8.3+ with composer^). See desktop\nativephp\README.md & goto end)
echo ==^> [nativephp] php artisan native:build win
pushd desktop\nativephp
call php artisan native:build win
popd
if "%WANT%"=="nativephp" goto end

:win_dioxus
where dx >nul 2>&1 || (echo   missing: dx ^(Dioxus CLI^). Install: cargo install dioxus-cli --locked & goto end)
echo ==^> [dioxus] dx bundle
pushd desktop\dioxus
call dx bundle
popd
goto end

REM ---------------------------------------------------------------- macOS (impossible on Windows)
:host_mac
echo ERROR: --os mac artifacts can only be built on a macOS machine.
echo        jpackage / electron-builder cannot cross-package, and macOS requires
echo        Apple tooling. Use the GitHub Actions matrix instead:
echo          .github/workflows/desktop-build.yml  ^(3 runners x 3 variants^)
exit /b 1

:end
popd
endlocal
