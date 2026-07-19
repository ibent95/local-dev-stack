@echo off
REM Restart one or more profiles (down + rm + up with lifecycle).
REM Delegates to `start.bat` which handles init -^> down -^> rm -^> build-bases -^> up.
REM   lds restart                     restart enabled toggles (from .env)
REM   lds restart mysql redis         restart specific profiles
REM   lds restart --rebuild kafka     restart with --build flag
setlocal
pushd "%~dp0..\.."
call "%~dp0start.bat" %*
popd
endlocal
