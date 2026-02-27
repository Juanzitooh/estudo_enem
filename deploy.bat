@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

set "VERSION=windows"
set "PORT=8787"
set "OUT_DIR=app_flutter\releases"
set "SKIP_BUILD=0"
set "BASE_URL="
set "MANIFEST_URL_ARG="
set "DB_DIR="
set "LIMIT=0"
set "TAG_ALIAS=stable"
set "NO_TAG_ALIAS=0"
set "ERR_MSG="

if /i "%~1"=="--help" goto :usage

:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="--version" (
  if "%~2"=="" (
    set "ERR_MSG=faltou valor para --version"
    goto :die
  )
  set "VERSION=%~2"
  shift
  shift
  goto :parse_args
)
if /i "%~1"=="--port" (
  if "%~2"=="" (
    set "ERR_MSG=faltou valor para --port"
    goto :die
  )
  set "PORT=%~2"
  shift
  shift
  goto :parse_args
)
if /i "%~1"=="--out-dir" (
  if "%~2"=="" (
    set "ERR_MSG=faltou valor para --out-dir"
    goto :die
  )
  set "OUT_DIR=%~2"
  shift
  shift
  goto :parse_args
)
if /i "%~1"=="--skip-build" (
  set "SKIP_BUILD=1"
  shift
  goto :parse_args
)
if /i "%~1"=="--base-url" (
  if "%~2"=="" (
    set "ERR_MSG=faltou valor para --base-url"
    goto :die
  )
  set "BASE_URL=%~2"
  shift
  shift
  goto :parse_args
)
if /i "%~1"=="--manifest-url" (
  if "%~2"=="" (
    set "ERR_MSG=faltou valor para --manifest-url"
    goto :die
  )
  set "MANIFEST_URL_ARG=%~2"
  shift
  shift
  goto :parse_args
)
if /i "%~1"=="--db-dir" (
  if "%~2"=="" (
    set "ERR_MSG=faltou valor para --db-dir"
    goto :die
  )
  set "DB_DIR=%~2"
  shift
  shift
  goto :parse_args
)
if /i "%~1"=="--limit" (
  if "%~2"=="" (
    set "ERR_MSG=faltou valor para --limit"
    goto :die
  )
  set "LIMIT=%~2"
  shift
  shift
  goto :parse_args
)
if /i "%~1"=="--tag-alias" (
  if "%~2"=="" (
    set "ERR_MSG=faltou valor para --tag-alias"
    goto :die
  )
  set "TAG_ALIAS=%~2"
  set "NO_TAG_ALIAS=0"
  shift
  shift
  goto :parse_args
)
if /i "%~1"=="--no-tag-alias" (
  set "NO_TAG_ALIAS=1"
  set "TAG_ALIAS="
  shift
  goto :parse_args
)
set "ERR_MSG=opcao desconhecida: %~1"
goto :die

:args_done
for /f "delims=0123456789" %%I in ("%PORT%") do (
  set "ERR_MSG=--port deve ser inteiro > 0"
  goto :die
)
if "%PORT%"=="0" (
  set "ERR_MSG=--port deve ser inteiro > 0"
  goto :die
)
for /f "delims=0123456789" %%I in ("%LIMIT%") do (
  set "ERR_MSG=--limit deve ser inteiro >= 0"
  goto :die
)

if "%VERSION%"=="" set "VERSION=windows"

for %%I in ("%OUT_DIR%") do set "OUT_DIR_ABS=%%~fI"
if not exist "%OUT_DIR_ABS%" mkdir "%OUT_DIR_ABS%"

set "BUILD_BASE_URL_ARG="
if not "%BASE_URL%"=="" set "BUILD_BASE_URL_ARG=--base-url \"%BASE_URL%\""
set "BUILD_MANIFEST_URL_ARG="
if not "%MANIFEST_URL_ARG%"=="" set "BUILD_MANIFEST_URL_ARG=--manifest-url \"%MANIFEST_URL_ARG%\""
set "BUILD_DB_DIR_ARG="
if not "%DB_DIR%"=="" set "BUILD_DB_DIR_ARG=--db-dir \"%DB_DIR%\""

if "%SKIP_BUILD%"=="0" (
  if not exist "%SCRIPT_DIR%dist_windows.bat" (
    set "ERR_MSG=dist_windows.bat nao encontrado."
    goto :die
  )

  echo [deploy-windows] buildando release Windows...
  if "%NO_TAG_ALIAS%"=="1" (
    call "%SCRIPT_DIR%dist_windows.bat" --version "%VERSION%" --out-dir "%OUT_DIR%" --limit %LIMIT% %BUILD_BASE_URL_ARG% %BUILD_MANIFEST_URL_ARG% %BUILD_DB_DIR_ARG% --no-tag-alias
  ) else if "%TAG_ALIAS%"=="" (
    call "%SCRIPT_DIR%dist_windows.bat" --version "%VERSION%" --out-dir "%OUT_DIR%" --limit %LIMIT% %BUILD_BASE_URL_ARG% %BUILD_MANIFEST_URL_ARG% %BUILD_DB_DIR_ARG%
  ) else (
    call "%SCRIPT_DIR%dist_windows.bat" --version "%VERSION%" --out-dir "%OUT_DIR%" --limit %LIMIT% %BUILD_BASE_URL_ARG% %BUILD_MANIFEST_URL_ARG% %BUILD_DB_DIR_ARG% --tag-alias "%TAG_ALIAS%"
  )
  if errorlevel 1 (
    set "ERR_MSG=falha no dist_windows.bat."
    goto :die
  )
)

set "RELEASE_DIR=%OUT_DIR_ABS%\%VERSION%"
if not exist "%RELEASE_DIR%" (
  set "ERR_MSG=release nao encontrada: %RELEASE_DIR%"
  goto :die
)

set "MANIFEST_FILE=manifest_stable.json"
if not exist "%RELEASE_DIR%\%MANIFEST_FILE%" set "MANIFEST_FILE=manifest.json"
if not exist "%RELEASE_DIR%\%MANIFEST_FILE%" (
  set "ERR_MSG=manifest nao encontrado em %RELEASE_DIR%."
  goto :die
)

set "APP_EXE=%RELEASE_DIR%\enem_offline_client_windows_x64_%VERSION%\enem_offline_client.exe"
if not exist "%APP_EXE%" set "APP_EXE=%SCRIPT_DIR%app_flutter\enem_offline_client\build\windows\x64\runner\Release\enem_offline_client.exe"
if not exist "%APP_EXE%" (
  set "ERR_MSG=executavel do app nao encontrado."
  goto :die
)

set "PORT_BUSY=0"
netstat -ano | findstr /R /C:":%PORT% .*LISTENING" >nul
if not errorlevel 1 set "PORT_BUSY=1"

if "%PORT_BUSY%"=="0" (
  where py >nul 2>&1
  if not errorlevel 1 (
    set "PYTHON_CMD=py -3"
  ) else (
    where python >nul 2>&1
    if errorlevel 1 (
      set "ERR_MSG=Python nao encontrado para servidor local."
      goto :die
    )
    set "PYTHON_CMD=python"
  )
)

if "%PORT_BUSY%"=="0" (
  echo [deploy-windows] subindo servidor local na porta %PORT% em background...
  start "ENEM_LOCAL_SERVER_%PORT%" /MIN cmd /c "cd /d \"%RELEASE_DIR%\" && %PYTHON_CMD% -m http.server %PORT%"
) else (
  echo [deploy-windows] porta %PORT% ja esta em uso; usando servidor existente.
)

set "MANIFEST_URL=http://127.0.0.1:%PORT%/%MANIFEST_FILE%"
echo [deploy-windows] manifest para update: %MANIFEST_URL%
echo [deploy-windows] abrindo app Windows...
start "" "%APP_EXE%"

echo [deploy-windows] pronto.
exit /b 0

:usage
echo Uso:
echo   deploy.bat [opcoes]
echo.
echo Opcoes:
echo   --version ^<v^>       Versao alvo da release ^(padrao: windows^)
echo   --port ^<n^>          Porta do servidor local ^(padrao: 8787^)
echo   --out-dir ^<dir^>     Diretorio de releases ^(padrao: app_flutter\releases^)
echo   --skip-build          Nao roda dist_windows.bat
echo   --base-url ^<url^>    URL base para download_url no manifest
echo   --manifest-url ^<u^>  Override ENEM_MANIFEST_URL no build
echo   --db-dir ^<dir^>      Override ENEM_DB_DIR no build
echo   --limit ^<n^>         Limite de questoes para o build ^(padrao: 0^)
echo   --tag-alias ^<nome^>  Alias de canal para build ^(padrao: stable^)
echo   --no-tag-alias        Build sem alias
echo   --help                Mostra esta ajuda
echo.
echo Exemplo:
echo   deploy.bat --version windows --tag-alias stable
exit /b 0

:die
if "%ERR_MSG%"=="" set "ERR_MSG=falha desconhecida"
echo [deploy-windows][erro] %ERR_MSG%
exit /b 1
