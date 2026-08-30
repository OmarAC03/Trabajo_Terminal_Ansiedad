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
├── models/                      # capa de modelos (Incremento 3)
│   ├── lectura.dart
│   └── resumen_dia.dart
├── repositories/                # capa de datos (Incremento 3)
│   └── lectura_repository.dart
├── providers/                   # capa de estado (Incremento 3)
│   └── historial_provider.dart
└── screens/
    ├── login_screen.dart
    ├── registro_screen.dart     # registro transaccional (Incremento 2)
    ├── alerta_screen.dart       # Monitor: Bluetooth + gráfica + modo simulación
    ├── historial_screen.dart    # REFACTORIZADA con Provider (Incremento 3)
    ├── mensajes_screen.dart     # chat Socket.io (sin revisar a fondo aún)
    ├── perfil_screen.dart       # perfil + avatares
    └── tecnicas_screen.dart     # técnicas de relajación + respiración animada
```

Las 5 pestañas del `main_layout`: **Inicio (Alerta)**, **Historial**, **Mensajes**, **Técnicas**, **Perfil**.

---

## 3. Endpoints del backend (`backend/server.js`)

- `POST /api/lecturas` — guarda una lectura biométrica.
- `GET /api/lecturas` — TODAS las lecturas (lo usa el portal web; ⚠️ sin filtro ni auth — deuda de seguridad conocida).
- `GET /api/lecturas/:pacienteId` — lecturas de un paciente (con `?limite=`).
- `GET /api/lecturas/:pacienteId/resumen?periodo=semana|mes` — agregación por día (GROUP BY), devuelve periodo actual + anterior para comparar.
- `POST /api/usuarios` — registra usuario tras crear cuenta en Firebase.
- `GET /api/usuarios/:id` — trae perfil (nombre, email, rol).
- `PUT /api/usuarios/:id` — edita el nombre.

**Tabla `lecturas_biometricas`:** id (uuid), paciente_id (varchar), bpm (int4), spo2 (int4), hrv (int4), score_ansiedad (numeric), estado_ansiedad (varchar: 'Alta'|'Moderada'|'Baja'), fecha_medicion (timestamptz).

---

## 4. Roadmap y estado

Plan de 4 fases / 7 incrementos hacia una app de producción.

### ✅ Fase 1 — Estabilización (COMPLETA)
- **Incremento 1 (hecho):** configuración central (`app_config.dart` con URL y enum `EstadoAnsiedad`); eliminado código muerto (`main_navigator.dart`); cliente de red central (`api_client.dart`) con reintento automático para el *cold start* de Render; arreglado el bug del "Sincronizar" que fallaba en silencio (ahora avisa y no pierde datos).

### ✅ Fase 2 — Arquitectura (en progreso)
- **Incremento 2 (hecho):** registro **transaccional** (si falla el guardado en Supabase, se borra la cuenta de Firebase recién creada — evita "cuentas fantasma"); `AuthGate` para persistencia de sesión (la app ya no pide login cada vez); validaciones previas en registro; limpieza de código en `login_screen`.
- **Incremento 3 (hecho):** refactor por capas usando **Provider**, con Historial como piloto. Creadas capas `models/`, `repositories/`, `providers/`. La UI de Historial ya no toca red ni parseo. Dependencia nueva: `provider: ^6.1.2`.
- **Incremento 4 (PENDIENTE):** completar y revisar `MensajesScreen` (chat Socket.io) ya con la arquitectura por capas. Migrar Perfil y Alerta al mismo patrón de Historial.

### ⏳ Fase 3 — Robustez, seguridad y calidad (PENDIENTE)
- **Incremento 5:** manejo global de excepciones en Flutter; validación estricta en el backend; logging estructurado.
- **Incremento 6:** cerrar la fuga de seguridad (`GET /api/lecturas` expone a todos los pacientes; portal web sin auth); proteger endpoints con verificación de token Firebase; estrategia de testing (unit, widget, integración).

### ⏳ Fase 4 — Lanzamiento (PENDIENTE)
- **Incremento 7:** CI/CD (GitHub Actions), optimización de rendimiento, firma y publicación en tienda, manejo de secretos por ambiente.

---

## 5. Deuda técnica / pendientes conocidos

- **Seguridad (prioritario, Inc. 6):** `GET /api/lecturas` devuelve lecturas de todos los pacientes sin autenticación; el portal web no exige login.
- **`withOpacity` deprecado:** ~20 avisos de `flutter analyze` (cosmético). En Historial ya se migró a `.withValues()`; falta en alerta, perfil, tecnicas, main_layout. Agendado para Inc. 5.
- **`avoid_print`:** hay `print()` en `alerta_screen` y `mensajes_screen`; cambiar por logging (Inc. 5).
- **Navegaciones manuales redundantes:** login/logout aún navegan a mano aunque el `AuthGate` ya lo maneja; limpiar al migrar esas pantallas a capas.
- **Migrar a capas:** Perfil, Alerta y Mensajes todavía tienen lógica mezclada (solo Historial está refactorizada).
- **Animación respiración:** el texto de fase ("Inhala"/"Sostén") se sale del círculo en pantallas chicas; ajustar con `FittedBox` o fuente adaptativa.

---

## 6. Feature en curso: audio en ejercicios de respiración

**Objetivo:** que el ejercicio de Respiración 4-7-8 (en `tecnicas_screen.dart`) diga las instrucciones en voz alta y tenga música de fondo relajante.

**Decisiones tomadas:**
- **Voz:** TTS (text-to-speech) con el paquete `flutter_tts`, en **español** (`es-MX` o `es-ES`), velocidad reducida (~0.4) para tono pausado/calmado.
- **Música:** archivo royalty-free / Creative Commons (el usuario lo consigue de Pixabay Music u similar). Instrumental, loopeable, `.mp3`. Se coloca en **`assets/audio/musica_relajante.mp3`** y se declara en `pubspec.yaml`. Reproducir con `audioplayers` (o `just_audio`), en bucle y a bajo volumen.
- **Dos toggles independientes:** uno para voz, uno para música (permitir usar solo una).
- **Sincronización:** el TTS dice "Inhala"/"Sostén"/"Exhala" en sync con la animación del círculo (`CustomPainter` con `AnimationController`); cuidar que la voz no se encime ni repita mal entre ciclos.
- **Ciclo de vida:** detener voz y música al pausar el ejercicio o salir de la pantalla (que no siga sonando en otras pantallas).

**Pasos técnicos:**
1. Agregar `flutter_tts` y `audioplayers` a `pubspec.yaml` → `flutter pub get`.
2. Declarar `assets/audio/` en `pubspec.yaml` y colocar el mp3.
3. Configurar TTS (idioma, velocidad, tono) e invocarlo en cada cambio de fase.
4. Reproducir música en bucle al iniciar; detener al pausar/salir.
5. Toggles de voz y música en la UI.
6. Probar en dispositivo físico (el audio y TTS no se prueban bien en emulador).

**Sugerencia de alcance:** aunque se harán voz + música juntas, si surge fricción con la música, priorizar que la voz funcione primero.

---

## 7. Cómo se ha trabajado (notas de proceso)

- Entorno: **Windows + VS Code**, se prueba en **celular Android físico** por USB.
- La app apunta al backend en producción (Render), así que no hace falta correr el backend localmente para probar la app.
- Firebase: la cuenta de Google del desarrollador debe tener acceso al proyecto Firebase existente.
- Flujo Git: `git add .` → `git commit -m "..."` → `git push`. Se recomienda empezar a usar ramas por incremento.
- **Cold start de Render:** el plan gratuito duerme el servidor tras ~15 min; la primera petición tarda 30-50s. El `api_client.dart` ya lo maneja con reintentos.
- **Supabase** (plan gratuito) puede pausarse por inactividad; si el backend no guarda, revisar que el proyecto Supabase esté activo.

---

## 8. Siguiente paso sugerido

Implementar el **feature de audio** (sección 6) en `tecnicas_screen.dart`. Después, continuar con el **Incremento 4** (revisar `MensajesScreen` y migrar Perfil/Alerta a la arquitectura por capas). El portal web (`web_portal`) se trabajará más adelante.
