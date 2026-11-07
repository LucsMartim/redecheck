#Requires -Version 5.1
<#
.SYNOPSIS
Diagnostico simples de DNS, ICMP e portas TCP, com relatorio HTML e JSON.
#>
[CmdletBinding()]
param(
    [string[]]$Target = @('127.0.0.1'),
    [ValidateRange(1,65535)][int[]]$Port = @(443),
    [ValidateRange(1,20)][int]$Count = 4,
    [ValidateRange(100,10000)][int]$TimeoutMs = 1000,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'reports')
)
$ErrorActionPreference = 'Stop'
foreach ($name in $Target) {
    if ([string]::IsNullOrWhiteSpace($name) -or $name.Length -gt 253 -or
        $name -match '[\s/\\<>"''&]' -or $name.StartsWith('-')) {
        throw "Destino invalido: informe apenas IP ou nome DNS, sem URL."
    }
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$results = @(
    foreach ($name in $Target) {
        Write-Host "Testando $name ..."
        $addresses = @()
        $dnsError = $null
        try {
            $addresses = @([System.Net.Dns]::GetHostAddresses($name) | ForEach-Object { $_.IPAddressToString })
        } catch { $dnsError = $_.Exception.GetBaseException().Message }
        $latencies = @()
        $icmpErrors = @()
        if ($addresses.Count -gt 0) {
            $ping = New-Object System.Net.NetworkInformation.Ping
            try {
                for ($i = 0; $i -lt $Count; $i++) {
                    try {
                        $reply = $ping.Send($addresses[0], $TimeoutMs)
                        if ($reply.Status -eq 'Success') {
                            $latencies += [long]$reply.RoundtripTime
                        } else { $icmpErrors += $reply.Status.ToString() }
                    } catch { $icmpErrors += $_.Exception.GetBaseException().Message }
                }
            } finally { $ping.Dispose() }
        }
        $tcpResults = @(
            foreach ($portNumber in $Port) {
                $attempts = @()
                $reachable = $false
                foreach ($address in $addresses) {
                    $ip = [System.Net.IPAddress]::Parse($address)
                    $client = New-Object System.Net.Sockets.TcpClient -ArgumentList $ip.AddressFamily
                    $timer = [System.Diagnostics.Stopwatch]::StartNew()
                    $state = 'erro'
                    $detail = $null
                    $async = $null
                    try {
                        $async = $client.BeginConnect($ip, $portNumber, $null, $null)
                        if ($async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
                            $client.EndConnect($async)
                            $state = 'acessivel'
                            $reachable = $true
                        } else { $state = 'tempo_esgotado' }
                    } catch { $detail = $_.Exception.GetBaseException().Message }
                    finally {
                        $timer.Stop()
                        $client.Close()
                        if ($null -ne $async) { $async.AsyncWaitHandle.Close() }
                    }
                    $attempts += [pscustomobject]@{
                        Address = $address; Status = $state
                        DurationMs = $timer.ElapsedMilliseconds; Detail = $detail
                    }
                    if ($reachable) { break }
                }
                $status = if ($dnsError) { 'nao_testada_dns' } elseif ($reachable) { 'acessivel' } else { 'nao_acessivel' }
                [pscustomobject]@{ Port = $portNumber; Status = $status; Attempts = @($attempts) }
            }
        )
        $received = $latencies.Count
        $sent = if ($addresses.Count -gt 0) { $Count } else { 0 }
        $loss = if ($sent -gt 0) { [math]::Round(100 * ($sent - $received) / $sent, 1) } else { $null }
        $average = if ($received -gt 0) { [math]::Round(($latencies | Measure-Object -Average).Average, 2) } else { $null }
        [pscustomobject]@{
            Target = $name; Addresses = @($addresses); DnsError = $dnsError
            IcmpAddress = if ($addresses.Count -gt 0) { $addresses[0] } else { $null }
            IcmpSent = $sent; IcmpReceived = $received; IcmpLossPercent = $loss
            IcmpAverageMs = $average; IcmpErrors = @($icmpErrors); Tcp = @($tcpResults)
        }
    }
)
$report = [pscustomobject]@{
    Tool = 'RedeCheck'; Version = '0.1.0'
    CreatedAt = (Get-Date).ToString('o'); TimeoutMs = $TimeoutMs
    Results = @($results)
}
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0,6)
$jsonPath = Join-Path $OutputDirectory "redecheck-$stamp.json"
$htmlPath = Join-Path $OutputDirectory "redecheck-$stamp.html"
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
function Encode([object]$Value) { [System.Net.WebUtility]::HtmlEncode([string]$Value) }
$rows = foreach ($result in $results) {
    $dns = if ($result.DnsError) { 'Falha: ' + $result.DnsError } else { $result.Addresses -join ', ' }
    $icmp = if ($result.IcmpSent -eq 0) { 'Nao testado (DNS)' } else {
        "Recebidos $($result.IcmpReceived)/$($result.IcmpSent); perda $($result.IcmpLossPercent)%"
    }
    $latency = if ($null -eq $result.IcmpAverageMs) { 'Sem resposta' } else { "$($result.IcmpAverageMs) ms" }
    $tcp = ($result.Tcp | ForEach-Object { "$($_.Port): $($_.Status)" }) -join '; '
    '<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td>{4}</td></tr>' -f (Encode $result.Target),(Encode $dns),(Encode $icmp),(Encode $latency),(Encode $tcp)
}
$html = @"
<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>RedeCheck - Relatorio</title><style>
body{font:16px system-ui,sans-serif;background:#f1f5f9;color:#172534;margin:0;padding:32px}
main{max-width:1200px;margin:auto;background:white;padding:28px;border-radius:14px}
h1{color:#0369a1;margin-top:0}table{width:100%;border-collapse:collapse;font-size:14px}
th,td{text-align:left;border-bottom:1px solid #cbd5e1;padding:14px;overflow-wrap:anywhere}
th{background:#e0f2fe}.scroll{overflow-x:auto}.note{line-height:1.6;color:#475569}
</style></head><body><main><h1>RedeCheck</h1>
<p>Diagnostico de conectividade | $(Encode $report.CreatedAt)</p>
<div class="scroll"><table><thead><tr><th>Destino</th><th>Resolucao de nome / IP</th><th>ICMP</th><th>Media ICMP</th><th>Portas TCP</th></tr></thead>
<tbody>$($rows -join "`n")</tbody></table></div>
<p class="note">A ausencia de resposta ICMP pode indicar bloqueio de ping; nao comprova indisponibilidade.
Uma porta TCP acessivel confirma a conexao, mas nao valida o servico, HTTPS ou certificado.
Este teste nao mede velocidade em Mbps. Detalhes por endereco estao no arquivo JSON.</p>
</main></body></html>
"@
$html | Set-Content -LiteralPath $htmlPath -Encoding UTF8
$results | Select-Object Target,IcmpReceived,IcmpSent,IcmpAverageMs | Format-Table -AutoSize | Out-Host
Write-Host "HTML: $htmlPath"
Write-Host "JSON: $jsonPath"
