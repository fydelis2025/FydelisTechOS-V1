@echo off
REM fydelis-ai.bat - Launcher for Windows
REM FydelisTechos © 2026

setlocal

REM Ir para o diretório do script
cd /d "%~dp0"

REM Verificar se Perl está instalado
where perl >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ❌ Perl não encontrado! Instale Strawberry Perl: https://strawberryperl.com/
    pause
    exit /b 1
)

REM Verificar se lib/ existe
if not exist "lib\FydelisAI.pm" (
    echo ❌ lib\FydelisAI.pm não encontrado!
    echo    Certifique-se de que está no diretório correto.
    pause
    exit /b 1
)

REM Executar
perl fydelis-ai.pl %*

endlocal