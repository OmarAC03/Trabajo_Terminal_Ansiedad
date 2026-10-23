# Funciones comunes de los scripts de prueba por comando contra el backend
# LOCAL (prueba_sesiones.ps1, prueba_gad7.ps1). Se cargan con:
#   . "$PSScriptRoot\comun.ps1"
# Los tokens se obtienen solos con correo + contrasena (no se guardan).

$Base = 'http://localhost:3000'
$FirebaseKey = 'AIzaSyBT8DdafzQLg89kmcHQ-J5A3q1Ak6fQO3o'  # la misma API key publica del portal

function Leer-Pass($etiqueta) {
  $seg = Read-Host "Contrasena de $etiqueta" -AsSecureString
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($seg)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

function Obtener-Cuenta($etiqueta, [switch]$Opcional) {
  $email = Read-Host "Correo de $etiqueta$(if ($Opcional) { ' (Enter para omitir)' })"
  if ($Opcional -and [string]::IsNullOrWhiteSpace($email)) { return $null }
  $pass = Leer-Pass $etiqueta
  $body = @{ email = $email; password = $pass; returnSecureToken = $true } | ConvertTo-Json
  try {
    $r = Invoke-RestMethod -Method Post -ContentType 'application/json' -Body $body `
      -Uri "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$FirebaseKey"
  } catch {
    Write-Host "No se pudo iniciar sesion como $etiqueta ($email): $($_.ErrorDetails.Message)" -ForegroundColor Red
    exit 1
  }
  return @{ token = $r.idToken; uid = $r.localId; email = $email }
}

function Llamar($metodo, $ruta, $token, $cuerpo) {
  $params = @{ Method = $metodo; Uri = "$Base$ruta"; UseBasicParsing = $true
               Headers = @{ Authorization = "Bearer $token" } }
  if ($null -ne $cuerpo) {
    $params.ContentType = 'application/json; charset=utf-8'
    $params.Body = ($cuerpo | ConvertTo-Json -Depth 6 -Compress)
  }
  try {
    $r = Invoke-WebRequest @params
    return @{ status = [int]$r.StatusCode; texto = $r.Content }
  } catch {
    $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { -1 }
    return @{ status = $status; texto = $_.ErrorDetails.Message }
  }
}

$script:ok = 0; $script:fallas = 0
function Caso($nombre, $esperado, $resp, [scriptblock]$extra) {
  $bien = ($resp.status -eq $esperado)
  $detalle = ''
  if ($bien -and $extra) {
    $res = & $extra
    if ($res -ne $true) { $bien = $false; $detalle = " -> $res" }
  }
  if ($bien) { $script:ok++; Write-Host "[OK]    $nombre (HTTP $($resp.status))" -ForegroundColor Green }
  else {
    $script:fallas++
    Write-Host "[FALLA] $nombre (esperado $esperado, llego $($resp.status))$detalle" -ForegroundColor Red
    Write-Host "        $($resp.texto)"
  }
}

function Tiene($obj, $campo) { return ($obj.PSObject.Properties.Name -contains $campo) }

# En PowerShell 5.1, ConvertFrom-Json emite un arreglo JSON como UN solo objeto:
# @($texto | ConvertFrom-Json) da un arreglo de 1 elemento que contiene el
# arreglo real. Guardarlo primero en una variable y luego envolverlo lo aplana.
function Lista-Json($texto) { $p = $texto | ConvertFrom-Json; return $p }

# Nombre de la cuenta (tabla usuarios), para los candados de cuentas PRUEBA.
function Nombre-De($cuenta) {
  $r = Llamar 'GET' "/api/usuarios/$($cuenta.uid)" $cuenta.token $null
  if ($r.status -ne 200) { return $null }
  return ($r.texto | ConvertFrom-Json).nombre
}
