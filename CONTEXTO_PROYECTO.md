# Contexto del proyecto — Sistema de Ansiedad (Trabajo Terminal)

> Documento para dar contexto a Claude Code al retomar el desarrollo.
> Resume la arquitectura, lo ya construido, las decisiones tomadas y el trabajo pendiente.

---

## 1. Qué es el proyecto

Sistema de monitoreo biométrico de ansiedad con 3 componentes en un monorepo:

- **`app_ansiedad/`** — App móvil en **Flutter** (la que más se ha trabajado). El paciente la usa.
- **`backend/`** — Servidor **Node.js + Express + Socket.io**, desplegado en **Render** (`https://tt-ansiedad-backend.onrender.com`).
- **`web_portal/`** — Portal clínico en **React** (Create React App) para que un especialista monitoree pacientes.

**Base de datos:** PostgreSQL en **Supabase**.
**Autenticación:** Firebase Auth.
**Flujo general:** un dispositivo ESP32 (vía Bluetooth) mide señales biométricas → la app Flutter las procesa y envía al backend → el backend las guarda en Supabase y las transmite en tiempo real → el especialista las ve en el portal web, con chat en vivo paciente–especialista.

> Nota: el ESP32 lo desarrolla otro compañero. Para trabajar la app sin hardware, existe un **modo simulación** que genera lecturas falsas.

> **Alcance (ver sección 4quater y `MARCO_ALCANCE_Y_LENGUAJE.md`):** el sistema **muestra parámetros fisiológicos** (BPM, SpO2, HRV) asociados a la ansiedad como apoyo al especialista. **No diagnostica** ansiedad ni reemplaza al profesional de salud; la interpretación clínica corresponde siempre al especialista.

---

## 2. Estructura de la app Flutter (post-refactor)

```
app_ansiedad/lib/
├── main.dart                    # arranca la app, usa AuthGate
├── auth_gate.dart               # decide Login vs Home según sesión Firebase
├── app_config.dart              # URL backend + enum EstadoAnsiedad (config central)
├── api_client.dart              # cliente HTTP central con reintento (cold start)
├── main_layout.dart             # BottomNavigationBar con 5 pestañas
├── firebase_options.dart
├── avatar_widgets.dart          # avatares de animales (CustomPainter)
├── models/                      # capa de modelos
│   ├── lectura.dart
│   ├── resumen_dia.dart
│   ├── perfil.dart              # (Incremento 4)
│   └── lectura_cruda.dart       # lectura biométrica antes del semáforo (Incremento 4)
├── repositories/                # capa de datos
│   ├── repository_exception.dart # excepción compartida por todos los repos (Incremento 4)
│   ├── lectura_repository.dart  # +enviarResumen() (Incremento 4)
│   ├── perfil_repository.dart   # (Incremento 4)
│   └── sensor_repository.dart   # Bluetooth Serial del ESP32 (Incremento 4)
├── providers/                   # capa de estado
│   ├── historial_provider.dart
│   ├── perfil_provider.dart     # (Incremento 4)
│   └── alerta_provider.dart     # (Incremento 4)
└── screens/
    ├── login_screen.dart
    ├── registro_screen.dart     # registro transaccional (Incremento 2)
    ├── alerta_screen.dart       # REFACTORIZADA con Provider (Incremento 4)
    ├── historial_screen.dart    # REFACTORIZADA con Provider (Incremento 3)
    ├── mensajes_screen.dart     # chat Socket.io (PENDIENTE revisar a fondo)
    ├── perfil_screen.dart       # REFACTORIZADA con Provider (Incremento 4)
    ├── tecnicas_screen.dart     # técnicas de relajación: respiración animada +
    │                             #  voz/música/animación por técnica (ver sección 6)
    └── ejercicios_asignados_screen.dart # ejercicios del especialista (Fase 2c, sección 4bis)
```

Las 5 pestañas del `main_layout`: **Inicio (Alerta)**, **Historial**, **Mensajes**, **Técnicas**, **Perfil**.

---

## 3. Endpoints del backend (`backend/server.js`)

- `POST /api/lecturas` — guarda una lectura biométrica.
- `GET /api/lecturas` — TODAS las lecturas; requiere `rol === 'especialista'` (cerrado en Inc. 6a).
- `GET /api/lecturas/:pacienteId` — lecturas de un paciente (con `?limite=`).
- `GET /api/lecturas/:pacienteId/resumen?periodo=semana|mes` — agregación por día (GROUP BY), devuelve periodo actual + anterior para comparar.
- `POST /api/usuarios` — registra usuario tras crear cuenta en Firebase.
- `GET /api/usuarios/:id` — trae perfil (nombre, email, rol, codigo_vinculacion). **Solo el propio perfil** (403 si `:id` ≠ uid del token) desde la Fase 2e.
- `PUT /api/usuarios/:id` — edita el nombre (devuelve también `codigo_vinculacion`). **Solo el propio perfil** desde la Fase 2e.
- `GET /api/pacientes` — lista de usuarios con `rol='paciente'` (nombre, email, última lectura si tiene: `ultimo_estado`, `ultima_lectura` y, desde la Fase A, `ultimo_bpm`/`ultimo_spo2`/`ultimo_hrv`); requiere `rol === 'especialista'`. Nuevo en Portal Web Fase 1.
- `GET /api/mensajes/:pacienteId` — historial del chat (Fase 2b).
- `POST /api/ejercicios` / `GET /api/ejercicios/:pacienteId` — ejercicios asignados (Fase 2c).
- `GET /api/pendientes` / `POST /api/pendientes/:seccion/visto` — badges de Mensajes y Ejercicios en la app (Fase 2c).

**Tabla `lecturas_biometricas`:** id (uuid), paciente_id (varchar), bpm (int4), spo2 (int4), hrv (int4), score_ansiedad (numeric), estado_ansiedad (varchar: 'Alta'|'Moderada'|'Baja'), fecha_medicion (timestamptz).

---

## 4. Roadmap y estado

Plan de 4 fases / 7 incrementos hacia una app de producción.

### ✅ Fase 1 — Estabilización (COMPLETA)
- **Incremento 1 (hecho):** configuración central (`app_config.dart` con URL y enum `EstadoAnsiedad`); eliminado código muerto (`main_navigator.dart`); cliente de red central (`api_client.dart`) con reintento automático para el *cold start* de Render; arreglado el bug del "Sincronizar" que fallaba en silencio (ahora avisa y no pierde datos).

### ✅ Fase 2 — Arquitectura (en progreso)
- **Incremento 2 (hecho):** registro **transaccional** (si falla el guardado en Supabase, se borra la cuenta de Firebase recién creada — evita "cuentas fantasma"); `AuthGate` para persistencia de sesión (la app ya no pide login cada vez); validaciones previas en registro; limpieza de código en `login_screen`.
- **Incremento 3 (hecho):** refactor por capas usando **Provider**, con Historial como piloto. Creadas capas `models/`, `repositories/`, `providers/`. La UI de Historial ya no toca red ni parseo. Dependencia nueva: `provider: ^6.1.2`.
- **Incremento 4 (COMPLETO):**
  - ✅ **Perfil migrado a capas**: `models/perfil.dart`, `repositories/perfil_repository.dart`, `providers/perfil_provider.dart`. `PerfilScreen` quedó como `StatelessWidget` que solo arma el `ChangeNotifierProvider` y dibuja (mismo patrón que Historial); la lógica de avatar (Firebase `photoURL`) y edición de nombre, con sus actualizaciones optimistas y reversión en error, vive ahora en `PerfilProvider`. De paso se extrajo `RepositoryException` a `repositories/repository_exception.dart` (compartida por todos los repos; antes vivía duplicable solo dentro de `lectura_repository.dart`, que ahora la reexporta).
  - ✅ **Alerta migrado a capas**: `models/lectura_cruda.dart`, `repositories/sensor_repository.dart` (encapsula Bluetooth Serial: permisos, búsqueda del dispositivo vinculado `TT_SENSOR_CLASICO`, expone un `Stream<String>` de líneas JSON crudas), `providers/alerta_provider.dart` (semáforo de ansiedad, buffers para promedios, modo simulación, envío del resumen — mismas reglas que antes: bpm>95 o hrv<25 → Alta, bpm>85 → Moderada, si no Baja). `lectura_repository.dart` ganó `enviarResumen()`. `AlertaScreen` quedó como `StatelessWidget` igual que Historial y Perfil. El provider cancela su suscripción al stream y el timer de simulación en `dispose()` para no notificar después de destruido. De paso se limpiaron los `withOpacity` deprecados, el `print()` de depuración y un método muerto (`_buildSensorStatusChip`) que tenía esa pantalla. **Pendiente de confirmar:** probar en dispositivo físico con Bluetooth real (aquí solo se validó con `flutter analyze`, no en hardware).
  - ✅ **Mensajes migrado a capas** (commit `8f42f01`): `models/mensaje.dart`, `repositories/chat_repository.dart` (encapsula Socket.io: conecta, expone `Stream<Mensaje>`, envía mensajes), `providers/mensajes_provider.dart` (lista de mensajes, conexión, envío, `esMio()`). `MensajesScreen` quedó como `StatelessWidget` (arma el `ChangeNotifierProvider`) + un `StatefulWidget` interno solo para el `TextEditingController` del input (control de UI, no de estado del chat). De paso se corrigió un placeholder del código original que asumía que todos los mensajes eran del paciente (burbuja siempre a la derecha); ahora se compara `paciente_id` para alinear la burbuja según quién lo envió. **Pendiente de confirmar:** probar en el celular mandando/recibiendo mensajes reales (solo validado con `flutter analyze` y reinstalado en el dispositivo, falta interactuar con el chat en vivo).

### ⏳ Fase 3 — Robustez, seguridad y calidad (en progreso)
- **Incremento 5 (hecho):**
  - **Flutter — manejo global de excepciones:** `lib/logger.dart` (nuevo, `AppLogger` sobre `dart:developer.log()`, sin dependencia nueva). `main.dart` envuelve `runApp` en `runZonedGuarded`, define `FlutterError.onError`, `PlatformDispatcher.instance.onError` y un `ErrorWidget.builder` con una tarjeta simple en vez de la pantalla roja de depuración. Los `catch` genéricos de los 4 providers (Historial, Perfil, Alerta, Mensajes) ahora loguean el error real y el stackTrace con `AppLogger` antes de fijar el mensaje amable al usuario (antes se tragaban en silencio); el stream de mensajes también quedó con `onError`.
  - **Backend — validación estricta:** `backend/validation.js` (nuevo) valida cada payload antes de tocar la base de datos (`validarLectura`, `validarUsuarioNuevo`, `validarNombre`, `validarMensajeChat`) y lanza `ValidationError` (`backend/errors.js`, `statusCode = 400`) si algo no cuadra (tipos, rangos de bpm/spo2/hrv, enum de `estado_ansiedad`/`rol`).
  - **Backend — logging estructurado:** `backend/logger.js` (nuevo, JSON por línea con timestamp/nivel/mensaje/metadata, sin dependencia nueva) reemplaza los `console.log`/`console.error` sueltos.
  - **Backend — manejo global de errores:** se apoya en que Express 5 (`^5.2.1`) reenvía automáticamente a `next(err)` cualquier excepción síncrona o promesa rechazada de un handler `async`; se quitaron los `try/catch` duplicados de cada ruta y se añadió un único middleware de error al final de `server.js` que loguea y responde 400 (validación) o 500 (fallo interno) de forma consistente. El listener de socket `enviar_mensaje` mantiene su propio `try/catch` (no es una ruta Express) pero ahora usa `validarMensajeChat` y el logger estructurado.
  - **Pendiente de confirmar:** probar en caliente contra el backend en Render (`POST /api/lecturas` con datos inválidos → debe dar 400 sin llegar a Supabase) y en el celular (que los mensajes de error al usuario no cambiaron).
- **Incremento 6a (✅ CERRADO):** autenticación Firebase end-to-end para cerrar la fuga de `GET /api/lecturas`.
  - **Backend:** `backend/auth.js` (nuevo) usa `firebase-admin` para verificar el `idToken` del header `Authorization: Bearer <token>`; como no hay custom claims, el `rol` (`'paciente'`|`'especialista'`) se resuelve consultando la tabla `usuarios` por el uid. Montado a nivel de router (`app.use('/api', requiereAuth(pool))`) antes de las rutas. Cada ruta de `server.js` gana su chequeo de autorización (dueño del recurso o especialista; `GET /api/lecturas` sin filtro ahora exige `rol === 'especialista'`). `POST /api/usuarios` permite el caso especial de `rol === null` (token válido pero la fila en `usuarios` aún no existe, justo entre crear la cuenta Firebase y el insert). Socket.io: `io.use(requiereAuthSocket(pool))` exige token en el handshake; `enviar_mensaje` valida que `paciente_id` coincida con el emisor o que sea especialista. Nuevo `AuthError` en `backend/errors.js` (mismo patrón que `ValidationError`, cae en el middleware de error existente). Nueva dependencia `firebase-admin` en `package.json`.
  - **App Flutter:** `api_client.dart` inyecta `Authorization: Bearer <idToken>` en cada request (`FirebaseAuth.instance.currentUser?.getIdToken()`), centralizado ahí — ningún repositorio cambió. `chat_repository.dart` (`conectar()` ahora async) manda el token en el handshake del socket (`setAuth({'token': ...})`); `mensajes_provider.dart` (`_conectar()` ahora `Future<void>`) se adaptó para esperarlo sin bloquear el constructor. `flutter analyze` limpio (solo quedan los avisos cosméticos de `withOpacity` ya conocidos).
  - **Portal web:** ganó login mínimo — `web_portal/src/firebase.js` (nuevo, init del SDK Web reusando la config de `firebase_options.dart`) y `web_portal/src/Login.js` (nuevo, email/password). `App.js` ahora exige sesión (`onAuthStateChanged`), manda el token en cada `axios.get`, tiene botón de logout y muestra un mensaje si el backend responde 403 (cuenta sin rol especialista) en vez de fallar en silencio. Nueva dependencia `firebase` en `package.json`.
  - **Verificado:** backend desplegado y *live* en Render con `firebase-admin` funcionando (Service Account key puesta como env var); la app Flutter manda el token en cada request y el paciente ve solo sus propios datos; la fuga de seguridad de `GET /api/lecturas` (antes sin filtro ni auth) quedó cerrada — ahora exige `rol === 'especialista'`.
  - **Pendiente menor (no bloquea el cierre):** confirmar el rol especialista end-to-end (login como especialista + ver la lista de pacientes) — se verificará de forma natural al construir el Portal Web (ver sección 4bis, Fase 1), no hace falta una prueba manual aparte.
- **Incremento 6b (pendiente):** estrategia de testing (unit, widget, integración) — deliberadamente separado de 6a porque ese ya tocaba 4 superficies distintas. Empezar por tests unitarios de `auth.js`/`validation.js` en el backend y un test de `api_client.dart` que confirme que se agrega el header de auth.

### ⏳ Fase 4 — Lanzamiento (PENDIENTE)
- **Incremento 7:** CI/CD (GitHub Actions), optimización de rendimiento, firma y publicación en tienda, manejo de secretos por ambiente.

---

## 4bis. Portal Web

Con el Incremento 6a cerrado (auth Firebase end-to-end), el foco pasó a construir el `web_portal/` (React) para que el especialista pueda monitorear pacientes. Se divide en 3 fases:

- **Fase 1 — Login de especialista + lista de pacientes (✅ COMPLETA y verificada):** login ya existía (`Login.js` del Inc. 6a). `GET /api/pacientes` en el backend (join `usuarios` + última fila de `lecturas_biometricas` por paciente, solo `rol === 'especialista'`) y `web_portal/src/PacientesList.js` (tarjetas con nombre/email/estado del semáforo/última lectura). **Verificado end-to-end** al probar la Fase D (sección 4ter): login real como especialista y la lista de pacientes carga con datos correctos — esto cierra también el pendiente menor del Incremento 6a.
- **Fase 2a — Detalle del paciente (implementada, pendiente de verificar en producción):** click en una tarjeta de `PacientesList` abre `web_portal/src/PacienteDetalle.js` (sin router: `App.js` guarda `pacienteSeleccionadoId`). Selector Día/Semana/Mes, KPIs (BPM promedio, HRV promedio, lecturas altas, última lectura), gráfica de tendencia de indicadores fisiológicos (BPM/SpO2/HRV, con **Recharts** — dependencia nueva), lista de lecturas (Día) o resumen por día (Semana/Mes) con semáforo Normal/Elevados/Altos, y disclaimer de alcance. Helpers del semáforo compartidos en `web_portal/src/semaforo.js`. **Backend:** `GET /api/lecturas/:pacienteId` y `/resumen` ahora usan `autorizarLecturaPaciente()`: un especialista solo ve pacientes con `especialista_id` = su uid (403 si no); el propio paciente sigue igual. **Pendiente de seguridad detectado:** `GET/PUT /api/usuarios/:id` aceptaba a cualquier especialista (el socket `enviar_mensaje` ya se cerró en la Fase 2b) — ✅ corregido en la Fase 2e (solo el propio perfil) y verificado con prueba manual en GET y PUT (403/200).
- **Fase 2b — Chat especialista–paciente (✅ LISTA en código, commit `a299a57`; ⚠️ NO CERRADA hasta pasar la prueba de aislamiento):** migración aplicada, backend + portal + app desplegados; el chat se ve y responde. **Pendiente:** prueba de aislamiento de seguridad con dos pacientes distintos (uno NO debe ver los mensajes del otro) — ver sección 8. El emisor es `remitente_id`; **no existe** `emisor_id`.
  - **Tabla `mensajes_chat`:** id (uuid), remitente_id (varchar, quién envió), paciente_id (varchar), especialista_id (varchar, **nueva** — migración aplicada a mano en Supabase con backfill desde `usuarios.especialista_id`), texto (text), tipo_mensaje (varchar), fecha_envio (timestamptz). Mensajes antiguos tienen `remitente_id` null → se tratan como del paciente.
  - **Backend:** cada socket entra a su sala privada `usuario:<uid>`; `enviar_mensaje` emite solo a la sala del paciente y a la de su especialista vinculado actual (antes `io.emit` a TODOS — cada paciente veía mensajes ajenos). Autorización: el paciente solo en su conversación y con especialista vinculado; el especialista solo con pacientes vinculados (`esPacienteVinculado`, compartido con lecturas). `remitente_id`/`especialista_id` los pone el servidor. Responde por ack `{ ok, error }`. Nuevo `GET /api/mensajes/:pacienteId` (últimos 200, solo la conversación con el especialista vinculado actual — si el paciente cambia de especialista, el nuevo no ve la anterior). Texto máx. 2000 caracteres.
  - **Portal:** `web_portal/src/ChatPaciente.js` dentro de `PacienteDetalle.js` (historial + tiempo real, token renovado en cada reconexión). Dependencia nueva `socket.io-client`.
  - **App:** `MensajesProvider` verifica vinculación → conecta → carga historial; burbujas por `remitente_id`; errores de envío visibles; aviso + botón "Vincular especialista" si no hay vínculo.
  - **Limitación conocida:** en la app el token del socket se manda solo al conectar; tras ~1 h, una reconexión falla hasta reabrir la pantalla.
- **Fase 2c — Ejercicios asignados + badges in-app (✅ PROBADA, 2026-09-28; queda solo la prueba del 403 por comando):** validada con `node --check`, `flutter analyze` (sin avisos nuevos) y `npm run build`. **No incluye push notifications (FCM)** — eso es la Fase 2d.
  - **Verificado con prueba manual:** asignar una técnica y un ejercicio personalizado desde el portal (aparecen correctamente); al paciente le sale "Nuevo" con badge en la app y se limpia al abrir la pantalla; el portal pasa a "Visto por el paciente".
  - **Pendiente (no bloquea):** `POST /api/ejercicios` con un especialista no vinculado → debe dar **403**. Se hará por comando (como la de `usuarios/:id`), junto con la regresión de registro/vinculación. Tampoco se reportó por separado el badge de la pestaña **Mensajes** (al recibir mensaje del especialista con otra pestaña abierta, y que se limpie al entrar).
  - **Migración (aplicada a mano en Supabase ANTES de desplegar el backend y verificada: 7 columnas, 2 marcas en `usuarios`, 2 índices):** tabla `ejercicios_asignados` — id (uuid, `uuid_generate_v4()`), paciente_id y especialista_id (varchar(50), FK a `usuarios.id`, sin `ON DELETE`, igual que `mensajes_chat`), tecnica_id (varchar(50), slug o null), texto_personalizado (text o null), nota (text, opcional), fecha_asignacion (timestamptz, `now()`); `CHECK chk_ejercicio_origen` = exactamente uno de tecnica_id / texto_personalizado; índice `idx_ejercicios_paciente_fecha`; RLS en false como las demás. En `usuarios`: `ultima_apertura_mensajes` y `ultima_apertura_ejercicios` (timestamptz NOT NULL DEFAULT now(), una marca por sección). Índice nuevo `idx_mensajes_paciente_fecha` en `mensajes_chat (paciente_id, fecha_envio DESC)`.
  - **Slugs de técnicas (IDÉNTICOS en 3 lugares):** `respiracion_478`, `relajacion_muscular`, `grounding_54321`, `visualizacion_guiada` — `Tecnica.id` en `tecnicas_screen.dart`, `TECNICAS_EJERCICIO` en `backend/validation.js` y `web_portal/src/tecnicas.js`. Antes las técnicas solo tenían `titulo` (no había id estable). La lista válida vive en el backend, no como CHECK en la BD (agregar una técnica no requiere migración). No cambiar un slug sin migrar filas.
  - **Sin columna `leido`:** "visto" se deriva de `fecha_asignacion <= usuarios.ultima_apertura_ejercicios` (una sola fuente de verdad). El portal lo muestra como "Visto por el paciente" / "Aún no lo ve".
  - **Backend:** `POST /api/ejercicios` (solo especialista, `esPacienteVinculado`, `especialista_id` desde el token; `validarEjercicioAsignado`: slug de la lista XOR texto libre ≤500, nota ≤1000). `GET /api/ejercicios/:pacienteId` (`autorizarLecturaPaciente`; igual que el chat, solo los del especialista vinculado ACTUAL). `GET /api/pendientes` (solo paciente): cuenta mensajes del especialista (`remitente_id` no null y ≠ paciente) y ejercicios posteriores a cada marca, dentro del vínculo actual. `POST /api/pendientes/:seccion/visto` (`mensajes`|`ejercicios`, columna tomada de una lista fija): mueve la marca a `now()` y devuelve la marca **anterior** — la app marca primero y lista después, y resalta como "Nuevo" lo posterior a la marca anterior (sin carrera entre marcar y listar).
  - **Portal:** `web_portal/src/EjerciciosPaciente.js` en `PacienteDetalle.js` (entre los datos y el chat): select con las 4 técnicas o "Ejercicio personalizado…", nota opcional, disclaimer de apoyo, lista de asignados con estado visto. Recarga con el botón "Actualizar".
  - **App:** capas `models/ejercicio_asignado.dart`, `models/pendientes.dart` (`SeccionPendiente`), `repositories/ejercicios_repository.dart`, `repositories/pendientes_repository.dart`, `providers/ejercicios_provider.dart`, `providers/pendientes_provider.dart`, `screens/ejercicios_asignados_screen.dart`. La sección vive dentro de la pestaña **Técnicas** (tarjeta "Ejercicios asignados por tu especialista" arriba del catálogo, con contador) — no es una sexta pestaña. Tocar un ejercicio que es técnica de la app la abre directo (`abrirTecnica`/`tecnicaPorId`). Disclaimer `Disclaimers.ejercicios` (herramienta de apoyo, no tratamiento).
  - **Badges:** `PendientesProvider` vive en `MainLayout` (sondeo cada 45 s en primer plano, se detiene en segundo plano, refresca al volver y al cambiar de pestaña). Badge en la pestaña Mensajes (oculto mientras está abierta; se marca visto al entrar Y al salir, porque lo que llega con el chat abierto ya se vio) y en la pestaña Técnicas + en la tarjeta (se limpia al abrir la pantalla de ejercicios). Limpieza optimista con contador de versión para que una consulta en vuelo no reencienda el badge.
  - **Limitación conocida:** el badge de mensajes se actualiza por sondeo (hasta ~45 s de retraso), no por socket (aceptado para el esqueleto; mejora futura en "Diferidos").
- **Fase 2e — Perfil del especialista + cierre de seguridad de `usuarios/:id` + base visual (✅ PROBADA y CERRADA, 2026-09-27):** pasa `node --check` y `npm run build`. No toca la base de datos ni la app Flutter.
  - **Estado de git:** backend en el commit `0268162` (solo `backend/server.js`, desplegado en Render); portal en el commit `86e369a` (`public/index.html`, `src/App.js`, `src/PerfilEspecialista.js`, `src/ui/`, `DISENO_REFERENCIA.png`). Ambos pusheados a `main`.
  - **Verificado con prueba manual:** con token de especialista, `GET /api/usuarios/<otro_uid>` → **403** ("No autorizado para ver este perfil") y `GET /api/usuarios/<uid_propio>` → **200** con el perfil completo (incluido `codigo_vinculacion`); `PUT /api/usuarios/<otro_uid>` → **403** ("No autorizado para editar este perfil") y `PUT /api/usuarios/<uid_propio>` → **200** con el perfil. Lista de pacientes, detalle, chat, ejercicios y el nuevo Perfil funcionan dentro del layout nuevo.
  - **Seguridad (✅ cierra el pendiente 🔴 #4 de la sección 8, verificado con la prueba de arriba):** `GET/PUT /api/usuarios/:id` usan `autorizarPerfilPropio()` en `server.js`: solo el dueño del perfil (uid del token = `:id`), 403 en cualquier otro caso, **incluido un especialista** (antes cualquier especialista podía leer/editar cualquier perfil). Se eligió "solo el propio" y no "por vinculación" porque ninguna pantalla lee perfiles ajenos por esta ruta (el especialista obtiene los datos de sus pacientes de `GET /api/pacientes`). Registro (`POST /api/usuarios`, `POST /api/especialistas`) y vinculación (`/api/vinculacion`) no pasan por esta ruta; la app (`perfil_repository.dart`) y el portal (`App.js`) solo piden el uid propio.
  - **Base visual del portal (`web_portal/src/ui/`):** `tokens.css` (variables CSS: colores, semáforo Normal/Elevados/Altos, tipografía Inter, radios, sombras), `ui.css` (clases con prefijo `ui-` para no chocar con los estilos en línea viejos; responsive, el sidebar pasa arriba en < 860 px), `components.js` (`PageHeader`, `Card`, `KpiCard`, `Button`, `Badge`, `Avatar`, `Field`, `Alert`, `Disclaimer`), `Layout.js` (sidebar "Portal Clínico TT" con secciones Principal → Pacientes y Cuenta → Mi perfil / Salir, barra superior con nombre y avatar). Inter se carga desde Google Fonts en `public/index.html` (también `lang="es"` y título "Portal Clínico TT"). Mockup de referencia guardado en `web_portal/DISENO_REFERENCIA.png`.
  - **Pantallas viejas (lista, detalle, chat, ejercicios):** envueltas en el nuevo `Layout` pero **SIN rediseñar** (siguen con sus estilos en línea; solo heredan la fuente Inter). El header viejo desapareció: "Salir" pasó al sidebar; el código de vinculación y "Actualizar" quedaron en una fila arriba del contenido. El rediseño es la Fase A del portal (abajo), ya completa.
  - **Perfil (`web_portal/src/PerfilEspecialista.js`):** `App.js` guarda el perfil completo (antes solo `codigo_vinculacion`) y un estado `seccion` (`'pacientes'|'perfil'`). Tarjetas: datos de la cuenta (avatar, nombre, email de solo lectura, editar nombre vía `PUT`), código de vinculación con botón copiar, cambio de contraseña (`reauthenticateWithCredential` con la actual + `updatePassword`; valida mínimo 6, confirmación y que sea distinta; errores de Firebase traducidos), y nota de alcance "Acerca del sistema".
  - **Alcance:** el mockup ("HealthMonitor") es referencia **SOLO visual** (colores, layout, tarjetas). Sus textos de diagnóstico ("Sin ansiedad", "Ansiedad moderada", "Score ansiedad", "Alta") **NO se usan**: siempre Normal/Elevados/Altos e "Indicadores fisiológicos" (ver `MARCO_ALCANCE_Y_LENGUAJE.md`). Marca: "Portal Clínico TT", nunca "HealthMonitor".
- **Fase A del portal — rediseño visual completo (✅ COMPLETA: los 7 pasos hechos, probados y commiteados, 2026-09-28).** No confundir con la "Fase A" del diseño de relación (sección 4ter). Referencia visual exacta: `web_portal/GUIA_ESTILO_PORTAL.md` (colores, medidas y componentes sacados del mockup Next.js/Tailwind; se reproduce el look en el React actual, sin migrar de framework). Regla de la fase: **solo apariencia**, un paso a la vez, con `npm run build` y prueba manual antes de commitear cada uno.
  - **Única excepción de backend (aprobada):** `GET /api/pacientes` devuelve también `ultimo_bpm`, `ultimo_spo2` y `ultimo_hrv` de la misma última lectura (misma autorización y filtro por especialista, sin migración).
  - **Paso 1 — Dashboard (✅ commit `2f3a1c0`):** `Dashboard.js` es la sección de inicio del sidebar (Principal → Dashboard / Pacientes). KPIs Pacientes vinculados / Normal / Elevados / Altos con "% del grupo", tabla ordenada Altos → Elevados → Normal → Sin lecturas, panel "Últimas lecturas altas" y dona "Distribución del grupo" (Recharts). Todo sale de los datos reales de `/api/pacientes`, según la **última lectura** de cada paciente (por eso se muestra "hace X"). Tokens (`tokens.css`/`ui.css`) ajustados a la guía; `semaforo.js` con los mismos colores, `getStatusTone`/`getStatusOrden` y "Sin lecturas"; `CodigoVinculacion` pasó a botón compacto en las acciones del encabezado.
  - **Paso 2 — Pacientes (✅ commit `469adba`):** `PacientesList.js` pasó de tarjetas a la tabla a todo el ancho, en orden alfabético, con búsqueda por nombre/email (ignora acentos) y filtro por estado, en el navegador. Tabla, acciones del encabezado y disclaimer compartidos en `PacientesComun.js`. El detalle regresa a la sección de origen. (La búsqueda se reinicia al volver del detalle — aceptado.)
  - **Paso 3 — Detalle del paciente (✅ commit `e4da009`):** tarjeta de encabezado (avatar, email, estado, última lectura), selector Día/Semana/Mes segmentado, KPIs con `KpiCard`, gráfica en `Card` con los colores de la guía y lecturas/resumen por día como tabla. Dos columnas en pantalla ancha (datos + ejercicios | chat fijo), **solo CSS, sin pestañas**, para que el chat no se desmonte ni reconecte el socket. La carga de datos no cambió.
  - **Paso 4 — Ejercicios (✅ commit `ea7990f`):** `EjerciciosPaciente.js` pasó a `Card` con `Disclaimer`, `Alert` y `Button`; `Select` y `Textarea` nuevos en `components.js` (mismo formato que `Field`; flecha propia del select en `ui.css`); contador `x/500` en el ejercicio personalizado; asignados como filas `ui-exercise` con `Badge` "Visto por el paciente" (tono primario, no el verde de Normal para no confundirlo con el semáforo) / "Aún no lo ve" (neutral). Carga y asignación sin cambios.
  - **Paso 5 — Chat (✅ commit `d4b61ea`):** `ChatPaciente.js` pasó a `Card` ("Mensajes" / "Conversación con …") con `Alert` y `Button`; lista, burbujas (propias en primario a la derecha, del paciente en blanco con borde a la izquierda), hora e input con clases `ui-chat-*` sobre los tokens. Se quitó el ajuste temporal `.ui-detail-side > :first-child`: el margen del chat al apilarse (< 1180 px) vive en `.ui-chat`. Socket, ack, historial, `combinar()` y autoscroll sin cambios.
  - **Paso 6 — Perfil (✅ commit `9a2f315`):** `ui-page-wide` como las demás secciones; "Datos de la cuenta" + "Código de vinculación" apiladas a la izquierda y "Cambiar contraseña" a la derecha (antes 3 tarjetas en rejilla de 2, la tercera sola); una columna en < 960 px; carga dentro de `Card`; estilos en línea a `ui-profile-*`/`ui-code-*`; icono `CircleAlert` como en el resto. Sin cambios de lógica.
  - **Paso 7 — Login, Registro y restablecer contraseña (✅ commit `cd316a5`; login verificado con prueba manual):** **única excepción funcional de la fase (aprobada): HU02 del protocolo.**
    - `ui/AuthLayout.js` (nuevo): panel de marca azul (logo, frase del sistema y aviso de alcance "no emite diagnósticos") + tarjeta del formulario; en < 860 px una columna y el panel se reduce a logo + aviso. `Button` ganó `variant="link"` y la clase `ui-btn-block`.
    - `Login.js`: `Field`/`Button`/`Alert`; enlace "¿Olvidaste tu contraseña?" (pasa el correo escrito). Errores: "sin conexión" y "demasiados intentos" separados; **credenciales incorrectas siguen genéricas** ("Correo o contraseña incorrectos.", sin distinguir correo vs contraseña, por seguridad).
    - `RegistroEspecialista.js`: mismos componentes + textos de ayuda; lógica de registro (Firebase → `POST /api/especialistas` → borrado si el backend rechaza) sin cambios.
    - `RecuperarPassword.js` (nuevo): `sendPasswordResetEmail(auth, email)` con `auth.languageCode = 'es'`. **Mensaje siempre genérico** ("Si existe una cuenta con ese correo…"), incluso ante `auth/user-not-found`, para no revelar qué correos existen. Errores traducidos (correo inválido, demasiadas solicitudes, sin conexión) y "Reenviar enlace". El enlace abre la página hospedada de Firebase; **sin backend ni base de datos**. `App.js`: `vista` suma `'recuperar'` + `emailRecuperar` para prellenar.
    - **Sin `continueUrl`** (no hay botón "Continuar" de vuelta al portal): el portal no tiene despliegue en el repo (solo corre local con `npm start`). Si se publica, agregar `{ url: <dominio> }` como 3er argumento y dar de alta el dominio en Firebase → Authentication → Authorized domains (si no, Firebase rechaza con `auth/unauthorized-continue-uri`).
    - **Configuración manual sugerida:** Firebase → Authentication → Templates → Restablecimiento de contraseña: nombre público "Portal Clínico TT", remitente y asunto en español.
    - **No reportado por separado:** recepción real del correo de restablecimiento y cambio de contraseña con el enlace, correo no registrado (mismo mensaje) y error de código de institución en el registro.
  - **Deliberadamente fuera (sin dato real detrás):** "+N este mes", "Score ansiedad" y su barra, sistema de "Alertas activas", Exportar/PDF, "+ Nuevo paciente", menú superior y las secciones Alertas/Análisis/Indicaciones/Reportes/Configuración.
  - **Queda con estilo viejo (menor):** el texto "Cargando..." de `App.js` mientras Firebase resuelve la sesión.

---

## 4ter. Diseño de relación paciente–especialista

**Estado: ✅ COMPLETO Y VERIFICADO** (Fases A, B, C y D — probado end-to-end con cuentas reales de paciente y especialista).

- **Registro de especialista:** pantalla propia en el portal web, protegida por un código de institución (una variable de entorno en el backend). Sin ese código no se puede crear cuenta de especialista. Justificación: la validación profesional real la hace la institución al entregar el código; la app provee el control de acceso técnico.
- **Vinculación paciente–especialista (tipo Classroom):** cada especialista tiene un código de vinculación fijo; el paciente lo escribe en su app; un paciente pertenece a un solo especialista.
- **Modelo de datos:** campo `especialista_id` en la tabla `usuarios` (referencia al id del especialista). Campo `codigo_vinculacion` en las filas de especialistas.
- **Filtrado:** `GET /api/pacientes` filtra por `especialista_id` del especialista autenticado (Fase D).

**Fase A (✅ COMPLETA):** diseño de arriba, documentado; columna `especialista_id` creada a mano en la tabla `usuarios` de Supabase.

**Fase B (✅ COMPLETA, commit `a3ea17c`):** registro de especialista con código de institución — `POST /api/especialistas` en el backend (genera `codigo_vinculacion` único de 6 caracteres) y `web_portal/src/RegistroEspecialista.js`.

**Fase C (✅ COMPLETA y verificada, commit `56c2090`):**
- **Backend:** `POST /api/vinculacion` — el paciente autenticado manda `{ codigo_vinculacion }`; el backend busca el especialista dueño de ese código (`ValidationError` 400 si no existe) y guarda su id en `usuarios.especialista_id` del paciente. `GET /api/vinculacion` — consulta el estado actual (vinculado sí/no + nombre del especialista). Ambos exigen `rol === 'paciente'`. Nuevo `validarCodigoVinculacion` en `validation.js` (normaliza a mayúsculas).
- **App Flutter:** capas nuevas siguiendo el patrón de Historial/Perfil — `models/vinculacion.dart`, `repositories/vinculacion_repository.dart`, `providers/vinculacion_provider.dart`, `screens/vinculacion_screen.dart`. Se accede desde una fila nueva "Especialista vinculado" en `PerfilScreen` (solo visible si `rol == 'paciente'`); la pantalla muestra el nombre del especialista si ya está vinculado, o un campo para escribir el código si no.
- **Verificado:** probado end-to-end con una cuenta de paciente real y el código de un especialista ya registrado.

**Fase D (✅ COMPLETA y verificada, commit `7c821e1`):**
- **Backend:** `GET /api/pacientes` ahora filtra `WHERE u.rol = 'paciente' AND u.especialista_id = $1` con el uid del especialista autenticado (antes traía a todos los pacientes sin importar el vínculo). `GET /api/usuarios/:id` ahora incluye `codigo_vinculacion` en la respuesta (en pacientes viene `null`).
- **Portal web:** `web_portal/src/CodigoVinculacion.js` (nuevo) — barra visible bajo el header con "Tu código de vinculación: XXXXXX" y botón de copiar, para que el especialista lo comparta con sus pacientes. `App.js` pide su propio perfil junto con la lista de pacientes en cada vuelta del polling de 15s (con `Promise.allSettled`, para que un fallo transitorio de uno no bloquee al otro — el primer intento era una petición única que no se reintentaba si fallaba por el cold start de Render).
- **Verificado:** login real como especialista, la lista de pacientes muestra solo los suyos, y el código de vinculación aparece visible en el portal.

---

## 4quater. Re-enfoque de alcance y lenguaje (parámetros fisiológicos, no diagnóstico)

**Estado: ✅ COMPLETO** (validado con `flutter analyze` y `npm run build`; ajustes de layout del Monitor pendientes de confirmar con hot reload).

Referencia: `MARCO_ALCANCE_Y_LENGUAJE.md`. El sistema monitorea parámetros fisiológicos asociados a la ansiedad como apoyo al especialista; **no emite diagnósticos**. Fue un cambio **solo de textos visibles y avisos**, sin tocar lógica ni base de datos.

- **Nombres internos intactos:** `estado_ansiedad` sigue guardando `'Alta'|'Moderada'|'Baja'`, igual que `score_ansiedad`, el enum `EstadoAnsiedad` y `textoDB`. La traducción a texto visible vive en `EstadoAnsiedadInfo.textoUI` / `textoUIDesdeTexto()` (`app_config.dart`) y en `getStatusLabel()` (`web_portal/src/PacientesList.js`).
- **Semáforo:** título "Nivel de Ansiedad" → **"Indicadores fisiológicos"**; valores Baja/Moderada/Alta → **Normal/Elevados/Altos** (mismos colores). En el Monitor la tarjeta "ESTRÉS" pasó a "ÍNDICE" y el botón a "Sincronizar resumen de datos".
- **Historial:** "Tendencia de indicadores fisiológicos", textos de la tarjeta de tendencia reformulados, KPIs "Nivel predominante" / "Lecturas altas" / "Días sin lecturas altas".
- **Disclaimers:** textos centralizados en la clase `Disclaimers` + widget `DisclaimerNota` (`app_config.dart`). Visibles en Monitor (bajo el semáforo), Historial (encabezado) y Perfil ("Acerca de la app"). En el portal, banner gris sobre la lista de pacientes.
- **Layout del Monitor (de paso):** título/estado del semáforo con `Flexible` para que no se encimen; fondo azul dentro del área scrolleable; padding inferior de 100 px para que el FAB no tape el botón de sincronizar.
- **Regla para pantallas nuevas:** toda pantalla que muestre datos del paciente (ej. Portal Web Fase 2) debe nacer con el lenguaje de "indicadores fisiológicos" y su disclaimer de alcance.

---

## 4quinquies. Rediseño visual de la app móvil (unificada con el portal)

**Estado: ⏳ EN PROGRESO (pasos 0, 1 y 2 de 7 hechos, 2026-09-29).** Referencia visual exacta: `app_ansiedad/GUIA_ESTILO_APP.md` (misma paleta que el portal: azul `#2563EB`, fondo `#F8FAFC`, semáforo verde/ámbar/rojo con fondos suaves, header con gradiente `#1D4ED8`→`#2563EB`, tarjetas de métrica, bottom nav). Regla: **solo apariencia**, un paso a la vez con `flutter analyze` + prueba en el celular antes de commitear. La lógica del monitor, el chat/socket y los datos no se tocan. Única funcionalidad nueva: "¿Olvidaste tu contraseña?" (HU02, paso 2, commit aparte).

- **Decisiones aprobadas:** (1) el Monitor deja de mostrar la tarjeta "ÍNDICE x/10" y la barra de score (va contra el marco de alcance); el score se sigue calculando y enviando por dentro. (2) Se mantienen las **5 pestañas** (la guía dice 4, pero Técnicas es funcionalidad real). (3) En el paso 2, los errores de login se unifican en "Correo o contraseña incorrectos." (como el portal: no revelar si el correo existe). (4) Sin Inter: fuente por defecto, sin agregar `google_fonts`.
- **Paso 0 — Base visual + barra inferior (✅ commit `81b6bde`, probado en el celular):** `lib/ui/app_colors.dart` (paleta y semáforo con fondos), `lib/ui/app_theme.dart` (`AppTheme.claro`: tema global, reemplaza el seed teal de `main.dart`), `lib/ui/widgets.dart` (`EncabezadoGradiente`, `appBarGradiente`, `Tarjeta`, `EtiquetaSeccion`, `TarjetaMetrica`, `BadgeEstado` — se usan desde el paso 1). `EstadoAnsiedadInfo.color` pasa a los colores de la guía y gana `colorFondo` (`textoDB`/`textoUI` sin cambios). `main_layout.dart`: barra blanca con borde superior, activo azul con puntito, badges en rojo; misma lógica de pestañas/badges/sondeo.
- **Paso 1 — Login + Registro (✅ commit `b89009e`, probado en el celular):** `lib/ui/estructura_acceso.dart` (como `AuthLayout` del portal: banda de marca con gradiente "Sistema de Ansiedad", tarjeta del formulario encima y `Disclaimers.acceso` al pie); `widgets.dart` gana `CampoTexto` y `BotonPrimario`. Lógica de login y registro transaccional sin cambios; único ajuste menor: "listo" en la contraseña del login dispara el inicio de sesión.
- **Paso 2 — "¿Olvidaste tu contraseña?" (HU02, lado paciente) + errores de login genéricos (✅ commit `59428ab`; aspecto probado en el celular):** única funcionalidad nueva del rediseño. `screens/recuperar_password_screen.dart` (nuevo): `setLanguageCode('es')` + `sendPasswordResetEmail`, correo prellenado desde el login, **mensaje siempre genérico** (también ante `user-not-found`), errores traducidos (correo inválido —validado antes de llamar a Firebase—, demasiadas solicitudes, sin conexión), "Reenviar enlace"; sin backend ni BD ni `continueUrl`. Login: enlace bajo la contraseña; errores como el portal ("Sin conexión…", "Demasiados intentos…" y "Correo o contraseña incorrectos." para todo lo demás). `widgets.dart` gana `Aviso` (info/error, como `Alert` del portal). **No reportado por separado:** recepción real del correo en español, cambio de contraseña con el enlace, correo no registrado (mismo mensaje) y los mensajes de error del login.
- **Pasos siguientes:** 3 Monitor · 4 Historial · 5 Técnicas + Ejercicios asignados (sin tocar animaciones/voz/música) · 6 Mensajes · 7 Perfil + Vinculación.
- **Fuera de este rediseño:** la pantalla "Alerta"/pedir ayuda del mockup (feature futura, en Diferidos), "Score de ansiedad", textos de diagnóstico, "Health Monitor" y elementos del mockup sin dato real detrás.

---

## 5. Deuda técnica / pendientes conocidos

- **Seguridad (Inc. 6a, ✅ CERRADO):** `GET /api/lecturas` y el resto de endpoints ya exigen token Firebase y el portal web ya exige login — verificado end-to-end (ver sección 4). El pendiente menor de confirmar el rol especialista quedó cerrado al verificar la Fase D del sistema de vinculación (sección 4ter).
- **`withOpacity` deprecado:** avisos de `flutter analyze` (cosmético). Ya migrado en Historial, Perfil, Alerta y main_layout (Fase 2c) a `.withValues()`; falta en tecnicas. Agendado para Inc. 5.
- **`avoid_print`:** resuelto (Inc. 5) — no quedan `print()` en la app; los providers usan `AppLogger` (`lib/logger.dart`) y el backend usa el logger estructurado (`backend/logger.js`).
- **Navegaciones manuales redundantes:** login/logout aún navegan a mano aunque el `AuthGate` ya lo maneja; limpiar al migrar esas pantallas a capas.
- **Migrar a capas:** completo — Historial, Perfil, Alerta y Mensajes ya están refactorizadas (Incremento 4 cerrado).
- **Animación respiración:** el texto de fase ("Inhala"/"Sostén") se sale del círculo en pantallas chicas; ajustar con `FittedBox` o fuente adaptativa.

---

## 6. Feature completado: audio + animaciones en técnicas de relajación

**Estado: ✅ COMPLETO** (implementado, probado en dispositivo físico, commiteado y pusheado — commits `c89e5f3` y `0fc1629`).

**Qué se construyó**, todo en `tecnicas_screen.dart`:
- **Voz (TTS):** paquete `flutter_tts`, español `es-MX`, velocidad 0.4. Lee en voz alta las fases de Respiración 4-7-8 ("Inhala"/"Sostén"/"Exhala") y, en las otras 3 técnicas, la introducción y cada paso al navegar.
- **Música:** `audioplayers`, reproduce `assets/audio/musica_relajante.mp3` en loop a volumen 0.3, en las 4 técnicas.
- **Toggles independientes** (íconos en el AppBar de cada pantalla de ejercicio): voz, música, y un tercero de **avance automático/manual** (solo en `TecnicaPasosScreen`, no en Respiración): en automático avanza solo al terminar de leer cada paso (con pausa fija de 4s de respaldo si la voz está apagada); en manual se usan los botones Anterior/Siguiente como antes.
- **Animaciones propias por técnica** (campo `tipoAnimacion` en el modelo `Tecnica`, cada una con su `CustomPainter`):
  - Respiración 4-7-8: ya existía (círculo con partículas orbitando).
  - Relajación muscular (`'tension'`): círculo que se contrae y vibra al tensar, se sostiene, se expande suave al soltar.
  - Grounding 5-4-3-2-1 (`'grounding'`): ícono del sentido (ver/tocar/oír/oler/saborear) + número grande, con animación de aparición (`elasticOut`) por paso.
  - Visualización guiada (`'visualizacion'`): escena ambiental continua (resplandor que "respira" + partículas orbitando), visible desde la introducción.
- **Ciclo de vida:** voz y música se detienen al pausar/salir de cada pantalla (`dispose()`); no se quedan sonando en otras pantallas.

**Pendiente relacionado, no bloqueante:**
- Probar bien el modo automático en las 3 técnicas de `TecnicaPasosScreen` con distintos largos de texto (la voz varía en duración; el auto-avance depende del `completionHandler` de `flutter_tts`, no de un timer fijo, así que en teoría siempre queda sincronizado, pero vale la pena confirmarlo con más uso).
- `assets/audio/musica_relajante.mp3` pesa ~4.6 MB — vigilar si el repo empieza a sentirse pesado por los binarios de audio.

---

## 7. Cómo se ha trabajado (notas de proceso)

- Entorno: **Windows + VS Code**, se prueba en **celular Android físico** por USB.
- La app apunta al backend en producción (Render), así que no hace falta correr el backend localmente para probar la app.
- Firebase: la cuenta de Google del desarrollador debe tener acceso al proyecto Firebase existente.
- Flujo Git: `git add .` → `git commit -m "..."` → `git push`. Se recomienda empezar a usar ramas por incremento.
- **Cold start de Render:** el plan gratuito duerme el servidor tras ~15 min; la primera petición tarda 30-50s. El `api_client.dart` ya lo maneja con reintentos.
- **Supabase** (plan gratuito) puede pausarse por inactividad; si el backend no guarda, revisar que el proyecto Supabase esté activo.
- **⚠️ Nota de operación:** antes de cualquier presentación o prueba importante, despertar manualmente **Supabase** y **Render** (ambos en plan gratuito y se pausan por inactividad) — entrar a los dashboards de ambos con antelación para que ya estén activos y no se pierda tiempo con el cold start en vivo.

---

## 8. Siguiente paso sugerido

**Estado al cierre de la última sesión (2026-09-29):** **Rediseño visual de la app móvil ⏳ en progreso** (pasos 0, 1 y 2 de 7 ✅ — incluye HU02 en la app —, sección 4quinquies). **Fase A del portal (rediseño visual) ✅ COMPLETA**: los 7 pasos (Dashboard, Pacientes, Detalle, Ejercicios, Chat, Perfil, Login/Registro + restablecer contraseña HU02) probados y commiteados — ver sección 4bis. **Fase 2e** (perfil del especialista + cierre de seguridad de `usuarios/:id` + base visual del portal, sección 4bis) **✅ PROBADA y CERRADA**: backend `0268162` y portal `86e369a`, ambos en `main`; seguridad de `usuarios/:id` verificada en GET y PUT (403 ajeno / 200 propio). Antes: re-enfoque de lenguaje (sección 4quater), Portal Web Fase 2a y **Fase 2b (chat)** construidos y desplegados; la 2b no se considera cerrada hasta pasar la prueba de aislamiento (punto 3, diferida). **Fase 2c (ejercicios + badges)** ✅ **PROBADA (2026-09-28)**: asignación, "Nuevo"/badge y "Visto por el paciente" verificados; solo queda la prueba del 403 por comando (punto 1).

### Pendientes, EN ORDEN

0. ~~**Fase 2e — pruebas antes de commitear el portal**~~ — ✅ **CERRADO (2026-09-27):** `GET` y `PUT /api/usuarios/<otro_uid>` → 403 y `<uid_propio>` → 200 con token de especialista; lista, detalle, chat, ejercicios y Perfil funcionan en el layout nuevo. Portal commiteado (`86e369a`).
1. **Fase 2c — prueba manual (sección 4bis)** — ✅ **PROBADA (2026-09-28):** asignar técnica y ejercicio personalizado, "Nuevo"/badge que se limpia al abrir, y "Visto por el paciente" en el portal. **Queda:** `POST /api/ejercicios` con especialista no vinculado → 403, por comando, junto con la regresión de registro/vinculación (ver pruebas pendientes abajo); y confirmar el badge de Mensajes.
2. **Fase 2d — Push notifications (FCM):** fuera del alcance de la 2c; aparte.
3. **⚠️ Prueba de aislamiento del chat (Fase 2b)** — diferida conscientemente para antes de las pruebas finales. Con dos pacientes distintos, confirmar que uno NO ve los mensajes del otro (ni en tiempo real ni en el historial al reabrir la pantalla). Hasta pasarla, la Fase 2b sigue abierta.
4. ~~**🔴 SEGURIDAD — `GET/PUT /api/usuarios/:id`**~~ — ✅ **CERRADO y verificado con prueba manual en GET y PUT (403 en perfil ajeno / 200 en el propio)** en la Fase 2e. Se cerró con "solo el propio perfil" (`autorizarPerfilPropio`, compartido por GET y PUT), más estricto que la verificación por vinculación que se había propuesto aquí.

### Siguientes fases (la 2e ya está cerrada)
- ~~**Fase A — rediseño visual completo del portal**~~ — ✅ **COMPLETA (2026-09-28, ver sección 4bis):** commits `2f3a1c0`, `469adba`, `e4da009`, `ea7990f`, `d4b61ea`, `9a2f315`, `cd316a5`.
- **⏳ Rediseño visual de la app móvil (sección 4quinquies):** pasos 0 (`81b6bde`), 1 (`b89009e`) y 2 (`59428ab`, HU02) ✅; sigue el paso 3 (Monitor).
- ~~**"¿Olvidaste tu contraseña?" en la app Flutter (HU02, lado paciente)**~~ — ✅ hecho como el **paso 2** del rediseño de la app (commit `59428ab`, sección 4quinquies).
- **Fase C — rol Admin.**
- **Documento de alineación protocolo TT vs. sistema** (pendiente).

### Diferidos (trabajo futuro)
- **Token del chat en la app:** se manda solo al conectar el socket; tras ~1 h una reconexión falla hasta reabrir la pantalla (el portal ya lo resuelve con `auth` como función).
- **Badge de Mensajes por socket (Fase 2c):** hoy el badge sale del sondeo cada 45 s; mejora: incrementarlo al recibir `recibir_mensaje` por el socket que ya abre `MensajesProvider`.
- **Reporte PDF descargable por paciente** (portal).
- **Pantalla "Alerta"/pedir ayuda (app):** en el mockup móvil el paciente elige un motivo y avisa a su especialista. Funcionalidad nueva, fuera del rediseño visual de la app.
- **Bugs visuales del Monitor:** fondo azul estático al hacer scroll y botón "Sincronizar" cortado por el FAB. *Nota:* ya se aplicó un ajuste para ambos en `alerta_screen.dart` (commit `3b4383c`: fondo dentro del scroll + padding inferior de 100 px), pero no se confirmó en el dispositivo — verificar si persisten antes de volver a tocarlo.
- **Cambio de tema de color azul → menta** (app y portal).
- **Incremento 6b:** estrategia de testing (unit, widget, integración) — empezar por `auth.js`/`validation.js` en el backend y un test de `api_client.dart` que confirme el header de auth.
- **Pulido general:** deuda técnica de la sección 5 (`withOpacity` deprecado en técnicas/main_layout, navegaciones manuales redundantes en login/logout, animación de respiración que se sale del círculo en pantallas chicas).

### Reglas permanentes
- **Base de datos:** Claude Code **NO tiene acceso** a la base de datos (el `.env` local no trae `DATABASE_URL`; solo existe en Render). Antes de proponer cualquier `ALTER TABLE` o DDL, pedir primero al desarrollador que corra una **consulta de solo lectura** (ej. `information_schema.columns`) para verificar el estado real, y usar los nombres de columna reales (ej. `mensajes_chat.remitente_id`, no inventar `emisor_id`). El desarrollador aplica las migraciones a mano en Supabase **antes** del deploy del backend.
- **Lenguaje y alcance:** toda pantalla nueva que muestre datos del paciente debe nacer con el lenguaje de "indicadores fisiológicos" (Normal/Elevados/Altos) y su disclaimer de alcance (ver `MARCO_ALCANCE_Y_LENGUAJE.md` y sección 4quater). Nunca presentar los datos como diagnóstico.

**Sección de pruebas pendientes (acumulada, se revisa más adelante — no bloquea seguir con los incrementos):**
- Alerta: flujo de Bluetooth real con el ESP32 (conectar sensor, modo simulación, gráfica, sincronizar resumen) — solo validado con `flutter analyze`.
- Mensajes: el chat ya se probó visualmente tras la Fase 2b (se ve y responde); falta la prueba de aislamiento con dos pacientes (pendiente #1 de arriba).
- Incremento 5: probar `POST /api/lecturas` con datos inválidos contra el backend real (Render) y confirmar `400`; confirmar en el celular que los mensajes de error al usuario no cambiaron con el refactor.
- Fase 2c (no bloqueante, por comando): `POST /api/ejercicios` con token de un especialista NO vinculado al paciente → 403. Hacerla en la misma sesión que la regresión de registro de paciente/especialista y vinculación (Fase 2e). Además, confirmar el badge de Mensajes.
- Fase 2e (no bloqueante): la seguridad de `usuarios/:id` ya está verificada completa (GET y PUT). No se reportaron por separado la regresión de registro de paciente/especialista y vinculación, ni los casos de error del cambio de contraseña.
- Fase A paso 7 (no bloqueante): el login ya se probó; falta confirmar que llega el correo de restablecimiento (en español; revisar spam), que el enlace permite poner una contraseña nueva y entrar con ella, que un correo no registrado da el mismo mensaje, y el error del registro con un código de institución incorrecto.
- Rediseño de la app, paso 2 (no bloqueante): ya se revisó el aspecto; falta confirmar desde la app que llega el correo de restablecimiento en español, que el enlace cambia la contraseña y se puede entrar con ella, que un correo no registrado da el mismo mensaje y los errores unificados del login.
- Portal Web Fase 1: confirmar el rol especialista end-to-end (login como especialista real + ver la lista de pacientes cargar con datos correctos) — código listo, solo falta esta prueba manual.
