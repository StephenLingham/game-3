param([switch]$StampOnly)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$htmlPath = Join-Path $projectRoot 'docs/index.html'
$packPath = Join-Path $projectRoot 'docs/index.pck'

if (-not $StampOnly) {
    & godot --headless --path $projectRoot --export-release Web $htmlPath
    if ($LASTEXITCODE -ne 0) { throw "Godot export failed with exit code $LASTEXITCODE" }
}

# Version only the small game pack; the unchanged Web engine stays cacheable.
$packVersion = (Get-FileHash -LiteralPath $packPath -Algorithm SHA256).Hash.Substring(0, 16).ToLowerInvariant()
$html = [System.IO.File]::ReadAllText($htmlPath)
$marker = 'engine.startGame({'
if (-not $html.Contains($marker)) { throw 'Godot loader entry point is missing' }
$html = [regex]::Replace($html, "(?m)^\s*'mainPack': 'index\.pck\?v=[a-f0-9]+',\r?\n", '')
$html = $html.Replace($marker, $marker + "`n`t`t`t'mainPack': 'index.pck?v=$packVersion',")
[System.IO.File]::WriteAllText($htmlPath, $html)
Write-Output "Web package ready: index.pck?v=$packVersion"
