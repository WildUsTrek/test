param(
  [int]$Port = 8000
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Game = Join-Path $Root "01_GIOCO_PRONTO_LOCAL_TEST"
$Log = Join-Path $Root "AVVIO_GIOCO_POWERSHELL_LOG.txt"

function Write-Log($msg) {
  $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
  Add-Content -Path $Log -Value $line -Encoding UTF8
  Write-Host $msg
}

function Get-ContentType($path) {
  $ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
  switch ($ext) {
    ".html" { return "text/html; charset=utf-8" }
    ".htm"  { return "text/html; charset=utf-8" }
    ".js"   { return "application/javascript; charset=utf-8" }
    ".mjs"  { return "application/javascript; charset=utf-8" }
    ".css"  { return "text/css; charset=utf-8" }
    ".json" { return "application/json; charset=utf-8" }
    ".svg"  { return "image/svg+xml; charset=utf-8" }
    ".png"  { return "image/png" }
    ".jpg"  { return "image/jpeg" }
    ".jpeg" { return "image/jpeg" }
    ".webp" { return "image/webp" }
    ".glb"  { return "model/gltf-binary" }
    ".gltf" { return "model/gltf+json; charset=utf-8" }
    ".bin"  { return "application/octet-stream" }
    ".ogg"  { return "audio/ogg" }
    ".wav"  { return "audio/wav" }
    ".mp3"  { return "audio/mpeg" }
    ".txt"  { return "text/plain; charset=utf-8" }
    default { return "application/octet-stream" }
  }
}

Clear-Content -Path $Log -ErrorAction SilentlyContinue
Write-Log "PERLA1 V61 - PowerShell static server"
Write-Log "Root: $Root"
Write-Log "Game: $Game"
Write-Log "Port: $Port"

if (!(Test-Path (Join-Path $Game "index.html"))) {
  Write-Log "ERRORE: index.html non trovato in $Game"
  Write-Host ""
  Write-Host "ERRORE: non trovo 01_GIOCO_PRONTO_LOCAL_TEST\index.html"
  Write-Host "Hai estratto completamente lo ZIP?"
  Write-Host ""
  Read-Host "Premi INVIO per chiudere"
  exit 1
}

# Kill previous local server on same port only if it is a PowerShell started by the user? Safer: do not kill.
# Instead fail clearly if the port is already in use.

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse("127.0.0.1"), $Port)

try {
  $listener.Start()
} catch {
  Write-Log "ERRORE: porta $Port non disponibile o bloccata. $($_.Exception.Message)"
  Write-Host ""
  Write-Host "ERRORE: la porta $Port non è disponibile."
  Write-Host "Chiudi eventuali vecchie finestre del server o riavvia il PC."
  Write-Host ""
  Read-Host "Premi INVIO per chiudere"
  exit 1
}

$url = "http://127.0.0.1:$Port/"
Write-Log "Server avviato su $url"
Write-Host ""
Write-Host "============================================================"
Write-Host " PERLA1 V61 - SERVER POWERSHELL"
Write-Host "============================================================"
Write-Host ""
Write-Host "Apro il browser su $url"
Write-Host "NON chiudere questa finestra mentre giochi."
Write-Host "Per fermare il server: CTRL + C oppure chiudi questa finestra."
Write-Host ""

Start-Process $url

while ($true) {
  $client = $listener.AcceptTcpClient()
  try {
    $stream = $client.GetStream()
    $buffer = New-Object byte[] 8192
    $read = $stream.Read($buffer, 0, $buffer.Length)
    if ($read -le 0) { continue }

    $requestText = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $read)
    $firstLine = ($requestText -split "`r?`n")[0]
    $parts = $firstLine -split " "
    if ($parts.Length -lt 2) { continue }

    $method = $parts[0]
    $rawPath = $parts[1]

    if ($method -ne "GET" -and $method -ne "HEAD") {
      $body = [System.Text.Encoding]::UTF8.GetBytes("Metodo non supportato")
      $header = "HTTP/1.1 405 Method Not Allowed`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
      $stream.Write([System.Text.Encoding]::ASCII.GetBytes($header), 0, $header.Length)
      if ($method -ne "HEAD") { $stream.Write($body, 0, $body.Length) }
      continue
    }

    $pathOnly = ($rawPath -split "\?")[0]
    $pathOnly = [System.Uri]::UnescapeDataString($pathOnly)
    if ($pathOnly -eq "/") { $pathOnly = "/index.html" }

    # Normalize and prevent traversal.
    $relative = $pathOnly.TrimStart("/").Replace("/", [System.IO.Path]::DirectorySeparatorChar)
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $Game $relative))
    $gameFull = [System.IO.Path]::GetFullPath($Game)

    if (!$fullPath.StartsWith($gameFull, [System.StringComparison]::OrdinalIgnoreCase)) {
      $body = [System.Text.Encoding]::UTF8.GetBytes("Forbidden")
      $header = "HTTP/1.1 403 Forbidden`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
      $stream.Write([System.Text.Encoding]::ASCII.GetBytes($header), 0, $header.Length)
      if ($method -ne "HEAD") { $stream.Write($body, 0, $body.Length) }
      continue
    }

    if (!(Test-Path $fullPath -PathType Leaf)) {
      $body = [System.Text.Encoding]::UTF8.GetBytes("Not found: $pathOnly")
      $header = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
      $stream.Write([System.Text.Encoding]::ASCII.GetBytes($header), 0, $header.Length)
      if ($method -ne "HEAD") { $stream.Write($body, 0, $body.Length) }
      Write-Log "404 $pathOnly"
      continue
    }

    $bytes = [System.IO.File]::ReadAllBytes($fullPath)
    $ctype = Get-ContentType $fullPath
    $headerText = "HTTP/1.1 200 OK`r`nContent-Type: $ctype`r`nContent-Length: $($bytes.Length)`r`nAccess-Control-Allow-Origin: *`r`nCache-Control: no-cache`r`nConnection: close`r`n`r`n"
    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headerText)
    $stream.Write($headerBytes, 0, $headerBytes.Length)
    if ($method -ne "HEAD") {
      $stream.Write($bytes, 0, $bytes.Length)
    }
  } catch {
    try { Write-Log "ERRORE richiesta: $($_.Exception.Message)" } catch {}
  } finally {
    try { $client.Close() } catch {}
  }
}
