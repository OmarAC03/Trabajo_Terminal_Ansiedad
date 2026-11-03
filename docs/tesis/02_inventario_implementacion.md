# 02 · Inventario de la implementación (lo construido hoy)

> Base para el capítulo de implementación.
> Estado del código: commit `9ccb954` (2026-10-31). Inventario hecho el 2026-11-03 leyendo el repositorio.
> **No se corrieron pruebas ni builds**: los conteos salen de leer los archivos de prueba, y los resultados de ejecución son los últimos que quedaron registrados en `CONTEXTO_PROYECTO.md`.

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
| Autorización | RLS de Supabase | En el backend, por ruta (`autorizarLecturaPaciente`, `autorizarPerfilPropio`, `esPacienteVinculado`, `requiereAdmin`). RLS desactivado. |
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
| `models/` | 12 modelos |
| `repositories/` | 12 archivos: HTTP, Socket.io, Bluetooth, intérprete del sensor, simulador |
| `providers/` | 11 providers con el estado |
| `screens/` | 13 pantallas |
| `medicion/` | Cálculo de la sesión, estado del sensor, mensajes de la mascota |
| `contenido/` | Textos del GAD-7 y textos educativos |
| `ui/` | Tema, colores y widgets compartidos |

**Backend** (lógica pura separada de las rutas, para poder probarla):

| Archivo | Qué hace |
|---|---|
| `server.js` | Rutas y Socket.io |
| `auth.js` | Verificación del token y resolución del rol |
| `validation.js` | Validación de cada payload (400 antes de tocar la base) |
| `linea_base.js` + `linea_base_vista.js` | Cálculo de la línea base y qué ve cada rol |
| `gad7.js` + `gad7_vista.js` | Puntaje, severidad, intervalo y qué ve cada rol |
| `admin.js` | Router del rol admin |
| `errors.js`, `logger.js` | Errores con código HTTP y log JSON |

**Portal**: componentes por pantalla con lógica pura en módulos aparte (`sesiones.js`, `gad7.js`, `actividad.js`, `semaforo.js`) y una base visual en `src/ui/` (`tokens.css`, `ui.css`, `components.js`, `Layout.js`, `AuthLayout.js`).

---

## 3. Base de datos: tablas reales vs. propuestas en el TT1

### 3.1 Tablas reales (Supabase)

| Tabla | Columnas | Restricciones / notas | Fase |
|---|---|---|---|
| `usuarios` | `id` (varchar(50) = uid de Firebase), `nombre`, `email`, `rol`, `fecha_registro`, `especialista_id`, `codigo_vinculacion`, `ultima_apertura_mensajes`, `ultima_apertura_ejercicios`, `suspendido` (bool, def. false), `eliminado_en` (timestamptz) | `CHECK usuarios_rol_check` (`paciente`/`especialista`/`admin`); `fk_especialista` → `usuarios.id` `ON DELETE SET NULL` | Base + 4ter + 2c + Fase C |
| `lecturas_biometricas` | `id` uuid, `paciente_id`, `bpm`, `spo2`, `hrv`, `score_ansiedad`, `estado_ansiedad` (`Alta`/`Moderada`/`Baja`), `fecha_medicion` | **Histórica**: método anterior de lecturas sueltas. Ya no la muestran la app ni el portal; sigue en la base y en `/api/lecturas`. | Inicial |
| `sesiones_medicion` | `id` uuid, `paciente_id`, `fecha_inicio`, `fecha_registro`, `duracion_total_seg`, `duracion_valida_seg`, `hrv_rmssd`/`hrv_min`/`hrv_max`, `bpm_promedio`/`bpm_min`/`bpm_max`, `spo2_promedio`/`spo2_min`/`spo2_max`, `indice_calidad` (0–1), `serie` (jsonb, ≤ 360 puntos `{t,bpm,spo2,hrv}`), `origen` (`simulacion`/`sensor`) | CHECK `chk_sesion_*` replicados en `validarSesion`. El mínimo de 120 s válidos vive solo en `validation.js`. | M1a |
| `respuestas_eva` | `id` uuid, `sesion_id`, `valor` (smallint 0–100), `contexto` (varchar(30), NULL), `fecha_respuesta` | `uq_eva_sesion` UNIQUE (una EVA por sesión → 409); `fk_eva_sesion` → `sesiones_medicion(id)`; `chk_eva_valor`, `chk_eva_contexto` | M2 |
| `respuestas_gad7` | `id` uuid, `paciente_id`, `item1`…`item7` (smallint 0–3), `dificultad` (0–3, NULL), `version` (`gad7-es-v1`), `fecha_respuesta` | `fk_gad7_paciente`, `chk_gad7_*`; índice `idx_gad7_paciente_fecha`. **El puntaje y la severidad no se guardan**: se calculan al leer. | M5a |
| `mensajes_chat` | `id` uuid, `remitente_id`, `paciente_id`, `especialista_id`, `texto`, `tipo_mensaje`, `fecha_envio` | Índice `idx_mensajes_paciente_fecha`. Texto ≤ 2000 caracteres (validado en el backend). | 2b |
| `ejercicios_asignados` | `id` uuid, `paciente_id`, `especialista_id`, `tecnica_id` (slug), `texto_personalizado`, `nota`, `fecha_asignacion` | `chk_ejercicio_origen` (exactamente uno de `tecnica_id` / `texto_personalizado`); índice `idx_ejercicios_paciente_fecha` | 2c |

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
| `consentimiento` | No existe. |
| `cuestionario` (catálogo) + `respuesta_cuestionario` | Una tabla por instrumento: `respuestas_gad7` (versión en columna) y `respuestas_eva` (ligada a la sesión) |
| `indicacion` (estado enviada/leída/completada) | `ejercicios_asignados` ("visto" derivado de `usuarios.ultima_apertura_ejercicios`) |
| *(no estaba en el TT1)* | `mensajes_chat` |
| `nota_clinica`, `regla_evento`, `evento`, `auditoria`, `exportacion_reporte` | No existen. |
| Políticas RLS (Tabla 65) | RLS desactivado. La autorización equivalente está en el backend. |
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
| `POST /api/usuarios` | token sin fila todavía | Alta del paciente tras crear su cuenta en Firebase |
| `POST /api/especialistas` | token sin fila + código de institución | Alta del especialista; genera su `codigo_vinculacion` |
| `GET /api/usuarios/:id` | solo el propio | Perfil (incluye `codigo_vinculacion`) |
| `PUT /api/usuarios/:id` | solo el propio | Editar el nombre |
| `POST /api/vinculacion` | paciente | Vincularse con el código del especialista |
| `GET /api/vinculacion` | paciente | Estado del vínculo y nombre del especialista |
| `GET /api/pacientes` | especialista | Sus pacientes, con la última lectura, la última sesión (estado, etapa), `sesiones_7d` y el último GAD-7 |

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
| `GET /api/admin/usuarios` | admin | Todas las cuentas: rol, estado (activa/suspendida/eliminada) y vínculo. Sin datos clínicos. |
| `PUT /api/admin/usuarios/:id` | admin | Editar nombre, correo (Firebase + base, con compensación) y especialista (null = desvincular) |

### Socket.io (mismo servidor, token en el handshake)

| Evento | Dirección | Qué hace |
|---|---|---|
| `enviar_mensaje` | cliente → servidor | Valida el vínculo y guarda el mensaje. El servidor pone `remitente_id` y `especialista_id`. Responde por ack `{ ok, error }`. |
| `recibir_mensaje` | servidor → clientes | Se emite solo a las salas `usuario:<paciente>` y `usuario:<especialista vinculado>` |

**Total: 25 rutas REST** (23 en `server.js` + 2 en `admin.js`) **y 2 eventos de Socket.io.**

---

## 5. Pantallas

### 5.1 App móvil (5 pestañas en `main_layout.dart`)

| Pestaña / flujo | Pantalla(s) | Contenido |
|---|---|---|
| Acceso | `login_screen.dart`, `registro_screen.dart`, `recuperar_password_screen.dart` (+ `auth_gate.dart`) | Login con error genérico, registro transaccional, restablecer contraseña |
| **Inicio** | `inicio_screen.dart` | Saludo, selector Simulación / Sensor, estado de la conexión, botón "Iniciar medición", última sesión con explicación de cada indicador, mascota de calibración ("día X de 7"), tarjeta del GAD-7 cuando le toca, disclaimer |
| Medición (pantalla completa) | `medicion_screen.dart` | Preparación → captura (anillo de progreso y guía, sin valores en vivo) → EVA 0–10 + contexto → resultado (promedios, sin semáforo) → envío / reintentar |
| Cuestionario | `gad7_screen.dart` | Intro → 7 preguntas → dificultad (solo si algún ítem > 0) → gracias, **sin resultado** |
| **Historial** | `historial_screen.dart`, `sesion_detalle_screen.dart` | Sesiones agrupadas por día; detalle con gráficas de la serie y la EVA |
| **Mensajes** | `mensajes_screen.dart` | Chat con el especialista (o aviso + "Vincular especialista") |
| **Técnicas** | `tecnicas_screen.dart`, `ejercicios_asignados_screen.dart` | 4 técnicas con animación, voz y música; tarjeta de ejercicios asignados con badge |
| **Perfil** | `perfil_screen.dart`, `vinculacion_screen.dart` | Avatar, nombre, rol, especialista vinculado, "Acerca de la app", cerrar sesión |

### 5.2 Portal web — especialista (`App.js`, `ui/Layout.js`)

| Sección | Componente(s) | Contenido |
|---|---|---|
| Acceso | `Login.js`, `RegistroEspecialista.js`, `RecuperarPassword.js` (`ui/AuthLayout.js`) | Login, registro con código de institución, restablecer contraseña (`continueUrl` al dominio publicado) |
| Dashboard | `Dashboard.js` | KPIs de actividad, estado de la última sesión (barra apilada), tabla de pacientes |
| Pacientes | `PacientesList.js`, `PacientesComun.js` | Tabla con búsqueda y filtro, columnas de estado y GAD-7 |
| Detalle del paciente | `PacienteDetalle.js` + `SesionesPaciente.js`, `SesionDetalle.js`, `Gad7Paciente.js`, `EjerciciosPaciente.js`, `ChatPaciente.js` | Encabezado; línea base por origen; gráfica HRV/FC por sesión; tabla de sesiones con estado, calidad y EVA; detalle de una sesión; GAD-7; ejercicios; chat en vivo |
| Mi perfil | `PerfilEspecialista.js`, `CodigoVinculacion.js` | Nombre, código de vinculación con botón copiar, cambio de contraseña |

### 5.3 Portal web — administrador (`AdminApp.js`)

| Sección | Componente(s) | Contenido |
|---|---|---|
| Usuarios | `AdminUsuarios.js`, `EditarUsuario.js` | Lista de cuentas con rol, estado y vínculo; edición de nombre, correo y especialista |
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

### 7.1 Pruebas automatizadas (contadas en los archivos, 2026-11-03)

**Backend — `node --test` (`npm test` en `backend/`): 50 pruebas**

| Archivo | Pruebas | Qué cubre |
|---|---:|---|
| `gad7.test.js` | 18 | Fronteras de severidad (4/5, 9/10, 14/15), valorar ≥ 10, intervalo de 14 días, medianoche en México vs UTC, validación del payload |
| `gad7_vista.test.js` | 9 | Campos exactos por rol; ninguna palabra prohibida llega al paciente |
| `linea_base.test.js` | 15 | Ln RMSSD, días locales, ventana de 7/30 días, banda k1/k2, calidad mínima, origen separado |
| `linea_base_vista.test.js` | 8 | El paciente nunca recibe la etiqueta ni la banda |

**Portal — Jest (`npm test` en `web_portal/`): 50 pruebas**

| Archivo | Pruebas | Qué cubre |
|---|---:|---|
| `sesiones.test.js` | 21 | Formato y cálculo de sesiones, estados, gráficas |
| `gad7.test.js` | 11 | Severidad, fechas, texto del próximo GAD-7; ningún color del GAD-7 es del semáforo |
| `actividad.test.js` | 10 | Actividad de 7 días por paciente y del grupo |
| `semaforo.test.js` | 5 | Etiquetas, tonos y orden del estado |
| `ui/components.test.js` | 3 | Tono de avatar estable por identidad |

**App — `flutter test` (`app_ansiedad/`): 181 pruebas** (156 declaradas + 25 generadas en bucles)

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

**Total automatizado: 281 pruebas** (50 + 50 + 181).

Últimos resultados registrados en `CONTEXTO_PROYECTO.md` (no se volvieron a correr):

- backend `npm test` 50/50;
- portal `npm test` 50/50;
- app `flutter test` 181/181 (M5a paso 4, 2026-10-23).

> Conviene volver a correr las tres suites una vez antes de la entrega para citar el resultado con fecha. Hoy no se corrieron por el congelamiento.

### 7.2 Pruebas por comando contra el backend (PowerShell)

| Script | Cobertura | Último resultado registrado |
|---|---|---|
| `backend/pruebas/prueba_sesiones.ps1` | Sesiones (validación, roles, `indice_calidad` oculto, detalle 404/400), EVA (13 casos, incluida la ventana de 15 min y el 409), `/api/pacientes` (`ultima_sesion`, `sesiones_7d`, estado), línea base por rol. 49 llamadas a `Caso`. | **47 OK / 0 FALLA** (2026-10-23, regresión de M5a) |
| `backend/pruebas/prueba_gad7.ps1` | GAD-7 por rol, validación (casos en bucle), sin vínculo (403), **carrera real 201/409**, 409 con fecha, `ultimo_gad7_*`, regla de oro en vivo. 17 llamadas a `Caso`, algunas dentro de bucles. | **21 OK / 0 FALLA** (2026-10-23, local) |
| `backend/pruebas/comun.ps1` | Funciones compartidas (`Obtener-Cuenta`, `Llamar`, `Caso`…) | — |
| `backend/pruebas/semilla_m3.js`, `semilla_gad7.js` | Generan SQL de datos de prueba (cuentas `PRUEBA`) y su limpieza | — |

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

### Portal web — administrador

| # | Archivo sugerido | Qué mostrar |
|---|---|---|
| 43 | `web_16_admin_usuarios.png` | Lista de cuentas con rol, estado y vínculo |
| 44 | `web_17_admin_editar.png` | Edición de usuario (reasignar o desvincular especialista) |

### Infraestructura y pruebas (evidencia para los capítulos de implementación y pruebas)

| # | Archivo sugerido | Qué mostrar |
|---|---|---|
| 45 | `infra_01_render_backend.png` | Dashboard de Render: servicio backend "Live" con el último deploy |
| 46 | `infra_02_render_portal.png` | Dashboard de Render: servicio del portal con su URL |
| 47 | `infra_03_supabase_tablas.png` | Table Editor de Supabase con las 7 tablas |
| 48 | `infra_04_firebase_auth.png` | Firebase Authentication: usuarios (ocultar correos reales) y Authorized domains |
| 49 | `pruebas_01_backend_npm_test.png` | Salida de `npm test` en `backend/` (50/50) |
| 50 | `pruebas_02_portal_npm_test.png` | Salida de `npm test` en `web_portal/` (50/50) |
| 51 | `pruebas_03_flutter_test.png` | Salida de `flutter test` (181/181) |
| 52 | `pruebas_04_prueba_sesiones_ps1.png` | Resultado de `prueba_sesiones.ps1` |
| 53 | `pruebas_05_prueba_gad7_ps1.png` | Resultado de `prueba_gad7.ps1` (incluida la carrera 201/409) |
| 54 | `hw_01_esp32_montaje.jpg` | Foto del ESP32 + MAX30102 (cuando esté el hardware) |

> Las capturas 49–53 implican correr las suites. Hacerlo cuando se levante el congelamiento o justo antes de la entrega.
