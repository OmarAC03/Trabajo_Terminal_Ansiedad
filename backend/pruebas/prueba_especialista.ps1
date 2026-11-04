# Pruebas por comando del Bloque 2 (portal del especialista) contra el backend LOCAL.
#   Seccion 1 - Quien entra: notas, marcadores y reporte solo para el
#               especialista vinculado (D1).
#   Seccion 2 - Notas clinicas con versiones (WEB-RF-27 / RN-15, D6).
#   Seccion 3 - Marcadores clinicos (WEB-RF-28, tipos D4).
#   Seccion 4 - Reporte para exportar, con y sin seudonimizar (WEB-RF-29, D3).
#   Seccion 5 - Bitacora como admin (WEB-RF-31 / RNF-WEB-05).
# Uso: .\backend\pruebas\prueba_especialista.ps1   (con el backend corriendo en otra ventana)
#
# Escribe notas y marcadores de verdad, solo entre A y E. El script se niega si
# A no es "PRUEBA - Test M3", E no es su especialista "PRUEBA ..." o C no es un
# paciente "PRUEBA ..." sin especialista. Las notas no se pueden borrar desde
# la API (D6): al final se imprime el SQL para limpiarlas. Lo que se escribe
# en la bitacora es permanente (es de solo insercion).
# Para que el reporte traiga sesiones, A debe tener la semilla de semilla_m3.js.
# Compatible con Windows PowerShell 5.1 (sin variables que solo difieran en
# mayusculas, contando las de comun.ps1).

# $Base, Obtener-Cuenta, Llamar, Caso, Tiene, Lista-Json, Nombre-De
. "$PSScriptRoot\comun.ps1"

Write-Host '--- Cuentas (las contrasenas no se muestran ni se guardan) ---'
$pac = Obtener-Cuenta 'PACIENTE A ("PRUEBA - Test M3", vinculado a E)'
$esp = Obtener-Cuenta 'ESPECIALISTA E (de A)'
$sinV = Obtener-Cuenta 'PACIENTE C ("PRUEBA - Sin vinculo")'
$adm = Obtener-Cuenta 'ADMIN'
$esp2 = Obtener-Cuenta 'ESPECIALISTA F, NO vinculado a A' -Opcional
$A = $pac.uid
$E = $esp.uid

# --- Candados: solo cuentas PRUEBA, A vinculado a E, C sin especialista ---
$nombreA = Nombre-De $pac
$nombreE = Nombre-De $esp
$nombreC = Nombre-De $sinV
$vincA = Llamar 'GET' '/api/vinculacion' $pac.token $null
$aConE = ($vincA.status -eq 200) -and ((($vincA.texto | ConvertFrom-Json).especialista_id) -eq $E)
$vincC = Llamar 'GET' '/api/vinculacion' $sinV.token $null
$cSinVinculo = ($vincC.status -eq 200) -and -not (($vincC.texto | ConvertFrom-Json).vinculado)
$perfilAdm = Llamar 'GET' "/api/usuarios/$($adm.uid)" $adm.token $null
$esAdmin = ($perfilAdm.status -eq 200) -and (($perfilAdm.texto | ConvertFrom-Json).rol -eq 'admin')
if ($nombreA -ne 'PRUEBA - Test M3' -or -not "$nombreE".StartsWith('PRUEBA') -or -not $aConE -or
    -not "$nombreC".StartsWith('PRUEBA') -or -not $cSinVinculo -or -not $esAdmin) {
  Write-Host "Alto: A debe ser 'PRUEBA - Test M3' (es '$nombreA') vinculado a E ($aConE), E un especialista 'PRUEBA ...' (es '$nombreE'), C un paciente 'PRUEBA ...' sin especialista (es '$nombreC', sin vinculo: $cSinVinculo) y ADMIN un admin ($esAdmin). No se escribio nada." -ForegroundColor Red
  exit 1
}

# Textos solo ASCII: Windows PowerShell 5.1 no siempre manda y lee bien los acentos.
$sello = (Get-Date).ToString('yyyyMMddHHmmss')
$textoNota = "PRUEBA nota $sello"
$textoNota2 = "PRUEBA nota $sello editada"
$descMarcador = "PRUEBA marcador $sello"
$ayer = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')   # siempre "no futuro" en Mexico
$manana = (Get-Date).AddDays(2).ToString('yyyy-MM-dd')
$hace2Dias = (Get-Date).ToUniversalTime().AddDays(-2).ToString('yyyy-MM-ddTHH:mm:ssZ')
$enUnDia = (Get-Date).ToUniversalTime().AddDays(1).ToString('yyyy-MM-ddTHH:mm:ssZ')
$desdeRep = (Get-Date).AddDays(-29).ToString('yyyy-MM-dd')
$hastaRep = (Get-Date).ToString('yyyy-MM-dd')
$uuidFalso = '00000000-0000-4000-8000-000000000000'

$NotasA = "/api/pacientes/$A/notas"
$MarcasA = "/api/pacientes/$A/marcadores"
$RepA = "/api/pacientes/$A/reporte?desde=$desdeRep&hasta=$hastaRep"

function Codigo-Es($resp, $codigo) {
  $f = $resp.texto | ConvertFrom-Json
  if ($f.codigo -ne $codigo) { return "codigo '$($f.codigo)', se esperaba '$codigo'" }
  $true
}

$idNota = $null
$idMarcador = $null
$idMarcadorBorrado = $null

Write-Host "`n=== 1. Quien entra (solo el especialista vinculado) ==="
$Rutas = @(
  @{ n = 'notas'; ruta = $NotasA },
  @{ n = 'marcadores'; ruta = $MarcasA },
  @{ n = 'reporte'; ruta = "$RepA&formato=csv&seudonimizado=false" }
)
foreach ($ru in $Rutas) {
  Caso "1. $($ru.n) de A como A (el propio paciente)" 403 (Llamar 'GET' $ru.ruta $pac.token $null)
  Caso "1. $($ru.n) de A como C (otro paciente)" 403 (Llamar 'GET' $ru.ruta $sinV.token $null)
  Caso "1. $($ru.n) de A como ADMIN" 403 (Llamar 'GET' $ru.ruta $adm.token $null)
  if ($esp2) { Caso "1. $($ru.n) de A como F (especialista sin vinculo)" 403 (Llamar 'GET' $ru.ruta $esp2.token $null) }
}
Caso '1. A no puede escribir una nota sobre si mismo' 403 (Llamar 'POST' $NotasA $pac.token @{ fecha = $ayer; contenido = 'x' })
Caso '1. ADMIN no puede escribir una nota' 403 (Llamar 'POST' $NotasA $adm.token @{ fecha = $ayer; contenido = 'x' })

Write-Host "`n=== 2. Notas clinicas con versiones ==="
Caso '2.1 Fecha futura' 400 (Llamar 'POST' $NotasA $esp.token @{ fecha = $manana; contenido = $textoNota })
Caso '2.2 Contenido vacio' 400 (Llamar 'POST' $NotasA $esp.token @{ fecha = $ayer; contenido = '   ' })
Caso '2.3 Campo de mas (especialista_id)' 400 (Llamar 'POST' $NotasA $esp.token @{ fecha = $ayer; contenido = 'x'; especialista_id = $A })
Caso '2.4 Mas de 5000 caracteres' 400 (Llamar 'POST' $NotasA $esp.token @{ fecha = $ayer; contenido = ('x' * 5001) })

$r = Llamar 'POST' $NotasA $esp.token @{ fecha = $ayer; contenido = "  $textoNota  " }
Caso '2.5 E crea una nota (version 1, texto recortado)' 201 $r {
  $n = $r.texto | ConvertFrom-Json
  $script:idNota = $n.id
  if ($n.version -ne 1 -or $n.contenido -ne $textoNota -or $n.fecha -ne $ayer) {
    return "version=$($n.version) contenido='$($n.contenido)' fecha=$($n.fecha)"
  }
  $true
}

if ($idNota) {
  $r = Llamar 'PUT' "$NotasA/$idNota" $esp.token @{ fecha = $ayer; contenido = $textoNota2; version = 1 }
  Caso '2.6 E la edita con la version 1 -> version 2' 200 $r {
    $n = $r.texto | ConvertFrom-Json
    if ($n.version -ne 2 -or $n.contenido -ne $textoNota2 -or -not $n.editada_en) { return "version=$($n.version) editada_en=$($n.editada_en)" }
    $true
  }
  $r = Llamar 'PUT' "$NotasA/$idNota" $esp.token @{ fecha = $ayer; contenido = 'otra'; version = 1 }
  Caso '2.7 Editar con la version vieja (otra pestana) -> 409' 409 $r { Codigo-Es $r 'nota_desactualizada' }
  $r = Llamar 'PUT' "$NotasA/$idNota" $esp.token @{ fecha = $ayer; contenido = $textoNota2; version = 2 }
  Caso '2.8 Guardar sin cambios no crea version' 200 $r {
    $n = $r.texto | ConvertFrom-Json
    if ($n.version -ne 2) { return "version=$($n.version)" }
    $true
  }
  $r = Llamar 'GET' "$NotasA/$idNota/versiones" $esp.token $null
  Caso '2.9 Historial: una version anterior con el texto original' 200 $r {
    $vs = @(Lista-Json $r.texto)
    if ($vs.Count -ne 1 -or $vs[0].version -ne 1 -or $vs[0].contenido -ne $textoNota) {
      return "versiones=$($vs.Count) v=$($vs[0].version) contenido='$($vs[0].contenido)'"
    }
    $true
  }
  $r = Llamar 'GET' $NotasA $esp.token $null
  Caso '2.10 La lista trae la nota en su version vigente' 200 $r {
    $lista = Lista-Json $r.texto
    $esta = @($lista) | Where-Object { $_.id -eq $idNota }
    if (-not $esta -or $esta.version -ne 2 -or $esta.contenido -ne $textoNota2) { return 'no aparece o no es la version 2' }
    $true
  }
  Caso '2.11 Historial de la nota como C' 403 (Llamar 'GET' "$NotasA/$idNota/versiones" $sinV.token $null)
  if ($esp2) { Caso '2.12 F no puede editar la nota de E' 403 (Llamar 'PUT' "$NotasA/$idNota" $esp2.token @{ fecha = $ayer; contenido = 'x'; version = 2 }) }
}
Caso '2.13 Nota inexistente' 404 (Llamar 'PUT' "$NotasA/$uuidFalso" $esp.token @{ fecha = $ayer; contenido = 'x'; version = 1 })
Caso '2.14 Id de nota no valido' 400 (Llamar 'GET' "$NotasA/no-es-uuid/versiones" $esp.token $null)
Caso '2.15 No hay DELETE de notas (D6)' 404 (Llamar 'DELETE' "$NotasA/$uuidFalso" $esp.token $null)

Write-Host "`n=== 3. Marcadores clinicos ==="
Caso '3.1 Tipo fuera de la lista (D4)' 400 (Llamar 'POST' $MarcasA $esp.token @{ fecha = $hace2Dias; tipo = 'examen' })
Caso '3.2 Fecha futura' 400 (Llamar 'POST' $MarcasA $esp.token @{ fecha = $enUnDia; tipo = 'consulta' })
Caso '3.3 Fecha sin zona horaria' 400 (Llamar 'POST' $MarcasA $esp.token @{ fecha = '2026-11-01T10:00:00'; tipo = 'consulta' })
Caso '3.4 Descripcion de mas de 140' 400 (Llamar 'POST' $MarcasA $esp.token @{ fecha = $hace2Dias; tipo = 'otro'; descripcion = ('x' * 141) })

$r = Llamar 'POST' $MarcasA $esp.token @{ fecha = $hace2Dias; tipo = 'otro'; descripcion = "$descMarcador (se borra)" }
Caso '3.5 E crea un marcador para borrar' 201 $r { $script:idMarcadorBorrado = ($r.texto | ConvertFrom-Json).id; $true }
$r = Llamar 'POST' $MarcasA $esp.token @{ fecha = $hace2Dias; tipo = 'periodo_examenes'; descripcion = $descMarcador }
Caso '3.6 E crea un marcador que se queda (para ver la grafica)' 201 $r {
  $m = $r.texto | ConvertFrom-Json
  $script:idMarcador = $m.id
  if ($m.tipo -ne 'periodo_examenes' -or $m.descripcion -ne $descMarcador) { return "tipo=$($m.tipo) descripcion='$($m.descripcion)'" }
  $true
}
foreach ($tipo in @('consulta', 'evento_personal', 'intervencion')) {
  # Los otros tipos de D4 tambien entran (y se borran enseguida).
  $r = Llamar 'POST' $MarcasA $esp.token @{ fecha = $hace2Dias; tipo = $tipo }
  Caso "3.7 Tipo '$tipo' aceptado" 201 $r
  if ($r.status -eq 201) { Llamar 'DELETE' "$MarcasA/$(($r.texto | ConvertFrom-Json).id)" $esp.token $null | Out-Null }
}
if ($idMarcadorBorrado) {
  if ($esp2) { Caso '3.8 F no puede borrar el marcador de E' 403 (Llamar 'DELETE' "$MarcasA/$idMarcadorBorrado" $esp2.token $null) }
  Caso '3.9 A no puede borrar un marcador' 403 (Llamar 'DELETE' "$MarcasA/$idMarcadorBorrado" $pac.token $null)
  Caso '3.10 E borra su marcador' 204 (Llamar 'DELETE' "$MarcasA/$idMarcadorBorrado" $esp.token $null)
  Caso '3.11 Borrarlo otra vez' 404 (Llamar 'DELETE' "$MarcasA/$idMarcadorBorrado" $esp.token $null)
}
$r = Llamar 'GET' $MarcasA $esp.token $null
Caso '3.12 La lista trae el que se queda y no el borrado' 200 $r {
  $ids = @(@(Lista-Json $r.texto) | ForEach-Object { $_.id })
  if ($ids -notcontains $idMarcador) { return 'falta el marcador que se queda' }
  if ($idMarcadorBorrado -and ($ids -contains $idMarcadorBorrado)) { return 'sigue el marcador borrado' }
  $true
}

Write-Host "`n=== 4. Reporte ==="
Caso '4.1 Sin formato' 400 (Llamar 'GET' "$RepA&seudonimizado=false" $esp.token $null)
Caso '4.2 Periodo de mas de 366 dias' 400 (Llamar 'GET' "/api/pacientes/$A/reporte?desde=2024-01-01&hasta=$hastaRep&formato=csv&seudonimizado=false" $esp.token $null)
Caso '4.3 Parametro de mas' 400 (Llamar 'GET' "$RepA&formato=csv&seudonimizado=false&paciente=$A" $esp.token $null)

$r = Llamar 'GET' "$RepA&formato=csv&seudonimizado=false" $esp.token $null
Caso '4.4 Con identificacion: nombre, especialista y descripcion del marcador' 200 $r {
  $rep = $r.texto | ConvertFrom-Json
  if ($rep.paciente.nombre -ne 'PRUEBA - Test M3' -or $rep.seudonimizado -ne $false) { return "nombre='$($rep.paciente.nombre)'" }
  if (-not $rep.especialista.nombre) { return 'falta el especialista' }
  if ("$($rep.paciente.id)" -notmatch '^P-[0-9a-f]{8}$') { return "id='$($rep.paciente.id)'" }
  $marca = @($rep.marcadores) | Where-Object { $_.descripcion -eq $descMarcador }
  if (-not $marca) { return 'no trae el marcador de la prueba' }
  Write-Host "        (sesiones en el periodo: $(@($rep.sesiones).Count), GAD-7: $(@($rep.gad7).Count), marcadores: $(@($rep.marcadores).Count))"
  $true
}
$idSeud = $null
$r = Llamar 'GET' "$RepA&formato=pdf&seudonimizado=true" $esp.token $null
Caso '4.5 Seudonimizado (D3): sin nombre, correo, especialista ni texto libre' 200 $r {
  $rep = $r.texto | ConvertFrom-Json
  $script:idSeud = $rep.paciente.id
  $campos = @($rep.paciente.PSObject.Properties.Name)
  if ($campos.Count -ne 1 -or $campos[0] -ne 'id') { return "paciente trae: $($campos -join ', ')" }
  if ($null -ne $rep.especialista) { return 'trae especialista' }
  foreach ($prohibido in @('PRUEBA', $pac.email, $esp.email, $A, $descMarcador, '"eva_contexto"', '"descripcion"')) {
    if ($r.texto.Contains($prohibido)) { return "el reporte seudonimizado contiene '$prohibido'" }
  }
  $true
}
$r = Llamar 'GET' "$RepA&formato=csv&seudonimizado=true" $esp.token $null
Caso '4.6 El seudonimo es estable (mismo paciente, mismo id)' 200 $r {
  if (($r.texto | ConvertFrom-Json).paciente.id -ne $idSeud) { return 'cambio el id seudonimizado' }
  $true
}

Write-Host "`n=== 5. Bitacora (admin) ==="
Caso '5.1 E no puede leer la bitacora' 403 (Llamar 'GET' '/api/admin/bitacora' $esp.token $null)
$r = Llamar 'GET' "/api/admin/bitacora?usuario=$A&limite=200" $adm.token $null
Caso '5.2 Quedaron las acciones de esta corrida sobre A' 200 $r {
  $filas = @((Lista-Json $r.texto).filas)
  $deE = @($filas | Where-Object { $_.actor_id -eq $E -and $_.objetivo_id -eq $A })
  $faltan = @()
  if ($idNota) {
    if (-not ($deE | Where-Object { $_.accion -eq 'nota_creada' -and $_.detalle.nota_id -eq $idNota })) { $faltan += 'nota_creada' }
    if (-not ($deE | Where-Object { $_.accion -eq 'nota_editada' -and $_.detalle.nota_id -eq $idNota -and $_.detalle.version -eq 2 })) { $faltan += 'nota_editada v2' }
    if (@($deE | Where-Object { $_.accion -eq 'nota_editada' -and $_.detalle.nota_id -eq $idNota }).Count -ne 1) { $faltan += 'una sola nota_editada (guardar sin cambios no registra)' }
  }
  if ($idMarcador -and -not ($deE | Where-Object { $_.accion -eq 'marcador_creado' -and $_.detalle.marcador_id -eq $idMarcador })) { $faltan += 'marcador_creado' }
  if ($idMarcadorBorrado -and -not ($deE | Where-Object { $_.accion -eq 'marcador_eliminado' -and $_.detalle.marcador_id -eq $idMarcadorBorrado })) { $faltan += 'marcador_eliminado' }
  $exp = @($deE | Where-Object { $_.accion -eq 'exportacion' -and $_.detalle.desde -eq $desdeRep -and $_.detalle.hasta -eq $hastaRep })
  if (-not ($exp | Where-Object { $_.detalle.formato -eq 'pdf' -and $_.detalle.seudonimizado -eq $true })) { $faltan += 'exportacion pdf seudonimizada' }
  if (-not ($exp | Where-Object { $_.detalle.formato -eq 'csv' -and $_.detalle.seudonimizado -eq $false })) { $faltan += 'exportacion csv' }
  # El acceso se registra uno por par cada 10 min: puede venir de antes.
  if (-not ($deE | Where-Object { $_.accion -eq 'acceso_datos_clinicos' })) { $faltan += 'acceso_datos_clinicos' }
  if ($faltan.Count -gt 0) { return "faltan: $($faltan -join ', ')" }
  $true
}
Caso '5.3 La bitacora no trae contenido clinico (ni la nota ni el marcador)' 200 $r {
  foreach ($prohibido in @($sello, '"contenido"', '"descripcion"')) {
    if ($r.texto.Contains($prohibido)) { return "la bitacora contiene '$prohibido'" }
  }
  $true
}
# El admin si puede tener entradas sobre A (vincular, suspender...), pero nunca
# de datos clinicos; A y C tampoco: sus intentos fueron 403.
$Clinicas = @('acceso_datos_clinicos', 'exportacion', 'nota_creada', 'nota_editada', 'marcador_creado', 'marcador_eliminado')
Caso '5.4 Los intentos rechazados no se registraron (ni A, ni C, ni ADMIN en acciones clinicas)' 200 $r {
  $filas = @((Lista-Json $r.texto).filas)
  $ajenos = @($A, $sinV.uid, $adm.uid)
  $raros = @($filas | Where-Object { ($Clinicas -contains $_.accion) -and ($ajenos -contains $_.actor_id) })
  if ($raros.Count -gt 0) { return "entradas inesperadas: $(($raros | ForEach-Object { "$($_.actor_id):$($_.accion)" }) -join ', ')" }
  $true
}
$r = Llamar 'GET' "/api/admin/bitacora?accion=exportacion&desde=$hastaRep&hasta=$hastaRep" $adm.token $null
Caso '5.5 Filtro por accion y fecha' 200 $r {
  $filas = @((Lista-Json $r.texto).filas)
  if ($filas.Count -lt 2) { return "solo $($filas.Count) exportaciones hoy" }
  if (@($filas | Where-Object { $_.accion -ne 'exportacion' }).Count -gt 0) { return 'trae otras acciones' }
  $true
}
Caso '5.6 Filtro no reconocido' 400 (Llamar 'GET' '/api/admin/bitacora?contenido=x' $adm.token $null)

Write-Host "`n=== Resultado: $script:ok OK, $script:fallas FALLA ===" -ForegroundColor $(if ($script:fallas -eq 0) { 'Green' } else { 'Red' })
Write-Host "Quedaron en Supabase (para revisar el portal): la nota $idNota y el marcador $idMarcador de A."
Write-Host 'Para limpiar las notas y marcadores de las cuentas PRUEBA (SQL Editor de Supabase):' -ForegroundColor Cyan
Write-Host "  DELETE FROM notas_clinicas WHERE paciente_id IN (SELECT id FROM usuarios WHERE rol = 'paciente' AND nombre LIKE 'PRUEBA%');"
Write-Host "  DELETE FROM marcadores_clinicos WHERE paciente_id IN (SELECT id FROM usuarios WHERE rol = 'paciente' AND nombre LIKE 'PRUEBA%');"
Write-Host 'Las entradas de la bitacora no se borran (solo insercion).'
