param (
    [string]$CommitMessage = "feat: painel customizacoes e automacao de push"
)

$gitPath = "C:\Users\tony\portable-git\cmd\git.exe"

if (-not (Test-Path $gitPath)) {
    Write-Error "O executável do Git portátil não foi encontrado em: $gitPath"
    exit 1
}

# Determina o diretório de trabalho correto
$repoPath = $PSScriptRoot
if (Test-Path "$PSScriptRoot\orion_dashboard\.git") {
    $repoPath = "$PSScriptRoot\orion_dashboard"
} elseif (Test-Path "$PSScriptRoot\.git") {
    $repoPath = $PSScriptRoot
} else {
    Write-Warning "Diretório .git não encontrado no root nem em orion_dashboard. Executando no diretório atual."
}

Write-Host ">>> Diretório do repositório: $repoPath" -ForegroundColor Yellow

# Salva a localização atual e vai para o repositório
Push-Location $repoPath

Write-Host ">>> Executando git add..." -ForegroundColor Cyan
& $gitPath add .

Write-Host ">>> Executando git commit..." -ForegroundColor Cyan
& $gitPath commit -m $CommitMessage

Write-Host ">>> Executando git push..." -ForegroundColor Cyan
& $gitPath push origin main

Pop-Location
Write-Host ">>> Envio concluído com sucesso!" -ForegroundColor Green
