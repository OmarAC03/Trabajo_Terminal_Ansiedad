# Pruebas por comando de /api/sesiones (Fase M1a) y de la EVA post-medicion
# (Fase M2, seccion 9) contra el backend LOCAL.
# Uso: .\backend\pruebas\prueba_sesiones.ps1   (con el backend corriendo en otra ventana)
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

# -HaceMinutos: fecha_inicio en el pasado (para probar la ventana de la EVA).
function Sesion-Valida([int]$HaceMinutos = 0) {
  $serie = @()
  for ($t = 0; $t -le 235; $t += 5) {
    $serie += @{ t = $t; bpm = 70 + ($t % 7); spo2 = 97; hrv = 40 + ($t % 9) }
  }
  return @{
    fecha_inicio        = (Get-Date).AddMinutes(-$HaceMinutos).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    duracion_total_seg  = 240
    duracion_valida_seg = 200
    hrv_rmssd = 42.46; hrv_min = 38.5; hrv_max = 49.1
    bpm_promedio = 73.2; bpm_min = 70; bpm_max = 76
    spo2_promedio = 97.4; spo2_min = 96; spo2_max = 99
    indice_calidad = 0.833
    serie  = $serie
    origen = 'simulacion'
  }
}

Write-Host '--- Cuentas (las contrasenas no se muestran ni se guardan) ---'
$pac  = Obtener-Cuenta 'PACIENTE A (vinculado al especialista E)'
$esp  = Obtener-Cuenta 'ESPECIALISTA E (vinculado a A)'
$esp2 = Obtener-Cuenta 'ESPECIALISTA NO vinculado a A'
$adm  = Obtener-Cuenta 'ADMIN'
$pacB = Obtener-Cuenta 'PACIENTE B (otro paciente)' -Opcional
$A = $pac.uid
$creadas = @()

# Para la seccion 10: sesiones_7d de A ANTES de crear las sesiones de prueba.
$r = Llamar 'GET' '/api/pacientes' $esp.token $null
$filaAntes = if ($r.status -eq 200) { @(Lista-Json $r.texto) | Where-Object { $_.id -eq $A } } else { $null }
$sesiones7dAntes = if ($filaAntes -and (Tiene $filaAntes 'sesiones_7d')) { [int]$filaAntes.sesiones_7d } else { $null }
$creadasA = 0  # sesiones de A creadas por este script (todas dentro de los 7 dias)

Write-Host "`n--- 1. POST valido ---"
$r = Llamar 'POST' '/api/sesiones' $pac.token (Sesion-Valida)
Caso 'Paciente, sesion valida -> 201 sin indice_calidad' 201 $r {
  $d = ($r.texto | ConvertFrom-Json).data
  if (Tiene $d 'indice_calidad') { 'la respuesta trae indice_calidad' }
  elseif (-not $d.id) { 'la respuesta no trae id' } else { $true }
}
$sesionId = if ($r.status -eq 201) { ($r.texto | ConvertFrom-Json).data.id } else { $null }
if ($sesionId) { $creadas += $sesionId; $creadasA++; Write-Host "        id creado: $sesionId" }

Write-Host "`n--- 2. Campos no permitidos ---"
$s = Sesion-Valida; $s.paciente_id = $A
Caso 'Cuerpo con paciente_id -> 400' 400 (Llamar 'POST' '/api/sesiones' $pac.token $s)
$s = Sesion-Valida; $s.estado_ansiedad = 'Alta'
Caso 'Cuerpo con campo extra (estado_ansiedad) -> 400' 400 (Llamar 'POST' '/api/sesiones' $pac.token $s)

Write-Host "`n--- 3. Minimo de senal valida ---"
$s = Sesion-Valida; $s.duracion_valida_seg = 100
Caso 'duracion_valida_seg = 100 -> 400' 400 (Llamar 'POST' '/api/sesiones' $pac.token $s)

Write-Host "`n--- 4. Coherencia ---"
$s = Sesion-Valida; $s.bpm_promedio = 90
Caso 'bpm_promedio fuera de min-max -> 400' 400 (Llamar 'POST' '/api/sesiones' $pac.token $s)
$s = Sesion-Valida; $s.serie[1].t = 0
Caso 't de la serie no creciente -> 400' 400 (Llamar 'POST' '/api/sesiones' $pac.token $s)
$s = Sesion-Valida; $s.bpm_min = 69.5
Caso 'bpm_min decimal -> 400' 400 (Llamar 'POST' '/api/sesiones' $pac.token $s)

Write-Host "`n--- 5. POST con otros roles ---"
Caso 'POST como especialista -> 403' 403 (Llamar 'POST' '/api/sesiones' $esp.token (Sesion-Valida))
Caso 'POST como admin -> 403' 403 (Llamar 'POST' '/api/sesiones' $adm.token (Sesion-Valida))

Write-Host "`n--- 6. Lista como el propio paciente ---"
$r = Llamar 'GET' "/api/sesiones/$A" $pac.token $null
Caso 'Lista propia -> 200 sin indice_calidad ni serie' 200 $r {
  $lista = @(Lista-Json $r.texto)
  if ($lista.Count -eq 0) { return 'lista vacia' }
  foreach ($x in $lista) {
    if (Tiene $x 'indice_calidad') { return 'alguna fila trae indice_calidad' }
    if (Tiene $x 'serie') { return 'alguna fila trae serie' }
  }
  if ($sesionId -and -not ($lista.id -contains $sesionId)) { return 'no aparece la sesion creada' }
  $true
}

Write-Host "`n--- 7. Lista con otros roles ---"
$r = Llamar 'GET' "/api/sesiones/$A" $esp.token $null
Caso 'Lista como especialista vinculado -> 200 con indice_calidad' 200 $r {
  $lista = @(Lista-Json $r.texto)
  if ($lista.Count -eq 0) { return 'lista vacia' }
  foreach ($x in $lista) {
    if (-not (Tiene $x 'indice_calidad')) { return 'alguna fila no trae indice_calidad' }
  }
  if ($sesionId) {
    $fila = $lista | Where-Object { $_.id -eq $sesionId }
    if (-not $fila) { return 'no aparece la sesion creada' }
    # pg devuelve numeric como texto ("0.833"): se compara como numero.
    if ([double]$fila.indice_calidad -ne 0.833) { return "indice_calidad = $($fila.indice_calidad) (esperado 0.833)" }
  }
  $true
}
Caso 'Lista como especialista NO vinculado -> 403' 403 (Llamar 'GET' "/api/sesiones/$A" $esp2.token $null)
Caso 'Lista como admin -> 403' 403 (Llamar 'GET' "/api/sesiones/$A" $adm.token $null)

Write-Host "`n--- 8. Detalle ---"
if ($sesionId) {
  $r = Llamar 'GET' "/api/sesiones/$A/$sesionId" $pac.token $null
  Caso 'Detalle propio -> 200 con serie, sin indice_calidad' 200 $r {
    $d = $r.texto | ConvertFrom-Json
    if (Tiene $d 'indice_calidad') { 'trae indice_calidad' }
    elseif (@($d.serie).Count -ne 48) { "la serie trae $(@($d.serie).Count) puntos (esperados 48)" } else { $true }
  }
  $r = Llamar 'GET' "/api/sesiones/$A/$sesionId" $esp.token $null
  Caso 'Detalle como especialista vinculado -> 200 con indice_calidad' 200 $r {
    if (Tiene ($r.texto | ConvertFrom-Json) 'indice_calidad') { $true } else { 'no trae indice_calidad' }
  }
} else { Write-Host '        (se omiten: no se creo la sesion en el caso 1)' -ForegroundColor Yellow }
Caso 'Detalle con uuid inexistente -> 404' 404 (Llamar 'GET' "/api/sesiones/$A/$([guid]::NewGuid())" $pac.token $null)
Caso 'Detalle con id mal formado -> 400' 400 (Llamar 'GET' "/api/sesiones/$A/abc" $pac.token $null)

Write-Host "`n--- 9. EVA post-medicion (Fase M2) ---"
# Sesion nueva solo para la EVA (la del caso 1 se queda SIN EVA para el ultimo caso).
$r = Llamar 'POST' '/api/sesiones' $pac.token (Sesion-Valida)
$idEva = if ($r.status -eq 201) { ($r.texto | ConvertFrom-Json).data.id } else { $null }
if ($idEva) {
  $creadas += $idEva; $creadasA++
  $urlEva = "/api/sesiones/$idEva/eva"
  Caso 'EVA con valor 101 -> 400' 400 (Llamar 'POST' $urlEva $pac.token @{ valor = 101 })
  Caso 'EVA con valor decimal -> 400' 400 (Llamar 'POST' $urlEva $pac.token @{ valor = 50.5 })
  Caso 'EVA con contexto fuera de la lista -> 400' 400 (Llamar 'POST' $urlEva $pac.token @{ valor = 50; contexto = 'trabajando' })
  Caso 'EVA con campo extra -> 400' 400 (Llamar 'POST' $urlEva $pac.token @{ valor = 50; nota = 'x' })
  Caso 'EVA como especialista -> 403' 403 (Llamar 'POST' $urlEva $esp.token @{ valor = 50 })
  Caso 'EVA valida -> 201' 201 (Llamar 'POST' $urlEva $pac.token @{ valor = 63; contexto = 'antes_examen' })
  Caso 'EVA por segunda vez (no editable) -> 409' 409 (Llamar 'POST' $urlEva $pac.token @{ valor = 20 })

  $r = Llamar 'GET' "/api/sesiones/$A" $esp.token $null
  Caso 'Lista del especialista trae la EVA (63, antes_examen)' 200 $r {
    $fila = @(Lista-Json $r.texto) | Where-Object { $_.id -eq $idEva }
    if (-not $fila) { return 'no aparece la sesion con EVA' }
    if ($fila.eva_valor -ne 63 -or $fila.eva_contexto -ne 'antes_examen' -or -not $fila.eva_fecha) {
      return "eva_valor=$($fila.eva_valor) eva_contexto=$($fila.eva_contexto) eva_fecha=$($fila.eva_fecha)"
    }
    $true
  }
  $r = Llamar 'GET' "/api/sesiones/$A/$idEva" $esp.token $null
  Caso 'Detalle del especialista trae la EVA' 200 $r {
    $d = $r.texto | ConvertFrom-Json
    if ($d.eva_valor -eq 63 -and $d.eva_contexto -eq 'antes_examen') { $true } else { "eva_valor=$($d.eva_valor) eva_contexto=$($d.eva_contexto)" }
  }
} else { Write-Host "        No se pudo crear la sesion para la EVA (HTTP $($r.status)): $($r.texto)" -ForegroundColor Yellow }

if ($sesionId) {
  $r = Llamar 'GET' "/api/sesiones/$A/$sesionId" $esp.token $null
  Caso 'Sesion sin EVA -> eva_valor null (omitida = sin fila)' 200 $r {
    $d = $r.texto | ConvertFrom-Json
    if (-not (Tiene $d 'eva_valor')) { 'no trae el campo eva_valor' }
    elseif ($null -ne $d.eva_valor) { "eva_valor=$($d.eva_valor) (esperado null)" } else { $true }
  }
}
Caso 'EVA sobre sesion inexistente -> 404' 404 (Llamar 'POST' "/api/sesiones/$([guid]::NewGuid())/eva" $pac.token @{ valor = 50 })
Caso 'EVA con id mal formado -> 400' 400 (Llamar 'POST' '/api/sesiones/abc/eva' $pac.token @{ valor = 50 })

# Sesion que empezo hace 30 min y duro 4 min: termino hace 26 min (> 15).
$r = Llamar 'POST' '/api/sesiones' $pac.token (Sesion-Valida -HaceMinutos 30)
if ($r.status -eq 201) {
  $idVieja = ($r.texto | ConvertFrom-Json).data.id; $creadas += $idVieja; $creadasA++
  Caso 'EVA fuera de la ventana de 15 min -> 400' 400 (Llamar 'POST' "/api/sesiones/$idVieja/eva" $pac.token @{ valor = 50 })
} else { Write-Host "        No se pudo crear la sesion de hace 30 min (HTTP $($r.status)): $($r.texto)" -ForegroundColor Yellow }

if ($pacB) {
  $r = Llamar 'POST' '/api/sesiones' $pacB.token (Sesion-Valida)
  if ($r.status -eq 201) {
    $idB = ($r.texto | ConvertFrom-Json).data.id; $creadas += $idB
    Caso 'Sesion de B pedida bajo el id de A -> 404' 404 (Llamar 'GET' "/api/sesiones/$A/$idB" $pac.token $null)
    Caso 'EVA de A sobre la sesion de B -> 404' 404 (Llamar 'POST' "/api/sesiones/$idB/eva" $pac.token @{ valor = 50 })
  } else { Write-Host "        No se pudo crear la sesion de B (HTTP $($r.status)): $($r.texto)" -ForegroundColor Yellow }
}

Write-Host "`n--- 10. Actividad de sesiones en GET /api/pacientes (Dashboard del portal) ---"
$r = Llamar 'GET' '/api/pacientes' $esp.token $null
$filas = if ($r.status -eq 200) { @(Lista-Json $r.texto) } else { @() }
Caso 'Especialista -> 200; cada fila trae los campos nuevos y los viejos' 200 $r {
  if ($filas.Count -eq 0) { return 'lista vacia' }
  foreach ($x in $filas) {
    foreach ($c in 'ultima_sesion', 'ultima_sesion_origen', 'sesiones_7d', 'ultimo_estado', 'ultima_lectura') {
      if (-not (Tiene $x $c)) { return "la fila de $($x.nombre) no trae $c" }
    }
    if ($x.sesiones_7d -is [string]) { return "sesiones_7d llega como texto ('$($x.sesiones_7d)')" }
  }
  $true
}
$filaA = $filas | Where-Object { $_.id -eq $A }
$r2 = Llamar 'GET' "/api/sesiones/${A}?limite=1" $esp.token $null
Caso 'ultima_sesion de A = fecha_inicio de su sesion mas reciente' 200 $r2 {
  if (-not $filaA) { return 'A no aparece en la lista del especialista' }
  $ultima = @(Lista-Json $r2.texto)[0]
  if (-not $ultima) { return 'A no tiene sesiones' }
  if ([DateTime]::Parse($filaA.ultima_sesion) -ne [DateTime]::Parse($ultima.fecha_inicio)) {
    return "ultima_sesion=$($filaA.ultima_sesion) fecha_inicio=$($ultima.fecha_inicio)"
  }
  if ($filaA.ultima_sesion_origen -ne $ultima.origen) { return "ultima_sesion_origen=$($filaA.ultima_sesion_origen) origen=$($ultima.origen)" }
  $true
}
Caso "sesiones_7d de A subio en $creadasA (las sesiones de este script)" 200 $r {
  if (-not $filaA) { return 'A no aparece en la lista' }
  if ($null -eq $sesiones7dAntes) { return 'no se pudo leer sesiones_7d antes de crear las sesiones (backend sin el cambio?)' }
  if ([int]$filaA.sesiones_7d -ne $sesiones7dAntes + $creadasA) {
    return "antes=$sesiones7dAntes, creadas=$creadasA, ahora=$($filaA.sesiones_7d)"
  }
  $true
}
Caso 'Coherencia: sin sesiones -> null/null/0; con sesiones -> origen no null' 200 $r {
  foreach ($x in $filas) {
    if ($null -eq $x.ultima_sesion) {
      if ($null -ne $x.ultima_sesion_origen -or [int]$x.sesiones_7d -ne 0) {
        return "$($x.nombre): sin ultima_sesion pero origen=$($x.ultima_sesion_origen), sesiones_7d=$($x.sesiones_7d)"
      }
    } elseif ($null -eq $x.ultima_sesion_origen) { return "$($x.nombre): con ultima_sesion pero sin origen" }
  }
  $true
}
$sinSesiones = @($filas | Where-Object { $null -eq $_.ultima_sesion })
Write-Host "        Pacientes del especialista sin sesiones: $($sinSesiones.Count) (si es 0, el caso null/null/0 no se ejercito con datos reales)"
Caso 'GET /api/pacientes como paciente -> 403' 403 (Llamar 'GET' '/api/pacientes' $pac.token $null)
Caso 'GET /api/pacientes como admin -> 403' 403 (Llamar 'GET' '/api/pacientes' $adm.token $null)

Write-Host "`n=== Resultado: $script:ok OK, $script:fallas FALLA ===" -ForegroundColor $(if ($script:fallas -eq 0) { 'Green' } else { 'Red' })
if ($creadas.Count -gt 0) {
  Write-Host "Sesiones de prueba creadas en Supabase (origen 'simulacion'): $($creadas -join ', ')"
}
