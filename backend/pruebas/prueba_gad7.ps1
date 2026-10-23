# Pruebas por comando del GAD-7 (Fase M5a, paso 3) contra el backend LOCAL:
# POST /api/gad7, GET /api/gad7/:pacienteId y ultimo_gad7_* en /api/pacientes.
# Uso: .\backend\pruebas\prueba_gad7.ps1   (con el backend corriendo en otra ventana)
#
# Escribe un GAD-7: solo en las cuentas de prueba. El script se niega si
#   A no es "PRUEBA - Test M3", E no es su especialista "PRUEBA ..." o
#   C no es un paciente "PRUEBA ..." SIN especialista.
# Antes de correrlo, A debe tener la semilla y hoy le debe tocar responder:
#   node pruebas/semilla_gad7.js limpiar   (si ya tiene GAD-7)  -> pegar en Supabase
#   node pruebas/semilla_gad7.js sql                            -> pegar en Supabase
# Para volver a correrlo (A ya respondio hoy): limpiar -> sql -> script.

# $Base, Leer-Pass, Obtener-Cuenta, Llamar, Caso, Tiene, Lista-Json, Nombre-De
. "$PSScriptRoot\comun.ps1"

Write-Host '--- Cuentas (las contrasenas no se muestran ni se guardan) ---'
$pac = Obtener-Cuenta 'PACIENTE A ("PRUEBA - Test M3", vinculado a E)'
$esp = Obtener-Cuenta 'ESPECIALISTA E (de A)'
$sinV = Obtener-Cuenta 'PACIENTE C ("PRUEBA - Sin vinculo")'
$esp2 = Obtener-Cuenta 'ESPECIALISTA F, NO vinculado a A' -Opcional
$adm = Obtener-Cuenta 'ADMIN' -Opcional
$A = $pac.uid

# --- Candados: solo cuentas PRUEBA, y C de verdad sin especialista ---
$nombreA = Nombre-De $pac
$nombreE = Nombre-De $esp
$nombreC = Nombre-De $sinV
$vincC = Llamar 'GET' '/api/vinculacion' $sinV.token $null
$cSinVinculo = ($vincC.status -eq 200) -and -not (($vincC.texto | ConvertFrom-Json).vinculado)
if ($nombreA -ne 'PRUEBA - Test M3' -or -not ("$nombreE".StartsWith('PRUEBA')) -or
    -not ("$nombreC".StartsWith('PRUEBA')) -or -not $cSinVinculo) {
  Write-Host "Alto: A debe ser 'PRUEBA - Test M3' (es '$nombreA'), E un especialista 'PRUEBA ...' (es '$nombreE') y C un paciente 'PRUEBA ...' sin especialista (es '$nombreC', sin vinculo: $cSinVinculo). No se escribio nada." -ForegroundColor Red
  exit 1
}

# --- Regla de oro: nada del resultado en lo que recibe un paciente ---
$Prohibidas = @('puntaje', 'severidad', 'item', 'dificultad', 'valorar', 'version',
                'minima', 'leve', 'moderada', 'grave', 'normal', 'elevados', 'altos')
$script:paraPaciente = @()
function Sin-Resultado($texto) {
  $t = "$texto".ToLower()
  foreach ($p in $Prohibidas) {
    if ($t.Contains('"' + $p)) { return "el paciente recibio '$p': $texto" }
  }
  $true
}
# Guarda lo que recibio un paciente (para la revision final) y lo revisa ya.
function De-Paciente($resp) { $script:paraPaciente += $resp.texto; Sin-Resultado $resp.texto }

$CamposEstado = @('toca', 'proxima_fecha', 'dias_restantes', 'ultima_respuesta', 'intervalo_dias', 'vinculado')
function Estado-Exacto($estado) {
  $campos = @($estado.PSObject.Properties.Name)
  $faltan = $CamposEstado | Where-Object { $campos -notcontains $_ }
  $sobran = $campos | Where-Object { $CamposEstado -notcontains $_ }
  if ($faltan -or $sobran) { return "estado con campos de mas o de menos (faltan: $faltan; sobran: $sobran)" }
  $true
}

$hoy = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow, 'Central Standard Time (Mexico)').Date
$en14 = $hoy.AddDays(14).ToString('yyyy-MM-dd')
$valido = @{ items = @(1, 0, 2, 1, 0, 1, 0); dificultad = 1 }   # puntaje 5 -> leve

# --- Precondicion: a A le toca responder hoy ---
$pre = Llamar 'GET' "/api/gad7/$A" $pac.token $null
if ($pre.status -ne 200 -or -not (($pre.texto | ConvertFrom-Json).estado.toca)) {
  Write-Host "Alto: a A no le toca responder hoy (HTTP $($pre.status): $($pre.texto)). Corre 'limpiar' y 'sql' de semilla_gad7.js en Supabase." -ForegroundColor Red
  exit 1
}

Write-Host "`n--- 1-2. Lectura antes de responder ---"
$r = Llamar 'GET' "/api/gad7/$A" $pac.token $null
Caso '1. GET A como A: solo estado, toca y vinculado' 200 $r {
  $v = $r.texto | ConvertFrom-Json
  if ((@($v.PSObject.Properties.Name) -join ',') -ne 'estado') { return "trae $(@($v.PSObject.Properties.Name) -join ',')" }
  $e = Estado-Exacto $v.estado; if ($e -ne $true) { return $e }
  if (-not $v.estado.toca -or -not $v.estado.vinculado) { return "toca=$($v.estado.toca) vinculado=$($v.estado.vinculado)" }
  De-Paciente $r
}

$r = Llamar 'GET' "/api/gad7/$A" $esp.token $null
Caso '2. GET A como E: historial de la semilla (16/12/8/4) en orden' 200 $r {
  $v = $r.texto | ConvertFrom-Json
  $resp = @($v.respuestas)
  if ($resp.Count -ne 4) { return "$($resp.Count) respuestas (esperaba las 4 de la semilla)" }
  $obtenido = ($resp | ForEach-Object { "$($_.puntaje)/$($_.severidad)/$($_.valorar)" }) -join ' '
  $esperado = '4/minima/False 8/leve/False 12/moderada/True 16/grave/True'
  if ($obtenido -ne $esperado) { return "obtenido '$obtenido', esperado '$esperado'" }
  if (@($resp[0].items).Count -ne 7 -or $resp[0].version -ne 'gad7-es-v1') { return 'faltan items o version' }
  $true
}

Write-Host "`n--- 3-5. Quien NO puede responder, y validacion (nada se guarda) ---"
Caso '3a. POST como E' 403 (Llamar 'POST' '/api/gad7' $esp.token $valido)
if ($adm) { Caso '3b. POST como ADMIN' 403 (Llamar 'POST' '/api/gad7' $adm.token $valido) }

$malos = [ordered]@{
  '6 items'         = @{ items = @(1, 0, 2, 1, 0, 1) }
  'item = 4'        = @{ items = @(1, 0, 2, 4, 0, 1, 0) }
  'item = "1"'      = @{ items = @(1, 0, 2, '1', 0, 1, 0) }
  'con puntaje'     = @{ items = $valido.items; puntaje = 5 }
  'con paciente_id' = @{ items = $valido.items; paciente_id = $A }
  'con version'     = @{ items = $valido.items; version = 'gad7-es-v1' }
  'dificultad = 5'  = @{ items = $valido.items; dificultad = 5 }
  'cuerpo vacio'    = @{}
}
# (Los 400 nombran el campo que mando el propio paciente, p. ej. "items[3]":
# no es su resultado, asi que no entran a la revision de la regla de oro.)
foreach ($k in $malos.Keys) {
  Caso "4. POST A $k" 400 (Llamar 'POST' '/api/gad7' $pac.token $malos[$k])
}

$r = Llamar 'POST' '/api/gad7' $sinV.token $valido
Caso '5. POST como C (sin vinculo)' 403 $r { De-Paciente $r }

Write-Host "`n--- 6-8. Dos envios simultaneos: uno 201 y el otro 409 ---"
Add-Type -AssemblyName System.Net.Http
$cli = New-Object System.Net.Http.HttpClient
$json = $valido | ConvertTo-Json -Compress
function Peticion-Gad7 {
  $m = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, "$Base/api/gad7")
  $m.Headers.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue('Bearer', $pac.token)
  $m.Content = New-Object System.Net.Http.StringContent($json, [Text.Encoding]::UTF8, 'application/json')
  return $m
}
$p1 = Peticion-Gad7; $p2 = Peticion-Gad7
$t1 = $cli.SendAsync($p1); $t2 = $cli.SendAsync($p2)   # se lanzan los dos antes de esperar
[Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($t1, $t2))
$res = @($t1.Result, $t2.Result) | ForEach-Object {
  @{ status = [int]$_.StatusCode; texto = $_.Content.ReadAsStringAsync().Result }
}
$cli.Dispose()
$creada = $res | Where-Object { $_.status -eq 201 }
$rechazo = $res | Where-Object { $_.status -eq 409 }
$carrera = @{ status = $(if (@($creada).Count -eq 1 -and @($rechazo).Count -eq 1) { 1 } else { 0 }); texto = ($res | ForEach-Object { "$($_.status): $($_.texto)" }) -join ' | ' }
Caso '6. Carrera: exactamente un 201 y un 409' 1 $carrera { $script:paraPaciente += $res.texto; $true }

$idCreada = $null
if (@($creada).Count -eq 1) {
  $c = @{ status = 201; texto = $creada.texto }
  Caso '7. El 201: id, fecha y estado (toca=false, 14 dias)' 201 $c {
    $d = ($c.texto | ConvertFrom-Json).data
    $script:idCreada = $d.id
    if ((@($d.PSObject.Properties.Name) -join ',') -ne 'id,fecha_respuesta,estado') { return "data trae $(@($d.PSObject.Properties.Name) -join ',')" }
    $e = Estado-Exacto $d.estado; if ($e -ne $true) { return $e }
    if ($d.estado.toca -or $d.estado.dias_restantes -ne 14 -or $d.estado.proxima_fecha -ne $en14) {
      return "toca=$($d.estado.toca) dias=$($d.estado.dias_restantes) proxima=$($d.estado.proxima_fecha) (esperado $en14)"
    }
    De-Paciente $c
  }
}

$r = Llamar 'POST' '/api/gad7' $pac.token $valido
Caso '8. POST A otra vez: 409 con la fecha' 409 $r {
  if (-not "$($r.texto)".Contains($en14)) { return "el mensaje no trae la fecha $en14" }
  De-Paciente $r
}

Write-Host "`n--- 9-13. Lecturas despues de responder ---"
$r = Llamar 'GET' "/api/gad7/$A" $pac.token $null
Caso '9. GET A como A: ya no le toca' 200 $r {
  $e = ($r.texto | ConvertFrom-Json).estado
  if ($e.toca -or $e.proxima_fecha -ne $en14 -or -not $e.ultima_respuesta) { return "toca=$($e.toca) proxima=$($e.proxima_fecha)" }
  De-Paciente $r
}

$r = Llamar 'GET' "/api/gad7/$A" $esp.token $null
Caso '10. GET A como E: 5 respuestas, la nueva primero' 200 $r {
  $resp = @(($r.texto | ConvertFrom-Json).respuestas)
  if ($resp.Count -ne 5) { return "$($resp.Count) respuestas (esperaba 5: una sola de la carrera)" }
  if ($idCreada -and $resp[0].id -ne $idCreada) { return "la primera es $($resp[0].id), no la nueva $idCreada" }
  if ($resp[0].puntaje -ne 5 -or $resp[0].severidad -ne 'leve' -or $resp[0].dificultad -ne 1) {
    return "nueva: puntaje=$($resp[0].puntaje) severidad=$($resp[0].severidad) dificultad=$($resp[0].dificultad)"
  }
  $true
}

Caso '11a. GET A como C (otro paciente)' 403 (Llamar 'GET' "/api/gad7/$A" $sinV.token $null)
if ($esp2) { Caso '11b. GET A como F (especialista sin vinculo)' 403 (Llamar 'GET' "/api/gad7/$A" $esp2.token $null) }
if ($adm) { Caso '11c. GET A como ADMIN' 403 (Llamar 'GET' "/api/gad7/$A" $adm.token $null) }

$r = Llamar 'GET' "/api/gad7/$($sinV.uid)" $sinV.token $null
Caso '12. GET C como C: vinculado=false' 200 $r {
  $e = ($r.texto | ConvertFrom-Json).estado
  if ($e.vinculado -ne $false) { return "vinculado=$($e.vinculado)" }
  De-Paciente $r
}

$r = Llamar 'GET' '/api/pacientes' $esp.token $null
Caso '13. /api/pacientes como E: ultimo_gad7_* de A es el de hoy' 200 $r {
  $filas = Lista-Json $r.texto
  $filaA = @($filas) | Where-Object { $_.id -eq $A }
  if (-not $filaA) { return 'A no aparece en la lista' }
  if ($filaA.ultimo_gad7_puntaje -ne 5 -or $filaA.ultimo_gad7_severidad -ne 'leve' -or $filaA.ultimo_gad7_valorar -ne $false -or $filaA.gad7_toca -ne $false) {
    return "puntaje=$($filaA.ultimo_gad7_puntaje) severidad=$($filaA.ultimo_gad7_severidad) valorar=$($filaA.ultimo_gad7_valorar) toca=$($filaA.gad7_toca)"
  }
  $true
}

Write-Host "`n--- 14. Regla de oro sobre TODO lo que recibio un paciente ---"
$malas = @($script:paraPaciente | ForEach-Object { Sin-Resultado $_ } | Where-Object { $_ -ne $true })
$regla = @{ status = $(if ($malas.Count -eq 0) { 1 } else { 0 }); texto = ($malas -join ' | ') }
Caso "14. Ninguna de las $($script:paraPaciente.Count) respuestas al paciente trae puntaje/severidad/items" 1 $regla

Write-Host "`n=== Resultado: $script:ok OK, $script:fallas FALLA ===" -ForegroundColor $(if ($script:fallas -eq 0) { 'Green' } else { 'Red' })
if ($idCreada) { Write-Host "GAD-7 de prueba creado en Supabase para A: $idCreada" }
Write-Host "Para volver a correrlo: node pruebas/semilla_gad7.js limpiar -> sql (en Supabase) -> script."
