# Pruebas por comando del Bloque 1 (cuentas) contra el backend LOCAL.
#   Seccion 1 - Suspender / reactivar (RF-33).
#   Seccion 2 - Consentimiento (RN-01, RN-02, RNF-06). Crea pacientes
#               desechables "PRUEBA - Desechable ..." (@example.com).
# Uso: .\backend\pruebas\prueba_cuentas.ps1   (con el backend corriendo en otra ventana)
#
# SUSPENDE CUENTAS DE VERDAD (en la base y en Firebase): solo las de prueba.
# El script se niega si C no es un paciente "PRUEBA ..." sin especialista o
# si E no es un especialista "PRUEBA ...". Al final (aunque algo falle)
# reactiva a C y a E y deja a C sin especialista.

# $Base, Obtener-Cuenta, Login-Firebase, Llamar, Caso, Tiene, Lista-Json, Nombre-De
. "$PSScriptRoot\comun.ps1"

Write-Host '--- Cuentas (las contrasenas no se muestran ni se guardan) ---'
$adm = Obtener-Cuenta 'ADMIN'
$sinV = Obtener-Cuenta 'PACIENTE C ("PRUEBA - Sin vinculo")' -ConPass
$esp = Obtener-Cuenta 'ESPECIALISTA E ("PRUEBA ...")'
$C = $sinV.uid
$E = $esp.uid

# --- Candados: solo cuentas PRUEBA, C sin especialista, y el admin es admin ---
$nombreC = Nombre-De $sinV
$perfilE = Llamar 'GET' "/api/usuarios/$E" $esp.token $null
$perfilA = Llamar 'GET' "/api/usuarios/$($adm.uid)" $adm.token $null
$vincC = Llamar 'GET' '/api/vinculacion' $sinV.token $null
$cSinVinculo = ($vincC.status -eq 200) -and -not (($vincC.texto | ConvertFrom-Json).vinculado)
$e = if ($perfilE.status -eq 200) { $perfilE.texto | ConvertFrom-Json } else { $null }
$esAdmin = ($perfilA.status -eq 200) -and (($perfilA.texto | ConvertFrom-Json).rol -eq 'admin')
if (-not "$nombreC".StartsWith('PRUEBA') -or -not $cSinVinculo -or -not $e -or
    -not "$($e.nombre)".StartsWith('PRUEBA') -or $e.rol -ne 'especialista' -or -not $esAdmin) {
  Write-Host "Alto: C debe ser un paciente 'PRUEBA ...' sin especialista (es '$nombreC', sin vinculo: $cSinVinculo), E un especialista 'PRUEBA ...' (es '$($e.nombre)') y ADMIN un admin ($esAdmin). No se cambio nada." -ForegroundColor Red
  exit 1
}

# $true si la fila de /api/admin/usuarios trae el estado esperado.
function Estado-Es($resp, $estado) {
  $f = $resp.texto | ConvertFrom-Json
  if ($f.estado -ne $estado) { return "estado '$($f.estado)', se esperaba '$estado'" }
  $true
}
# $true si el error trae el codigo esperado (p. ej. cuenta_suspendida).
function Codigo-Es($resp, $codigo) {
  $f = $resp.texto | ConvertFrom-Json
  if ($f.codigo -ne $codigo) { return "codigo '$($f.codigo)', se esperaba '$codigo'" }
  $true
}
# Adapta el resultado de Login-Firebase al formato de Caso (status 1 = paso lo esperado).
function Como-Caso($cumple, $texto) { return @{ status = [int][bool]$cumple; texto = $texto } }

# Version vigente del aviso y el consentimiento (backend/consentimiento.js).
$Version = @{ version_aviso = 'privacidad-v0-borrador'; version_consentimiento = 'consentimiento-v0-borrador' }

# Pacientes desechables "PRUEBA - Desechable ...": cuenta nueva en Firebase
# (correo @example.com, contrasena aleatoria) + POST /api/usuarios, con o sin
# consentimiento. Se anotan en $script:desechables para la limpieza final.
$script:desechables = @()
$sello = (Get-Date).ToString('yyyyMMddHHmmss')
function Crear-Desechable($etiqueta, $consentimiento) {
  $email = "prueba.desechable.$sello.$($etiqueta.ToLower())@example.com"
  $pass = [guid]::NewGuid().ToString('N')
  $body = @{ email = $email; password = $pass; returnSecureToken = $true } | ConvertTo-Json
  $r = Invoke-RestMethod -Method Post -ContentType 'application/json' -Body $body `
    -Uri "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$FirebaseKey"
  $cuenta = @{ token = $r.idToken; uid = $r.localId; email = $email; pass = $pass }
  $script:desechables += $cuenta
  $cuerpo = @{ id = $cuenta.uid; nombre = "PRUEBA - Desechable $etiqueta $sello"; email = $email; rol = 'paciente' }
  if ($null -ne $consentimiento) { $cuerpo.consentimiento = $consentimiento }
  $cuenta.registro = Llamar 'POST' '/api/usuarios' $cuenta.token $cuerpo
  return $cuenta
}

try {
  Write-Host "`n=== 1. Suspender / reactivar ==="

  Caso '1.1 Un paciente no puede suspender (ruta de admin)' 403 (Llamar 'POST' "/api/admin/usuarios/$C/suspender" $sinV.token $null)
  Caso '1.2 Un especialista no puede suspender' 403 (Llamar 'POST' "/api/admin/usuarios/$C/suspender" $esp.token $null)
  Caso '1.3 El admin no puede suspenderse a si mismo' 409 (Llamar 'POST' "/api/admin/usuarios/$($adm.uid)/suspender" $adm.token $null)
  Caso '1.4 Suspender una cuenta que no existe' 404 (Llamar 'POST' '/api/admin/usuarios/no-existe-uid/suspender' $adm.token $null)

  $r = Llamar 'POST' "/api/admin/usuarios/$C/suspender" $adm.token $null
  Caso '1.5 El admin suspende a C' 200 $r { Estado-Es $r 'suspendida' }

  # El token de C sigue vigente en Firebase, pero el backend ya lo rechaza.
  $r = Llamar 'GET' '/api/vinculacion' $sinV.token $null
  Caso '1.6 C con su token vigente: 403 cuenta_suspendida' 403 $r { Codigo-Es $r 'cuenta_suspendida' }
  $r = Llamar 'GET' "/api/sesiones/$C" $sinV.token $null
  Caso '1.7 Tambien en rutas clinicas' 403 $r { Codigo-Es $r 'cuenta_suspendida' }

  $r = Llamar 'POST' "/api/admin/usuarios/$C/suspender" $adm.token $null
  Caso '1.8 Suspender otra vez: idempotente' 200 $r { Estado-Es $r 'suspendida' }

  $r = Llamar 'GET' '/api/admin/usuarios' $adm.token $null
  Caso '1.9 La lista del admin muestra a C suspendida' 200 $r {
    $fila = (Lista-Json $r.texto) | Where-Object { $_.id -eq $C }
    if ($fila.estado -ne 'suspendida') { return "C aparece como '$($fila.estado)'" }
    $true
  }

  # Firebase: con la contrasena correcta debe negar el inicio de sesion.
  $l = Login-Firebase $sinV.email $sinV.pass
  Caso '1.10 C no puede iniciar sesion (Firebase USER_DISABLED)' 1 (Como-Caso ($l.error -eq 'USER_DISABLED') "Firebase devolvio '$($l.error)'")
  # Decision 2 de la Fase C: que devuelve Firebase con una contrasena INCORRECTA
  # en una cuenta desactivada. Si tambien dice USER_DISABLED, mostrar "cuenta
  # suspendida" en el login revelaria que correos existen -> se queda el
  # mensaje generico. Solo se informa.
  $lMala = Login-Firebase $sinV.email ('incorrecta-' + [guid]::NewGuid().ToString('N'))
  Write-Host "[INFO]  Contrasena incorrecta en cuenta desactivada -> Firebase: '$($lMala.error)'" -ForegroundColor Cyan

  # Especialista suspendido: su codigo de vinculacion deja de funcionar.
  $r = Llamar 'POST' "/api/admin/usuarios/$E/suspender" $adm.token $null
  Caso '1.11 El admin suspende al especialista E' 200 $r { Estado-Es $r 'suspendida' }
  $r = Llamar 'POST' "/api/admin/usuarios/$C/reactivar" $adm.token $null
  Caso '1.12 El admin reactiva a C' 200 $r { Estado-Es $r 'activa' }

  $l = Login-Firebase $sinV.email $sinV.pass
  Caso '1.13 C vuelve a iniciar sesion' 1 (Como-Caso $l.ok "Firebase devolvio '$($l.error)'")
  if ($l.ok) { $sinV.token = $l.token }
  Caso '1.14 C vuelve a usar la API' 200 (Llamar 'GET' '/api/vinculacion' $sinV.token $null)

  $r = Llamar 'POST' '/api/vinculacion' $sinV.token @{ codigo_vinculacion = $e.codigo_vinculacion }
  Caso '1.15 Vincularse con el codigo de un especialista suspendido: 400' 400 $r

  $r = Llamar 'POST' "/api/admin/usuarios/$E/reactivar" $adm.token $null
  Caso '1.16 El admin reactiva a E' 200 $r { Estado-Es $r 'activa' }
  # Su token anterior vuelve a servir: el bloqueo es la marca en la base.
  Caso '1.17 E vuelve a usar la API' 200 (Llamar 'GET' "/api/usuarios/$E" $esp.token $null)
  $r = Llamar 'POST' "/api/admin/usuarios/$C/reactivar" $adm.token $null
  Caso '1.18 Reactivar otra vez: idempotente' 200 $r { Estado-Es $r 'activa' }

  Write-Host "`n=== 2. Consentimiento ==="

  # D: paciente desechable registrado SIN consentimiento (como un APK viejo o
  # una cuenta de antes del Bloque 1).
  $D = Crear-Desechable 'D' $null
  Caso '2.1 Registro de D sin consentimiento' 201 $D.registro
  $r = Llamar 'GET' '/api/consentimiento' $D.token $null
  Caso '2.2 D: requerido y no aceptado' 200 $r {
    $c = $r.texto | ConvertFrom-Json
    if (-not $c.requerido -or $c.aceptado -or $c.version_aviso -ne $Version.version_aviso) { return "consentimiento inesperado: $($r.texto)" }
    $true
  }
  # El consentimiento se revisa antes de validar: un cuerpo vacio basta.
  $r = Llamar 'POST' '/api/sesiones' $D.token @{}
  Caso '2.3 D sin consentimiento no registra sesiones' 403 $r { Codigo-Es $r 'consentimiento_requerido' }
  $r = Llamar 'POST' '/api/gad7' $D.token @{ items = @(0, 0, 0, 0, 0, 0, 0) }
  Caso '2.4 Ni GAD-7 (antes que el chequeo de vinculo)' 403 $r { Codigo-Es $r 'consentimiento_requerido' }
  $r = Llamar 'POST' '/api/lecturas' $D.token @{ paciente_id = $D.uid }
  Caso '2.5 Ni lecturas' 403 $r { Codigo-Es $r 'consentimiento_requerido' }
  $r = Llamar 'POST' '/api/sesiones/00000000-0000-4000-8000-000000000000/eva' $D.token @{ valor = 10 }
  Caso '2.6 Ni EVA' 403 $r { Codigo-Es $r 'consentimiento_requerido' }
  Caso '2.7 D sin consentimiento SI puede leer (solo se bloquea la captura)' 200 (Llamar 'GET' "/api/sesiones/$($D.uid)" $D.token $null)

  Caso '2.8 Aceptar una version vieja' 400 (Llamar 'POST' '/api/consentimiento' $D.token @{ version_aviso = 'privacidad-v-vieja'; version_consentimiento = $Version.version_consentimiento })
  Caso '2.9 Aceptar con un campo de mas' 400 (Llamar 'POST' '/api/consentimiento' $D.token @{ version_aviso = $Version.version_aviso; version_consentimiento = $Version.version_consentimiento; aceptado_en = '2020-01-01' })
  $r = Llamar 'POST' '/api/consentimiento' $D.token $Version
  Caso '2.10 D acepta la version vigente' 201 $r {
    $c = $r.texto | ConvertFrom-Json
    if (-not $c.aceptado -or -not $c.aceptado_en) { return "no quedo aceptado: $($r.texto)" }
    $true
  }
  Caso '2.11 Aceptar otra vez: 200 sin duplicar' 200 (Llamar 'POST' '/api/consentimiento' $D.token $Version)
  # Con consentimiento ya pasa al validador: el cuerpo vacio es un 400, no un 403.
  Caso '2.12 D con consentimiento ya llega a la validacion de la sesion' 400 (Llamar 'POST' '/api/sesiones' $D.token @{})

  $r = Llamar 'GET' '/api/consentimiento' $esp.token $null
  Caso '2.13 Especialista: no lo requiere' 200 $r {
    if (($r.texto | ConvertFrom-Json).requerido) { return "al especialista se le pide: $($r.texto)" }
    $true
  }
  Caso '2.14 Especialista no puede aceptar' 403 (Llamar 'POST' '/api/consentimiento' $esp.token $Version)

  # D2: registro con el consentimiento en el mismo POST (la app nueva).
  $D2 = Crear-Desechable 'D2' $Version
  Caso '2.15 Registro de D2 con consentimiento' 201 $D2.registro
  $r = Llamar 'GET' '/api/consentimiento' $D2.token $null
  Caso '2.16 D2 queda aceptado desde el registro' 200 $r {
    if (-not ($r.texto | ConvertFrom-Json).aceptado) { return "no quedo aceptado: $($r.texto)" }
    $true
  }
  # D3: registro con una version vieja -> 400 y NO se crea la fila (transaccion).
  $D3 = Crear-Desechable 'D3' @{ version_aviso = 'privacidad-v-vieja'; version_consentimiento = $Version.version_consentimiento }
  Caso '2.17 Registro con version vieja: 400' 400 $D3.registro
  Caso '2.18 ...y la cuenta no quedo registrada' 404 (Llamar 'GET' "/api/usuarios/$($D3.uid)" $D3.token $null)
}
finally {
  # Limpieza: C y E activos y C sin especialista, aunque algo haya fallado.
  Write-Host "`n--- Limpieza ---"
  foreach ($uid in @($C, $E)) {
    $r = Llamar 'POST' "/api/admin/usuarios/$uid/reactivar" $adm.token $null
    Write-Host "Reactivar $uid -> HTTP $($r.status)"
  }
  $r = Llamar 'GET' '/api/admin/usuarios' $adm.token $null
  if ($r.status -eq 200) {
    $fila = (Lista-Json $r.texto) | Where-Object { $_.id -eq $C }
    if ($fila.especialista_id) {
      $d = Llamar 'PUT' "/api/admin/usuarios/$C" $adm.token @{ especialista_id = $null }
      Write-Host "C habia quedado vinculado: se desvinculo (HTTP $($d.status))" -ForegroundColor Yellow
    }
  }
  # Desechables: se borra su cuenta de Firebase. Su fila en `usuarios` (y sus
  # consentimientos) quedan; ver el SQL de limpieza que se imprime.
  foreach ($d in $script:desechables) {
    try {
      Invoke-RestMethod -Method Post -ContentType 'application/json' -Body (@{ idToken = $d.token } | ConvertTo-Json) `
        -Uri "https://identitytoolkit.googleapis.com/v1/accounts:delete?key=$FirebaseKey" | Out-Null
      Write-Host "Desechable $($d.email): cuenta de Firebase borrada"
    } catch {
      Write-Host "Desechable $($d.email): no se pudo borrar en Firebase ($($_.ErrorDetails.Message))" -ForegroundColor Yellow
    }
  }
  if ($script:desechables.Count -gt 0) {
    Write-Host "Filas que quedan en la base (opcional, en el SQL Editor):" -ForegroundColor Cyan
    Write-Host "  DELETE FROM consentimientos WHERE usuario_id IN (SELECT id FROM usuarios WHERE nombre LIKE 'PRUEBA - Desechable %$sello');"
    Write-Host "  DELETE FROM usuarios WHERE nombre LIKE 'PRUEBA - Desechable %$sello';"
  }
}

Write-Host "`n=== Resultado: $script:ok OK, $script:fallas FALLA ===" -ForegroundColor $(if ($script:fallas -eq 0) { 'Green' } else { 'Red' })
