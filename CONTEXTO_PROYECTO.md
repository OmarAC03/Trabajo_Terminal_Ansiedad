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
    └── tecnicas_screen.dart     # técnicas de relajación: respiración animada +
                                  #  voz/música/animación por técnica (ver sección 6)
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
- **Incremento 4 (PENDIENTE — siguiente paso):** completar y revisar `MensajesScreen` (chat Socket.io) ya con la arquitectura por capas. Migrar Perfil y Alerta al mismo patrón de Historial.

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

---

## 8. Siguiente paso sugerido

El feature de audio + animaciones (sección 6) ya quedó completo y pusheado. Lo siguiente es el **Incremento 4**: revisar `MensajesScreen` (chat Socket.io) y migrar Perfil y Alerta a la arquitectura por capas (`models/` + `repositories/` + `providers/`), siguiendo el mismo patrón que ya se usó en Historial (Incremento 3). El portal web (`web_portal`) se trabajará más adelante.
