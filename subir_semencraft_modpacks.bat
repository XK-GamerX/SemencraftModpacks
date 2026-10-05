@echo off
setlocal
title Semencraft Modpacks - Actualizar y subir

set "SCRIPT=%~dp0tools\actualizar_y_subir.ps1"

echo.
echo ==============================================
echo   SEMENCRAFT MODPACKS - ACTUALIZAR Y SUBIR
echo ==============================================
echo.
echo [1] Compilar Semencraft, copiar el JAR y subir todo
echo [2] Copiar el ultimo JAR compilado y subir todo
echo [3] Subir solamente los cambios actuales del repo
echo [4] Cancelar
echo.

choice /C 1234 /N /M "Elige una opcion [1-4]: "
if errorlevel 4 exit /b 0
if errorlevel 3 (
    set "MODO=SoloSubir"
    goto ejecutar
)
if errorlevel 2 (
    set "MODO=Copiar"
    goto ejecutar
)
set "MODO=Completo"

:ejecutar
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Modo "%MODO%"
set "RESULTADO=%ERRORLEVEL%"

echo.
if "%RESULTADO%"=="0" (
    echo Operacion terminada correctamente.
) else (
    echo La operacion no termino. Revisa el mensaje de arriba.
)
echo.
pause
exit /b %RESULTADO%
