@echo off
chcp 65001 > nul
set gitPath="C:\Users\tony\portable-git\cmd\git.exe"

if not exist %gitPath% (
    echo [ERRO] O executável do Git portátil não foi encontrado em: %gitPath%
    pause
    exit /b 1
)

set /p msg="Digite a mensagem do commit: "
if "%msg%"=="" (
    set msg="feat: atualizacao automatica do projeto"
)

rem --- Repositório do Dashboard ---
if exist "%~dp0orion_dashboard\.git" (
    echo =============================================
    echo >>> Processando Dashboard (Oriontech)
    echo =============================================
    cd /d "%~dp0orion_dashboard"
    %gitPath% add .
    %gitPath% commit -m "%msg%"
    %gitPath% push origin main
    echo.
)

rem --- Repositório do Robô MT5 ---
if exist "%~dp0.git" (
    echo =============================================
    echo >>> Processando Robô MT5 (Orion-MT5)
    echo =============================================
    cd /d "%~dp0"
    %gitPath% add .
    %gitPath% commit -m "%msg%"
    %gitPath% push origin main
    echo.
)

echo >>> Todos os envios concluidos com sucesso!
pause
