@echo off
chcp 65001 > nul
set gitPath="C:\Users\tony\portable-git\cmd\git.exe"

if not exist %gitPath% (
    echo [ERRO] O executável do Git portátil não foi encontrado em: %gitPath%
    pause
    exit /b 1
)

set repoPath=%~dp0
if exist "%~dp0orion_dashboard\.git" (
    set repoPath="%~dp0orion_dashboard"
)

echo >>> Diretório do repositório: %repoPath%
cd /d %repoPath%

echo >>> Staging files (git add)
%gitPath% add .

set /p msg="Digite a mensagem do commit: "
if "%msg%"=="" (
    set msg="feat: painel customizacoes e automacao de push"
)

echo >>> Committing files (git commit)
%gitPath% commit -m "%msg%"

echo >>> Pushing to GitHub (git push)
%gitPath% push origin main

echo.
echo >>> Envio concluído com sucesso!
pause
