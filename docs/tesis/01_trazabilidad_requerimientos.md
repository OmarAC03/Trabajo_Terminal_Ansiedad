# 01 · Trazabilidad de requerimientos (TT1 → sistema construido)

> Base para el capítulo de pruebas (organizado por requerimiento).
> Fuente de los requerimientos: `TT1-DETECCION_ANSIEDAD_FINAL (1).pdf`, §3.9 (Tablas 28–30), §3.10 (Tablas 31–49) y §3.11 (Tablas 50–52).
> Estado del código: commit `9ccb954` (2026-10-31). Inventario hecho el 2026-11-03 leyendo el código y los archivos de prueba; **no se corrió ninguna prueba ni build** para este documento.

## Convenciones

**Estado**

- **Implementado**: hace lo que pide el TT1, aunque la tecnología o el detalle de la interfaz cambien un poco.
- **Implementado con cambios**: existe, pero con un alcance, mecanismo o criterio distinto al del TT1. Aquí también entra lo **parcial** (se dice qué parte falta).
- **No implementado**: no hay código que lo cubra. Que exista una columna sin uso no cuenta.

**Evidencia de prueba**

- **Unitaria**: archivo de prueba automatizada con el número de pruebas que contiene.
  - Backend: `node --test` (archivos `backend/*.test.js`).
  - Portal: Jest (`web_portal/src/**/*.test.js`).
  - App: `flutter test` (`app_ansiedad/test/*.dart`).
- **Script .ps1**: prueba por comando contra el backend (`backend/pruebas/prueba_sesiones.ps1`, `prueba_gad7.ps1`). Entre paréntesis va el número o el nombre del caso.
- **Solo manual**: se probó a mano en el teléfono, en el portal o por comando suelto (registrado en `CONTEXTO_PROYECTO.md`), sin prueba automatizada.
- **Pendiente**: ni siquiera hay prueba manual registrada.

**Identificadores.** El TT1 repite números entre tablas: hay un `RF-01` de hardware y otro de la app, y `RNF-01`, `RNF-06` y `RNF-11` aparecen en más de una tabla. Para no confundirlos, este documento les pone un prefijo:

| Prefijo | Tabla del TT1 |
|---|---|
| `HW-` | RF de hardware (Tabla 28) |
| `APP-` | RF de la app (Tabla 29) |
| `WEB-` | RF de la web (Tabla 30) |
| `RNF-WEB-` | RNF de la web (Tabla 50) |
| `RNF-APP-` | RNF de la app (Tabla 51) |
| `RNF-HW-` | RNF de hardware (Tabla 52) |

> **Nota sobre la extracción del PDF.** Varias tablas del TT1 tienen celdas partidas. En la Tabla 29 (`RF-15`…`RF-35`) y en la Tabla 52 (`RNF-09/12/07/11`), la relación ID ↔ texto se reconstruyó por el orden de las filas. **Conviene confirmarla contra el PDF antes de citarla.**

---

## Resumen de totales

| Grupo | Total | Implementado | Con cambios | No implementado |
|---|---:|---:|---:|---:|
| RF hardware (Tabla 28) | 8 | 2 | 6 | 0 |
| RF app móvil (Tabla 29) | 20 | 6 | 10 | 4 |
| RF plataforma web (Tabla 30) | 15 | 5 | 6 | 4 |
| **RF total** | **43** | **13** | **22** | **8** |
| RNF (Tablas 50–52) | 16 | 6 | 4 | 6 |
| Historias de usuario (Tablas 31–49) | 19 | 0 | 19 | 0 |

**Lectura rápida.** Los 8 RF no implementados son los del "incremento 5" administrativo y de cumplimiento:

- notas clínicas, marcadores, exportación PDF/CSV y bitácora consultable;
- suspensión y eliminación de cuentas;
- operación offline.

Ninguna HU quedó tal cual: todas se construyeron con algún criterio de aceptación cambiado. El cambio más frecuente viene de la decisión de alcance de no diagnosticar (`MARCO_ALCANCE_Y_LENGUAJE.md`, `DESARROLLO_FUNDAMENTADO.md` §2): **el paciente nunca ve una etiqueta de estado**, y el estado se calcula contra la **línea base individual**, no contra umbrales fijos.

**Hardware.** El firmware del ESP32 lo desarrolla un compañero y **no está en este repositorio**. El estado de los `HW-` se juzga por el contrato de datos (`CONTRATO_SENSOR.md`) y por el lado de la app. **La prueba con el ESP32 real (M7a paso 5) sigue pendiente**: todo lo de hardware está validado solo con el simulador y con pruebas unitarias del intérprete.

---

## Cambios transversales (para no repetirlos en cada fila)

| # | Cambio respecto al TT1 | Dónde se ve |
|---|---|---|
| C1 | **BLE (GATT) → Bluetooth clásico (SPP)**, plugin `flutter_classic_bluetooth` 1.7.0. El sensor se empareja una vez en los ajustes de Android con el nombre `TT_SENSOR_CLASICO`. | `app_ansiedad/lib/repositories/sensor_repository.dart` |
| C2 | **Una línea JSON por segundo** (`v`, `seq`, `bpm`, `spo2`, `rr`, `dedo`, `estable`) en vez de un paquete por minuto. | `CONTRATO_SENSOR.md`, `lib/repositories/interprete_sensor.dart` |
| C3 | **Solo MAX30102** (FC, SpO2, intervalos RR). Sin GSR/EDA ni temperatura. | `CONTRATO_SENSOR.md` |
| C4 | **Sesión de medición guiada** (180 s de señal limpia en ≤ 300 s) que se guarda como un registro con resumen y serie submuestreada, en vez de `medicion_minuto`. | `sesiones_medicion`, `lib/medicion/calculo_sesion.dart` |
| C5 | **El estado ya no es un "score de ansiedad" con umbrales fijos.** Es la desviación de la HRV (Ln RMSSD) respecto a la **línea base individual** de 7 días (Normal / Elevados / Altos), y **solo lo ve el especialista** ("regla de oro"). | `backend/linea_base.js`, `backend/linea_base_vista.js` |
| C6 | **Autenticación con Firebase Auth** (ID token verificado con `firebase-admin`) en vez de JWT propio con `/auth/login` y `/auth/refresh`. El rol sale de la tabla `usuarios`. | `backend/auth.js`, `app_ansiedad/lib/api_client.dart`, `web_portal/src/firebase.js` |
| C7 | **Control de acceso en el backend**, no con Row Level Security de Supabase (RLS desactivado en todas las tablas). | `server.js` (`autorizarLecturaPaciente`, `autorizarPerfilPropio`, `esPacienteVinculado`), `requiereAdmin` |
| C8 | **Indicaciones → "ejercicios asignados"** (técnica del catálogo o texto libre + nota), con "visto" derivado de la última apertura. | `ejercicios_asignados`, `POST/GET /api/ejercicios` |
| C9 | **Sin notificaciones push (FCM).** Hay badges dentro de la app por sondeo cada 45 s. | `lib/providers/pendientes_provider.dart`, `GET /api/pendientes` |
| C10 | **Vinculación tipo Classroom.** El paciente escribe el código de 6 caracteres de su especialista; un paciente tiene un solo especialista. | `POST/GET /api/vinculacion`, `usuarios.especialista_id` |
| C11 | **Sin almacenamiento local persistente en la app** (ni SQLite ni `shared_preferences`). La sesión se arma en memoria y se sube al terminar; si falla, queda en memoria para "Reintentar envío". | `lib/providers/medicion_provider.dart` |

---

## 1. Requerimientos funcionales de hardware (Tabla 28)

| ID | Requerimiento (TT1) | Estado | Dónde vive | Evidencia de prueba | Nota del cambio |
|---|---|---|---|---|---|
| HW-RF-01 | Adquirir lecturas de sensores (PPG/EDA/temperatura) según parámetros definidos | Implementado con cambios | Firmware `firmware_sensor_tt.ino` (fuera del repo); contrato en `CONTRATO_SENSOR.md` | Pendiente (prueba con ESP32 real, M7a paso 5); simulación: `simulador_sensor_test.dart` (3) | Solo PPG con MAX30102 (C3). Muestreo ≥ 100 Hz exigido por el contrato. |
| HW-RF-02 | Acondicionamiento básico / preprocesamiento de señal | Implementado | Firmware (fuera del repo): detecta picos y entrega RR crudos, BPM y SpO2 | Pendiente (hardware real) | El RMSSD **no** lo calcula el firmware: lo calcula la app a partir de los RR (`calculo_sesion.dart`). |
| HW-RF-03 | Empaquetar datos con estructura definida (indicador, valor, timestamp/contador) | Implementado | `CONTRATO_SENSOR.md` v1; intérprete en `lib/repositories/interprete_sensor.dart` | Unitaria: `interprete_sensor_test.dart` (21 + 6 generadas = 27) | JSON por línea con contador `seq`. La marca de tiempo la pone la app (un dato por segundo de reloj). |
| HW-RF-04 | Publicar un servicio BLE (GATT) y permitir emparejamiento | Implementado con cambios | `lib/repositories/sensor_repository.dart` | Unitaria: `alerta_provider_test.dart` (11, con sensor falso); hardware pendiente | Bluetooth clásico SPP (C1). Sin perfil GATT. |
| HW-RF-05 | Notificaciones periódicas por BLE cada 1 minuto | Implementado con cambios | `lib/repositories/lector_lineas.dart`, `interprete_sensor.dart` | Unitaria: `lector_lineas_test.dart` (13), `interprete_sensor_test.dart` | 1 línea por segundo por SPP (C2). |
| HW-RF-06 | Indicador de calidad de señal (quality flag) | Implementado con cambios | Campos `dedo` y `estable` del contrato; `interprete_sensor.dart`; `indice_calidad` por sesión | Unitaria: `interprete_sensor_test.dart`, `calculo_sesion_test.dart` (17) | Dos banderas booleanas por segundo en vez de un `quality_flag` 0/1/2. Paquete incompleto = segundo sin dedo. |
| HW-RF-07 | Reinicio/recuperación del servicio ante desconexión | Implementado con cambios | Firmware (fuera del repo); app: `AlertaProvider` (estados "no llegan datos" a los 8 s y "conexión perdida", tope de 15 s en `connect`, botón "Reintentar") | Unitaria: `alerta_provider_test.dart`, `estado_sensor_test.dart` (3); hardware pendiente | La reconexión es **manual** ("Reintentar"), no automática. |
| HW-RF-08 | Registrar `device_id` y versión de firmware | Implementado con cambios | Campo `v` (versión del contrato) y `EstadoFirmware` en `interprete_sensor.dart` | Unitaria: `interprete_sensor_test.dart` (firmware compatible / no compatible) | Se verifica la **versión del contrato** en cada conexión; **no hay `device_id`** ni tabla de dispositivos. La sesión guarda `origen` (`sensor`/`simulacion`). |

## 2. Requerimientos funcionales de la app móvil (Tabla 29)

| ID | Requerimiento (TT1) | Estado | Dónde vive | Evidencia de prueba | Nota del cambio |
|---|---|---|---|---|---|
| APP-RF-01 | Registro / inicio de sesión del paciente | Implementado | `screens/registro_screen.dart`, `screens/login_screen.dart`, `auth_gate.dart`, `screens/recuperar_password_screen.dart`; `POST /api/usuarios` | Solo manual | Registro transaccional: si falla el guardado en la base, se borra la cuenta de Firebase. Con "¿Olvidaste tu contraseña?". |
| APP-RF-03 | Cerrar sesión | Implementado | `screens/perfil_screen.dart` (`PerfilProvider`) | Solo manual | — |
| APP-RF-05 | Vincular el ESP32 vía BLE (escaneo, selección, emparejamiento) | Implementado con cambios | Selector Simulación / Sensor en `screens/inicio_screen.dart`; `AlertaProvider.elegirSensor()`; `sensor_repository.dart` | Unitaria: `alerta_provider_test.dart` (11); hardware pendiente | Sin pantalla de escaneo: se empareja en los ajustes de Android y la app busca `TT_SENSOR_CLASICO` (C1). |
| APP-RF-06 | Mostrar el estado de conexión y el nivel básico de señal | Implementado con cambios | `lib/medicion/estado_sensor.dart`; tarjeta de estado en `inicio_screen.dart` | Unitaria: `estado_sensor_test.dart` (3), `alerta_provider_test.dart` | Estados: buscando, verificando, conectado, sin vincular, sin permisos, firmware no compatible, no llegan datos, conexión perdida, error. **No hay "reconectando" automático.** |
| APP-RF-07 | Iniciar / detener una sesión de monitoreo | Implementado | `screens/medicion_screen.dart`, `providers/medicion_provider.dart` | Unitaria: `calculo_sesion_test.dart` (17); manual en el teléfono (simulación) | Sesión guiada (C4) con anillo de progreso. Mantiene la pantalla encendida (`wakelock_plus`). |
| APP-RF-08 | Recibir datos del ESP32 (por minuto) y validarlos | Implementado con cambios | `repositories/lector_lineas.dart`, `repositories/interprete_sensor.dart` | Unitaria: `lector_lineas_test.dart` (13), `interprete_sensor_test.dart` (27) | Por segundo (C2). Validación estricta de tipos y campos; hueco en `seq` = corte de la cadena RR. |
| APP-RF-09 | Guardar localmente (buffer) con control de duplicados | Implementado con cambios | `AcumuladorSesion` en `lib/medicion/calculo_sesion.dart`; `interprete_sensor.dart` (crédito por segundo, tope 2) | Unitaria: `calculo_sesion_test.dart`, `interprete_sensor_test.dart` | **Parcial**: el buffer vive **en memoria** durante la sesión y no sobrevive a cerrar la app (C11). Los duplicados y huecos se controlan con `seq`. |
| APP-RF-10 | Marcar datos con calidad (artefacto/movimiento) | Implementado con cambios | `calculo_sesion.dart` (segundos válidos, `indice_calidad`); `backend/linea_base.js` (umbral de 60 %) | Unitaria: `calculo_sesion_test.dart`, `linea_base.test.js` (15); script `prueba_sesiones.ps1` ("calidad baja") | La calidad es por sesión: con menos de 60 % de señal válida, la sesión se guarda pero no recibe estado. `indice_calidad` solo lo ve el especialista. |
| APP-RF-11 | Resumen básico (últimos valores / última sesión) | Implementado | `screens/inicio_screen.dart`, `providers/inicio_provider.dart` | Unitaria: `inicio_test.dart` (16) | Muestra la **última sesión guardada** (no valores en vivo), con textos educativos y la mascota de calibración. |
| APP-RF-12 | Sincronización automática cuando hay conectividad | Implementado con cambios | `MedicionProvider` → `SesionRepository.enviarSesion()` → `POST /api/sesiones` | Script: `prueba_sesiones.ps1` (POST de sesión válida → 201); app solo manual | La sesión se sube **sola al terminar**. No hay cola en segundo plano que espere conectividad (C11). |
| APP-RF-13 | Sincronización manual ("subir ahora") | Implementado con cambios | Botón "Reintentar envío" en `medicion_screen.dart` | Solo manual | Solo aparece si falló la subida. El botón "Sincronizar resumen" del método anterior se retiró. |
| APP-RF-14 | Reintentos de sincronización sin duplicados | Implementado con cambios | `lib/api_client.dart` (2 reintentos con espera creciente ante timeout o sin conexión; por el cold start de Render) | Solo manual | No hay llave de idempotencia en `POST /api/sesiones`. Sí la hay en la EVA (`uq_eva_sesion` → 409) y en el GAD-7 (409 por intervalo). |
| APP-RF-15 | Historial por día/semana con gráficas simples | Implementado con cambios | `screens/historial_screen.dart`, `screens/sesion_detalle_screen.dart`, `providers/historial_sesiones_provider.dart` | Unitaria: `historial_test.dart` (15) | Lista de sesiones agrupada por día, con detalle y gráficas de la serie. **Sin vista semanal ni tendencia** (no se interpreta sin línea base). |
| APP-RF-16 | Responder cuestionarios (tamizajes breves) | Implementado | GAD-7: `screens/gad7_screen.dart`, `providers/cuestionario_gad7_provider.dart`, `contenido/gad7_textos.dart`. EVA 0–10 post-medición: `medicion_screen.dart`, `models/eva_respuesta.dart` | Unitaria: `gad7_test.dart` (15), `gad7_textos_test.dart` (8 + 19 generadas = 27), `eva_test.dart` (12); backend `gad7.test.js` (18); scripts `prueba_gad7.ps1`, `prueba_sesiones.ps1` (EVA) | GAD-7 cada 14 días, solo para pacientes vinculados. El paciente **no ve su resultado**. |
| APP-RF-17 | Asociar cuestionarios a una ventana de mediciones | Implementado con cambios | `respuestas_eva.sesion_id` (`POST /api/sesiones/:sesionId/eva`, ventana de 15 min) | Script: `prueba_sesiones.ps1` (13 casos de EVA, incluido "fuera de la ventana de 15 min → 400"); unitaria `eva_test.dart` | La EVA queda ligada a **una sesión**. El GAD-7 se asocia solo por fecha. El análisis cruzado en el portal (M5b) **no está hecho**. |
| APP-RF-18 | Mensajes de uso responsable (no diagnostica) | Implementado | Clase `Disclaimers` y `DisclaimerNota` en `app_config.dart`; `ui/estructura_acceso.dart` | Unitaria: `gad7_textos_test.dart` (regla de oro: los textos no hablan del resultado); `mensajes_mascota_test.dart` (16) | Visibles en acceso, Inicio, resultados de la medición, Historial, GAD-7 y Perfil. |
| APP-RF-19 | Solicitar eliminación de cuenta/datos | No implementado | — | — | Existe la columna `usuarios.eliminado_en` (borrado lógico que el admin ve como estado), pero no hay flujo de solicitud. |
| APP-RF-33 | (Web/Admin) Desactivar o suspender cuentas; una cuenta suspendida no accede ni sincroniza | No implementado | Solo la columna `usuarios.suspendido`, que el admin ve como estado en `AdminUsuarios.js` | — | No hay acción para suspender y `auth.js` no revisa `suspendido` (Fase C, paso 3, pendiente). |
| APP-RF-34 | Solicitud de eliminación registrada y ejecutada según la política | No implementado | — | — | Ídem APP-RF-19. |
| APP-RF-35 | Operar offline y sincronizar al volver la red sin perder datos | No implementado | — | — | Ver C11. Sin red, la sesión terminada se puede reintentar solo mientras la pantalla siga abierta. |

## 3. Requerimientos funcionales de la plataforma web (Tabla 30)

| ID | Requerimiento (TT1) | Estado | Dónde vive | Evidencia de prueba | Nota del cambio |
|---|---|---|---|---|---|
| WEB-RF-02 | Inicio de sesión en la plataforma web | Implementado | `web_portal/src/Login.js`, `firebase.js`, `ui/AuthLayout.js`, `RecuperarPassword.js` | Solo manual | Firebase Auth (C6). Error genérico de credenciales. Sesión por pestaña (`browserSessionPersistence`). |
| WEB-RF-04 | Cerrar sesión | Implementado | `ui/Layout.js` (sidebar → Salir), `App.js` | Solo manual | — |
| WEB-RF-20 | Alta / baja / edición de usuarios (admin) | Implementado con cambios | `AdminApp.js`, `AdminUsuarios.js`, `EditarUsuario.js`; `GET/PUT /api/admin/usuarios[/:id]` (`backend/admin.js`) | Solo manual (por comando: 403/403/200, Fase C paso 1) | El admin **ve y edita** nombre, correo (Firebase + base, con compensación) y especialista. **Sin alta ni baja**: el paciente se registra en la app y el especialista con el código de institución. |
| WEB-RF-21 | Asignar pacientes a especialistas | Implementado con cambios | Paciente: `POST /api/vinculacion` (código); admin: `PUT /api/admin/usuarios/:id` (`especialista_id`, null = desvincular) | Solo manual | Vinculación por código (C10). Solo el admin reasigna o desvincula. |
| WEB-RF-22 | Lista de pacientes asignados y su estado general | Implementado | `Dashboard.js`, `PacientesList.js`, `PacientesComun.js`; `GET /api/pacientes` | Unitaria: `actividad.test.js` (10), `sesiones.test.js` (21), `semaforo.test.js` (5); script `prueba_sesiones.ps1` (`ultima_sesion`, `sesiones_7d`, estado de la última sesión) y `prueba_gad7.ps1` (caso 13, `ultimo_gad7_*`) | Estado = el de la última sesión contra la línea base (C5). También muestra la actividad de 7 días y la columna GAD-7. Filtrado por vínculo. |
| WEB-RF-23 | Perfil del paciente (datos generales + configuración) | Implementado con cambios | Encabezado de `PacienteDetalle.js` | Solo manual | Nombre, correo, estado y última medición. **No hay datos de salud ni de configuración** porque el modelo no los guarda. |
| WEB-RF-24 | Gráficas de indicadores por rango (día/semana/mes) | Implementado con cambios | `SesionesPaciente.js` (HRV y FC por sesión de los últimos 30 días, con franja del rango habitual), `SesionDetalle.js` (serie de la sesión) | Unitaria: `sesiones.test.js` (21) | El selector Día/Semana/Mes se retiró junto con las lecturas sueltas. Ahora la unidad es la **sesión**. |
| WEB-RF-25 | Filtrar / segmentar datos (rango, tipo, sesiones) | Implementado con cambios | `PacientesList.js` (búsqueda y filtro por estado); `SesionesPaciente.js` (por sesión y por origen simulación/sensor) | Unitaria: `sesiones.test.js` | Sin filtro por rango de fechas libre. |
| WEB-RF-26 | Ver los cuestionarios del paciente y su línea de tiempo | Implementado | `Gad7Paciente.js` (último puntaje, severidad, "Valorar ≥ 10", gráfica 0–21, historial con detalle de ítems); EVA en `SesionesPaciente.js` / `SesionDetalle.js` | Unitaria: `web_portal/src/gad7.test.js` (11), `backend/gad7_vista.test.js` (9); script `prueba_gad7.ps1` (casos 2 y 10) | — |
| WEB-RF-27 | Notas / observaciones clínicas por paciente y fecha | No implementado | — | — | — |
| WEB-RF-28 | Marcar eventos / marcadores en la línea de tiempo | No implementado | — | — | — |
| WEB-RF-29 | Exportar reporte (PDF/CSV) por paciente y rango | No implementado | — | — | — |
| WEB-RF-30 | Gestión de roles y permisos | Implementado con cambios | `backend/auth.js` (`requiereAuth`, rol desde `usuarios`), `requiereAdmin`, `CHECK usuarios_rol_check`; `App.js` decide portal de especialista o de admin | Script: `prueba_sesiones.ps1` y `prueba_gad7.ps1` (casos 403 por rol y por vínculo); manual 403/200 de `usuarios/:id` | Tres roles fijos en el código (paciente, especialista, admin). **No son configurables** desde la interfaz. |
| WEB-RF-31 | Bitácora básica de actividad (accesos, asignaciones, exportaciones) | No implementado | — | — | Solo hay logs estructurados del servidor (`backend/logger.js`) en Render, sin consulta desde el portal. |
| WEB-RF-32 | Avisos de uso responsable | Implementado | `Disclaimer` en `ui/components.js`; `AuthLayout.js` ("no emite diagnósticos"); disclaimers en Pacientes, Detalle, Sesiones, GAD-7 y Ejercicios | Solo manual | — |

---

## 4. Requerimientos no funcionales (Tablas 50–52)

| ID | Requerimiento (TT1) | Estado | Dónde vive | Evidencia de prueba | Nota del cambio |
|---|---|---|---|---|---|
| RNF-WEB-01 / RNF-APP-01 | Cifrado en tránsito (HTTPS/TLS) | Implementado | Render sirve backend y portal por HTTPS; `API_BASE` y `app_config.dart` apuntan a `https://` | Solo manual | Render redirige HTTP a HTTPS. Socket.io va sobre `wss://`. |
| RNF-WEB-03 | Control de acceso por roles (RBAC) | Implementado | `backend/auth.js`, `server.js` (autorización por ruta), `admin.js` | Script: `prueba_sesiones.ps1` (403 a especialista no vinculado, admin y otro paciente), `prueba_gad7.ps1` (casos 3a, 5, 11a); unitaria `gad7_vista.test.js`, `linea_base_vista.test.js` (qué campos ve cada rol) | En el backend, no con RLS (C7). |
| RNF-WEB-05 | Bitácora / auditoría de accesos a datos clínicos, consultable por el admin | Implementado con cambios | `backend/logger.js` (JSON por línea) | Solo manual | **Parcial**: hay logs de las acciones críticas (sin datos clínicos), pero no se guardan en la base ni los consulta el admin. |
| RNF-WEB-06 / RNF-APP-06 | Consentimiento del paciente (registro; bloqueo si no existe) | No implementado | — | — | Solo hay disclaimers de alcance; no se registra consentimiento. |
| RNF-WEB-08 | Anonimización / seudonimización de datasets | No implementado | — | — | Va ligado a la exportación (WEB-RF-29), que tampoco existe. |
| RNF-APP-02 | Cifrado en reposo de la información sensible local | No implementado | — | — | La app no guarda datos clínicos en el teléfono (C11). En el servidor, el cifrado en reposo es el que da Supabase. |
| RNF-APP-04 | Expiración de sesión por inactividad | No implementado | — | — | En la app la sesión de Firebase persiste. En el portal (no es este RNF) la sesión dura lo que la pestaña. |
| RNF-APP-10 | Operar offline sin pérdida (buffer de 72 h) | No implementado | — | — | Ver APP-RF-35. |
| RNF-APP-11 | Prevenir duplicados (idempotencia) | Implementado con cambios | `seq` en el sensor; `uq_eva_sesion`; `POST /api/gad7` con transacción `FOR UPDATE` + 409 | Script: `prueba_gad7.ps1` (caso 6, carrera real: exactamente un 201 y un 409), `prueba_sesiones.ps1` ("EVA por segunda vez → 409"); unitaria `interprete_sensor_test.dart` | **Parcial**: `POST /api/sesiones` no tiene llave de idempotencia. |
| RNF-APP-15 | Fechas en un estándar (UTC) y mostradas en la zona local | Implementado | `timestamptz` en todas las tablas; `diaLocal` con `America/Mexico_City` en `linea_base.js` y `gad7.js`; `ui/formato_fecha.dart`; `fechaDia` en `web_portal/src/gad7.js` | Unitaria: `gad7.test.js` (medianoche 23:59/00:00, día de México y no UTC, fin de mes), `linea_base.test.js`, `historial_test.dart`, `web_portal/src/gad7.test.js` | — |
| RNF-HW-09 | Tolerar desconexiones y reconectar en ≤ 30 s | Implementado con cambios | `AlertaProvider` (detecta 8 s sin datos, tope de 15 s al conectar) | Unitaria: `alerta_provider_test.dart`; hardware pendiente | Detecta la falla y ofrece "Reintentar" **manual**. Sin reconexión automática. |
| RNF-HW-12 | Sincronización temporal consistente | Implementado con cambios | `interprete_sensor.dart` (una lectura por segundo de reloj del teléfono; crédito con tope 2) | Unitaria: `interprete_sensor_test.dart` (reloj inyectable) | La hora la pone el teléfono. El ESP32 solo manda el contador `seq`. |
| RNF-HW-07 | Minimización de datos en el payload | Implementado | `CONTRATO_SENSOR.md` (7 campos) | Unitaria: `interprete_sensor_test.dart` (un campo extra se ignora) | Sin identificadores personales en el payload. |
| RNF-HW-11 | Prevenir duplicados por paquete (timestamp/contador) | Implementado | Campo `seq`; `InterpreteSensor` (hueco o reinicio de `seq` → corte) | Unitaria: `interprete_sensor_test.dart`, `calculo_sesion_test.dart` | — |

---

## 5. Historias de usuario (Tablas 31–49)

En la columna "Nota del cambio" se dice qué criterios de aceptación del TT1 **no** se cumplen tal cual (CA = criterio de aceptación).

| HU | Nombre (TT1) | Estado | Dónde vive | Evidencia de prueba | Nota del cambio |
|---|---|---|---|---|---|
| HU01 | Registro de perfil del estudiante | Implementado con cambios | `registro_screen.dart`; `POST /api/usuarios` | Solo manual | Pide nombre, correo y contraseña. **Sin** edad ni teléfono (CA1) y **sin correo de verificación** (CA3–4). La vinculación con el especialista es aparte (C10). |
| HU02 | Inicio de sesión del estudiante | Implementado con cambios | `login_screen.dart`, `recuperar_password_screen.dart` | Solo manual | Cumple CA1–3 y CA5 (error genérico, restablecimiento por correo). CA4 (bloqueo de 15 min tras 5 intentos) lo cubre **Firebase**, con su propio límite: la app muestra "Demasiados intentos". |
| HU03 | Conexión del dispositivo vía Bluetooth | Implementado con cambios | `sensor_repository.dart`, `estado_sensor.dart`, `inicio_screen.dart` | Unitaria: `alerta_provider_test.dart`, `estado_sensor_test.dart`; hardware pendiente | Sin pantalla de escaneo (CA1–2, C1). Sin los 3 reintentos automáticos (CA5): hay "Reintentar". |
| HU04 | Medición de biomarcadores en tiempo real | Implementado con cambios | `medicion_screen.dart`, `medicion_provider.dart`, `calculo_sesion.dart` | Unitaria: `calculo_sesion_test.dart` (17); script `prueba_sesiones.ps1` (validación de la sesión) | **Por diseño no se muestran valores en vivo** (CA2): solo un anillo de progreso y una guía de colocación del dedo (CA3 ✓). La sesión se sube al terminar (CA4 ✓, sin almacenamiento local). Duración fija de 180 s limpios en ≤ 300 s (CA5). |
| HU05 | Visualización de métricas e indicadores | Implementado con cambios | `inicio_screen.dart`, `ui/fila_indicador.dart`, `contenido/textos_educativos.dart` | Unitaria: `inicio_test.dart` (16), `mensajes_mascota_test.dart` (16) | **El paciente no ve semáforo** (CA1, C5): ve promedios de FC, HRV y SpO2 con explicación sencilla (CA2, CA5 ✓) y a la mascota de calibración. Sin gráfica en vivo (CA3–4). |
| HU06 | Consulta del historial de mediciones | Implementado con cambios | `historial_screen.dart`, `sesion_detalle_screen.dart` | Unitaria: `historial_test.dart` (15) | Sesiones por fecha descendente con resumen y detalle con gráficas (CA1–3 ✓, **sin nivel de ansiedad**). Sin filtro por rango (CA4) ni tendencia (CA5). |
| HU07 | Ejercicios de respiración guiados | Implementado con cambios | `tecnicas_screen.dart` | Solo manual (probado en el teléfono) | Técnicas: respiración 4-7-8, relajación muscular, grounding 5-4-3-2-1 y visualización guiada (CA1 pedía diafragmática y coherencia cardíaca). Animación + voz TTS + música (CA2 ✓). Sin duración configurable (CA3), sin valoración final (CA4) y sin comparar la FC antes/después (CA5). |
| HU08 | Recepción de indicaciones del especialista | Implementado con cambios | `ejercicios_asignados_screen.dart`, `ejercicios_provider.dart`, `pendientes_provider.dart` | Solo manual (Fase 2c) | "Ejercicios asignados" (C8): lista cronológica (CA1, CA5 ✓) que abre la técnica referida (CA3 ✓, texto plano). Badge en la app en vez de push (CA2, C9). "Visto" automático al abrir; no se marca "completada" (CA4). |
| HU09 | Mensajería con el especialista | Implementado con cambios | `mensajes_screen.dart`, `mensajes_provider.dart`, `chat_repository.dart`; Socket.io `enviar_mensaje` / `recibir_mensaje`; `GET /api/mensajes/:pacienteId` | Solo manual | Hilo, envío, hora e historial (CA1–3 y CA5 ✓). **Sin push** (CA4): badge por sondeo. Prueba de aislamiento entre dos pacientes **pendiente**. |
| HU10 | Gestión del perfil del estudiante | Implementado con cambios | `perfil_screen.dart`, `perfil_provider.dart`; `GET/PUT /api/usuarios/:id` | Solo manual (403/200 por comando) | Edita nombre y avatar (CA2 parcial). Sin contacto ni datos de salud. **Sin cambio de contraseña en la app** (CA4). |
| HU11 | Registro de perfil del especialista | Implementado con cambios | `RegistroEspecialista.js`; `POST /api/especialistas` | Solo manual | Pide nombre, correo, contraseña y **código de institución** en vez de cédula, especialidad e institución (CA1–2). Sin correo de verificación (CA3). |
| HU12 | Inicio de sesión del especialista | Implementado con cambios | `Login.js`, `RecuperarPassword.js`, `firebase.js` | Solo manual | CA1–3 ✓. Bloqueo (CA4) por Firebase. En lugar de expirar a los 30 min de inactividad (CA5), la sesión dura lo que la pestaña. |
| HU13 | Estado de todos los pacientes | Implementado con cambios | `Dashboard.js`, `PacientesList.js`, `PacientesComun.js` | Unitaria: `actividad.test.js`, `sesiones.test.js`, `semaforo.test.js`, `components.test.js` (3) | Tabla con avatar, estado de la última sesión con color, fecha, búsqueda y filtro, y clic al detalle (CA1–5). El "nivel" es contra la **línea base individual** (C5) y existe "Sin estado" mientras se calibra. |
| HU14 | Historial de registros de un paciente | Implementado con cambios | `SesionesPaciente.js`, `SesionDetalle.js`; `GET /api/sesiones/:pacienteId[/:sesionId]` | Unitaria: `sesiones.test.js` (21); script `prueba_sesiones.ps1` (lista y detalle por rol) | CA1, CA2 y CA4 ✓. Sin filtro por rango (CA3) ni exportación PDF/Excel (CA5). |
| HU15 | Métricas clínicas y KPIs del paciente | Implementado con cambios | `SesionesPaciente.js` (KPIs de 30 días, gráfica HRV/FC con rango habitual), `SesionDetalle.js` (z, banda); `GET /api/linea-base/:pacienteId` | Unitaria: `linea_base.test.js` (15), `linea_base_vista.test.js` (8), `sesiones.test.js`; script `prueba_sesiones.ps1` (sección de línea base) | Se compara contra la **línea base individual**, no contra rangos clínicos generales (CA2). No hay "índice de ansiedad consolidado" (CA3). Sin alertas con umbrales configurables (CA5). |
| HU16 | Envío de indicaciones a pacientes | Implementado con cambios | `EjerciciosPaciente.js`; `POST/GET /api/ejercicios` | Solo manual (Fase 2c); el 403 a un especialista no vinculado está pendiente | Técnica del catálogo o texto ≤ 500 + nota (CA1 sin texto enriquecido; CA5 ✓). Historial ✓ (CA3). Estado "visto / aún no lo ve" (CA4 parcial). Llega por sondeo de ≤ 45 s (CA2 ✓). |
| HU17 | Mensajería con pacientes | Implementado con cambios | `ChatPaciente.js` dentro de `PacienteDetalle.js`; Socket.io | Solo manual | Hilo por paciente, envío, tiempo real dentro del detalle e historial (CA1–3, CA5). **Sin estado enviado/leído** (CA4). |
| HU18 | Gestión de pacientes (vincular, consultar, desvincular) | Implementado con cambios | `CodigoVinculacion.js`; `POST/GET /api/vinculacion`; admin `PUT /api/admin/usuarios/:id` | Solo manual | El paciente se vincula con el código del especialista (C10), en vez de que el especialista lo invite (CA1–2). Desvincular solo lo hace el admin (CA4). Sin registro histórico de vinculaciones (CA5). |
| HU19 | Gestión del perfil del especialista | Implementado con cambios | `PerfilEspecialista.js`; `PUT /api/usuarios/:id` | Solo manual (403/200 por comando, Fase 2e) | Edita nombre y cambia la contraseña confirmando la actual (CA4 ✓). Sin foto, cédula, especialidad ni institución (CA2). |

---

## 6. Funcionalidad construida que el TT1 no pedía

Sirve para el capítulo de pruebas como "requerimientos emergentes".

| Funcionalidad | Dónde vive | Evidencia de prueba |
|---|---|---|
| Línea base individual (Ln RMSSD, 7 días, por origen) y estado Normal / Elevados / Altos solo para el especialista | `backend/linea_base.js`, `linea_base_vista.js`; `GET /api/linea-base/:pacienteId` | Unitaria: `linea_base.test.js` (15), `linea_base_vista.test.js` (8); script `prueba_sesiones.ps1` |
| EVA 0–10 post-medición con contexto | `respuestas_eva`; `POST /api/sesiones/:sesionId/eva` | Script: `prueba_sesiones.ps1` (13 casos); unitaria `eva_test.dart` (12) |
| Modo simulación (sin hardware) | `repositories/simulador_sensor.dart` | Unitaria: `simulador_sensor_test.dart` (3) |
| Mascota de acompañamiento ("día X de 7") | `lib/medicion/mensajes_mascota.dart`, `avatar_widgets.dart` | Unitaria: `mensajes_mascota_test.dart` (16) |
| Aviso de SpO2 baja (regla de seguridad, no de ansiedad) | `app_config.dart` | Solo manual |
| Rol administrador con borrado lógico y estado de cuenta | `backend/admin.js`, `AdminUsuarios.js` | Solo manual |
