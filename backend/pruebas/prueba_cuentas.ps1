# Pruebas por comando del Bloque 1 (cuentas) contra el backend LOCAL.
#   Seccion 1 - Suspender / reactivar (RF-33).
#   Seccion 2 - Consentimiento (RN-01, RN-02, RNF-06). Crea pacientes
#               desechables "PRUEBA - Desechable ..." (@example.com).
#   Seccion 3 - Solicitud de eliminacion (RF-19 / RF-34). ELIMINA de verdad
#               a los desechables D y D2 (datos, fila anonimizada, Firebase).
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
$perfE = if ($perfilE.status -eq 200) { $perfilE.texto | ConvertFrom-Json } else { $null }
$esAdmin = ($perfilA.status -eq 200) -and (($perfilA.texto | ConvertFrom-Json).rol -eq 'admin')
if (-not "$nombreC".StartsWith('PRUEBA') -or -not $cSinVinculo -or -not $perfE -or
    -not "$($perfE.nombre)".StartsWith('PRUEBA') -or $perfE.rol -ne 'especialista' -or -not $esAdmin) {
  Write-Host "Alto: C debe ser un paciente 'PRUEBA ...' sin especialista (es '$nombreC', sin vinculo: $cSinVinculo), E un especialista 'PRUEBA ...' (es '$($perfE.nombre)') y ADMIN un admin ($esAdmin). No se cambio nada." -ForegroundColor Red
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
$Version = @{ version_aviso = 'privacidad-v1'; version_consentimiento = 'consentimiento-v1' }

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

  $r = Llamar 'POST' '/api/vinculacion' $sinV.token @{ codigo_vinculacion = $perfE.codigo_vinculacion }
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
    $cons = $r.texto | ConvertFrom-Json
    if (-not $cons.requerido -or $cons.aceptado -or $cons.version_aviso -ne $Version.version_aviso) { return "consentimiento inesperado: $($r.texto)" }
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
    $cons = $r.texto | ConvertFrom-Json
    if (-not $cons.aceptado -or -not $cons.aceptado_en) { return "no quedo aceptado: $($r.texto)" }
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

  Write-Host "`n=== 3. Solicitud de eliminacion ==="

  $r = Llamar 'GET' '/api/solicitud-eliminacion' $D.token $null
  Caso '3.1 D sin solicitud' 200 $r {
    if ($null -ne ($r.texto | ConvertFrom-Json).solicitud) { return "ya tenia solicitud: $($r.texto)" }
    $true
  }
  Caso '3.2 Un especialista no puede solicitar por esta via' 403 (Llamar 'POST' '/api/solicitud-eliminacion' $esp.token @{})
  Caso '3.3 La solicitud no lleva datos (motivo -> 400)' 400 (Llamar 'POST' '/api/solicitud-eliminacion' $D.token @{ motivo = 'x' })

  # Un dato clinico de D, para comprobar despues que se borra.
  $r = Llamar 'POST' '/api/lecturas' $D.token @{ paciente_id = $D.uid; bpm = 72; spo2 = 97; hrv = 45; score_ansiedad = 2; estado_ansiedad = 'Baja' }
  Caso '3.4 D registra una lectura (con consentimiento)' 201 $r

  $r = Llamar 'POST' '/api/solicitud-eliminacion' $D.token @{}
  Caso '3.5 D solicita la eliminacion' 201 $r {
    if (($r.texto | ConvertFrom-Json).solicitud.estado -ne 'pendiente') { return "no quedo pendiente: $($r.texto)" }
    $true
  }
  Caso '3.6 Una segunda solicitud pendiente: 409' 409 (Llamar 'POST' '/api/solicitud-eliminacion' $D.token @{})
  Caso '3.7 Con la solicitud pendiente D sigue usando la app' 200 (Llamar 'GET' "/api/lecturas/$($D.uid)" $D.token $null)

  Caso '3.8 Un paciente no ve las solicitudes (ruta de admin)' 403 (Llamar 'GET' '/api/admin/solicitudes-eliminacion' $sinV.token $null)
  $r = Llamar 'GET' '/api/admin/solicitudes-eliminacion' $adm.token $null
  $solD = if ($r.status -eq 200) { (Lista-Json $r.texto) | Where-Object { $_.usuario_id -eq $D.uid } } else { $null }
  Caso '3.9 El admin ve la solicitud de D pendiente' 200 $r {
    if (-not $solD -or $solD.estado -ne 'pendiente' -or $solD.rol -ne 'paciente') { return "solicitud de D: $($solD | ConvertTo-Json -Compress)" }
    foreach ($campo in @('serie', 'bpm', 'hrv', 'puntaje', 'texto')) { if (Tiene $solD $campo) { return "la fila trae el campo clinico '$campo'" } }
    $true
  }
  $r = Llamar 'GET' '/api/admin/usuarios' $adm.token $null
  Caso '3.10 La lista de usuarios marca a D' 200 $r {
    $fila = (Lista-Json $r.texto) | Where-Object { $_.id -eq $D.uid }
    if (-not $fila.solicitud_pendiente) { return "D sin solicitud_pendiente: $($fila | ConvertTo-Json -Compress)" }
    $true
  }

  Caso '3.11 Atender con un id mal formado' 400 (Llamar 'POST' '/api/admin/solicitudes-eliminacion/no-es-uuid/atender' $adm.token $null)
  Caso '3.12 Atender una solicitud que no existe' 404 (Llamar 'POST' '/api/admin/solicitudes-eliminacion/00000000-0000-4000-8000-000000000000/atender' $adm.token $null)
  Caso '3.13 Un especialista no puede atender' 403 (Llamar 'POST' "/api/admin/solicitudes-eliminacion/$($solD.id)/atender" $esp.token $null)

  $r = Llamar 'POST' "/api/admin/solicitudes-eliminacion/$($solD.id)/atender" $adm.token $null
  Caso '3.14 El admin atiende la solicitud de D' 200 $r {
    if (($r.texto | ConvertFrom-Json).estado -ne 'atendida') { return "no quedo atendida: $($r.texto)" }
    $true
  }
  if ($r.status -eq 200) { $D.eliminada = $true }

  # Su token aun no expira, pero la cuenta ya esta eliminada.
  $r = Llamar 'GET' "/api/lecturas/$($D.uid)" $D.token $null
  Caso '3.15 D con su token vigente: 403 cuenta_eliminada' 403 $r { Codigo-Es $r 'cuenta_eliminada' }
  $l = Login-Firebase $D.email $D.pass
  Caso '3.16 D ya no puede iniciar sesion (cuenta borrada en Firebase)' 1 (Como-Caso (-not $l.ok) 'inicio de sesion exitoso')

  $r = Llamar 'GET' '/api/admin/usuarios' $adm.token $null
  Caso '3.17 D queda como lapida anonima' 200 $r {
    $fila = (Lista-Json $r.texto) | Where-Object { $_.id -eq $D.uid }
    if (-not $fila) { return 'la fila de D desaparecio (debia conservarse)' }
    if ($fila.estado -ne 'eliminada' -or $fila.nombre -ne 'Cuenta eliminada' -or $fila.email -ne "eliminada-$($D.uid)@invalid" -or $fila.solicitud_pendiente) {
      return "fila de D: $($fila | ConvertTo-Json -Compress)"
    }
    $true
  }
  $r = Llamar 'POST' "/api/admin/solicitudes-eliminacion/$($solD.id)/atender" $adm.token $null
  Caso '3.18 Atender otra vez: idempotente' 200 $r
  Caso '3.19 Una cuenta eliminada no se suspende' 409 (Llamar 'POST' "/api/admin/usuarios/$($D.uid)/suspender" $adm.token $null)
  Caso '3.20 Ni se edita' 409 (Llamar 'PUT' "/api/admin/usuarios/$($D.uid)" $adm.token @{ nombre = 'Otra vez' })

  # D2 tambien se elimina por el flujo real (asi no quedan desechables vivos).
  $r = Llamar 'POST' '/api/solicitud-eliminacion' $D2.token @{}
  Caso '3.21 D2 solicita la eliminacion' 201 $r
  $r = Llamar 'GET' '/api/admin/solicitudes-eliminacion' $adm.token $null
  $solD2 = if ($r.status -eq 200) { (Lista-Json $r.texto) | Where-Object { $_.usuario_id -eq $D2.uid -and $_.estado -eq 'pendiente' } } else { $null }
  $r = Llamar 'POST' "/api/admin/solicitudes-eliminacion/$($solD2.id)/atender" $adm.token $null
  Caso '3.22 El admin atiende la de D2' 200 $r
  if ($r.status -eq 200) { $D2.eliminada = $true }

  Write-Host "[INFO]  Para confirmar en el SQL Editor que se borraron los datos clinicos (debe dar 0):" -ForegroundColor Cyan
  Write-Host "        SELECT count(*) FROM lecturas_biometricas WHERE paciente_id = '$($D.uid)';"
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
      $desv = Llamar 'PUT' "/api/admin/usuarios/$C" $adm.token @{ especialista_id = $null }
      Write-Host "C habia quedado vinculado: se desvinculo (HTTP $($desv.status))" -ForegroundColor Yellow
    }
  }
  # Desechables que NO se eliminaron por el flujo de la seccion 3 (D3, o si
  # algo fallo): se borra su cuenta de Firebase. Su fila en `usuarios`, si la
  # tiene, queda; ver el SQL de limpieza que se imprime.
  foreach ($des in $script:desechables) {
    if ($des.eliminada) { continue }
    try {
      Invoke-RestMethod -Method Post -ContentType 'application/json' -Body (@{ idToken = $des.token } | ConvertTo-Json) `
        -Uri "https://identitytoolkit.googleapis.com/v1/accounts:delete?key=$FirebaseKey" | Out-Null
      Write-Host "Desechable $($des.email): cuenta de Firebase borrada"
    } catch {
      Write-Host "Desechable $($des.email): no se pudo borrar en Firebase ($(Cuerpo-Error $_))" -ForegroundColor Yellow
    }
  }
  if (@($script:desechables | Where-Object { -not $_.eliminada -and $_.registro.status -eq 201 }).Count -gt 0) {
    Write-Host "Quedaron desechables registrados sin eliminar (opcional, en el SQL Editor):" -ForegroundColor Cyan
    Write-Host "  DELETE FROM consentimientos WHERE usuario_id IN (SELECT id FROM usuarios WHERE nombre LIKE 'PRUEBA - Desechable %$sello');"
    Write-Host "  DELETE FROM usuarios WHERE nombre LIKE 'PRUEBA - Desechable %$sello';"
  }
}

Write-Host "`n=== Resultado: $script:ok OK, $script:fallas FALLA ===" -ForegroundColor $(if ($script:fallas -eq 0) { 'Green' } else { 'Red' })
