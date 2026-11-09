# Prueba de aislamiento (Fase S, d) contra el backend LOCAL: un paciente no
# puede leer el historial ni el canal de Socket.io de otro paciente, y un
# especialista no vinculado tampoco.
#   Seccion 0 - Cuentas PRUEBA B (paciente sin especialista) y F (especialista
#               sin pacientes), correos @example.com. Si no existen, se crean
#               (Firebase + backend local) con la contrasena que se escriba.
#   Seccion 1 - HTTP: B y F reciben 403 en todo lo de A; A y E (controles) 200.
#   Seccion 2 - Socket.io (node pruebas\aislamiento_socket.js): sin token o
#               desde otro origen no hay conexion; B y F no escriben en el
#               canal de A ni reciben sus mensajes; E (control) si los recibe.
# Uso: .\backend\pruebas\prueba_aislamiento.ps1   (con el backend corriendo en otra ventana)
#
# Se niega si A no es "PRUEBA - Test M3" vinculado a un especialista E "PRUEBA ...".
# Deja 1 mensaje de A a E ("PRUEBA aislamiento ..."): al final se imprime el SQL
# para borrarlo. Compatible con Windows PowerShell 5.1 (sin variables que solo
# difieran en mayusculas, contando las de comun.ps1).

. "$PSScriptRoot\comun.ps1"

# Mismos datos que pruebas\semilla_aislamiento.js (una prueba de node lo comprueba).
$datosB = @{ nombre = 'PRUEBA - Aislamiento B'; email = 'prueba.aislamiento.b@example.com' }
$datosF = @{ nombre = 'PRUEBA - Aislamiento F'; email = 'prueba.aislamiento.f@example.com' }
$Versiones = @{ version_aviso = 'privacidad-v1'; version_consentimiento = 'consentimiento-v1' }

function Alto($texto) { Write-Host "Alto: $texto No se escribio nada." -ForegroundColor Red; exit 1 }

# Inicia sesion en la cuenta PRUEBA o la crea en Firebase si no existe.
# Devuelve @{ token; uid; nueva }.
function Firebase-Cuenta($datos, $pass) {
  $login = Login-Firebase $datos.email $pass
  if ($login.ok) {
    $info = Invoke-RestMethod -Method Post -ContentType 'application/json' `
      -Body (@{ idToken = $login.token } | ConvertTo-Json) `
      -Uri "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=$FirebaseKey"
    return @{ token = $login.token; uid = $info.users[0].localId; nueva = $false }
  }
  if ($login.error -notmatch 'EMAIL_NOT_FOUND|INVALID_LOGIN_CREDENTIALS') { Alto "Firebase rechazo $($datos.email): $($login.error)." }
  $cuerpo = @{ email = $datos.email; password = $pass; returnSecureToken = $true } | ConvertTo-Json
  try {
    $r = Invoke-RestMethod -Method Post -ContentType 'application/json' -Body $cuerpo `
      -Uri "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$FirebaseKey"
  } catch {
    $texto = Cuerpo-Error $_
    if ($texto -match 'EMAIL_EXISTS') { Alto "$($datos.email) ya existe en Firebase con otra contrasena." }
    Alto "no se pudo crear $($datos.email) en Firebase: $texto."
  }
  Write-Host "  Creada en Firebase: $($datos.email)"
  return @{ token = $r.idToken; uid = $r.localId; nueva = $true }
}

Write-Host '--- Cuentas (las contrasenas no se muestran ni se guardan) ---'
$pacA = Obtener-Cuenta 'PACIENTE A ("PRUEBA - Test M3", vinculado a E)'
$espE = Obtener-Cuenta 'ESPECIALISTA E (de A)'
$passPrueba = Leer-Pass 'las cuentas PRUEBA B y F (si no existen se crean con ella; minimo 6)'
if ($passPrueba.Length -lt 6) { Alto 'la contrasena debe tener al menos 6 caracteres.' }
$uidA = $pacA.uid

# --- Candados de A y E ---
$nombreA = Nombre-De $pacA
$nombreE = Nombre-De $espE
$vincA = Llamar 'GET' '/api/vinculacion' $pacA.token $null
$aConE = ($vincA.status -eq 200) -and ((($vincA.texto | ConvertFrom-Json).especialista_id) -eq $espE.uid)
if ($nombreA -ne 'PRUEBA - Test M3' -or -not $aConE -or -not ("$nombreE" -like 'PRUEBA*')) {
  Alto "A debe ser 'PRUEBA - Test M3' vinculado a E 'PRUEBA ...' (A='$nombreA', E='$nombreE', vinculados=$aConE)."
}

Write-Host ''
Write-Host '=== Seccion 0: cuentas PRUEBA B y F ==='
$fbB = Firebase-Cuenta $datosB $passPrueba
$fbF = Firebase-Cuenta $datosF $passPrueba
if ($fbB.uid -eq $uidA -or $fbF.uid -eq $espE.uid) { Alto 'B o F coinciden con A o E.' }

# Registro en el backend si falta la fila en `usuarios`.
$perfilB = Llamar 'GET' "/api/usuarios/$($fbB.uid)" $fbB.token $null
if ($perfilB.status -eq 404) {
  $r = Llamar 'POST' '/api/usuarios' $fbB.token @{ id = $fbB.uid; nombre = $datosB.nombre; email = $datosB.email; rol = 'paciente'; consentimiento = $Versiones }
  Caso '0.1 B se registra como paciente PRUEBA' 201 $r
}
$perfilF = Llamar 'GET' "/api/usuarios/$($fbF.uid)" $fbF.token $null
if ($perfilF.status -eq 404) {
  $codigoInst = Leer-Pass 'el CODIGO_INSTITUCION (solo para registrar a F esta vez)'
  $r = Llamar 'POST' '/api/especialistas' $fbF.token @{ nombre = $datosF.nombre; email = $datosF.email; codigo_institucion = $codigoInst }
  $codigoInst = $null
  Caso '0.2 F se registra como especialista PRUEBA' 201 $r
}

# Candados de B y F: son las cuentas PRUEBA y no tienen vinculo.
$cuentaB = @{ token = $fbB.token; uid = $fbB.uid }
$cuentaF = @{ token = $fbF.token; uid = $fbF.uid }
$nombreB = Nombre-De $cuentaB
$nombreF = Nombre-De $cuentaF
$vincB = Llamar 'GET' '/api/vinculacion' $cuentaB.token $null
$bSinVinculo = ($vincB.status -eq 200) -and -not (($vincB.texto | ConvertFrom-Json).vinculado)
$listaF = Llamar 'GET' '/api/pacientes' $cuentaF.token $null
$fSinPacientes = ($listaF.status -eq 200) -and (@(Lista-Json $listaF.texto).Count -eq 0)
if ($nombreB -ne $datosB.nombre -or $nombreF -ne $datosF.nombre -or -not $bSinVinculo -or -not $fSinPacientes) {
  Alto "B y F deben ser las cuentas PRUEBA sin vinculo (B='$nombreB' sin vinculo=$bSinVinculo; F='$nombreF' sin pacientes=$fSinPacientes)."
}
Write-Host "[OK]    0.3 B y F son cuentas PRUEBA sin vinculo" -ForegroundColor Green
$script:ok++

Write-Host ''
Write-Host '=== Seccion 1: HTTP ==='
$sesionFalsa = '00000000-0000-0000-0000-000000000000'
$rutasDeA = @(
  "/api/lecturas/$uidA", "/api/lecturas/$uidA/resumen", "/api/linea-base/$uidA",
  "/api/sesiones/$uidA", "/api/sesiones/$uidA/$sesionFalsa", "/api/gad7/$uidA",
  "/api/mensajes/$uidA", "/api/ejercicios/$uidA", "/api/usuarios/$uidA",
  "/api/pacientes/$uidA/notas", "/api/pacientes/$uidA/marcadores", "/api/pacientes/$uidA/reporte"
)
$num = 0
foreach ($ruta in $rutasDeA) {
  $num++
  Caso "1.$num B (otro paciente) GET $($ruta.Replace($uidA, '<A>'))" 403 (Llamar 'GET' $ruta $cuentaB.token $null)
  Caso "1.$num F (especialista no vinculado) GET $($ruta.Replace($uidA, '<A>'))" 403 (Llamar 'GET' $ruta $cuentaF.token $null)
}

Caso '1.20 B GET /api/lecturas (todas): 403' 403 (Llamar 'GET' '/api/lecturas' $cuentaB.token $null)
$r = Llamar 'GET' '/api/lecturas' $cuentaF.token $null
Caso '1.21 F GET /api/lecturas: solo de sus pacientes (ninguna de A)' 200 $r {
  $filas = @(Lista-Json $r.texto)
  $deA = @($filas | Where-Object { $_.paciente_id -eq $uidA }).Count
  if ($deA -eq 0) { $true } else { "trae $deA lecturas de A" }
}
Caso '1.22 B GET /api/pacientes: 403' 403 (Llamar 'GET' '/api/pacientes' $cuentaB.token $null)
Caso '1.23 F asigna un ejercicio a A: 403' 403 (Llamar 'POST' '/api/ejercicios' $cuentaF.token @{ paciente_id = $uidA; tecnica_id = 'respiracion_478' })
Caso '1.24 F escribe una nota sobre A: 403' 403 (Llamar 'POST' "/api/pacientes/$uidA/notas" $cuentaF.token @{ texto = 'PRUEBA aislamiento: no deberia guardarse' })
# Controles: la prueba no pasa "porque todo da 403".
Caso '1.25 A lee sus propias sesiones (control)' 200 (Llamar 'GET' "/api/sesiones/$uidA" $pacA.token $null)
Caso '1.26 E (su especialista) lee las sesiones de A (control)' 200 (Llamar 'GET' "/api/sesiones/$uidA" $espE.token $null)

Write-Host ''
Write-Host '=== Seccion 2: Socket.io ==='
$sello = Get-Date -Format 'yyyyMMdd-HHmmss'
$env:AISL_BASE = $Base
$env:AISL_TOKEN_A = $pacA.token
$env:AISL_TOKEN_B = $cuentaB.token
$env:AISL_TOKEN_E = $espE.token
$env:AISL_TOKEN_F = $cuentaF.token
$env:AISL_UID_A = $uidA
$env:AISL_SELLO = $sello
try {
  $salida = & node "$PSScriptRoot\aislamiento_socket.js" 2>&1
  $codigoSalida = $LASTEXITCODE
} finally {
  foreach ($nombreVar in 'AISL_BASE', 'AISL_TOKEN_A', 'AISL_TOKEN_B', 'AISL_TOKEN_E', 'AISL_TOKEN_F', 'AISL_UID_A', 'AISL_SELLO') {
    Remove-Item "Env:$nombreVar" -ErrorAction SilentlyContinue
  }
}
foreach ($linea in $salida) {
  $textoLinea = "$linea"
  if ($textoLinea.StartsWith('[OK]')) { $script:ok++; Write-Host $textoLinea -ForegroundColor Green }
  elseif ($textoLinea.StartsWith('[FALLA]')) { $script:fallas++; Write-Host $textoLinea -ForegroundColor Red }
  else { Write-Host $textoLinea }
}
if ($codigoSalida -ne 0 -and -not ($salida -match '^\[FALLA\]')) {
  $script:fallas++
  Write-Host "[FALLA] el script de Socket.io termino con codigo $codigoSalida (revisa 'npm install' en backend)" -ForegroundColor Red
}

Write-Host ''
Write-Host "=== Resultado: $($script:ok) OK, $($script:fallas) FALLA ===" -ForegroundColor $(if ($script:fallas -eq 0) { 'Green' } else { 'Red' })
Write-Host ''
Write-Host 'Limpieza (pegar en Supabase): borra el mensaje de prueba de A a E.'
Write-Host "  DELETE FROM mensajes_chat WHERE texto LIKE 'PRUEBA aislamiento%';"
Write-Host 'Las cuentas PRUEBA B y F se conservan para repetir la prueba.'
