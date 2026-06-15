param (
    [string]$CommitMessage
)

$gitPath = "C:\Users\tony\portable-git\cmd\git.exe"

if (-not (Test-Path $gitPath)) {
    Write-Error "O executável do Git portátil não foi encontrado em: $gitPath"
    exit 1
}

# Função auxiliar para fazer push em um repositório
function Push-Repo {
    param (
        [string]$Path,
        [string]$Name,
        [string]$Msg
    )
    if (Test-Path "$Path\.git") {
        Write-Host "=============================================" -ForegroundColor Magenta
        Write-Host ">>> Processando repositório: $Name" -ForegroundColor Yellow
        Write-Host ">>> Pasta: $Path" -ForegroundColor Gray
        Write-Host "=============================================" -ForegroundColor Magenta
        
        Push-Location $Path
        
        Write-Host ">>> Executando git add..." -ForegroundColor Cyan
        & $gitPath add .
        
        Write-Host ">>> Executando git commit..." -ForegroundColor Cyan
        & $gitPath commit -m $Msg
        
        Write-Host ">>> Executando git push..." -ForegroundColor Cyan
        & $gitPath push origin main
        
        Pop-Location
        Write-Host ">>> Envio do $Name concluído!" -ForegroundColor Green
        Write-Host ""
    }
}

# Se não foi fornecido commit message, solicita ou usa default
if (-not $CommitMessage) {
    $CommitMessage = Read-Host "Digite a mensagem do commit [Pressione Enter para usar o padrão]"
    if (-not $CommitMessage) {
        $CommitMessage = "feat: atualização automática do projeto"
    }
}

# Executa para o Dashboard (se existir)
Push-Repo -Path "$PSScriptRoot\orion_dashboard" -Name "Dashboard (Oriontech)" -Msg $CommitMessage

# Executa para o Robô MT5 (se existir)
Push-Repo -Path $PSScriptRoot -Name "Robô MT5 (Orion-MT5)" -Msg $CommitMessage

Write-Host ">>> Todos os envios concluídos com sucesso!" -ForegroundColor Green
