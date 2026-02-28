@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

set "VERSION=windows"
set "BASE_URL="
set "OUT_DIR=app_flutter\releases"
set "LIMIT=0"
set "MANIFEST_URL="
set "DB_DIR="
set "TAG_ALIAS=stable"
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
if /i "%~1"=="--manifest-url" (
  if "%~2"=="" (
    set "ERR_MSG=faltou valor para --manifest-url"
    goto :die
  )
  set "MANIFEST_URL=%~2"
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
if /i "%~1"=="--tag-alias" (
  if "%~2"=="" (
    set "ERR_MSG=faltou valor para --tag-alias"
    goto :die
  )
  set "TAG_ALIAS=%~2"
  shift
  shift
  goto :parse_args
)
if /i "%~1"=="--no-tag-alias" (
  set "TAG_ALIAS="
  shift
  goto :parse_args
)
set "ERR_MSG=opcao desconhecida: %~1"
goto :die

:args_done
if "%VERSION%"=="" set "VERSION=windows"

if "%LIMIT%"=="" set "LIMIT=0"
for /f "delims=0123456789" %%I in ("%LIMIT%") do (
  set "ERR_MSG=--limit deve ser inteiro >= 0"
  goto :die
)

for %%I in ("%OUT_DIR%") do set "OUT_DIR_ABS=%%~fI"

set "QUESTIONS_CSV=%SCRIPT_DIR%questoes\mapeamento_habilidades\questoes_mapeadas.csv"
set "MODULES_CSV=%SCRIPT_DIR%plano\indice_livros_6_volumes.csv"
set "ASSET_BUILDER=%SCRIPT_DIR%scripts\build_assets_release.py"
set "MANIFEST_UPDATER=%SCRIPT_DIR%scripts\update_release_manifest_windows.py"
set "APP_DIR=%SCRIPT_DIR%app_flutter\enem_offline_client"
set "WINDOWS_ICON_SOURCE=%APP_DIR%\assets\app_icon.ico"
set "RELEASE_DIR=%OUT_DIR_ABS%\%VERSION%"
set "MANIFEST_PATH=%RELEASE_DIR%\manifest.json"
set "RELEASE_MANIFEST_PATH=%RELEASE_DIR%\release_manifest.json"
set "SUMMARY_PATH=%RELEASE_DIR%\dist_summary_windows.txt"

if not exist "%QUESTIONS_CSV%" (
  set "ERR_MSG=CSV de questoes nao encontrado: %QUESTIONS_CSV%"
  goto :die
)
if not exist "%MODULES_CSV%" (
  set "ERR_MSG=CSV de modulos nao encontrado: %MODULES_CSV%"
  goto :die
)
if not exist "%ASSET_BUILDER%" (
  set "ERR_MSG=script nao encontrado: %ASSET_BUILDER%"
  goto :die
)
if not exist "%MANIFEST_UPDATER%" (
  set "ERR_MSG=script nao encontrado: %MANIFEST_UPDATER%"
  goto :die
)
if not exist "%APP_DIR%" (
  set "ERR_MSG=diretorio do app nao encontrado: %APP_DIR%"
  goto :die
)

where py >nul 2>&1
if not errorlevel 1 (
  set "PYTHON_CMD=py -3"
) else (
  where python >nul 2>&1
  if errorlevel 1 (
    set "ERR_MSG=Python nao encontrado (instale Python 3 e py launcher)."
    goto :die
  )
  set "PYTHON_CMD=python"
)

where flutter >nul 2>&1
if errorlevel 1 (
  set "ERR_MSG=Flutter nao encontrado no PATH."
  goto :die
)

if not exist "%OUT_DIR_ABS%" mkdir "%OUT_DIR_ABS%"
if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"

set "CONTENT_BASE_URL="
if not "%BASE_URL%"=="" set "CONTENT_BASE_URL=%BASE_URL%"
if not "%CONTENT_BASE_URL%"=="" if "%CONTENT_BASE_URL:~-1%"=="/" set "CONTENT_BASE_URL=%CONTENT_BASE_URL:~0,-1%"
if not "%CONTENT_BASE_URL%"=="" set "CONTENT_BASE_URL=%CONTENT_BASE_URL%/%VERSION%"

echo [dist-windows] versao: %VERSION%
echo [dist-windows] release: %RELEASE_DIR%
echo [dist-windows] gerando assets + manifest de conteudo...
if "%CONTENT_BASE_URL%"=="" (
  call %PYTHON_CMD% "%ASSET_BUILDER%" --questions-csv "%QUESTIONS_CSV%" --modules-csv "%MODULES_CSV%" --out-dir "%OUT_DIR_ABS%" --version "%VERSION%" --limit %LIMIT%
) else (
  call %PYTHON_CMD% "%ASSET_BUILDER%" --questions-csv "%QUESTIONS_CSV%" --modules-csv "%MODULES_CSV%" --out-dir "%OUT_DIR_ABS%" --version "%VERSION%" --limit %LIMIT% --base-url "%CONTENT_BASE_URL%"
)
if errorlevel 1 (
  set "ERR_MSG=falha ao gerar assets/manifest."
  goto :die
)

if not exist "%MANIFEST_PATH%" (
  set "ERR_MSG=manifest nao encontrado: %MANIFEST_PATH%"
  goto :die
)

set "ASSET_ARCHIVE_FILE="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "(Get-Content -Raw -Path \"%MANIFEST_PATH%\" ^| ConvertFrom-Json).archive_file"`) do set "ASSET_ARCHIVE_FILE=%%I"
if "%ASSET_ARCHIVE_FILE%"=="" (
  set "ERR_MSG=manifest sem archive_file: %MANIFEST_PATH%"
  goto :die
)

set "ASSET_ARCHIVE_PATH=%RELEASE_DIR%\%ASSET_ARCHIVE_FILE%"
if not exist "%ASSET_ARCHIVE_PATH%" (
  set "ERR_MSG=asset zip nao encontrado: %ASSET_ARCHIVE_PATH%"
  goto :die
)

for /f %%I in ('powershell -NoProfile -Command "(Get-FileHash -Algorithm SHA256 -Path \"%ASSET_ARCHIVE_PATH%\").Hash.ToLower()"') do set "ASSET_SHA=%%I"
for %%I in ("%ASSET_ARCHIVE_PATH%") do set "ASSET_NAME=%%~nxI"
> "%ASSET_ARCHIVE_PATH%.sha256" echo %ASSET_SHA%  *%ASSET_NAME%

echo [dist-windows] preparando build Windows...
pushd "%APP_DIR%" >nul
flutter config --enable-windows-desktop >nul 2>&1
if not exist "%APP_DIR%\windows\CMakeLists.txt" (
  echo [dist-windows] plataforma Windows ausente. executando flutter create...
  flutter create --platforms=windows .
  if errorlevel 1 (
    popd >nul
    set "ERR_MSG=falha no flutter create --platforms=windows."
    goto :die
  )
)
flutter pub get
if errorlevel 1 (
  popd >nul
  set "ERR_MSG=falha no flutter pub get."
  goto :die
)
if exist "%WINDOWS_ICON_SOURCE%" if exist "%APP_DIR%\windows\runner\resources" (
  copy /y "%WINDOWS_ICON_SOURCE%" "%APP_DIR%\windows\runner\resources\app_icon.ico" >nul
  if errorlevel 1 (
    popd >nul
    set "ERR_MSG=falha ao copiar app_icon.ico para windows/runner/resources."
    goto :die
  )
)

set "DART_DEFINES="
if not "%MANIFEST_URL%"=="" set "DART_DEFINES=%DART_DEFINES% --dart-define=ENEM_MANIFEST_URL=%MANIFEST_URL%"
if not "%DB_DIR%"=="" set "DART_DEFINES=%DART_DEFINES% --dart-define=ENEM_DB_DIR=%DB_DIR%"

flutter build windows --release%DART_DEFINES%
if errorlevel 1 (
  popd >nul
  set "ERR_MSG=falha no flutter build windows --release."
  goto :die
)
popd >nul

set "WINDOWS_BUILD_DIR=%APP_DIR%\build\windows\x64\runner\Release"
set "WINDOWS_EXE=%WINDOWS_BUILD_DIR%\enem_offline_client.exe"
if not exist "%WINDOWS_EXE%" (
  set "ERR_MSG=executavel nao encontrado: %WINDOWS_EXE%"
  goto :die
)

set "WINDOWS_BUNDLE_DIR=%RELEASE_DIR%\enem_offline_client_windows_x64_%VERSION%"
if exist "%WINDOWS_BUNDLE_DIR%" rmdir /s /q "%WINDOWS_BUNDLE_DIR%"
robocopy "%WINDOWS_BUILD_DIR%" "%WINDOWS_BUNDLE_DIR%" /E >nul
set "ROBOCOPY_CODE=%ERRORLEVEL%"
if %ROBOCOPY_CODE% GEQ 8 (
  set "ERR_MSG=falha ao copiar bundle Windows para release."
  goto :die
)

set "WINDOWS_ZIP=%RELEASE_DIR%\enem_offline_client_windows_x64_%VERSION%.zip"
if exist "%WINDOWS_ZIP%" del /f /q "%WINDOWS_ZIP%"
powershell -NoProfile -Command "Compress-Archive -Path '%WINDOWS_BUNDLE_DIR%\*' -DestinationPath '%WINDOWS_ZIP%' -Force" >nul
if errorlevel 1 (
  set "ERR_MSG=falha ao empacotar ZIP Windows."
  goto :die
)

for /f %%I in ('powershell -NoProfile -Command "(Get-FileHash -Algorithm SHA256 -Path \"%WINDOWS_ZIP%\").Hash.ToLower()"') do set "WINDOWS_SHA=%%I"
for %%I in ("%WINDOWS_ZIP%") do set "WINDOWS_ZIP_NAME=%%~nxI"
> "%WINDOWS_ZIP%.sha256" echo %WINDOWS_SHA%  *%WINDOWS_ZIP_NAME%

set "TAG_WINDOWS_ZIP="
set "TAG_ASSET_PATH="
set "TAG_MANIFEST_PATH="
if "%TAG_ALIAS%"=="" goto :skip_tag_alias

set "TAG_WINDOWS_ZIP=%RELEASE_DIR%\enem_offline_client_windows_x64_%TAG_ALIAS%.zip"
copy /y "%WINDOWS_ZIP%" "%TAG_WINDOWS_ZIP%" >nul
if errorlevel 1 (
  set "ERR_MSG=falha ao criar ZIP alias do Windows."
  goto :die
)
for /f %%I in ('powershell -NoProfile -Command "(Get-FileHash -Algorithm SHA256 -Path \"%TAG_WINDOWS_ZIP%\").Hash.ToLower()"') do set "TAG_WINDOWS_SHA=%%I"
for %%I in ("%TAG_WINDOWS_ZIP%") do set "TAG_WINDOWS_ZIP_NAME=%%~nxI"
> "%TAG_WINDOWS_ZIP%.sha256" echo %TAG_WINDOWS_SHA%  *%TAG_WINDOWS_ZIP_NAME%

set "TAG_ASSET_PATH=%RELEASE_DIR%\assets_%TAG_ALIAS%.zip"
copy /y "%ASSET_ARCHIVE_PATH%" "%TAG_ASSET_PATH%" >nul
if errorlevel 1 (
  set "ERR_MSG=falha ao criar ZIP alias dos assets."
  goto :die
)
for /f %%I in ('powershell -NoProfile -Command "(Get-FileHash -Algorithm SHA256 -Path \"%TAG_ASSET_PATH%\").Hash.ToLower()"') do set "TAG_ASSET_SHA=%%I"
for %%I in ("%TAG_ASSET_PATH%") do set "TAG_ASSET_NAME=%%~nxI"
> "%TAG_ASSET_PATH%.sha256" echo %TAG_ASSET_SHA%  *%TAG_ASSET_NAME%

set "TAG_MANIFEST_PATH=%RELEASE_DIR%\manifest_%TAG_ALIAS%.json"
powershell -NoProfile -Command "$m=Get-Content -Raw -Path '%MANIFEST_PATH%' ^| ConvertFrom-Json; $m.archive_file='assets_%TAG_ALIAS%.zip'; $m.download_url=''; $m ^| Add-Member -NotePropertyName channel -NotePropertyValue '%TAG_ALIAS%' -Force; $m ^| ConvertTo-Json -Depth 20 ^| Set-Content -Encoding UTF8 '%TAG_MANIFEST_PATH%'"
if errorlevel 1 (
  set "ERR_MSG=falha ao gerar manifest de alias."
  goto :die
)

:skip_tag_alias

set "CHANNEL=%TAG_ALIAS%"
if "%CHANNEL%"=="" set "CHANNEL=windows"

if "%TAG_ALIAS%"=="" (
  call %PYTHON_CMD% "%MANIFEST_UPDATER%" --release-manifest "%RELEASE_MANIFEST_PATH%" --version "%VERSION%" --channel "%CHANNEL%" --manifest-file "%MANIFEST_PATH%" --assets-file "%ASSET_ARCHIVE_PATH%" --windows-file "%WINDOWS_ZIP%"
) else (
  call %PYTHON_CMD% "%MANIFEST_UPDATER%" --release-manifest "%RELEASE_MANIFEST_PATH%" --version "%VERSION%" --channel "%CHANNEL%" --manifest-file "%MANIFEST_PATH%" --assets-file "%ASSET_ARCHIVE_PATH%" --windows-file "%WINDOWS_ZIP%" --manifest-tag-file "%TAG_MANIFEST_PATH%" --assets-tag-file "%TAG_ASSET_PATH%" --windows-tag-file "%TAG_WINDOWS_ZIP%"
)
if errorlevel 1 (
  set "ERR_MSG=falha ao atualizar release_manifest.json (windows)."
  goto :die
)

> "%SUMMARY_PATH%" (
  echo version=%VERSION%
  echo generated_at_local=%DATE% %TIME%
  echo manifest=%MANIFEST_PATH%
  echo assets_zip=%ASSET_ARCHIVE_PATH%
  echo assets_zip_sha256_file=%ASSET_ARCHIVE_PATH%.sha256
  echo windows_bundle_dir=%WINDOWS_BUNDLE_DIR%
  echo windows_exe=%WINDOWS_EXE%
  echo windows_zip=%WINDOWS_ZIP%
  echo windows_zip_sha256_file=%WINDOWS_ZIP%.sha256
  echo release_manifest=%RELEASE_MANIFEST_PATH%
  if not "%TAG_ALIAS%"=="" (
    echo tag_alias=%TAG_ALIAS%
    echo windows_tag_zip=%TAG_WINDOWS_ZIP%
    echo windows_tag_zip_sha256_file=%TAG_WINDOWS_ZIP%.sha256
    echo manifest_tag=%TAG_MANIFEST_PATH%
    echo assets_tag=%TAG_ASSET_PATH%
    echo assets_tag_sha256_file=%TAG_ASSET_PATH%.sha256
  )
)

echo [dist-windows] resumo: %SUMMARY_PATH%
echo [dist-windows] release pronta em: %RELEASE_DIR%
echo [dist-windows] finalizado
exit /b 0

:usage
echo Uso:
echo   dist_windows.bat [opcoes]
echo.
echo Opcoes:
echo   --version ^<v^>       Versao da release ^(padrao: windows^)
echo   --base-url ^<url^>    Base URL para download_url no manifest ^(opcional^)
echo   --out-dir ^<dir^>     Diretorio de saida ^(padrao: app_flutter\releases^)
echo   --limit ^<n^>         Limite de questoes no assets ^(0 = todas^)
echo   --manifest-url ^<u^>  Override ENEM_MANIFEST_URL no build Windows
echo   --db-dir ^<dir^>      Override ENEM_DB_DIR no build Windows
echo   --tag-alias ^<nome^>  Alias estavel para artefatos ^(padrao: stable^)
echo   --no-tag-alias        Nao gera artefatos de alias
echo   --help                Mostra esta ajuda
echo.
echo Exemplo:
echo   dist_windows.bat --version windows --tag-alias stable
exit /b 0

:die
if "%ERR_MSG%"=="" set "ERR_MSG=falha desconhecida"
echo [dist-windows][erro] %ERR_MSG%
exit /b 1
