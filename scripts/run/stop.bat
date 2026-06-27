@echo off
REM Stop running containers WITHOUT removing them — keeps the containers (and all
REM data) so `lds up` resumes them quickly. Contrast with:
REM   down      removes the containers (data volumes kept)
REM   down -v   removes containers AND wipes data volumes
setlocal
pushd "%~dp0..\.."
echo Stopping all running services (containers kept; lds up resumes them)...
docker compose --profile "*" stop
popd
endlocal
