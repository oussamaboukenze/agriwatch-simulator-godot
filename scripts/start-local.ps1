$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot

function Find-Executable($environmentPath, $commands, $candidates) {
    if ($environmentPath -and (Test-Path -LiteralPath $environmentPath -PathType Leaf)) { return $environmentPath }
    foreach ($name in $commands) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

$downloads = @(Get-ChildItem -LiteralPath (Join-Path $HOME 'Downloads') -Filter 'Godot*' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    Get-ChildItem -LiteralPath $_.FullName -Filter 'Godot*.exe' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike '*console*' } | Select-Object -ExpandProperty FullName
})
$godot = Find-Executable $env:GODOT_EXE @('godot', 'godot4') $downloads
$python = Join-Path $projectRoot '.venv\Scripts\python.exe'
$brokerCandidates = @((Join-Path $projectRoot 'tools\mosquitto\mosquitto.exe'), (Join-Path $env:ProgramFiles 'mosquitto\mosquitto.exe'))
if ($env:MOSQUITTO_DIR) { $brokerCandidates = @((Join-Path $env:MOSQUITTO_DIR 'mosquitto.exe')) + $brokerCandidates }
$broker = Find-Executable $null @('mosquitto') $brokerCandidates
if (-not $godot) { throw 'Godot 4 introuvable. Ajouter godot au PATH ou definir GODOT_EXE avec le chemin complet de Godot.exe. Voir README.md.' }
if (-not (Test-Path -LiteralPath $python)) { throw 'Python .venv absent. Executer : python -m venv .venv, puis .venv\Scripts\python.exe -m pip install -r bridge/requirements.txt' }
if (-not $broker) { throw 'Mosquitto absent. Installer Mosquitto ou placer ses fichiers dans tools\mosquitto. Voir README.md.' }
$subscriber = Join-Path (Split-Path $broker -Parent) 'mosquitto_sub.exe'
if (-not (Test-Path -LiteralPath $subscriber)) { throw 'mosquitto_sub.exe absent du dossier Mosquitto.' }

$brokerConfig = Join-Path $projectRoot 'broker\mosquitto.conf'
if (-not (Get-NetTCPConnection -LocalPort 1883 -State Listen -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $broker -ArgumentList '-c', ('"' + $brokerConfig + '"') -WorkingDirectory $projectRoot -WindowStyle Hidden
}
if (-not (Get-NetTCPConnection -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $python -ArgumentList 'bridge/bridge.py' -WorkingDirectory $projectRoot -WindowStyle Hidden
}
Start-Sleep -Seconds 2
Start-Process -FilePath $subscriber -ArgumentList '-h','127.0.0.1','-p','1883','-i','agriwatch-local-viewer','-t','agriwatch/farm-001/+/sensors/+/telemetry','-v' -WorkingDirectory $projectRoot -WindowStyle Normal
Start-Process -FilePath $godot -ArgumentList '--path', ('"' + $projectRoot + '"'), '--', '--mqtt-local' -WorkingDirectory $projectRoot
