$ErrorActionPreference = 'Stop'
$env:PYTHONUTF8 = '1'

# The repository root is derived from this script's location, so the project
# can be cloned to any drive and used on any machine.
$repoRoot = Split-Path -Parent $PSScriptRoot
$validatorCandidates = @()
if ($env:CODEX_HOME) {
    $validatorCandidates += Join-Path $env:CODEX_HOME "skills\.system\skill-creator\scripts\quick_validate.py"
}
$validatorCandidates += Join-Path $HOME ".codex\skills\.system\skill-creator\scripts\quick_validate.py"
$validator = $validatorCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $validator) {
    throw "Codex Skill validator not found. Set CODEX_HOME or install skill-creator."
}

$skillDirectories = @($repoRoot) + @(
    Get-ChildItem -LiteralPath $repoRoot -Directory -Force |
        Where-Object { $_.Name -ne ".git" -and $_.Name -ne "scripts" } |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md") } |
        Select-Object -ExpandProperty FullName
)

foreach ($directory in $skillDirectories) {
    Write-Host "[$directory]"
    & python $validator $directory
    if ($LASTEXITCODE -ne 0) {
        throw "Skill validation failed: $directory"
    }
}

Write-Host "All Skill directories passed validation. Count: $($skillDirectories.Count)"
