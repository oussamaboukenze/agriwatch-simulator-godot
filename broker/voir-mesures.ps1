$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Write-Host 'AgriWatch : mesures recues depuis Mosquitto local (127.0.0.1:1883)' -ForegroundColor Green
Write-Host 'Laisser la ferme en cours. Ctrl+C pour arreter la lecture.'
& (Join-Path $projectRoot 'tools\mosquitto\mosquitto_sub.exe') -h 127.0.0.1 -p 1883 -t 'agriwatch/farm-001/+/sensors/+/telemetry' -v
