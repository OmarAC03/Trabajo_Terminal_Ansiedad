# 02 · Inventario de la implementación (lo construido hoy)

> Base para el capítulo de implementación.
> Estado del código: commit `9ccb954` (2026-10-31). Inventario hecho el 2026-11-03 leyendo el repositorio.
> **No se corrieron pruebas ni builds**: los conteos salen de leer los archivos de prueba, y los resultados de ejecución son los últimos que quedaron registrados en `CONTEXTO_PROYECTO.md`.
>
> **Actualización 2026-11-04 (Bloque 1, cuentas: commits `38148ea`, `0e3eae2`, `4b6ef04`):** suspensión de cuentas, consentimiento y solicitud de eliminación. Tablas, endpoints, pantallas y suites de este documento ya los incluyen. Las tres suites se corrieron en esta actualización (backend 82/82, portal 61/61, app 208/208). Los scripts `.ps1` siguen pendientes de correr antes del push.

---

## 1. Arquitectura real

```
 ESP32 + MAX30102 ──(Bluetooth clásico SPP, 1 línea JSON/s)──▶ App Flutter (Android)
   (firmware del compañero,                                     │  sesión guiada, cálculo RMSSD,
    fuera de este repo)                                         │  EVA, GAD-7, técnicas, chat
                                                                │
                                     HTTPS (REST + ID token Firebase) / WSS (Socket.io)
                                                                ▼
                                   Backend Node.js + Express 5 + Socket.io  (Render)
                                     auth.js · validation.js · linea_base.js · gad7.js · admin.js
                                                                │  pg (SQL directo)
                                                                ▼
                                                PostgreSQL (Supabase, RLS desactivado)
                                                                ▲
                                     HTTPS / WSS               │
 Portal web React (Render) ─────────────────────────────────────┘
   especialista: dashboard, pacientes, sesiones, GAD-7, ejercicios, chat, perfil
   admin: usuarios

 Firebase Authentication: cuentas de los tres roles (correo + contraseña, restablecimiento).
```

### Diferencias de arquitectura contra el TT1 (§4.1)

| Tema | Propuesto en el TT1 | Construido |
|---|---|---|
| Enlace sensor–app | BLE GATT, 1 paquete/minuto | Bluetooth clásico SPP, 1 línea JSON/segundo (`CONTRATO_SENSOR.md` v1) |
| Sensores | MAX30102 + GSR + termistor NTC | Solo MAX30102 |
| Autenticación | JWT propio (`/auth/login`, `/auth/refresh`) | Firebase Auth. El backend verifica el ID token con `firebase-admin` y lee el rol de `usuarios`. |
| Autorización | RLS de Supabase | En el backend, por ruta (`autorizarLecturaPaciente`, `autorizarPerfilPropio`, `esPacienteVinculado`, `requiereAdmin`; en `especialista.js`, solo el especialista vinculado). RLS desactivado, salvo en las 4 tablas del Bloque 2 (activado sin políticas: la API REST de Supabase no las lee). |
| Caché en tiempo real | Firebase Realtime Database (último score) | No se usa. El portal sondea `GET /api/pacientes` cada 15 s y el chat va por Socket.io. |
| Hosting del portal | Vercel | Render |
| Archivos / reportes | Bóveda de Supabase (Storage) | No se usa (no hay exportación). |
| Cliente HTTP de la app | `dio` con retroceso exponencial | `http` + `ApiClient` propio (20 s por intento, 2 reintentos con espera creciente, solo ante timeout o sin conexión) |
| Persistencia local | Buffer offline de 72 h | Ninguna. La sesión vive en memoria hasta subirse. |
| Eventos Socket.io | `score:updated`, `measurement:received`, `alert:triggered`, `indication:read`, `connection:status` | Solo el chat: `enviar_mensaje` (cliente → servidor, con ack) y `recibir_mensaje` (servidor → salas `usuario:<uid>`) |

## 2. Stack y dependencias principales

| Componente | Tecnología | Dependencias clave (versión declarada) |
|---|---|---|
| App móvil (`app_ansiedad/`) | Flutter / Dart (`sdk ^3.11.5`), Android | `provider` ^6.1.2, `firebase_core` ^2.27.0, `firebase_auth` ^4.17.4, `http` ^1.6.0, `socket_io_client` ^3.0.2, `flutter_classic_bluetooth` 1.7.0, `permission_handler` ^12.0.1, `fl_chart` ^1.2.0, `flutter_tts` ^4.2.0, `audioplayers` ^6.1.0, `wakelock_plus` ^1.5.2 |
| Backend (`backend/`) | Node.js, CommonJS | `express` ^5.2.1, `socket.io` ^4.8.3, `pg` ^8.20.0, `firebase-admin` ^13.0.0, `cors` ^2.8.6, `dotenv` ^17.4.2; pruebas con `node --test` (sin dependencia extra) |
| Portal (`web_portal/`) | React 19 (Create React App, `react-scripts` 5.0.1) | `firebase` ^11.0.2, `axios` ^1.15.2, `socket.io-client` ^4.8.3, `recharts` ^3.10.1, `lucide-react` ^1.14.0; pruebas con Jest + Testing Library |
| Base de datos | PostgreSQL en Supabase (plan gratuito) | Tablas creadas a mano en el SQL Editor (no hay migraciones en el repo) |
| Identidad | Firebase Authentication | Mismo proyecto para la app y el portal |

### Organización interna

**App** (patrón por capas con Provider):

| Carpeta | Contenido |
|---|---|
| `models/` | 14 modelos |
| `repositories/` | 14 archivos: HTTP, Socket.io, Bluetooth, intérprete del sensor, simulador |
| `providers/` | 13 providers con el estado |
| `screens/` | 15 pantallas |
| `medicion/` | Cálculo de la sesión, estado del sensor, mensajes de la mascota |
| `contenido/` | Textos del GAD-7, textos educativos y aviso de privacidad / consentimiento (borrador) |
| raíz | `api_client.dart` (cliente HTTP; cierra la sesión si la cuenta está bloqueada), `sesion.dart`, `cuenta_bloqueada.dart`, `auth_gate.dart` (con la puerta de consentimiento) |
| `ui/` | Tema, colores y widgets compartidos |

**Backend** (lógica pura separada de las rutas, para poder probarla):

| Archivo | Qué hace |
|---|---|
| `server.js` | Rutas y Socket.io |
| `auth.js` | Verificación del token y resolución del rol |
| `validation.js` | Validación de cada payload (400 antes de tocar la base) |
| `linea_base.js` + `linea_base_vista.js` | Cálculo de la línea base y qué ve cada rol |
| `gad7.js` + `gad7_vista.js` | Puntaje, severidad, intervalo y qué ve cada rol |
| `admin.js` | Router del rol admin: usuarios, suspender / reactivar, solicitudes de eliminación |
| `cuentas.js` | Bloqueo de cuentas suspendidas o eliminadas y candados de suspensión |
| `consentimiento.js` | Versión vigente del aviso y el consentimiento, validación y bloqueo de la captura |
| `eliminacion.js` | Qué se borra y qué se conserva al atender una eliminación |
| `errors.js`, `logger.js` | Errores con código HTTP (y `codigo` estable opcional) y log JSON |

**Portal**: componentes por pantalla con lógica pura en módulos aparte (`sesiones.js`, `gad7.js`, `actividad.js`, `semaforo.js`, `cuentas.js`, `solicitudes.js`) y una base visual en `src/ui/` (`tokens.css`, `ui.css`, `components.js`, `Layout.js`, `AuthLayout.js`).

---

## 3. Base de datos: tablas reales vs. propuestas en el TT1

### 3.1 Tablas reales (Supabase)

| Tabla | Columnas | Restricciones / notas | Fase |
|---|---|---|---|
| `usuarios` | `id` (varchar(50) = uid de Firebase), `nombre`, `email`, `rol`, `fecha_registro`, `especialista_id`, `codigo_vinculacion`, `ultima_apertura_mensajes`, `ultima_apertura_ejercicios`, `suspendido` (bool, def. false), `eliminado_en` (timestamptz) | `CHECK usuarios_rol_check` (`paciente`/`especialista`/`admin`); `fk_especialista` → `usuarios.id` `ON DELETE SET NULL`; `email` UNIQUE. Desde el Bloque 1, `suspendido` y `eliminado_en` bloquean el acceso; una cuenta eliminada queda como lápida (`'Cuenta eliminada'`, `eliminada-<id>@invalid`) | Base + 4ter + 2c + Fase C + Bloque 1 |
| `lecturas_biometricas` | `id` uuid, `paciente_id`, `bpm`, `spo2`, `hrv`, `score_ansiedad`, `estado_ansiedad` (`Alta`/`Moderada`/`Baja`), `fecha_medicion` | **Histórica**: método anterior de lecturas sueltas. Ya no la muestran la app ni el portal; sigue en la base y en `/api/lecturas`. | Inicial |
| `sesiones_medicion` | `id` uuid, `paciente_id`, `fecha_inicio`, `fecha_registro`, `duracion_total_seg`, `duracion_valida_seg`, `hrv_rmssd`/`hrv_min`/`hrv_max`, `bpm_promedio`/`bpm_min`/`bpm_max`, `spo2_promedio`/`spo2_min`/`spo2_max`, `indice_calidad` (0–1), `serie` (jsonb, ≤ 360 puntos `{t,bpm,spo2,hrv}`), `origen` (`simulacion`/`sensor`) | CHECK `chk_sesion_*` replicados en `validarSesion`. El mínimo de 120 s válidos vive solo en `validation.js`. | M1a |
| `respuestas_eva` | `id` uuid, `sesion_id`, `valor` (smallint 0–100), `contexto` (varchar(30), NULL), `fecha_respuesta` | `uq_eva_sesion` UNIQUE (una EVA por sesión → 409); `fk_eva_sesion` → `sesiones_medicion(id)`; `chk_eva_valor`, `chk_eva_contexto` | M2 |
| `respuestas_gad7` | `id` uuid, `paciente_id`, `item1`…`item7` (smallint 0–3), `dificultad` (0–3, NULL), `version` (`gad7-es-v1`), `fecha_respuesta` | `fk_gad7_paciente`, `chk_gad7_*`; índice `idx_gad7_paciente_fecha`. **El puntaje y la severidad no se guardan**: se calculan al leer. | M5a |
| `mensajes_chat` | `id` uuid, `remitente_id`, `paciente_id`, `especialista_id`, `texto`, `tipo_mensaje`, `fecha_envio` | Índice `idx_mensajes_paciente_fecha`. Texto ≤ 2000 caracteres (validado en el backend). | 2b |
| `ejercicios_asignados` | `id` uuid, `paciente_id`, `especialista_id`, `tecnica_id` (slug), `texto_personalizado`, `nota`, `fecha_asignacion` | `chk_ejercicio_origen` (exactamente uno de `tecnica_id` / `texto_personalizado`); índice `idx_ejercicios_paciente_fecha` | 2c |
| `consentimientos` | `id` uuid, `usuario_id`, `version_aviso`, `version_consentimiento`, `origen` (`registro`/`inicio_sesion`), `aceptado_en` | `fk_consentimiento_usuario`, `chk_consentimiento_*`, `uq_consentimiento_version` (una fila por versión aceptada); índice `idx_consentimientos_usuario_fecha`. No se edita ni se borra (evidencia). | Bloque 1 |
| `solicitudes_eliminacion` | `id` uuid, `usuario_id`, `estado` (`pendiente`/`atendida`), `fecha_solicitud`, `atendida_en`, `atendida_por` | `fk_solicitud_usuario`, `fk_solicitud_admin`, `chk_solicitud_estado`, `chk_solicitud_atencion`; índice único parcial `uq_solicitud_pendiente` (una pendiente por usuario) | Bloque 1 |
| `notas_clinicas` | `id` uuid, `paciente_id`, `especialista_id`, `fecha` (date), `contenido` (1–5000), `version`, `creada_en`, `editada_en` | FK a `usuarios`; índice `idx_notas_par_fecha`. Sin borrado (salvo con la cuenta del paciente). RLS activado sin políticas. | Bloque 2 |
| `notas_clinicas_versiones` | `id` identity, `nota_id`, `version`, `fecha`, `contenido`, `escrita_en`, `reemplazada_en` | FK a `notas_clinicas` `ON DELETE CASCADE`; `uq_nota_version`; trigger `trg_notas_versiones_inmutables` (sin UPDATE). RLS activado sin políticas. | Bloque 2 |
| `marcadores_clinicos` | `id` uuid, `paciente_id`, `especialista_id`, `fecha` (timestamptz), `tipo`, `descripcion` (≤ 140), `creado_en` | CHECK de `tipo` (`consulta`, `periodo_examenes`, `evento_personal`, `intervencion`, `otro`); índice `idx_marcadores_par_fecha`. RLS activado sin políticas. | Bloque 2 |
| `bitacora` | `id` identity, `fecha`, `actor_id`, `actor_rol`, `accion`, `objetivo_id`, `detalle` (jsonb) | CHECK de `accion` (11 acciones) y de `detalle` (objeto); **sin FK** a propósito; 4 índices; triggers `trg_bitacora_sin_update_delete` y `trg_bitacora_sin_truncate` (solo inserción). RLS activado sin políticas. | Bloque 2 |

**La línea base no es una tabla**: se calcula al leer, a partir de `sesiones_medicion` (`linea_base.js`, versión de parámetros `m3-v1`).

### 3.2 Comparación con el modelo del TT1 (Tablas 54, 55 y 60–65)

| Entidad del TT1 | Qué existe hoy |
|---|---|
| `usuario` + `paciente` + `especialista` + `administrador` (3FN, una tabla por rol) | Una sola tabla `usuarios` con la columna `rol` (paciente sin edad, sexo ni contacto; especialista sin cédula ni especialidad) |
| `asignacion_especialista_paciente` (con vigencia e historial) | `usuarios.especialista_id` (vínculo vigente, sin historial) + `codigo_vinculacion` |
| `dispositivo`, `sensor` (catálogo), `vinculacion_dispositivo` | No existen. Solo `sesiones_medicion.origen`. |
| `sesion_monitoreo` | `sesiones_medicion` (sin `dispositivo_id` ni estado activa/cerrada: se guarda ya terminada) |
| `medicion_minuto` (+ `tipo_indicador`, RR como `INTEGER[]`, `quality_flag`, `UNIQUE (paciente_id, timestamp)`) | `sesiones_medicion.serie` (jsonb submuestreado) + `indice_calidad`. Los RR crudos no se guardan. |
| `lote_sincronizacion` | No existe. |
| `consentimiento` | `consentimientos` (versión del aviso y del consentimiento, fecha y origen; sin estado "revocado": revocar = solicitar la eliminación) |
| *(no estaba en el TT1)* | `solicitudes_eliminacion` (RF-19 / RF-34) |
| `cuestionario` (catálogo) + `respuesta_cuestionario` | Una tabla por instrumento: `respuestas_gad7` (versión en columna) y `respuestas_eva` (ligada a la sesión) |
| `indicacion` (estado enviada/leída/completada) | `ejercicios_asignados` ("visto" derivado de `usuarios.ultima_apertura_ejercicios`) |
| *(no estaba en el TT1)* | `mensajes_chat` |
| `nota_clinica` | `notas_clinicas` + `notas_clinicas_versiones` (historial inmutable) |
| `evento` | `marcadores_clinicos` (los marca el especialista) |
| `regla_evento` | No existe (no hay eventos automáticos). |
| `auditoria` | `bitacora` (solo inserción, sin contenido clínico) |
| `exportacion_reporte` | No es tabla: cada exportación queda en `bitacora` (`accion = 'exportacion'`, con formato, periodo y si fue seudonimizada) |
| Políticas RLS (Tabla 65) | RLS desactivado en las tablas anteriores; activado **sin políticas** en las 4 del Bloque 2. La autorización está en el backend. |
| PK UUID en todas las tablas | UUID en todas salvo `usuarios.id`, que es el uid de Firebase (varchar(50)) |

---

## 4. Endpoints

Todo `/api/*` exige `Authorization: Bearer <ID token de Firebase>` (`requiereAuth`). Todo `/api/admin/*` exige además el rol `admin`. Los errores salen de un único middleware: 400 (validación), 401/403 (autorización), 404, 409 y 500.

### Lecturas biométricas (históricas)

| Método y ruta | Quién | Qué hace |
|---|---|---|
| `POST /api/lecturas` | el propio usuario (`paciente_id` = uid) | Guarda una lectura suelta (método anterior) |
| `GET /api/lecturas` | especialista | Todas las lecturas |
| `GET /api/lecturas/:pacienteId?limite=` | dueño o especialista vinculado | Lecturas de un paciente |
| `GET /api/lecturas/:pacienteId/resumen?periodo=semana\|mes` | ídem | Agregado por día; periodo actual y anterior |

### Sesiones, EVA y línea base

| Método y ruta | Quién | Qué hace |
|---|---|---|
| `POST /api/sesiones` | paciente | Guarda una sesión (`validarSesion`). Responde la `evaluacion` y la `calibracion`, sin etiqueta para el paciente. |
| `GET /api/sesiones/:pacienteId?limite=` | dueño o especialista vinculado | Lista ligera (sin `serie`), con la evaluación de cada sesión y la EVA |
| `GET /api/sesiones/:pacienteId/:sesionId` | ídem | Detalle con `serie`. 404 también si la sesión es de otro paciente. |
| `POST /api/sesiones/:sesionId/eva` | paciente dueño | EVA 0–10 + contexto, dentro de una ventana de 15 min. 409 si ya se respondió. |
| `GET /api/linea-base/:pacienteId` | dueño o especialista vinculado | Calibración de hoy por origen. La banda y la `n` solo van al especialista. |

### GAD-7

| Método y ruta | Quién | Qué hace |
|---|---|---|
| `POST /api/gad7` | paciente vinculado | Guarda la respuesta en una transacción `FOR UPDATE`. 409 si aún no le toca (cada 14 días). Responde sin resultado. |
| `GET /api/gad7/:pacienteId` | dueño o especialista vinculado | Paciente: solo `estado`. Especialista: `estado` + `respuestas` (puntaje, severidad, valorar). |

### Usuarios, vinculación y pacientes

| Método y ruta | Quién | Qué hace |
|---|---|---|
| `POST /api/usuarios` | token sin fila todavía | Alta del paciente tras crear su cuenta en Firebase; con `consentimiento` opcional, que se guarda en la misma transacción |
| `POST /api/especialistas` | token sin fila + código de institución | Alta del especialista; genera su `codigo_vinculacion` |
| `GET /api/usuarios/:id` | solo el propio | Perfil (incluye `codigo_vinculacion`) |
| `PUT /api/usuarios/:id` | solo el propio | Editar el nombre |
| `POST /api/vinculacion` | paciente | Vincularse con el código del especialista |
| `GET /api/vinculacion` | paciente | Estado del vínculo y nombre del especialista |
| `GET /api/pacientes` | especialista | Sus pacientes, con la última lectura, la última sesión (estado, etapa), `sesiones_7d` y el último GAD-7 |

### Consentimiento y eliminación de cuenta (Bloque 1)

| Método y ruta | Quién | Qué hace |
|---|---|---|
| `GET /api/consentimiento` | cualquiera registrado | `{ requerido, version_aviso, version_consentimiento, aceptado, aceptado_en }`. Solo el paciente lo requiere. |
| `POST /api/consentimiento` | paciente | Acepta la versión vigente (otra versión → 400). 201 la primera vez; repetido → 200 sin duplicar. |
| `GET /api/solicitud-eliminacion` | paciente | Su solicitud más reciente (estado y fechas) o `null` |
| `POST /api/solicitud-eliminacion` | paciente | Registra la solicitud (sin datos). 409 si ya hay una pendiente. |

Sin el consentimiento vigente, `POST /api/sesiones`, `POST /api/sesiones/:id/eva`, `POST /api/gad7` y `POST /api/lecturas` responden **403 `consentimiento_requerido`**. Una cuenta suspendida o eliminada recibe **403 `cuenta_suspendida` / `cuenta_eliminada`** en cualquier ruta, y su socket se rechaza.

### Mensajes, ejercicios y pendientes

| Método y ruta | Quién | Qué hace |
|---|---|---|
| `GET /api/mensajes/:pacienteId` | dueño o especialista vinculado | Últimos 200 mensajes del vínculo actual |
| `POST /api/ejercicios` | especialista vinculado | Asignar una técnica (slug) o un texto libre + nota |
| `GET /api/ejercicios/:pacienteId` | dueño o especialista vinculado | Ejercicios del vínculo actual, con "visto" |
| `GET /api/pendientes` | paciente | Contadores de mensajes y ejercicios nuevos (para los badges) |
| `POST /api/pendientes/:seccion/visto` | paciente | Marca `mensajes` o `ejercicios` como vistos; devuelve la marca anterior |

### Administración

| Método y ruta | Quién | Qué hace |
|---|---|---|
| `GET /api/admin/usuarios` | admin | Todas las cuentas: rol, estado (activa/suspendida/eliminada), vínculo y `solicitud_pendiente`. Sin datos clínicos. |
| `PUT /api/admin/usuarios/:id` | admin | Editar nombre, correo (Firebase + base, con compensación) y especialista (null = desvincular) |
| `POST /api/admin/usuarios/:id/suspender` | admin | Suspende: base + Firebase `disabled` + revocación de tokens + cierre de sus sockets. No a sí mismo, nunca cero admins. Idempotente. |
| `POST /api/admin/usuarios/:id/reactivar` | admin | Reactiva (una eliminada → 409). Idempotente. |
| `GET /api/admin/solicitudes-eliminacion` | admin | Solicitudes con nombre, correo, estado y fechas (pendientes primero). Sin datos clínicos. |
| `POST /api/admin/solicitudes-eliminacion/:id/atender` | admin | Ejecuta la eliminación: borra lo clínico y la comunicación (también notas y marcadores), anonimiza la fila y borra la cuenta de Firebase. Solo pacientes; repetirlo reintenta el borrado en Firebase. |
| `GET /api/admin/bitacora?desde&hasta&usuario&accion&antes_de&limite` | admin | Bitácora, más recientes primero, paginada con cursor. Sin contenido clínico. |

### Herramientas del especialista (Bloque 2, `backend/especialista.js`, montado en `/api/pacientes`)

Solo el especialista vinculado actual (paciente y admin → 403); todo filtrado por el par paciente–especialista.

| Método y ruta | Quién | Qué hace |
|---|---|---|
| `GET /api/pacientes/:id/notas` | especialista vinculado | Notas del par en su versión vigente, por fecha clínica |
| `POST /api/pacientes/:id/notas` | especialista vinculado | Crea una nota `{ fecha, contenido }` (y su entrada en la bitácora) |
| `PUT /api/pacientes/:id/notas/:notaId` | especialista vinculado | Edita con `version`; guarda la anterior. Versión vieja → 409 `nota_desactualizada` |
| `GET /api/pacientes/:id/notas/:notaId/versiones` | especialista vinculado | Versiones anteriores de la nota |
| `GET /api/pacientes/:id/marcadores` | especialista vinculado | Marcadores del par |
| `POST /api/pacientes/:id/marcadores` | especialista vinculado | Crea `{ fecha, tipo, descripcion? }` |
| `DELETE /api/pacientes/:id/marcadores/:marcadorId` | su autor | Lo borra (queda en la bitácora) |
| `GET /api/pacientes/:id/reporte?desde&hasta&formato&seudonimizado` | especialista vinculado | Datos del periodo para el CSV o el PDF; registra la exportación antes de responder |

### Socket.io (mismo servidor, token en el handshake)

| Evento | Dirección | Qué hace |
|---|---|---|
| `enviar_mensaje` | cliente → servidor | Valida el vínculo y guarda el mensaje. El servidor pone `remitente_id` y `especialista_id`. Responde por ack `{ ok, error }`. |
| `recibir_mensaje` | servidor → clientes | Se emite solo a las salas `usuario:<paciente>` y `usuario:<especialista vinculado>` |

**Total: 42 rutas REST** (27 en `server.js` + 7 en `admin.js` + 8 en `especialista.js`) **y 2 eventos de Socket.io.**

---

## 5. Pantallas

### 5.1 App móvil (5 pestañas en `main_layout.dart`)

| Pestaña / flujo | Pantalla(s) | Contenido |
|---|---|---|
| Acceso | `login_screen.dart`, `registro_screen.dart`, `recuperar_password_screen.dart` (+ `auth_gate.dart`) | Login con error genérico (y aviso si el servidor cerró la sesión por cuenta suspendida o eliminada), registro transaccional con la casilla del aviso de privacidad, restablecer contraseña |
| Puerta de consentimiento | `consentimiento_screen.dart` (dentro de `auth_gate.dart`) | Si el paciente no aceptó la versión vigente: aviso de privacidad + consentimiento (BORRADOR), dos casillas, "Aceptar y continuar" o "Cerrar sesión". Sin aceptar no ve la app. |
| **Inicio** | `inicio_screen.dart` | Saludo, selector Simulación / Sensor, estado de la conexión, botón "Iniciar medición", última sesión con explicación de cada indicador, mascota de calibración ("día X de 7"), tarjeta del GAD-7 cuando le toca, disclaimer |
| Medición (pantalla completa) | `medicion_screen.dart` | Preparación → captura (anillo de progreso y guía, sin valores en vivo) → EVA 0–10 + contexto → resultado (promedios, sin semáforo) → envío / reintentar |
| Cuestionario | `gad7_screen.dart` | Intro → 7 preguntas → dificultad (solo si algún ítem > 0) → gracias, **sin resultado** |
| **Historial** | `historial_screen.dart`, `sesion_detalle_screen.dart` | Sesiones agrupadas por día; detalle con gráficas de la serie y la EVA |
| **Mensajes** | `mensajes_screen.dart` | Chat con el especialista (o aviso + "Vincular especialista") |
| **Técnicas** | `tecnicas_screen.dart`, `ejercicios_asignados_screen.dart` | 4 técnicas con animación, voz y música; tarjeta de ejercicios asignados con badge |
| **Perfil** | `perfil_screen.dart`, `vinculacion_screen.dart`, `eliminar_cuenta_screen.dart` | Avatar, nombre, rol, especialista vinculado, Privacidad (releer el aviso, "Eliminar mi cuenta"), "Acerca de la app", cerrar sesión |

### 5.2 Portal web — especialista (`App.js`, `ui/Layout.js`)

| Sección | Componente(s) | Contenido |
|---|---|---|
| Acceso | `Login.js`, `RegistroEspecialista.js`, `RecuperarPassword.js` (`ui/AuthLayout.js`) | Login, registro con código de institución, restablecer contraseña (`continueUrl` al dominio publicado) |
| Dashboard | `Dashboard.js` | KPIs de actividad, estado de la última sesión (barra apilada), tabla de pacientes |
| Pacientes | `PacientesList.js`, `PacientesComun.js` | Tabla con búsqueda y filtro, columnas de estado y GAD-7 |
| Detalle del paciente | `PacienteDetalle.js` + `SesionesPaciente.js`, `MarcadoresPanel.js`, `SesionDetalle.js`, `Gad7Paciente.js`, `NotasPaciente.js`, `EjerciciosPaciente.js`, `ExportarReporte.js` (+ `ReporteImpresion.js`), `ChatPaciente.js` | Encabezado; línea base por origen; gráfica HRV/FC con eje de tiempo y marcadores clínicos; tabla de sesiones con estado, calidad y EVA; detalle de una sesión; GAD-7; notas clínicas con historial; ejercicios; exportar reporte (CSV / imprimir-PDF, con o sin seudonimizar); chat en vivo |
| Mi perfil | `PerfilEspecialista.js`, `CodigoVinculacion.js` | Nombre, código de vinculación con botón copiar, cambio de contraseña |

### 5.3 Portal web — administrador (`AdminApp.js`)

| Sección | Componente(s) | Contenido |
|---|---|---|
| Usuarios | `AdminUsuarios.js`, `EditarUsuario.js` | Lista de cuentas con rol, estado, vínculo y "Solicitó eliminación"; edición de nombre, correo y especialista; "Estado de la cuenta" con Suspender / Reactivar (con confirmación) |
| Solicitudes de eliminación | `AdminSolicitudes.js` | Lista con contador en el sidebar; "Atender" muestra qué se borra y qué se conserva, y pide escribir el correo de la cuenta |
| Bitácora | `AdminBitacora.js` | Filtros (desde, hasta, usuario, acción), tabla de quién, qué, sobre quién y cuándo, y "Cargar más" |
| Mi perfil | `PerfilEspecialista.js` (reusado) | — |

---

## 6. Despliegue

| Pieza | Dónde | URL / dato |
|---|---|---|
| Backend (API + Socket.io) | Render, plan gratuito | `https://tt-ansiedad-backend.onrender.com` |
| Portal web | Render (build de Create React App), publicado con el commit `9ccb954` | **`https://monitor-ansiedad-escom.onrender.com`** |
| Base de datos | Supabase (PostgreSQL), plan gratuito | Conexión por `DATABASE_URL` |
| Autenticación | Firebase Authentication | El dominio del portal debe estar en *Authorized domains* para el `continueUrl` |
| App móvil | APK de Android instalado por USB (`flutter install`) | APK release; **todavía firmado con la llave de depuración** (firmar con llave propia está pendiente) |

**Variables de entorno del backend** (en Render, no en el repo): `DATABASE_URL`, `FIREBASE_SERVICE_ACCOUNT_JSON`, `CODIGO_INSTITUCION` y `PORT`.

**Portal**: `REACT_APP_API_URL` es opcional (por defecto apunta al backend de Render, `src/config.js`).

**Ajustes de publicación del portal** (`9ccb954`):

- `continueUrl` en el restablecimiento de contraseña;
- sesión por pestaña (`browserSessionPersistence`), porque el portal se usa en computadoras compartidas;
- `noindex` y `robots.txt` con `Disallow: /`.

**Limitaciones operativas**:

- Render (gratuito) se duerme tras unos 15 min sin uso; la primera petición tarda de 30 a 50 s. La app lo absorbe con reintentos.
- Supabase (gratuito) se pausa por inactividad.
- Antes de una demostración hay que despertar ambos.

**No hay CI/CD** (GitHub Actions). Render despliega el backend desde `main`. La configuración de los servicios vive en el dashboard de Render: no hay `render.yaml` en el repo.

---

## 7. Suites de pruebas

### 7.1 Pruebas automatizadas (contadas en los archivos, 2026-11-04)

**Backend — `node --test` (`npm test` en `backend/`): 131 pruebas**

| Archivo | Pruebas | Qué cubre |
|---|---:|---|
| `gad7.test.js` | 18 | Fronteras de severidad (4/5, 9/10, 14/15), valorar ≥ 10, intervalo de 14 días, medianoche en México vs UTC, validación del payload |
| `gad7_vista.test.js` | 9 | Campos exactos por rol; ninguna palabra prohibida llega al paciente |
| `linea_base.test.js` | 15 | Ln RMSSD, días locales, ventana de 7/30 días, banda k1/k2, calidad mínima, origen separado |
| `linea_base_vista.test.js` | 8 | El paciente nunca recibe la etiqueta ni la banda |
| `cuentas.test.js` | 13 | Bloqueo de cuentas suspendidas o eliminadas; candados de suspensión (propia, último admin, eliminada); código en los errores |
| `consentimiento.test.js` | 10 | Versión vigente, validación, 403 `consentimiento_requerido`, qué ve cada rol |
| `eliminacion.test.js` | 9 | Qué se borra (8 tablas, en orden de FK, incluidas notas y marcadores), qué se conserva (también la bitácora), lápida anónima, solo pacientes |
| `bitacora.test.js` | 22 | Claves permitidas por acción (ninguna de contenido clínico), dedupe de accesos, filtros y paginación de la consulta del admin |
| `notas.test.js` | 7 | Validación (fecha no futura en día de México, 1–5000 caracteres reales), control de versión (409), SQL por el par y sin DELETE |
| `marcadores.test.js` | 4 | Tipos D4, fecha ISO con zona y no futura, descripción ≤ 140, SQL por el par |
| `reporte.test.js` | 5 | Seudónimo `P-` + SHA-256, periodo ≤ 366 días, versión seudonimizada sin nombre, correo, especialista ni texto libre |
| `especialista.test.js` | 11 | Rutas con base falsa: 403 a paciente, admin y otro especialista; bitácora en la misma transacción; ROLLBACK si falla; 409/404/400 |

**Portal — Jest (`npm test` en `web_portal/`): 94 pruebas**

| Archivo | Pruebas | Qué cubre |
|---|---:|---|
| `sesiones.test.js` | 21 | Formato y cálculo de sesiones, estados, gráficas |
| `gad7.test.js` | 11 | Severidad, fechas, texto del próximo GAD-7; ningún color del GAD-7 es del semáforo |
| `actividad.test.js` | 10 | Actividad de 7 días por paciente y del grupo |
| `semaforo.test.js` | 5 | Etiquetas, tonos y orden del estado |
| `ui/components.test.js` | 3 | Tono de avatar estable por identidad |
| `cuentas.test.js` | 6 | Reconocer el 403 de cuenta bloqueada, aviso de cierre, qué acción de estado se ofrece |
| `solicitudes.test.js` | 5 | Conteo de pendientes, confirmación con el correo, qué se borra y qué se conserva |
| `bitacora.test.js` | 8 | Textos de acción y detalle (nunca claves inesperadas), parámetros de consulta |
| `AdminBitacora.test.js` | 1 | Render de la bitácora: un `contenido` inesperado no se muestra |
| `notas.test.js` | 7 | Día local, texto de fechas sin corrimiento, validación del borrador, mensajes de error |
| `NotasPaciente.test.js` | 2 | Lista e historial; editar manda la versión, un 409 recarga y conserva el borrador |
| `marcadores.test.js` | 6 | Tipos D4, marcadores en la gráfica, dominio y marcas del eje de tiempo, `datetime-local` |
| `MarcadoresPanel.test.js` | 2 | Agregar (fecha ISO) y borrar con confirmación |
| `reporte.test.js` | 5 | CSV largo con BOM, sin inyección de fórmulas, versión seudonimizada, nombre de archivo |
| `ExportarReporte.test.js` | 2 | Imprimir pide la versión seudonimizada y la vista no trae el nombre; periodo inválido |

**App — `flutter test` (`app_ansiedad/`): 208 pruebas** (183 declaradas + 25 generadas en bucles)

| Archivo | Pruebas | Qué cubre |
|---|---:|---|
| `interprete_sensor_test.dart` | 27 (21 + 6 de un bucle por campo) | Contrato del sensor, firmware, `seq`, una lectura por segundo |
| `gad7_textos_test.dart` | 27 (8 + 19 de un bucle por texto) | Texto exacto `gad7-es-v1`; regla de oro en los textos |
| `calculo_sesion_test.dart` | 17 | Acumulación de la sesión, RMSSD, cortes de RR, payload |
| `inicio_test.dart` | 16 | Provider de Inicio (última sesión, GAD-7, errores) |
| `mensajes_mascota_test.dart` | 16 | Mensajes de la mascota por etapa |
| `gad7_test.dart` | 15 | Flujo del cuestionario, envío y 409 |
| `historial_test.dart` | 15 | Agrupación por día local, detalle |
| `lector_lineas_test.dart` | 13 | Armado de líneas desde bytes (UTF-8 partido, desbordes) |
| `eva_test.dart` | 12 | EVA post-medición |
| `alerta_provider_test.dart` | 11 | Elegir sensor o simulación, estados de conexión (con sensor falso) |
| `calibracion_test.dart` | 6 | Modelo de calibración de la línea base |
| `estado_sensor_test.dart` | 3 | Textos del estado del sensor |
| `simulador_sensor_test.dart` | 3 | Simulador de lecturas |
| `consentimiento_test.dart` | 12 | Puerta de consentimiento (pide, deja pasar, error → Reintentar), casillas, versiones iguales al backend, borrador |
| `eliminar_cuenta_test.dart` | 9 | Solicitud de eliminación: enviar, pendiente sin cancelar, errores, textos |
| `cuenta_bloqueada_test.dart` | 6 | Reconocer el 403 de cuenta suspendida o eliminada |

**Total automatizado: 433 pruebas** (131 + 94 + 208).

Resultado de la última corrida (2026-11-04, Bloque 2, sobre el commit `c469e89`):

- backend `npm test` 131/131;
- portal `npm test` 94/94 (`npm run build` sin avisos);
- app: sin cambios en el Bloque 2 (última corrida, Bloque 1: `flutter test` 208/208).

### 7.2 Pruebas por comando contra el backend (PowerShell)

| Script | Cobertura | Último resultado registrado |
|---|---|---|
| `backend/pruebas/prueba_sesiones.ps1` | Sesiones (validación, roles, `indice_calidad` oculto, detalle 404/400), EVA (13 casos, incluida la ventana de 15 min y el 409), `/api/pacientes` (`ultima_sesion`, `sesiones_7d`, estado), línea base por rol. 49 llamadas a `Caso`. | **47 OK / 0 FALLA** (2026-10-23, regresión de M5a) |
| `backend/pruebas/prueba_gad7.ps1` | GAD-7 por rol, validación (casos en bucle), sin vínculo (403), **carrera real 201/409**, 409 con fecha, `ultimo_gad7_*`, regla de oro en vivo. 17 llamadas a `Caso`, algunas dentro de bucles. | **21 OK / 0 FALLA** (2026-10-23, local) |
| `backend/pruebas/prueba_cuentas.ps1` | Bloque 1. Sección 1: suspender / reactivar (roles, candados, 403 con el token vigente, Firebase `USER_DISABLED`, código de un especialista suspendido). Sección 2: consentimiento (bloqueo de las 4 rutas de captura, versiones, registro con consentimiento en la misma transacción). Sección 3: solicitud y atención de la eliminación (lápida, token vigente → 403, idempotencia). Crea pacientes desechables `@example.com`. 58 llamadas a `Caso`. | **Pendiente de correr** (antes del push) |
| `backend/pruebas/prueba_especialista.ps1` | Bloque 2. Sección 1: quién entra a notas, marcadores y reporte (paciente, otro paciente, admin y especialista no vinculado → 403). Sección 2: notas (validación, versión 1 → 2, 409 con versión vieja, sin cambios no versiona, historial). Sección 3: marcadores (tipos D4, fecha futura o sin zona → 400, borrar solo el autor, 404 al repetir). Sección 4: reporte con y sin seudonimizar (sin nombre, correo, uid ni texto libre; seudónimo estable). Sección 5: bitácora como admin (cada acción quedó, sin contenido clínico, los 403 no se registran, filtros). 40 llamadas a `Caso` (50 casos; 55 con el especialista F opcional). | **Pendiente de correr** (antes del push) |
| `backend/pruebas/comun.ps1` | Funciones compartidas (`Obtener-Cuenta`, `Login-Firebase`, `Llamar`, `Caso`, `Exigir-Consentimiento`…) | — |
| `backend/pruebas/semilla_m3.js`, `semilla_gad7.js` (+ `consentimiento_prueba.js`) | Generan SQL de datos de prueba (cuentas `PRUEBA`) y su limpieza; desde el Bloque 1 incluyen el consentimiento de las cuentas `PRUEBA` | — |

Los scripts corren contra el backend **local** con cuentas de prueba y se niegan a escribir en otras cuentas.

### 7.3 Lo que solo tiene prueba manual o está pendiente

- **Probado a mano**: registro, login, recuperación de contraseña, chat, ejercicios y badges, perfil, técnicas (voz, música, animación), admin (403/403/200), `usuarios/:id` (403/200) y el flujo completo de medición en simulación.
- **Pendientes registrados**:
  - prueba con el ESP32 real (M7a paso 5);
  - prueba de aislamiento del chat con dos pacientes;
  - `POST /api/ejercicios` con especialista no vinculado → 403;
  - recepción real del correo de restablecimiento;
  - vinculación desde cero.

---

## 8. Capturas de pantalla por tomar

Sugerencia: guardarlas en `docs/tesis/capturas/`.

- **App**: tomarlas en el teléfono con la cuenta `PRUEBA - Test M3`, después de sembrar los datos (`semilla_m3.js` / `semilla_gad7.js`).
- **Portal**: tomarlas en `https://monitor-ansiedad-escom.onrender.com` con `PRUEBA - Especialista M3`.

### App móvil

| # | Archivo sugerido | Qué mostrar |
|---|---|---|
| 1 | `app_01_login.png` | Login con la banda de marca y el disclaimer |
| 2 | `app_02_registro.png` | Registro de paciente |
| 3 | `app_03_recuperar_password.png` | Restablecer contraseña (mensaje genérico) |
| 4 | `app_04_inicio_primer_uso.png` | Inicio sin mediciones |
| 5 | `app_05_inicio_calibrando.png` | Inicio con la última sesión y la mascota "día X de 7" |
| 6 | `app_06_selector_fuente.png` | Chip Simulación / Sensor |
| 7 | `app_07_estado_sensor_sin_vincular.png` | Tarjeta "Vincula TT_SENSOR_CLASICO…" + Reintentar |
| 8 | `app_08_estado_sensor_conectado.png` | Sensor conectado (con el ESP32 real, si se logra) |
| 9 | `app_09_medicion_preparacion.png` | Preparación de la medición |
| 10 | `app_10_medicion_captura.png` | Anillo de progreso con la guía |
| 11 | `app_11_medicion_mala_senal.png` | Guía en ámbar con señal mala ("Forzar mala señal") |
| 12 | `app_12_eva.png` | Deslizador de la EVA 0–10 y el contexto |
| 13 | `app_13_medicion_resultado.png` | Resultado con promedios y disclaimer |
| 14 | `app_14_historial.png` | Historial de sesiones por día |
| 15 | `app_15_sesion_detalle.png` | Detalle de la sesión con gráficas |
| 16 | `app_16_gad7_tarjeta.png` | Tarjeta "Cuestionario quincenal" en Inicio |
| 17 | `app_17_gad7_pregunta.png` | Una pregunta del GAD-7 |
| 18 | `app_18_gad7_gracias.png` | Agradecimiento sin resultado |
| 19 | `app_19_mensajes.png` | Chat con el especialista |
| 20 | `app_20_mensajes_sin_vinculo.png` | Aviso + "Vincular especialista" |
| 21 | `app_21_tecnicas.png` | Catálogo de técnicas con la tarjeta de ejercicios asignados y su badge |
| 22 | `app_22_respiracion_478.png` | Respiración 4-7-8 con la animación |
| 23 | `app_23_tecnica_pasos.png` | Técnica por pasos (grounding o relajación muscular) |
| 24 | `app_24_ejercicios_asignados.png` | Lista con "Nuevo" y la nota del especialista |
| 25 | `app_25_perfil.png` | Perfil (avatar, rol, "Acerca de la app") |
| 26 | `app_26_vinculacion.png` | Formulario del código de vinculación / "Ya estás vinculado" |
| 27 | `app_27_barra_badges.png` | Barra inferior con badges en Mensajes y Técnicas |
| 59 | `app_28_registro_consentimiento.png` | Registro con la casilla del aviso de privacidad |
| 60 | `app_29_puerta_consentimiento.png` | Puerta de consentimiento (cuenta existente) |
| 61 | `app_30_eliminar_cuenta.png` | "Eliminar mi cuenta" antes de enviar |
| 62 | `app_31_eliminar_cuenta_pendiente.png` | Solicitud enviada / pendiente |
| 63 | `app_32_login_cuenta_suspendida.png` | Login con el aviso "Tu cuenta está suspendida" |

### Portal web — especialista

| # | Archivo sugerido | Qué mostrar |
|---|---|---|
| 28 | `web_01_login.png` | Login (`AuthLayout`) |
| 29 | `web_02_registro_especialista.png` | Registro con el código de institución |
| 30 | `web_03_recuperar_password.png` | Restablecer contraseña |
| 31 | `web_04_dashboard.png` | Dashboard: KPIs, estado de la última sesión, tabla |
| 32 | `web_05_pacientes.png` | Tabla de pacientes con búsqueda y filtro (columnas Estado y GAD-7) |
| 33 | `web_06_detalle_encabezado.png` | Encabezado del detalle + tarjeta de línea base por origen |
| 34 | `web_07_grafica_hrv_fc.png` | Gráfica HRV/FC por sesión con la franja del rango habitual |
| 35 | `web_08_tabla_sesiones.png` | Tabla de sesiones con estado, calidad, origen y EVA |
| 36 | `web_09_sesion_detalle.png` | Detalle de la sesión: comparación con la línea base, z, gráficas |
| 37 | `web_10_gad7.png` | Tarjeta GAD-7: último puntaje, gráfica 0–21 con líneas 5/10/15 |
| 38 | `web_11_gad7_detalle_items.png` | Fila del historial desplegada con los 7 ítems |
| 39 | `web_12_ejercicios.png` | Asignar ejercicio + lista con "Visto por el paciente" |
| 40 | `web_13_chat.png` | Chat en vivo con el paciente |
| 41 | `web_14_perfil.png` | Mi perfil: código de vinculación y cambio de contraseña |
| 42 | `web_15_responsive.png` | Vista angosta (< 860 px) |
| 65 | `web_23_grafica_marcadores.png` | Gráfica HRV/FC con la franja y un marcador numerado, y la lista de marcadores |
| 66 | `web_24_notas_historial.png` | Notas clínicas con una nota editada y su historial abierto |
| 67 | `web_25_exportar_reporte.png` | Tarjeta "Exportar reporte" (periodo y casilla Seudonimizado) |
| 68 | `web_26_reporte_pdf.png` | Vista de impresión del reporte (o el PDF guardado), con identificación y seudonimizado |

### Portal web — administrador

| # | Archivo sugerido | Qué mostrar |
|---|---|---|
| 43 | `web_16_admin_usuarios.png` | Lista de cuentas con rol, estado y vínculo |
| 44 | `web_17_admin_editar.png` | Edición de usuario (reasignar o desvincular especialista) |
| 55 | `web_18_admin_suspender.png` | "Estado de la cuenta" y la confirmación de Suspender |
| 56 | `web_19_admin_solicitudes.png` | Solicitudes de eliminación con el contador del sidebar |
| 57 | `web_20_admin_atender.png` | Confirmación de "Atender" (qué se borra / se conserva, correo escrito) |
| 58 | `web_21_login_cuenta_suspendida.png` | Login del portal con el aviso de cuenta suspendida |
| 64 | `web_22_admin_bitacora.png` | Bitácora con filtros y entradas de nota, marcador y exportación |

### Infraestructura y pruebas (evidencia para los capítulos de implementación y pruebas)

| # | Archivo sugerido | Qué mostrar |
|---|---|---|
| 45 | `infra_01_render_backend.png` | Dashboard de Render: servicio backend "Live" con el último deploy |
| 46 | `infra_02_render_portal.png` | Dashboard de Render: servicio del portal con su URL |
| 47 | `infra_03_supabase_tablas.png` | Table Editor de Supabase con las 9 tablas |
| 48 | `infra_04_firebase_auth.png` | Firebase Authentication: usuarios (ocultar correos reales) y Authorized domains |
| 49 | `pruebas_01_backend_npm_test.png` | Salida de `npm test` en `backend/` (82/82) |
| 50 | `pruebas_02_portal_npm_test.png` | Salida de `npm test` en `web_portal/` (61/61) |
| 51 | `pruebas_03_flutter_test.png` | Salida de `flutter test` (208/208) |
| 52 | `pruebas_04_prueba_sesiones_ps1.png` | Resultado de `prueba_sesiones.ps1` |
| 53 | `pruebas_05_prueba_gad7_ps1.png` | Resultado de `prueba_gad7.ps1` (incluida la carrera 201/409) |
| 54 | `hw_01_esp32_montaje.jpg` | Foto del ESP32 + MAX30102 (cuando esté el hardware) |
| 64 | `pruebas_06_prueba_cuentas_ps1.png` | Resultado de `prueba_cuentas.ps1` (las tres secciones) |

> Las capturas 49–53 y 64 implican correr las suites. Las 55–64 son del Bloque 1 (se numeraron al final para no mover las anteriores).
