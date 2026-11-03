# Pruebas por comando del Bloque 1 (cuentas) contra el backend LOCAL.
#   Seccion 1 - Suspender / reactivar (RF-33).
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
}

Write-Host "`n=== Resultado: $script:ok OK, $script:fallas FALLA ===" -ForegroundColor $(if ($script:fallas -eq 0) { 'Green' } else { 'Red' })
