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
    └── tecnicas_screen.dart     # técnicas de relajación: respiración animada +
                                  #  voz/música/animación por técnica (ver sección 6)
```

Las 5 pestañas del `main_layout`: **Inicio (Alerta)**, **Historial**, **Mensajes**, **Técnicas**, **Perfil**.

---

## 3. Endpoints del backend (`backend/server.js`)

- `POST /api/lecturas` — guarda una lectura biométrica.
- `GET /api/lecturas` — TODAS las lecturas; requiere `rol === 'especialista'` (cerrado en Inc. 6a).
- `GET /api/lecturas/:pacienteId` — lecturas de un paciente (con `?limite=`).
- `GET /api/lecturas/:pacienteId/resumen?periodo=semana|mes` — agregación por día (GROUP BY), devuelve periodo actual + anterior para comparar.
- `POST /api/usuarios` — registra usuario tras crear cuenta en Firebase.
- `GET /api/usuarios/:id` — trae perfil (nombre, email, rol).
- `PUT /api/usuarios/:id` — edita el nombre.
- `GET /api/pacientes` — lista de usuarios con `rol='paciente'` (nombre, email, última lectura si tiene); requiere `rol === 'especialista'`. Nuevo en Portal Web Fase 1.

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

## 4bis. Portal Web (próximo objetivo)

Con el Incremento 6a cerrado (auth Firebase end-to-end), el siguiente foco es construir el `web_portal/` (React) para que el especialista pueda monitorear pacientes. Se divide en 3 fases:

- **Fase 1 — Login de especialista + lista de pacientes (código hecho, verificación pendiente):** login ya existía (`Login.js` del Inc. 6a). Se agregó `GET /api/pacientes` en el backend (join `usuarios` + última fila de `lecturas_biometricas` por paciente, solo `rol === 'especialista'`) y `web_portal/src/PacientesList.js` (nuevo, tarjetas con nombre/email/estado del semáforo/última lectura); `App.js` ahora apunta a `/api/pacientes` en vez de al `/api/lecturas` crudo y delega el render a `PacientesList`. Validado con `npm run build` (compila sin warnings) y `npm start` local (pantalla de login renderiza bien). **Pendiente de confirmar** (requiere credenciales reales, no automatizable): login como especialista de verdad y ver la lista de pacientes cargar — esto cierra también el pendiente menor del Incremento 6a.
- **Fase 2 — Ver lecturas y gráficas de cada paciente:** al seleccionar un paciente de la lista, mostrar su historial de lecturas biométricas (bpm, spo2, hrv, score de ansiedad) con gráficas, reusando `GET /api/lecturas/:pacienteId` y `GET /api/lecturas/:pacienteId/resumen`.
- **Fase 3 — Chat en tiempo real especialista–paciente vía Socket.io:** reusar el mismo canal de chat que ya usa la app Flutter (`enviar_mensaje`, autenticado con `requiereAuthSocket`) para que el especialista converse en vivo con el paciente seleccionado.

---

## 5. Deuda técnica / pendientes conocidos

- **Seguridad (Inc. 6a, ✅ CERRADO):** `GET /api/lecturas` y el resto de endpoints ya exigen token Firebase y el portal web ya exige login — verificado end-to-end (ver sección 4). Queda solo el pendiente menor de confirmar el rol especialista, que se cierra construyendo la Fase 1 del Portal Web (sección 4bis).
- **`withOpacity` deprecado:** avisos de `flutter analyze` (cosmético). Ya migrado en Historial, Perfil y Alerta a `.withValues()`; falta en tecnicas y main_layout. Agendado para Inc. 5.
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

El feature de audio + animaciones (sección 6), el **Incremento 5** (manejo global de excepciones en Flutter, validación estricta y logging estructurado en el backend) y el **Incremento 6a** (auth Firebase end-to-end) ya quedaron implementados y verificados. El **Portal Web Fase 1** (sección 4bis) ya tiene el código listo (endpoint `/api/pacientes` + vista de lista); falta la verificación manual con una cuenta de especialista real. Después sigue la **Fase 2** del Portal Web (lecturas y gráficas por paciente) y, en paralelo, el **Incremento 6b** (testing).

**Sección de pruebas pendientes (acumulada, se revisa más adelante — no bloquea seguir con los incrementos):**
- Alerta: flujo de Bluetooth real con el ESP32 (conectar sensor, modo simulación, gráfica, sincronizar resumen) — solo validado con `flutter analyze`.
- Mensajes: enviar/recibir mensajes reales por Socket.io y confirmar que la alineación de burbujas (`esMio`) distingue bien remitente propio vs. ajeno — solo validado con `flutter analyze` y reinstalado en el dispositivo.
- Incremento 5: probar `POST /api/lecturas` con datos inválidos contra el backend real (Render) y confirmar `400`; confirmar en el celular que los mensajes de error al usuario no cambiaron con el refactor.
- Portal Web Fase 1: confirmar el rol especialista end-to-end (login como especialista real + ver la lista de pacientes cargar con datos correctos) — código listo, solo falta esta prueba manual.
