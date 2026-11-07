$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path ([System.IO.Path]::GetTempPath()) ('redecheck-test-' + [guid]::NewGuid().ToString('N'))
$listener = New-Object System.Net.Sockets.TcpListener -ArgumentList ([System.Net.IPAddress]::Loopback),0
$closedListener = New-Object System.Net.Sockets.TcpListener -ArgumentList ([System.Net.IPAddress]::Loopback),0
$listener.Start()
$closedListener.Start()
$openPort = $listener.LocalEndpoint.Port
$closedPort = $closedListener.LocalEndpoint.Port
$closedListener.Stop()
try {
    & (Join-Path $root 'redecheck.ps1') -Target '127.0.0.1' -Port $openPort,$closedPort -Count 2 -TimeoutMs 200 -OutputDirectory $out
    $json = Get-ChildItem $out -Filter '*.json' | Select-Object -First 1
    $data = Get-Content -LiteralPath $json.FullName -Raw | ConvertFrom-Json
    $result = $data.Results[0]
    if ($result.Tcp[0].Status -ne 'acessivel') { throw 'TCP local deveria conectar.' }
    if ($result.Tcp[1].Status -ne 'nao_acessivel') { throw 'Porta fechada deveria falhar.' }
    if ($result.IcmpReceived -ne 2 -or $result.IcmpLossPercent -ne 0) { throw 'Ping loopback falhou.' }
    $htmlFile = Get-ChildItem $out -Filter '*.html' | Select-Object -First 1
    $html = Get-Content -LiteralPath $htmlFile.FullName -Raw
    if ($html -notmatch '<table>' -or $html -notmatch '127.0.0.1') { throw 'Relatorio HTML invalido.' }
    $rejected = $false
    try { & (Join-Path $root 'redecheck.ps1') -Target '<script>' -OutputDirectory $out } catch { $rejected = $true }
    if (-not $rejected) { throw 'Destino invalido deveria ser rejeitado.' }
    Write-Host 'PASS: TCP aberto/fechado, ICMP loopback, HTML, JSON e entrada invalida.'
    Write-Host "Arquivos de teste: $out"
} finally { $listener.Stop() }
