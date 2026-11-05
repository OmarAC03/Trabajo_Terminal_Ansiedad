# Pruebas por comando del Bloque 3 (notificaciones push) contra el backend LOCAL.
#   Seccion 1 - Quien entra: /api/dispositivos solo para pacientes.
#   Seccion 2 - Validacion del token.
#   Seccion 3 - Registro, reasignacion entre cuentas y borrado propio.
#   Seccion 4 - Suspender borra los tokens (C se reactiva al final).
#   Seccion 5 - Envio REAL a FCM con tokens falsos: FCM responde
#               registration-token-not-registered a un token con forma real
#               (el backend lo borra) e invalid-argument a uno arbitrario
#               (el backend lo CONSERVA: solo se borra con esos dos codigos).
# Uso: .\backend\pruebas\prueba_notificaciones.ps1   (con el backend corriendo en otra ventana)
#
# Escribe solo en cuentas de prueba: se niega si A no es "PRUEBA - Test M3"
# vinculado a E "PRUEBA ...", o C no es un paciente "PRUEBA ..." sin especialista.
# Deja 2 ejercicios asignados a A (nota "PRUEBA push ..."): al final se imprime
# el SQL para borrarlos. Ningun telefono recibe nada (los tokens son falsos).
# La regla de oro (texto fijo, sin contenido) la cubre notificaciones.test.js.
# Compatible con Windows PowerShell 5.1 (sin variables que solo difieran en
# mayusculas, contando las de comun.ps1).

# $Base, Obtener-Cuenta, Login-Firebase, Llamar, Caso, Nombre-De
. "$PSScriptRoot\comun.ps1"

Write-Host '--- Cuentas (las contrasenas no se muestran ni se guardan) ---'
$pac = Obtener-Cuenta 'PACIENTE A ("PRUEBA - Test M3", vinculado a E)'
$esp = Obtener-Cuenta 'ESPECIALISTA E (de A)'
$sinV = Obtener-Cuenta 'PACIENTE C ("PRUEBA - Sin vinculo")' -ConPass
$adm = Obtener-Cuenta 'ADMIN'
$A = $pac.uid
$C = $sinV.uid

# --- Candados ---
$nombreA = Nombre-De $pac
$nombreE = Nombre-De $esp
$nombreC = Nombre-De $sinV
$vincA = Llamar 'GET' '/api/vinculacion' $pac.token $null
$aConE = ($vincA.status -eq 200) -and ((($vincA.texto | ConvertFrom-Json).especialista_id) -eq $esp.uid)
$vincC = Llamar 'GET' '/api/vinculacion' $sinV.token $null
$cSinVinculo = ($vincC.status -eq 200) -and -not (($vincC.texto | ConvertFrom-Json).vinculado)
$perfilAdm = Llamar 'GET' "/api/usuarios/$($adm.uid)" $adm.token $null
$esAdmin = ($perfilAdm.status -eq 200) -and (($perfilAdm.texto | ConvertFrom-Json).rol -eq 'admin')
if ($nombreA -ne 'PRUEBA - Test M3' -or -not "$nombreE".StartsWith('PRUEBA') -or -not $aConE -or
    -not "$nombreC".StartsWith('PRUEBA') -or -not $cSinVinculo -or -not $esAdmin) {
  Write-Host "Alto: A debe ser 'PRUEBA - Test M3' (es '$nombreA') vinculado a E ($aConE), E 'PRUEBA ...' (es '$nombreE'), C un paciente 'PRUEBA ...' sin especialista (es '$nombreC', sin vinculo: $cSinVinculo) y ADMIN un admin ($esAdmin). No se escribio nada." -ForegroundColor Red
  exit 1
}

$sello = (Get-Date).ToString('yyyyMMddHHmmss')
# Forma de un token real de FCM (22 caracteres, ':APA91b', resto): FCM lo da
# por no registrado. Uno por caso, para no mezclar corridas.
function Token-Forma-Real($n) { return ('p' + $sello + 'q' * 6 + $n) + ':APA91b' + ('E' * 134) }
$tokCuenta = Token-Forma-Real 'a'
$tokSusp = Token-Forma-Real 'b'
$tokFcm = Token-Forma-Real 'c'
$tokRaro = "prueba-fcm-$sello-" + ('x' * 40)   # FCM: invalid-argument

$Disp = '/api/dispositivos'
function Contar($cuenta) {
  $r = Llamar 'GET' $Disp $cuenta.token $null
  if ($r.status -ne 200) { return -1 }
  return [int](($r.texto | ConvertFrom-Json).registrados)
}
function Igual($real, $esperado, $que) {
  if ($real -ne $esperado) { return "$que = $real, se esperaba $esperado" }
  $true
}
function Como-Caso($cumple, $texto) { return @{ status = [int][bool]$cumple; texto = $texto } }

# Espera (hasta $segundos) a que A tenga $esperado tokens: el envio a FCM va
# despues de responder el POST, sin esperar.
function Esperar-Conteo($cuenta, $esperado, $segundos) {
  $limite = (Get-Date).AddSeconds($segundos)
  do {
    $n = Contar $cuenta
    if ($n -eq $esperado) { return $n }
    Start-Sleep -Milliseconds 1000
  } while ((Get-Date) -lt $limite)
  return $n
}

$nA = Contar $pac
$nC = Contar $sinV
if ($nA -lt 0 -or $nC -lt 0 -or $nA -ge 5 -or $nC -ge 5) {
  Write-Host "Alto: GET $Disp fallo o alguna cuenta ya tiene 5 tokens (A: $nA, C: $nC). Corriste el DDL del Bloque 3?" -ForegroundColor Red
  exit 1
}
Write-Host "(tokens antes de empezar: A $nA, C $nC)"

Write-Host "`n=== 1. Quien entra (solo pacientes) ==="
foreach ($quien in @(@{ n = 'E'; c = $esp }, @{ n = 'ADMIN'; c = $adm })) {
  Caso "1. GET dispositivos como $($quien.n)" 403 (Llamar 'GET' $Disp $quien.c.token $null)
  Caso "1. PUT dispositivos como $($quien.n)" 403 (Llamar 'PUT' $Disp $quien.c.token @{ token = $tokCuenta })
  Caso "1. DELETE dispositivos como $($quien.n)" 403 (Llamar 'DELETE' $Disp $quien.c.token @{ token = $tokCuenta })
}
Caso '1. Sin token de Firebase' 401 (Llamar 'GET' $Disp 'no-es-un-token' $null)

Write-Host "`n=== 2. Validacion ==="
Caso '2.1 Cuerpo sin token' 400 (Llamar 'PUT' $Disp $pac.token @{})
Caso '2.2 Token demasiado corto' 400 (Llamar 'PUT' $Disp $pac.token @{ token = 'corto' })
Caso '2.3 Token con espacios' 400 (Llamar 'PUT' $Disp $pac.token @{ token = "con espacio $tokCuenta" })
Caso '2.4 Campo de mas (usuario_id)' 400 (Llamar 'PUT' $Disp $pac.token @{ token = $tokCuenta; usuario_id = $C })
Caso '2.5 DELETE sin token' 400 (Llamar 'DELETE' $Disp $pac.token @{})

Write-Host "`n=== 3. Registro, reasignacion y borrado ==="
$r = Llamar 'PUT' $Disp $pac.token @{ token = $tokCuenta }
Caso '3.1 A registra un token' 200 $r { Igual (Contar $pac) ($nA + 1) 'tokens de A' }
$r = Llamar 'PUT' $Disp $pac.token @{ token = $tokCuenta }
Caso '3.2 Registrarlo otra vez no duplica' 200 $r { Igual (Contar $pac) ($nA + 1) 'tokens de A' }
$r = Llamar 'PUT' $Disp $sinV.token @{ token = $tokCuenta }
Caso '3.3 C inicia sesion en ese telefono: el token pasa a C' 200 $r {
  $res = Igual (Contar $pac) $nA 'tokens de A'
  if ($res -ne $true) { return $res }
  Igual (Contar $sinV) ($nC + 1) 'tokens de C'
}
$r = Llamar 'DELETE' $Disp $pac.token @{ token = $tokCuenta }
Caso '3.4 A no puede borrar el token que ahora es de C (204, sin efecto)' 204 $r { Igual (Contar $sinV) ($nC + 1) 'tokens de C' }
$r = Llamar 'DELETE' $Disp $sinV.token @{ token = $tokCuenta }
Caso '3.5 C cierra sesion: borra su token' 204 $r { Igual (Contar $sinV) $nC 'tokens de C' }
Caso '3.6 Borrarlo otra vez tambien es 204' 204 (Llamar 'DELETE' $Disp $sinV.token @{ token = $tokCuenta })

Write-Host "`n=== 4. Suspender borra los tokens ==="
$reactivada = $false
try {
  $r = Llamar 'PUT' $Disp $sinV.token @{ token = $tokSusp }
  Caso '4.1 C registra un token' 200 $r { Igual (Contar $sinV) ($nC + 1) 'tokens de C' }
  Caso '4.2 ADMIN suspende a C' 200 (Llamar 'POST' "/api/admin/usuarios/$C/suspender" $adm.token $null)
  $r = Llamar 'POST' "/api/admin/usuarios/$C/reactivar" $adm.token $null
  $reactivada = ($r.status -eq 200)
  Caso '4.3 ADMIN reactiva a C' 200 $r
  # Al suspender se revocaron sus sesiones: se vuelve a iniciar.
  $login = Login-Firebase $sinV.email $sinV.pass
  if ($login.ok) { $sinV.token = $login.token }
  $nTras = if ($login.ok) { Contar $sinV } else { -1 }
  Caso '4.4 Tras suspender, C ya no tiene tokens (al entrar a la app los registra de nuevo)' 1 (Como-Caso ($nTras -eq 0) "tokens de C = $nTras; login: $($login.error)")
} finally {
  if (-not $reactivada) {
    $re = Llamar 'POST' "/api/admin/usuarios/$C/reactivar" $adm.token $null
    Write-Host "C reactivado en la limpieza (HTTP $($re.status))" -ForegroundColor Yellow
  }
}

Write-Host "`n=== 5. Envio real a FCM ==="
$r = Llamar 'PUT' $Disp $pac.token @{ token = $tokFcm }
Caso '5.1 A registra un token con forma real (falso)' 200 $r { Igual (Contar $pac) ($nA + 1) 'tokens de A' }
$r = Llamar 'POST' '/api/ejercicios' $esp.token @{ paciente_id = $A; tecnica_id = 'respiracion_478'; nota = "PRUEBA push $sello (1)" }
Caso '5.2 E asigna un ejercicio a A (dispara el push)' 201 $r
$n = Esperar-Conteo $pac $nA 20
Caso '5.3 FCM respondio registration-token-not-registered y el backend lo borro' 1 (Como-Caso ($n -eq $nA) "tokens de A = $n tras 20 s (se esperaba $nA). Revisa el log del backend: 'Push: FCM no entrego' trae el codigo.")

$r = Llamar 'PUT' $Disp $pac.token @{ token = $tokRaro }
Caso '5.4 A registra un token arbitrario (FCM lo rechaza con invalid-argument)' 200 $r { Igual (Contar $pac) ($nA + 1) 'tokens de A' }
$r = Llamar 'POST' '/api/ejercicios' $esp.token @{ paciente_id = $A; tecnica_id = 'respiracion_478'; nota = "PRUEBA push $sello (2)" }
Caso '5.5 E asigna otro ejercicio' 201 $r
Start-Sleep -Seconds 8
$n = Contar $pac
Caso '5.6 invalid-argument NO borra el token (solo los dos codigos lo hacen)' 1 (Como-Caso ($n -eq ($nA + 1)) "tokens de A = $n (se esperaba $($nA + 1))")
$r = Llamar 'DELETE' $Disp $pac.token @{ token = $tokRaro }
Caso '5.7 Limpieza: A borra el token arbitrario' 204 $r { Igual (Contar $pac) $nA 'tokens de A' }

Write-Host "`n=== Resultado: $script:ok OK, $script:fallas FALLA ===" -ForegroundColor $(if ($script:fallas -eq 0) { 'Green' } else { 'Red' })
Write-Host 'En el log del backend deben aparecer:' -ForegroundColor Cyan
Write-Host "  'Push: tokens rechazados por FCM, borrados' con codigos { messaging/registration-token-not-registered: 1 }"
Write-Host "  'Push: FCM no entrego (tokens conservados)' con codigos { messaging/invalid-argument: 1 }"
Write-Host 'Para borrar los 2 ejercicios de prueba de A (SQL Editor de Supabase):' -ForegroundColor Cyan
Write-Host "  DELETE FROM ejercicios_asignados WHERE nota LIKE 'PRUEBA push $sello%';"
