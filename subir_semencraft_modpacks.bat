@echo off
setlocal
title Semencraft Modpacks - Subir cambios

set "REPO=E:\Documentos 2026\SemencraftModpacks\SemencraftModpacks"

echo.
echo ==========================================
echo   SEMENCRAFT MODPACKS - SUBIR CAMBIOS
echo ==========================================
echo.

if not exist "%REPO%\.git" (
    echo [ERROR] No encontre un repositorio Git en:
    echo %REPO%
    echo.
    pause
    exit /b 1
)

where git >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Git no esta instalado o no esta en PATH.
    echo.
    pause
    exit /b 1
)

cd /d "%REPO%"
if errorlevel 1 (
    echo [ERROR] No pude abrir la carpeta del repositorio.
    pause
    exit /b 1
)

for /f "delims=" %%B in ('git branch --show-current') do set "BRANCH=%%B"
if not defined BRANCH (
    echo [ERROR] No pude detectar la rama actual.
    pause
    exit /b 1
)

echo Repositorio: %REPO%
echo Rama: %BRANCH%
echo.

echo [1/4] Buscando cambios...
git add -A
if errorlevel 1 goto :error

git diff --cached --quiet
if not errorlevel 1 (
    echo.
    echo No hay cambios nuevos para subir.
    echo.
    pause
    exit /b 0
)

echo [2/4] Creando commit...
for /f "delims=" %%T in ('powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"') do set "STAMP=%%T"
git commit -m "Auto update Semencraft Modpacks - %STAMP%"
if errorlevel 1 goto :error

echo [3/4] Sincronizando con GitHub...
git pull --rebase origin "%BRANCH%"
if errorlevel 1 (
    echo.
    echo [ERROR] Git no pudo sincronizar con el remoto.
    echo Puede haber un conflicto o un problema de conexion.
    echo Tus cambios YA quedaron guardados en un commit local.
    echo.
    pause
    exit /b 1
)

echo [4/4] Subiendo cambios...
git push origin "%BRANCH%"
if errorlevel 1 goto :error

echo.
echo ==========================================
echo   CAMBIOS SUBIDOS CORRECTAMENTE :D
echo ==========================================
echo.
pause
exit /b 0

:error
echo.
echo [ERROR] Algo fallo. Revisa los mensajes de Git de arriba.
echo No se borraron tus archivos.
echo.
pause
exit /b 1
