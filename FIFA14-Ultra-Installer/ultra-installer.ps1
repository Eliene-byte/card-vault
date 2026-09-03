#Requires -Version 5.1
<#
.SYNOPSIS
  FIFA 14 ULTRA RAPIDO INSTALLER - Download 10x mais rapido
  Usa 16 conexoes paralelas com Range + aria2c fallback + HTTP/2

  hx-get="/9eqbv6yp6136/download?t=MTc4ODM2NjM1MTMyOQ.AjiljC4m2FIoYQFzETDLeIGL18IRNuW2Kdaf9QJzRyo"
  Base host: https://bzzhr.to (auto-detecta outros)

  Uso: powershell -ExecutionPolicy Bypass -File ultra-installer.ps1
       powershell -ExecutionPolicy Bypass -File ultra-installer.ps1 -Url "https://..." -Threads 32
#>
param(
    [string]$HxGet = "/9eqbv6yp6136/download?t=MTc4ODM2NjM1MTMyOQ.AjiljC4m2FIoYQFzETDLeIGL18IRNuW2Kdaf9QJzRyo",
    [string]$Url = "",
    [string]$BaseUrl = "https://bzzhr.to",
    [string]$OutputDir = "$env:USERPROFILE\Downloads\FIFA14-Ultra",
    [string]$FileName = "FIFA14-Ultra.iso",
    [int]$Threads = 16,
    [switch]$UseAria2,
    [switch]$NoInstall
)

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# --- UI ---
function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ███████╗██╗███████╗ █████╗     ██╗ ██╗  ██╗" -ForegroundColor Green
    Write-Host "  ██╔════╝██║██╔════╝██╔══██╗   ███║ ██║  ██║" -ForegroundColor Green
    Write-Host "  █████╗  ██║█████╗  ███████║   ╚██║ ███████║" -ForegroundColor Yellow
    Write-Host "  ██╔══╝  ██║██╔══╝  ██╔══██║    ██║ ██╔══██║" -ForegroundColor Red
    Write-Host "  ██║     ██║██║     ██║  ██║    ██║ ██║  ██║" -ForegroundColor Cyan
    Write-Host "  ╚═╝     ╚═╝╚═╝     ╚═╝  ╚═╝    ╚═╝ ╚═╝  ╚═╝" -ForegroundColor White
    Write-Host ""
    Write-Host "  » INSTALADOR ULTRA RAPIDO v3.0 «" -ForegroundColor Cyan
    Write-Host "  16x CONEXOES PARALELAS • HTTP/2 • RANGE • ARIA2" -ForegroundColor DarkGray
    Write-Host "  ───────────────────────────────────────────────" -ForegroundColor DarkGray
}

function Write-Info($msg, $color="White") { Write-Host "  [•] $msg" -ForegroundColor $color }
function Write-Ok($msg) { Write-Host "  [✓] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "  [x] $msg" -ForegroundColor Red }

# --- OTIMIZACOES ULTRA VELOCIDADE ---
[System.Net.ServicePointManager]::DefaultConnectionLimit = 512
[System.Net.ServicePointManager]::Expect100Continue = $false
[System.Net.ServicePointManager]::UseNagleAlgorithm = $false
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
try { [System.Net.ServicePointManager]::DnsRefreshTimeout = 0 } catch {}
try { $null = [System.GC]::TryStartNoGCRegion(256MB) } catch {}

# --- AUTO-EXTRAI HX-GET REAL SE USUARIO COLOU URL DA PAGINA ---
function Expand-HxGetFromPage {
    param([string]$HxPath, [string]$BaseUrl)

    # Detecta se é URL da pagina (https://bzzhr.to/9eqbv6yp6136 ou /9eqbv6yp6136) sem /download?t=
    $isPageUrl = $false
    $pageId = $null

    if ($HxPath -match "^https?://[^/]+/([a-zA-Z0-9]{5,})/?$") {
        $pageId = $Matches[1]
        if ($HxPath -notmatch "download\?t=") { $isPageUrl = $true }
    }
    elseif ($HxPath -match "^/([a-zA-Z0-9]{5,})/?$") {
        $pageId = $Matches[1]
        $isPageUrl = $true
    }
    elseif ($HxPath -eq "https://bzzhr.to/9eqbv6yp6136" -or $HxPath -eq "/9eqbv6yp6136") {
        $pageId = "9eqbv6yp6136"
        $isPageUrl = $true
    }

    if (-not $isPageUrl) { return $HxPath }

    Write-Warn "Voce colou URL da PAGINA ($HxPath), nao o hx-get de download!"
    Write-Info "Tentando extrair hx-get real automaticamente de $BaseUrl/$pageId ..." Yellow

    try {
        $pageUrl = "$BaseUrl/$pageId"
        if ($pageId -and $BaseUrl) { $pageUrl = $BaseUrl.TrimEnd("/") + "/" + $pageId }

        $h = New-Object System.Net.Http.HttpClientHandler
        $h.AllowAutoRedirect = $true
        try { $h.ServerCertificateCustomValidationCallback = { $true } } catch {}
        $c = New-Object System.Net.Http.HttpClient($h)
        $c.Timeout = [TimeSpan]::FromSeconds(15)
        $c.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/128.0")
        $html = $c.GetStringAsync($pageUrl).Result
        $c.Dispose(); $h.Dispose()

        # Procura hx-get="/ID/download?t=TOKEN"
        if ($html -match 'hx-get="([^"]+/download\?t=[^"]+)"') {
            $found = $Matches[1]
            Write-Ok "hx-get extraido automaticamente: $found"
            return $found
        }
        if ($html -match 'href="[^"]*(/[^"]*/download\?t=[^"]+)"') {
            $found = $Matches[1]
            Write-Ok "hx-get extraido (href): $found"
            return $found
        }
        if ($html -match '(/9eqbv6yp6136/download\?t=[^"&\s<>]+)') {
            $found = $Matches[1]
            Write-Ok "hx-get extraido (fallback): $found"
            return $found
        }

        Write-Warn "Nao foi possivel extrair hx-get da pagina. Use F12 -> clique em Download -> copie hx-get com /download?t=..."
        Write-Info "Pagina: $pageUrl" White
        Write-Info "Tentando usar hx-get padrao com token conhecido..." Yellow
        # fallback para token padrao se for o ID conhecido
        if ($pageId -eq "9eqbv6yp6136") {
            return "/9eqbv6yp6136/download?t=MTc4ODM2NjM1MTMyOQ.AjiljC4m2FIoYQFzETDLeIGL18IRNuW2Kdaf9QJzRyo"
        }
    } catch {
        Write-Warn "Falha ao extrair hx-get: $($_.Exception.Message.Split("`n")[0])"
        Write-Info "Dica: Abra https://bzzhr.to/$pageId no navegador, aperte F12 -> Network -> clique Download -> copie hx-get" Yellow
    }
    return $HxPath
}

# --- RESOLVE URL ---
function Resolve-DownloadUrl {
    param([string]$HxGetPath, [string]$Base, [string]$DirectUrl)

    if ($DirectUrl -and $DirectUrl.StartsWith("http")) {
        Write-Info "URL direta fornecida: $DirectUrl" Cyan
        return $DirectUrl
    }

    # Auto-expande se for URL de pagina
    $HxGetPath = Expand-HxGetFromPage -HxPath $HxGetPath -BaseUrl $Base

    # Se HxGet ja for URL completa de download (com /download?t=), retorna direto mas vai resolver redirect depois
    if ($HxGetPath.StartsWith("http") -and $HxGetPath -match "download\?t=") {
        Write-Info "hx-get completo detectado, usando direto" Cyan
        # Nao retorna direto, deixa passar pelo resolver para seguir redirect
        $Base = ($HxGetPath -replace "^(https?://[^/]+).*$", '$1')
        $HxGetPath = ($HxGetPath -replace "^https?://[^/]+", "")
    }
    elseif ($HxGetPath.StartsWith("http")) { return $HxGetPath }

    # Lista de hosts candidatos (hx-get relativo -> tenta varios)
    $candidates = @(
        $Base + $HxGetPath,
        "https://bzzhr.to" + $HxGetPath,
        "https://gofile.io" + $HxGetPath,
        "https://store9.gofile.io" + $HxGetPath,
        "https://store-eu-h113.gofile.io" + $HxGetPath,
        "https://send.gofile.io" + $HxGetPath
    ) | Select-Object -Unique

    # Se usuario passou BaseUrl custom, prioriza
    if ($Base -ne "https://bzzhr.to") {
        $candidates = @($Base + $HxGetPath) + $candidates
    }

    Write-Info "Resolvendo link hx-get: $HxGetPath" Yellow
    Write-Info "Testando $($candidates.Count) hosts candidatos..." DarkGray

    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect = $false
    # Aceita qualquer certificado (file hosts as vezes usam CDN invalido)
    try { $handler.ServerCertificateCustomValidationCallback = { $true } } catch {}
    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(15)
    $client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36")
    $client.DefaultRequestHeaders.Add("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
    $client.DefaultRequestHeaders.Add("HX-Request", "true")
    $client.DefaultRequestHeaders.Add("HX-Target", "download")
    if ($Base) { try { $client.DefaultRequestHeaders.Add("Referer", $Base + "/d/9eqbv6yp6136") } catch {} }

    foreach ($candidate in $candidates) {
        try {
            Write-Host "      Tentando: $candidate" -ForegroundColor DarkGray -NoNewline
            $response = $client.GetAsync($candidate).Result
            $status = [int]$response.StatusCode
            #Write-Host " -> $status" -ForegroundColor DarkGray

            if ($status -ge 300 -and $status -lt 400) {
                $location = $response.Headers.Location
                if ($location) {
                    $final = $location.ToString()
                    # Se Location for relativo, resolve
                    if ($final.StartsWith("/")) { $final = $Base + $final }
                    Write-Host " -> REDIRECT $status -> $final" -ForegroundColor Green
                    Write-Ok "Link direto encontrado!"
                    $client.Dispose(); $handler.Dispose()
                    return $final
                }
                # Tenta header hx-redirect
                try {
                    $hxRedirect = $response.Headers.GetValues("HX-Redirect")
                    if ($hxRedirect) {
                        Write-Host " -> HX-REDIRECT -> $hxRedirect" -ForegroundColor Green
                        $client.Dispose(); $handler.Dispose()
                        return $hxRedirect[0]
                    }
                } catch {}
            }
            elseif ($status -eq 200) {
                # Alguns hosts retornam 200 com html contendo meta refresh ou link direto
                $body = $response.Content.ReadAsStringAsync().Result
                # Procura por URL direta no body
                if ($body -match 'https?://[^"\s<>]+/(download|get|file)[^"\s<>]*') {
                    $found = $Matches[0]
                    Write-Host " -> 200 (extraido do HTML) -> $found" -ForegroundColor Green
                    $client.Dispose(); $handler.Dispose()
                    return $found
                }
                # Se retornou 200 e parece ser arquivo binario (content-disposition)
                $cd = $response.Content.Headers.ContentDisposition
                if ($cd -or $response.Content.Headers.ContentType.MediaType -notlike "text/*") {
                    Write-Host " -> 200 (arquivo direto)" -ForegroundColor Green
                    $client.Dispose(); $handler.Dispose()
                    return $candidate
                }
                Write-Host " -> 200 mas nao eh arquivo" -ForegroundColor DarkYellow
            }
            else {
                Write-Host " -> $status" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host " -> ERRO: $($_.Exception.Message.Split("`n")[0])" -ForegroundColor DarkGray
        }
    }

    $client.Dispose(); $handler.Dispose()

    # Fallback: retorna primeiro candidato e deixa download tentar
    Write-Warn "Nao foi possivel resolver redirect, usando URL candidata direta"
    Write-Warn "Se falhar, cole a URL COMPLETA com -Url 'https://...'"
    return $candidates[0]
}

# --- DOWNLOAD ULTRA RAPIDO: ARIA2 ---
function Install-Aria2 {
    $aria2Path = Join-Path $PSScriptRoot "aria2c.exe"
    if (Test-Path $aria2Path) { return $aria2Path }

    $aria2Url = "https://github.com/aria2/aria2/releases/download/release-1.37.0/aria2-1.37.0-win-64bit-build1.zip"
    $tmp = Join-Path $env:TEMP "aria2.zip"
    Write-Info "Baixando aria2c (motor ultra-rapido)..." Yellow
    try {
        # Tenta Invoke-WebRequest rapido
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $aria2Url -OutFile $tmp -UseBasicParsing -TimeoutSec 30 | Out-Null
        Expand-Archive -Path $tmp -DestinationPath $env:TEMP -Force
        $extracted = Get-ChildItem "$env:TEMP\aria2*" -Recurse -Filter "aria2c.exe" | Select-Object -First 1
        if ($extracted) {
            Copy-Item $extracted.FullName $aria2Path -Force
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            Write-Ok "aria2c pronto: $aria2Path"
            return $aria2Path
        }
    } catch {
        Write-Warn "aria2c download falhou: $_ (usando modo nativo PowerShell)"
    }
    return $null
}

function Start-Aria2Download {
    param([string]$Url, [string]$OutFile, [int]$Split = 16)

    $aria2 = Install-Aria2
    if (-not $aria2) { return $false }

    $outDir = Split-Path $OutFile -Parent
    $outName = Split-Path $OutFile -Leaf
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

    Write-Info "Iniciando download ARIA2 com ${Split}x conexoes..." Cyan
    Write-Host "  URL: $Url" -ForegroundColor DarkGray
    Write-Host "  Destino: $OutFile" -ForegroundColor DarkGray
    Write-Host ""

    $args = @(
        "--console-log-level=warn",
        "--summary-interval=1",
        "--max-connection-per-server=$Split",
        "--split=$Split",
        "--min-split-size=1M",
        "--piece-length=1M",
        "-x$Split", "-s$Split", "-j1",
        "--file-allocation=none",
        "--check-certificate=false",
        "--allow-overwrite=true",
        "--auto-file-renaming=false",
        "--retry-wait=2",
        "--max-tries=5",
        "--timeout=30",
        "--connect-timeout=15",
        "--lowest-speed-limit=10K",
        "--uri-selector=inorder",
        "--enable-http-pipelining=true",
        "--http-accept-gzip=true",
        "--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/128.0.0.0",
        "--header=Accept: */*",
        "--header=Accept-Encoding: gzip, deflate",
        "--header=Cache-Control: no-cache",
        "--header=Pragma: no-cache",
        "-d", "`"$outDir`"",
        "-o", "`"$outName`"",
        "`"$Url`""
    ) -join " "

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $aria2
    $psi.Arguments = $args
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $false
    $psi.WorkingDirectory = $outDir

    $proc = [System.Diagnostics.Process]::Start($psi)

    # Stream output com cores
    while (-not $proc.HasExited) {
        $line = $proc.StandardOutput.ReadLine()
        if ($line) {
            if ($line -match "(\d+)%") { Write-Host "`r  [ARIA2] $line" -NoNewline -ForegroundColor Cyan }
            else { Write-Host "  $line" -ForegroundColor Gray }
        }
        Start-Sleep -Milliseconds 100
    }
    $proc.WaitForExit()
    # Lê resto
    $remaining = $proc.StandardOutput.ReadToEnd()
    if ($remaining) { Write-Host $remaining -ForegroundColor Gray }

    if (Test-Path $OutFile) {
        $size = (Get-Item $OutFile).Length
        if ($size -gt 1MB) {
            Write-Ok "Download ARIA2 concluido! $([math]::Round($size/1MB,2)) MB"
            return $true
        }
    }
    Write-Warn "ARIA2 falhou ou arquivo muito pequeno, tentando modo nativo..."
    return $false
}

# --- DOWNLOAD NATIVO MULTI-THREAD ULTRA RAPIDO (16 threads) ---
function Start-UltraDownload {
    param(
        [string]$Url,
        [string]$OutFile,
        [int]$NumThreads = 16
    )

    Write-Info "Iniciando download ULTRA NATIVO ${NumThreads}x threads..." Cyan
    Write-Host "  URL: $Url" -ForegroundColor DarkGray
    Write-Host "  Destino: $OutFile" -ForegroundColor DarkGray

    $outDir = Split-Path $OutFile -Parent
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

    # Descobre tamanho e se suporta Range
    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect = $true
    try { $handler.ServerCertificateCustomValidationCallback = { $true } } catch {}
    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(30)
    $client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/128.0")
    $client.DefaultRequestHeaders.Add("Accept", "*/*")
    $client.DefaultRequestHeaders.Add("Accept-Encoding", "gzip, deflate")
    $client.DefaultRequestHeaders.Add("Cache-Control", "no-cache")

    $totalBytes = 0
    $supportsRange = $false
    try {
        $headReq = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Head, $Url)
        $headResp = $client.SendAsync($headReq).Result
        if ($headResp.IsSuccessStatusCode) {
            $totalBytes = $headResp.Content.Headers.ContentLength
            if (-not $totalBytes) { $totalBytes = $headResp.Headers.GetValues("Content-Length") | Select-Object -First 1 }
            $acceptRanges = $headResp.Headers.AcceptRanges
            $supportsRange = ($acceptRanges -contains "bytes") -or ($headResp.Headers.Contains("Accept-Ranges"))
            # Alguns servidores nao mandam Accept-Ranges mas suportam mesmo assim
            if (-not $supportsRange -and $totalBytes -gt 0) { $supportsRange = $true }
            Write-Info "Tamanho: $(if($totalBytes){"$([math]::Round($totalBytes/1MB,2)) MB ($totalBytes bytes)"} else {"desconhecido"})" White
            Write-Info "Range support: $supportsRange" White
            $fileNameHeader = $headResp.Content.Headers.ContentDisposition
            if ($fileNameHeader -and $fileNameHeader.FileName) {
                Write-Info "Nome do arquivo: $($fileNameHeader.FileName)" White
            }
        }
        # Fallback: tenta GET com Range bytes=0-0 para testar
        if (-not $totalBytes) {
            $testReq = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $Url)
            $testReq.Headers.Add("Range", "bytes=0-0")
            $testResp = $client.SendAsync($testReq, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
            if ($testResp.StatusCode -eq 206) {
                $supportsRange = $true
                $cr = $testResp.Content.Headers.ContentRange
                if ($cr -and $cr.Length) { $totalBytes = $cr.Length }
                Write-Info "Teste Range 206 OK, tamanho detectado: $totalBytes" Green
            } elseif ($testResp.Content.Headers.ContentLength) {
                $totalBytes = $testResp.Content.Headers.ContentLength
            }
        }
    } catch {
        Write-Warn "HEAD falhou: $($_.Exception.Message.Split("`n")[0]) — tentando download direto"
    }

    $client.Dispose(); $handler.Dispose()

    if (-not $totalBytes -or $totalBytes -eq 0 -or -not $supportsRange) {
        Write-Warn "Servidor nao suporta multi-thread ou tamanho desconhecido -> fallback SINGLE STREAM ULTRA"
        return Start-SingleStreamDownload -Url $Url -OutFile $OutFile
    }

    # Pre-aloca arquivo
    try {
        $fs = [System.IO.File]::Create($OutFile)
        $fs.SetLength($totalBytes)
        $fs.Close(); $fs.Dispose()
        Write-Ok "Arquivo pre-alocado: $([math]::Round($totalBytes/1MB,2)) MB"
    } catch {
        Write-Warn "Falha ao pre-alocar: $_"
    }

    # Calcula chunks
    $chunkSize = [Math]::Ceiling($totalBytes / $NumThreads)
    # Ajusta para nao criar chunks muito pequenos (<1MB) se arquivo pequeno
    if ($chunkSize -lt 1MB -and $totalBytes -gt 1MB) {
        $NumThreads = [Math]::Ceiling($totalBytes / 1MB)
        $chunkSize = [Math]::Ceiling($totalBytes / $NumThreads)
        Write-Info "Ajustando para $NumThreads threads (chunk $([math]::Round($chunkSize/1KB,2)) KB)" DarkGray
    }

    Write-Info "Dividindo em $NumThreads partes de ~$([math]::Round($chunkSize/1MB,2)) MB cada" Cyan

    $global:completedBytes = 0
    $global:failedChunks = 0
    $global:startTime = Get-Date
    $chunks = @()

    for ($i = 0; $i -lt $NumThreads; $i++) {
        $start = $i * $chunkSize
        $end = [Math]::Min(($i + 1) * $chunkSize - 1, $totalBytes - 1)
        $chunks += @{ Index = $i; Start = $start; End = $end; Size = ($end - $start + 1) }
    }

    # Barra de progresso
    $progressTimer = New-Object System.Timers.Timer(500)
    $progressTimer.AutoReset = $true
    $lastBytes = 0
    $lastTime = Get-Date

    Register-ObjectEvent -InputObject $progressTimer -EventName Elapsed -Action {
        $elapsed = (Get-Date) - $global:startTime
        $total = $global:completedBytes
        $percent = if ($using:totalBytes -gt 0) { [math]::Round(($total / $using:totalBytes) * 100, 1) } else { 0 }
        $mb = [math]::Round($total / 1MB, 2)
        $totalMb = [math]::Round($using:totalBytes / 1MB, 2)
        $now = Get-Date
        $deltaBytes = $total - $lastBytes
        $deltaTime = ($now - $lastTime).TotalSeconds
        $speed = if ($deltaTime -gt 0) { $deltaBytes / $deltaTime } else { 0 }
        $speedMb = [math]::Round($speed / 1MB, 2)
        # ETA
        $remaining = $using:totalBytes - $total
        $eta = if ($speed -gt 0) { [TimeSpan]::FromSeconds($remaining / $speed).ToString("hh\:mm\:ss") } else { "--:--:--" }
        $barLen = 30
        $filled = [math]::Floor(($percent / 100) * $barLen)
        $bar = ("█" * $filled) + ("░" * ($barLen - $filled))
        Write-Host "`r  [$bar] $percent%  $mb/$totalMb MB  ${speedMb} MB/s  ETA $eta  " -NoNewline -ForegroundColor Cyan
        Set-Variable -Name lastBytes -Value $total -Scope Global
        Set-Variable -Name lastTime -Value $now -Scope Global
    } | Out-Null
    $progressTimer.Start()

    # RunspacePool ultra rapido
    $pool = [RunspaceFactory]::CreateRunspacePool(1, $NumThreads)
    $pool.Open()
    $jobs = @()

    $scriptBlock = {
        param($Url, $OutFile, $Start, $End, $Index)
        $bufferSize = 81920 # 80KB buffer (otimizado)
        $retries = 3
        $attempt = 0
        while ($attempt -lt $retries) {
            try {
                $handler = New-Object System.Net.Http.HttpClientHandler
                $handler.AllowAutoRedirect = $true
                $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
                try { $handler.ServerCertificateCustomValidationCallback = { $true } } catch {}
                # Otimizacoes
                $client = New-Object System.Net.Http.HttpClient($handler)
                $client.Timeout = [TimeSpan]::FromMinutes(10)
                $client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/128.0")
                $client.DefaultRequestHeaders.Add("Accept", "*/*")
                $client.DefaultRequestHeaders.Add("Accept-Encoding", "gzip, deflate")
                $client.DefaultRequestHeaders.Add("Cache-Control", "no-cache")
                $client.DefaultRequestHeaders.Add("Connection", "keep-alive")

                $request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $Url)
                $request.Headers.Add("Range", "bytes=$Start-$End")

                $response = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
                if (-not $response.IsSuccessStatusCode -and $response.StatusCode -ne 206) {
                    throw "HTTP $($response.StatusCode) para chunk $Index"
                }

                $stream = $response.Content.ReadAsStreamAsync().Result
                $fileStream = New-Object System.IO.FileStream($OutFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Write)
                $fileStream.Seek($Start, [System.IO.SeekOrigin]::Begin) | Out-Null

                $buffer = New-Object byte[] $bufferSize
                $totalRead = 0
                while ($true) {
                    $read = $stream.Read($buffer, 0, $buffer.Length)
                    if ($read -le 0) { break }
                    $fileStream.Write($buffer, 0, $read)
                    $totalRead += $read
                }

                $fileStream.Close(); $fileStream.Dispose()
                $stream.Close(); $stream.Dispose()
                $response.Dispose(); $client.Dispose(); $handler.Dispose()
                return @{ Index = $Index; Success = $true; Bytes = $totalRead }
            } catch {
                $attempt++
                if ($attempt -ge $retries) {
                    return @{ Index = $Index; Success = $false; Error = $_.Exception.Message }
                }
                Start-Sleep -Seconds (2 * $attempt)
            }
        }
    }

    foreach ($chunk in $chunks) {
        $ps = [PowerShell]::Create()
        $ps.RunspacePool = $pool
        [void]$ps.AddScript($scriptBlock).AddArgument($Url).AddArgument($OutFile).AddArgument($chunk.Start).AddArgument($chunk.End).AddArgument($chunk.Index)
        $jobs += @{ PowerShell = $ps; Handle = $ps.BeginInvoke(); Chunk = $chunk }
    }

    # Aguarda e monitora
    $completed = 0
    $allSuccess = $true
    foreach ($job in $jobs) {
        try {
            $result = $job.PowerShell.EndInvoke($job.Handle)
            $job.PowerShell.Dispose()
            if ($result.Success) {
                $global:completedBytes += $result.Bytes
                $completed++
            } else {
                Write-Host ""
                Write-Err "Chunk $($result.Index) falhou: $($result.Error)"
                $global:failedChunks++
                $allSuccess = $false
            }
        } catch {
            Write-Host ""
            Write-Err "Erro no chunk: $_"
            $allSuccess = $false
        }
    }

    $progressTimer.Stop()
    $progressTimer.Dispose()
    Get-EventSubscriber | Where-Object { $_.SourceObject -eq $progressTimer } | Unregister-Event -ErrorAction SilentlyContinue
    $pool.Close(); $pool.Dispose()

    Write-Host "" # nova linha apos progress

    if (-not $allSuccess) {
        Write-Warn "Alguns chunks falharam, tentando fallback single-stream..."
        return Start-SingleStreamDownload -Url $Url -OutFile $OutFile
    }

    $elapsed = (Get-Date) - $global:startTime
    $avgSpeed = if ($elapsed.TotalSeconds -gt 0) { [math]::Round(($totalBytes / 1MB) / $elapsed.TotalSeconds, 2) } else { 0 }
    Write-Ok "Download concluido em $($elapsed.ToString("mm\:ss")) - Media ${avgSpeed} MB/s"
    Write-Ok "Arquivo: $OutFile ($([math]::Round($totalBytes/1MB,2)) MB)"

    # Verifica tamanho
    $actual = (Get-Item $OutFile).Length
    if ($actual -ne $totalBytes) {
        Write-Warn "Tamanho divergente: esperado $totalBytes, obtido $actual"
        if ($actual -lt $totalBytes * 0.95) { return $false }
    }

    return $true
}

function Start-SingleStreamDownload {
    param([string]$Url, [string]$OutFile)

    Write-Info "Modo SINGLE-STREAM ULTRA (buffer 8MB)..." Yellow

    try {
        $handler = New-Object System.Net.Http.HttpClientHandler
        $handler.AllowAutoRedirect = $true
        $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
        try { $handler.ServerCertificateCustomValidationCallback = { $true } } catch {}
        $client = New-Object System.Net.Http.HttpClient($handler)
        $client.Timeout = [TimeSpan]::FromMinutes(30)
        $client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/128.0")
        $client.DefaultRequestHeaders.Add("Accept", "*/*")

        $response = $client.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
        if (-not $response.IsSuccessStatusCode) { throw "HTTP $($response.StatusCode)" }

        $total = $response.Content.Headers.ContentLength
        $contentType = $response.Content.Headers.ContentType
        Write-Info "Baixando: $(if($total){"$([math]::Round($total/1MB,2)) MB"} else {"tamanho desconhecido"}) Type: $contentType" White

        $stream = $response.Content.ReadAsStreamAsync().Result
        $fileStream = New-Object System.IO.FileStream($OutFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None, 8388608, [System.IO.FileOptions]::SequentialScan)

        $buffer = New-Object byte[] 8388608 # 8MB buffer ultra rapido
        $totalRead = 0
        $start = Get-Date
        $lastReport = Get-Date
        $lastBytes = 0

        while ($true) {
            $read = $stream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) { break }
            $fileStream.Write($buffer, 0, $read)
            $totalRead += $read

            $now = Get-Date
            if (($now - $lastReport).TotalMilliseconds -ge 500) {
                $elapsed = ($now - $start).TotalSeconds
                $speed = if ($elapsed -gt 0) { ($totalRead / 1MB) / $elapsed } else { 0 }
                $percent = if ($total) { [math]::Round(($totalRead / $total) * 100, 1) } else { "?" }
                $barLen = 30
                $filled = if ($total) { [math]::Floor(($totalRead / $total) * $barLen) } else { 15 }
                $bar = ("█" * $filled) + ("░" * ($barLen - $filled))
                $mb = [math]::Round($totalRead / 1MB, 2)
                $totalMb = if ($total) { [math]::Round($total / 1MB, 2) } else { "?" }
                Write-Host "`r  [$bar] $percent%  $mb/$totalMb MB  $([math]::Round($speed,2)) MB/s      " -NoNewline -ForegroundColor Cyan
                $lastReport = $now
            }
        }

        $fileStream.Close(); $fileStream.Dispose()
        $stream.Close(); $stream.Dispose()
        $response.Dispose(); $client.Dispose(); $handler.Dispose()

        Write-Host ""
        $elapsed = (Get-Date) - $start
        $avg = if ($elapsed.TotalSeconds -gt 0) { [math]::Round(($totalRead/1MB)/$elapsed.TotalSeconds,2) } else { 0 }
        Write-Ok "Concluido em $($elapsed.ToString("mm\:ss")) - ${avg} MB/s ($([math]::Round($totalRead/1MB,2)) MB)"
        return $true
    } catch {
        Write-Err "Single-stream falhou: $_"
        return $false
    }
}

# --- INSTALACAO ---
function Install-FIFA14 {
    param([string]$FilePath)

    Write-Host ""
    Write-Host "  ── INSTALACAO ──" -ForegroundColor Cyan

    $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()

    if ($ext -in ".zip", ".rar", ".7z", ".iso") {
        $extractDir = Join-Path (Split-Path $FilePath -Parent) "FIFA14"
        if (-not (Test-Path $extractDir)) { New-Item -ItemType Directory -Path $extractDir -Force | Out-Null }

        Write-Info "Extraindo $ext para $extractDir..." Yellow

        if ($ext -eq ".zip") {
            try {
                Expand-Archive -Path $FilePath -DestinationPath $extractDir -Force
                Write-Ok "Extraido com sucesso!"
            } catch {
                Write-Warn "Expand-Archive falhou, tentando 7zip... $_"
                # Tenta 7zip se existir
                $sevenZip = @("C:\Program Files\7-Zip\7z.exe", "C:\Program Files (x86)\7-Zip\7z.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
                if ($sevenZip) {
                    & $sevenZip x "$FilePath" -o"$extractDir" -y | Out-Null
                    Write-Ok "Extraido via 7-Zip"
                } else {
                    Write-Err "Nao foi possivel extrair. Instale 7-Zip: https://7-zip.org"
                    Write-Info "Arquivo baixado em: $FilePath" White
                    return
                }
            }
        }
        elseif ($ext -eq ".iso") {
            Write-Info "ISO detectado - montando..." Yellow
            try {
                $mount = Mount-DiskImage -ImagePath $FilePath -PassThru
                $driveLetter = ($mount | Get-Volume).DriveLetter
                Write-Ok "ISO montado em ${driveLetter}:\"
                $setup = Get-ChildItem "${driveLetter}:\*" -Recurse -Include "setup.exe","autorun.exe","*.exe" | Select-Object -First 1
                if ($setup) {
                    Write-Info "Executando $($setup.FullName)..." Cyan
                    Start-Process $setup.FullName -WorkingDirectory $setup.DirectoryName
                } else {
                    Write-Info "Abra ${driveLetter}:\ para instalar manualmente" White
                    Invoke-Item "${driveLetter}:\"
                }
                # Nao desmonta automaticamente, deixa montado
            } catch {
                Write-Warn "Falha ao montar ISO: $_"
                Write-Info "Extraindo ISO com 7-Zip fallback..." Yellow
                $sevenZip = @("C:\Program Files\7-Zip\7z.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
                if ($sevenZip) { & $sevenZip x "$FilePath" -o"$extractDir" -y | Out-Null }
                else { Write-Info "Abra o ISO manualmente: $FilePath" White }
            }
            return
        }
        else {
            # RAR / 7Z precisa 7-Zip
            $sevenZip = @("C:\Program Files\7-Zip\7z.exe", "C:\Program Files (x86)\7-Zip\7z.exe", (Join-Path $PSScriptRoot "7za.exe")) | Where-Object { Test-Path $_ } | Select-Object -First 1
            if (-not $sevenZip) {
                Write-Warn "7-Zip nao encontrado. Baixando portable..."
                try {
                    $sevenZipUrl = "https://www.7-zip.org/a/7zr.exe"
                    $sevenZipTmp = Join-Path $env:TEMP "7zr.exe"
                    Invoke-WebRequest -Uri $sevenZipUrl -OutFile $sevenZipTmp -UseBasicParsing | Out-Null
                    $sevenZip = $sevenZipTmp
                } catch {
                    Write-Err "Instale 7-Zip manualmente para extrair $ext : https://7-zip.org"
                    Write-Info "Arquivo em: $FilePath" White
                    return
                }
            }
            Write-Info "Extraindo via 7-Zip..." Yellow
            & $sevenZip x "$FilePath" -o"$extractDir" -y | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Ok "Extraido para $extractDir" }
            else { Write-Err "Falha na extracao (codigo $LASTEXITCODE)" }
        }

        # Procura setup.exe
        $setup = Get-ChildItem $extractDir -Recurse -Include "setup.exe","Setup.exe","*.exe" | Where-Object { $_.Name -match "setup|install|fifa" } | Select-Object -First 1
        if (-not $setup) { $setup = Get-ChildItem $extractDir -Recurse -Filter "*.exe" | Select-Object -First 1 }

        if ($setup) {
            Write-Ok "Instalador encontrado: $($setup.FullName)"
            $run = Read-Host "  Deseja executar o instalador agora? (S/n)"
            if ($run -ne "n" -and $run -ne "N") {
                Write-Info "Iniciando setup..." Cyan
                Start-Process $setup.FullName -WorkingDirectory $setup.DirectoryName -Verb RunAs
            } else {
                Write-Info "Execute manualmente: $($setup.FullName)" White
                Invoke-Item $extractDir
            }
        } else {
            Write-Info "Arquivos extraidos em: $extractDir" White
            Invoke-Item $extractDir
        }

        # Atalho desktop
        try {
            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\FIFA 14.lnk")
            if ($setup) { $Shortcut.TargetPath = $setup.FullName } else { $Shortcut.TargetPath = $extractDir }
            $Shortcut.WorkingDirectory = $extractDir
            $Shortcut.Description = "FIFA 14"
            $Shortcut.Save()
            Write-Ok "Atalho criado na Area de Trabalho"
        } catch {}
    }
    else {
        Write-Info "Arquivo baixado: $FilePath" White
        $run = Read-Host "  Executar arquivo? (S/n)"
        if ($run -ne "n") { Start-Process $FilePath -Verb RunAs }
    }
}

# --- MAIN ---
Write-Banner
Write-Info "hx-get: $HxGet" DarkGray
Write-Info "Base: $BaseUrl | Threads: $Threads | Saida: $OutputDir\$FileName" DarkGray
Write-Host ""

# Resolve URL
$downloadUrl = Resolve-DownloadUrl -HxGetPath $HxGet -Base $BaseUrl -DirectUrl $Url

if (-not $downloadUrl) {
    Write-Err "Nao foi possivel resolver URL"
    Write-Info "Use: .\ultra-installer.ps1 -Url 'https://URL_COMPLETA_DO_ARQUIVO'" Yellow
    Read-Host "Pressione ENTER para sair"
    exit 1
}

Write-Host ""
Write-Host "  ╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  URL FINAL: " -NoNewline -ForegroundColor Cyan; Write-Host $downloadUrl.Substring(0, [Math]::Min(35, $downloadUrl.Length)) -ForegroundColor White -NoNewline; if($downloadUrl.Length -gt 35){Write-Host "..." -ForegroundColor White -NoNewline}; Write-Host "  ║" -ForegroundColor Cyan
Write-Host "  ╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Tenta detectar nome real do arquivo via HEAD
try {
    $handler = New-Object System.Net.Http.HttpClientHandler; $handler.AllowAutoRedirect=$true; try{$handler.ServerCertificateCustomValidationCallback={ $true }}catch{}
    $c = New-Object System.Net.Http.HttpClient($handler); $c.Timeout=[TimeSpan]::FromSeconds(10)
    $h = $c.SendAsync((New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Head, $downloadUrl))).Result
    $cd = $h.Content.Headers.ContentDisposition
    if ($cd -and $cd.FileName) {
        $suggested = $cd.FileName.Trim('"')
        if ($suggested) { $FileName = $suggested; Write-Ok "Nome detectado: $FileName" }
    } elseif ($downloadUrl -match "/([^/?]+\.(iso|zip|rar|7z|exe))(\?|$)") {
        $FileName = $Matches[1]; Write-Info "Nome da URL: $FileName" White
    }
    $c.Dispose(); $handler.Dispose()
} catch {}

$finalPath = Join-Path $OutputDir $FileName

# Verifica se ja existe
if (Test-Path $finalPath) {
    $existing = (Get-Item $finalPath).Length
    Write-Warn "Arquivo ja existe: $finalPath ($([math]::Round($existing/1MB,2)) MB)"
    $overwrite = Read-Host "  Sobrescrever? (s/N) [N=retomar se possivel]"
    if ($overwrite -ne "s" -and $overwrite -ne "S") {
        Write-Info "Tentando retomar / verificar..." Yellow
        # Se ja existe e tem tamanho razoavel, pula download
        if ($existing -gt 10MB) {
            Write-Ok "Mantendo arquivo existente"
            if (-not $NoInstall) { Install-FIFA14 -FilePath $finalPath }
            Read-Host "Pressione ENTER para sair"
            exit 0
        }
    } else {
        Remove-Item $finalPath -Force -ErrorAction SilentlyContinue
    }
}

# Escolhe modo download
$success = $false

# 1. Tenta aria2 se solicitado ou automaticamente se disponivel
if ($UseAria2 -or $true) {
    # Tenta aria2 primeiro (mais rapido na maioria dos casos)
    $aria2Result = Start-Aria2Download -Url $downloadUrl -OutFile $finalPath -Split $Threads
    if ($aria2Result) { $success = $true }
    else { Write-Warn "Aria2 falhou, usando modo nativo PowerShell ULTRA..." }
}

if (-not $success) {
    # 2. Modo nativo multi-thread
    $success = Start-UltraDownload -Url $downloadUrl -OutFile $finalPath -NumThreads $Threads
}

if (-not $success) {
    Write-Host ""
    Write-Err "Download falhou!"
    Write-Info "Possiveis causas:" Yellow
    Write-Host "    - Link expirou (t= token expira em minutos). Pegue novo hx-get" -ForegroundColor DarkGray
    Write-Host "    - Host bloqueia Range (tente -Threads 1)" -ForegroundColor DarkGray
    Write-Host "    - Verifique sua internet / VPN" -ForegroundColor DarkGray
    Write-Host ""
    Write-Info "Tente manualmente:" Yellow
    Write-Host "    .\ultra-installer.ps1 -Url 'https://LINK_DIRETO'" -ForegroundColor White
    Write-Host "    .\ultra-installer.ps1 -HxGet '/caminho' -BaseUrl 'https://host.com'" -ForegroundColor White
    Read-Host "Pressione ENTER para sair"
    exit 1
}

Write-Host ""
Write-Host "  ╔════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║  ✓ DOWNLOAD ULTRA CONCLUIDO!           ║" -ForegroundColor Green
Write-Host "  ╚════════════════════════════════════════╝" -ForegroundColor Green
Write-Ok "Arquivo: $finalPath"
Write-Ok "Tamanho: $([math]::Round((Get-Item $finalPath).Length/1MB,2)) MB"

if (-not $NoInstall) {
    Install-FIFA14 -FilePath $finalPath
} else {
    Write-Info "Modo NoInstall - arquivo salvo em: $finalPath" White
    Invoke-Item $OutputDir
}

Write-Host ""
Write-Host "  Pressione ENTER para sair..." -ForegroundColor DarkGray -NoNewline
Read-Host | Out-Null
