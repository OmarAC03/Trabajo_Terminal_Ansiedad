# Funciones comunes de los scripts de prueba por comando contra el backend
# LOCAL (prueba_sesiones.ps1, prueba_gad7.ps1). Se cargan con:
#   . "$PSScriptRoot\comun.ps1"
# Los tokens se obtienen solos con correo + contrasena (no se guardan).

# Por defecto el backend local; contra produccion:
#   $env:TT_BASE_URL = 'https://tt-ansiedad-backend.onrender.com'
$Base = if ($env:TT_BASE_URL) { $env:TT_BASE_URL.TrimEnd('/') } else { 'http://localhost:3000' }
$FirebaseKey = 'AIzaSyBT8DdafzQLg89kmcHQ-J5A3q1Ak6fQO3o'  # la misma API key publica del portal

# Cuerpo de la respuesta de un error HTTP (se le pasa el $_ del catch). En
# Windows PowerShell 5.1, ErrorDetails.Message puede llegar nulo (pasa con las
# respuestas de Firebase); entonces se lee el cuerpo de Exception.Response.
function Cuerpo-Error($err) {
  if ($err.ErrorDetails -and $err.ErrorDetails.Message) { return $err.ErrorDetails.Message }
  $resp = $err.Exception.Response
  if ($resp) {
    try {
      $flujo = $resp.GetResponseStream()
      if ($flujo.CanSeek) { $flujo.Position = 0 }
      $texto = (New-Object System.IO.StreamReader($flujo)).ReadToEnd()
      if ($texto) { return $texto }
    } catch { }
  }
  return "$($err.Exception.Message)"
}

function Leer-Pass($etiqueta) {
  $seg = Read-Host "Contrasena de $etiqueta" -AsSecureString
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($seg)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

# -ConPass: devuelve tambien la contrasena (solo en memoria), para los scripts
# que necesitan volver a iniciar sesion (prueba_cuentas.ps1).
function Obtener-Cuenta($etiqueta, [switch]$Opcional, [switch]$ConPass) {
  $email = Read-Host "Correo de $etiqueta$(if ($Opcional) { ' (Enter para omitir)' })"
  if ($Opcional -and [string]::IsNullOrWhiteSpace($email)) { return $null }
  $pass = Leer-Pass $etiqueta
  $body = @{ email = $email; password = $pass; returnSecureToken = $true } | ConvertTo-Json
  try {
    $r = Invoke-RestMethod -Method Post -ContentType 'application/json' -Body $body `
      -Uri "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$FirebaseKey"
  } catch {
    Write-Host "No se pudo iniciar sesion como $etiqueta ($email): $(Cuerpo-Error $_)" -ForegroundColor Red
    exit 1
  }
  $cuenta = @{ token = $r.idToken; uid = $r.localId; email = $email }
  if ($ConPass) { $cuenta.pass = $pass }
  return $cuenta
}

# Inicio de sesion en Firebase sin salir del script si falla: devuelve
# @{ ok; token; error } con el codigo de error de Firebase (p. ej. USER_DISABLED).
function Login-Firebase($email, $pass) {
  $body = @{ email = $email; password = $pass; returnSecureToken = $true } | ConvertTo-Json
  try {
    $r = Invoke-RestMethod -Method Post -ContentType 'application/json' -Body $body `
      -Uri "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$FirebaseKey"
    return @{ ok = $true; token = $r.idToken; error = $null }
  } catch {
    $texto = Cuerpo-Error $_
    $codigo = $null
    if ($texto) { try { $codigo = ($texto | ConvertFrom-Json -ErrorAction Stop).error.message } catch { } }
    if (-not $codigo) { $codigo = $texto }
    return @{ ok = $false; token = $null; error = $codigo }
  }
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
    return @{ status = $status; texto = (Cuerpo-Error $_) }
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

# Precondicion (Bloque 1, paso 2): sin el consentimiento vigente, las rutas de
# captura dan 403 consentimiento_requerido y fallaria casi todo el script.
# Lo da el SQL de las semillas (semilla_m3.js / semilla_gad7.js sql).
function Exigir-Consentimiento($cuenta, $etiqueta) {
  $r = Llamar 'GET' '/api/consentimiento' $cuenta.token $null
  if ($r.status -ne 200 -or -not (($r.texto | ConvertFrom-Json).aceptado)) {
    Write-Host "Alto: $etiqueta no tiene el consentimiento vigente (HTTP $($r.status): $($r.texto)). Pega en Supabase el SQL de 'node pruebas/semilla_m3.js sql' o 'semilla_gad7.js sql' (incluye el consentimiento de las cuentas PRUEBA). No se escribio nada." -ForegroundColor Red
    exit 1
  }
}
