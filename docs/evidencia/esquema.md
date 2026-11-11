# Esquema de la base de datos

Leído del catálogo de Supabase el 11 de noviembre de 2026 con las consultas de solo
lectura C0–C6 (al final). El repositorio no guarda el DDL: este archivo es la
fuente para la tesis y no se le agregó ninguna columna que no saliera de las
consultas.

- **Motor:** PostgreSQL 17.6 (aarch64, administrado por Supabase).
- **Esquema `public`:** 14 tablas, 114 columnas, 32 índices, 2 triggers de
  fila visibles en C4 (ver la nota sobre TRUNCATE), 2 funciones propias.
- **RLS:** activada en las 14 tablas, sin políticas y sin permisos para los roles
  `anon` y `authenticated` (DDL de la Fase S, ejecutado y verificado el 11 nov 2026).

## Convenciones

- Identificadores de cuenta: `varchar(50)` con el uid de Firebase (`usuarios.id`).
- Llaves primarias `uuid`: `uuid_generate_v4()` en las tablas anteriores y
  `gen_random_uuid()` en las del Bloque 2 (`notas_clinicas`, `marcadores_clinicos`).
  Las dos generan UUID v4.
- `bitacora.id` y `notas_clinicas_versiones.id` son `bigint` sin valor por defecto
  en C1: son columnas identity (C1 no consulta `is_identity`; así se crearon en el
  Bloque 2, ver `CONTEXTO_PROYECTO.md`).
- Fechas con zona horaria (`timestamptz`), salvo la fecha clínica de las notas
  (`date`).
- En las tablas de columnas: **N** = admite nulos; «—» = sin valor por defecto.

## Relaciones

Todas las llaves foráneas apuntan a `usuarios(id)`, salvo dos:
`respuestas_eva → sesiones_medicion` y `notas_clinicas_versiones → notas_clinicas`.

| Desde | Hacia | Al borrar |
|---|---|---|
| `usuarios.especialista_id` | `usuarios.id` | SET NULL |
| `lecturas_biometricas.paciente_id` | `usuarios.id` | CASCADE |
| `mensajes_chat.paciente_id` | `usuarios.id` | CASCADE |
| `mensajes_chat.remitente_id` | `usuarios.id` | (restringe) |
| `dispositivos_push.usuario_id` | `usuarios.id` | CASCADE |
| `ejercicios_asignados.paciente_id`, `.especialista_id` | `usuarios.id` | (restringe) |
| `sesiones_medicion.paciente_id` | `usuarios.id` | (restringe) |
| `respuestas_eva.sesion_id` | `sesiones_medicion.id` | (restringe) |
| `respuestas_gad7.paciente_id` | `usuarios.id` | (restringe) |
| `consentimientos.usuario_id` | `usuarios.id` | (restringe) |
| `solicitudes_eliminacion.usuario_id`, `.atendida_por` | `usuarios.id` | (restringe) |
| `notas_clinicas.paciente_id`, `.especialista_id` | `usuarios.id` | (restringe) |
| `notas_clinicas_versiones.nota_id` | `notas_clinicas.id` | CASCADE |
| `marcadores_clinicos.paciente_id`, `.especialista_id` | `usuarios.id` | (restringe) |

«(restringe)» = sin `ON DELETE` (NO ACTION): la fila de `usuarios` no se puede
borrar mientras tenga datos. Por eso la eliminación de cuenta (`eliminacion.js`)
borra primero los datos clínicos y deja la fila de `usuarios` seudonimizada.

Sin llave foránea: `mensajes_chat.especialista_id` (lo pone el servidor) y toda
la `bitacora` (a propósito: la bitácora sobrevive a la eliminación de cuentas).

## Tablas

### `usuarios`

Cuentas de paciente, especialista y admin.

| # | Columna | Tipo | N | Por defecto |
|---:|---|---|:--:|---|
| 1 | `id` | varchar(50) | | — |
| 2 | `nombre` | varchar(100) | | — |
| 3 | `rol` | varchar(20) | | — |
| 4 | `email` | varchar(100) | | — |
| 5 | `fecha_registro` | timestamptz | N | `now()` |
| 6 | `especialista_id` | varchar (sin longitud) | N | — |
| 7 | `codigo_vinculacion` | varchar (sin longitud) | N | — |
| 8 | `ultima_apertura_mensajes` | timestamptz | | `now()` |
| 9 | `ultima_apertura_ejercicios` | timestamptz | | `now()` |
| 10 | `suspendido` | boolean | | `false` |
| 11 | `eliminado_en` | timestamptz | N | — |

- PK `usuarios_pkey (id)`.
- UNIQUE `usuarios_email_key (email)` y `usuarios_codigo_vinculacion_key (codigo_vinculacion)`.
- FK `fk_especialista`: `especialista_id → usuarios(id) ON DELETE SET NULL`.
- CHECK `usuarios_rol_check`: `rol` ∈ {paciente, especialista, admin}.

### `consentimientos`

Aceptaciones del aviso de privacidad y del consentimiento, por versión.

| # | Columna | Tipo | N | Por defecto |
|---:|---|---|:--:|---|
| 1 | `id` | uuid | | `uuid_generate_v4()` |
| 2 | `usuario_id` | varchar(50) | | — |
| 3 | `version_aviso` | varchar(40) | | — |
| 4 | `version_consentimiento` | varchar(40) | | — |
| 5 | `origen` | varchar(20) | | — |
| 6 | `aceptado_en` | timestamptz | | `now()` |

- PK `consentimientos_pkey (id)`.
- UNIQUE `uq_consentimiento_version (usuario_id, version_aviso, version_consentimiento)`:
  una aceptación por versión.
- FK `fk_consentimiento_usuario`: `usuario_id → usuarios(id)`.
- CHECK `chk_consentimiento_origen`: `origen` ∈ {registro, inicio_sesion}.
- CHECK `chk_consentimiento_versiones`: las dos versiones, sin espacios, no vacías.
- Índice `idx_consentimientos_usuario_fecha (usuario_id, aceptado_en DESC)`.

### `lecturas_biometricas`

Lecturas sueltas del sensor (ruta `POST /api/lecturas`, anterior a las sesiones).

| # | Columna | Tipo | N | Por defecto |
|---:|---|---|:--:|---|
| 1 | `id` | uuid | | `uuid_generate_v4()` |
| 2 | `paciente_id` | varchar(50) | N | — |
| 3 | `bpm` | integer | | — |
| 4 | `spo2` | integer | | — |
| 5 | `hrv` | integer | | — |
| 6 | `score_ansiedad` | numeric | | — |
| 7 | `estado_ansiedad` | varchar(20) | N | — |
| 8 | `fecha_medicion` | timestamptz | N | `now()` |

- PK `lecturas_biometricas_pkey (id)`.
- FK `lecturas_biometricas_paciente_id_fkey`: `paciente_id → usuarios(id) ON DELETE CASCADE`.
- Sin CHECK ni índices secundarios.

### `sesiones_medicion`

Sesiones de medición guiada: resumen, serie submuestreada y calidad.

| # | Columna | Tipo | N | Por defecto |
|---:|---|---|:--:|---|
| 1 | `id` | uuid | | `uuid_generate_v4()` |
| 2 | `paciente_id` | varchar(50) | | — |
| 3 | `fecha_inicio` | timestamptz | | — |
| 4 | `fecha_registro` | timestamptz | | `now()` |
| 5 | `duracion_total_seg` | integer | | — |
| 6 | `duracion_valida_seg` | integer | | — |
| 7 | `hrv_rmssd` | numeric | | — |
| 8 | `hrv_min` | numeric | | — |
| 9 | `hrv_max` | numeric | | — |
| 10 | `bpm_promedio` | numeric | | — |
| 11 | `bpm_min` | integer | | — |
| 12 | `bpm_max` | integer | | — |
| 13 | `spo2_promedio` | numeric | | — |
| 14 | `spo2_min` | integer | | — |
| 15 | `spo2_max` | integer | | — |
| 16 | `indice_calidad` | numeric | | — |
| 17 | `serie` | jsonb | | — |
| 18 | `origen` | varchar(20) | | — |

- PK `sesiones_medicion_pkey (id)`.
- FK `fk_sesiones_paciente`: `paciente_id → usuarios(id)`.
- CHECK:

  | Restricción | Condición |
  |---|---|
  | `chk_sesion_duracion` | 0 < `duracion_total_seg` ≤ 1800 y 0 ≤ `duracion_valida_seg` ≤ `duracion_total_seg` |
  | `chk_sesion_hrv` | `hrv_min` ≥ 0, `hrv_max` ≤ 300, `hrv_min` ≤ `hrv_max`, 0 < `hrv_rmssd` ≤ 300 |
  | `chk_sesion_bpm` | `bpm_min` > 0, `bpm_max` ≤ 300, `bpm_min` ≤ `bpm_promedio` ≤ `bpm_max` |
  | `chk_sesion_spo2` | `spo2_min` ≥ 0, `spo2_max` ≤ 100, `spo2_min` ≤ `spo2_promedio` ≤ `spo2_max` |
  | `chk_sesion_calidad` | 0 ≤ `indice_calidad` ≤ 1 |
  | `chk_sesion_serie` | `serie` es un arreglo JSON |
  | `chk_sesion_origen` | `origen` ∈ {simulacion, sensor} |

- Índice `idx_sesiones_paciente_fecha (paciente_id, fecha_inicio DESC)`.

### `respuestas_eva`

EVA al terminar una sesión (opcional; omitirla = no hay fila).

| # | Columna | Tipo | N | Por defecto |
|---:|---|---|:--:|---|
| 1 | `id` | uuid | | `uuid_generate_v4()` |
| 2 | `sesion_id` | uuid | | — |
| 3 | `valor` | smallint | | — |
| 4 | `contexto` | varchar(30) | N | — |
| 5 | `fecha_respuesta` | timestamptz | | `now()` |

- PK `respuestas_eva_pkey (id)`.
- UNIQUE `uq_eva_sesion (sesion_id)`: una EVA por sesión.
- FK `fk_eva_sesion`: `sesion_id → sesiones_medicion(id)`.
- CHECK `chk_eva_valor`: 0 ≤ `valor` ≤ 100. Es el valor continuo del deslizador;
  el portal lo muestra sobre 10 (`valor / 10`).
- CHECK `chk_eva_contexto`: nulo o ∈ {reposo, estudiando, antes_examen,
  despues_estresor, otro}.

### `respuestas_gad7`

Cuestionario GAD-7 quincenal.

| # | Columna | Tipo | N | Por defecto |
|---:|---|---|:--:|---|
| 1 | `id` | uuid | | `uuid_generate_v4()` |
| 2 | `paciente_id` | varchar(50) | | — |
| 3–9 | `item1` … `item7` | smallint | | — |
| 10 | `dificultad` | smallint | N | — |
| 11 | `version` | varchar(20) | | — |
| 12 | `fecha_respuesta` | timestamptz | | `now()` |

- PK `respuestas_gad7_pkey (id)`.
- FK `fk_gad7_paciente`: `paciente_id → usuarios(id)`.
- CHECK `chk_gad7_item1` … `chk_gad7_item7`: cada ítem entre 0 y 3.
- CHECK `chk_gad7_dificultad`: nulo o entre 0 y 3.
- CHECK `chk_gad7_version`: `version` no vacía.
- Índice `idx_gad7_paciente_fecha (paciente_id, fecha_respuesta DESC)`.
- El puntaje no se guarda: se calcula al leer (suma de los 7 ítems).

### `mensajes_chat`

Mensajes entre el paciente y su especialista.

| # | Columna | Tipo | N | Por defecto |
|---:|---|---|:--:|---|
| 1 | `id` | uuid | | `uuid_generate_v4()` |
| 2 | `remitente_id` | varchar(50) | N | — |
| 3 | `paciente_id` | varchar(50) | N | — |
| 4 | `texto` | text | | — |
| 5 | `tipo_mensaje` | varchar(20) | N | `'texto'` |
| 6 | `fecha_envio` | timestamptz | N | `now()` |
| 7 | `especialista_id` | varchar (sin longitud) | N | — |

- PK `mensajes_chat_pkey (id)`.
- FK `mensajes_chat_paciente_id_fkey`: `paciente_id → usuarios(id) ON DELETE CASCADE`.
- FK `mensajes_chat_remitente_id_fkey`: `remitente_id → usuarios(id)`.
- Índice `idx_mensajes_paciente_fecha (paciente_id, fecha_envio DESC)`.
- La longitud máxima del texto (2000) la valida el servidor; no hay CHECK.

### `ejercicios_asignados`

Ejercicios que el especialista asigna: una técnica del catálogo o un texto propio.

| # | Columna | Tipo | N | Por defecto |
|---:|---|---|:--:|---|
| 1 | `id` | uuid | | `uuid_generate_v4()` |
| 2 | `paciente_id` | varchar(50) | | — |
| 3 | `especialista_id` | varchar(50) | | — |
| 4 | `tecnica_id` | varchar(50) | N | — |
| 5 | `texto_personalizado` | text | N | — |
| 6 | `nota` | text | N | — |
| 7 | `fecha_asignacion` | timestamptz | | `now()` |

- PK `ejercicios_asignados_pkey (id)`.
- FK `paciente_id` y `especialista_id → usuarios(id)`.
- CHECK `chk_ejercicio_origen`: exactamente uno de `tecnica_id` o
  `texto_personalizado`.
- Índice `idx_ejercicios_paciente_fecha (paciente_id, fecha_asignacion DESC)`.

### `notas_clinicas`

Notas del especialista sobre un paciente (no se borran; se editan con versión).

| # | Columna | Tipo | N | Por defecto |
|---:|---|---|:--:|---|
| 1 | `id` | uuid | | `gen_random_uuid()` |
| 2 | `paciente_id` | varchar(50) | | — |
| 3 | `especialista_id` | varchar(50) | | — |
| 4 | `fecha` | date | | — |
| 5 | `contenido` | text | | — |
| 6 | `version` | integer | | `1` |
| 7 | `creada_en` | timestamptz | | `now()` |
| 8 | `editada_en` | timestamptz | N | — |

- PK `notas_clinicas_pkey (id)`.
- FK `paciente_id` y `especialista_id → usuarios(id)`.
- CHECK `notas_clinicas_contenido_check`: 1 a 5000 caracteres.
- CHECK `notas_clinicas_version_check`: `version` ≥ 1.
- Índice `idx_notas_par_fecha (paciente_id, especialista_id, fecha DESC)`.

### `notas_clinicas_versiones`

Versión anterior de una nota cada vez que se edita.

| # | Columna | Tipo | N | Por defecto |
|---:|---|---|:--:|---|
| 1 | `id` | bigint (identity) | | — |
| 2 | `nota_id` | uuid | | — |
| 3 | `version` | integer | | — |
| 4 | `fecha` | date | | — |
| 5 | `contenido` | text | | — |
| 6 | `escrita_en` | timestamptz | | — |
| 7 | `reemplazada_en` | timestamptz | | `now()` |

- PK `notas_clinicas_versiones_pkey (id)`.
- UNIQUE `uq_nota_version (nota_id, version)`.
- FK `notas_clinicas_versiones_nota_id_fkey`: `nota_id → notas_clinicas(id) ON DELETE CASCADE`.
- Trigger `trg_notas_versiones_inmutables` (BEFORE UPDATE): no admite UPDATE.

### `marcadores_clinicos`

Marcadores de eventos en el historial del paciente.

| # | Columna | Tipo | N | Por defecto |
|---:|---|---|:--:|---|
| 1 | `id` | uuid | | `gen_random_uuid()` |
| 2 | `paciente_id` | varchar(50) | | — |
| 3 | `especialista_id` | varchar(50) | | — |
| 4 | `fecha` | timestamptz | | — |
| 5 | `tipo` | varchar(30) | | — |
| 6 | `descripcion` | varchar(140) | N | — |
| 7 | `creado_en` | timestamptz | | `now()` |

- PK `marcadores_clinicos_pkey (id)`.
- FK `paciente_id` y `especialista_id → usuarios(id)`.
- CHECK `marcadores_clinicos_tipo_check`: `tipo` ∈ {consulta, periodo_examenes,
  evento_personal, intervencion, otro}.
- Índice `idx_marcadores_par_fecha (paciente_id, especialista_id, fecha)`.

### `dispositivos_push`

Tokens de notificaciones (FCM) de la app.

| # | Columna | Tipo | N | Por defecto |
|---:|---|---|:--:|---|
| 1 | `token` | text | | — |
| 2 | `usuario_id` | varchar(50) | | — |
| 3 | `plataforma` | varchar(10) | | `'android'` |
| 4 | `creado_en` | timestamptz | | `now()` |
| 5 | `actualizado_en` | timestamptz | | `now()` |

- PK `dispositivos_push_pkey (token)`: un token pertenece a una sola cuenta.
- FK `dispositivos_push_usuario_id_fkey`: `usuario_id → usuarios(id) ON DELETE CASCADE`.
- CHECK `dispositivos_push_token_check`: 20 a 4096 caracteres.
- CHECK `dispositivos_push_plataforma_check`: `plataforma` = android.
- Índice `idx_dispositivos_usuario (usuario_id)`.

### `solicitudes_eliminacion`

Solicitudes de eliminación de cuenta (derecho de cancelación).

| # | Columna | Tipo | N | Por defecto |
|---:|---|---|:--:|---|
| 1 | `id` | uuid | | `uuid_generate_v4()` |
| 2 | `usuario_id` | varchar(50) | | — |
| 3 | `estado` | varchar(20) | | `'pendiente'` |
| 4 | `fecha_solicitud` | timestamptz | | `now()` |
| 5 | `atendida_en` | timestamptz | N | — |
| 6 | `atendida_por` | varchar(50) | N | — |

- PK `solicitudes_eliminacion_pkey (id)`.
- FK `fk_solicitud_usuario` (`usuario_id`) y `fk_solicitud_admin` (`atendida_por`) `→ usuarios(id)`.
- CHECK `chk_solicitud_estado`: `estado` ∈ {pendiente, atendida}.
- CHECK `chk_solicitud_atencion`: pendiente ⇒ `atendida_en` y `atendida_por`
  nulos; atendida ⇒ los dos llenos.
- Índice único parcial `uq_solicitud_pendiente (usuario_id) WHERE estado = 'pendiente'`:
  a lo más una solicitud pendiente por cuenta.

### `bitacora`

Bitácora de seguridad: accesos a datos clínicos, escrituras, exportaciones y
acciones de administración. Solo inserción.

| # | Columna | Tipo | N | Por defecto |
|---:|---|---|:--:|---|
| 1 | `id` | bigint (identity) | | — |
| 2 | `fecha` | timestamptz | | `now()` |
| 3 | `actor_id` | varchar(50) | | — |
| 4 | `actor_rol` | varchar(20) | | — |
| 5 | `accion` | varchar(40) | | — |
| 6 | `objetivo_id` | varchar(50) | N | — |
| 7 | `detalle` | jsonb | | `'{}'` |

- PK `bitacora_pkey (id)`. Sin llaves foráneas (a propósito).
- CHECK `bitacora_accion_check`: `accion` ∈ {acceso_datos_clinicos, exportacion,
  nota_creada, nota_editada, marcador_creado, marcador_eliminado, vinculacion,
  desvinculacion, cuenta_suspendida, cuenta_reactivada, cuenta_eliminada}
  (11 acciones).
- CHECK `bitacora_detalle_check`: `detalle` es un objeto JSON.
- Índices: `idx_bitacora_fecha (fecha DESC)`, `idx_bitacora_actor (actor_id, fecha DESC)`,
  `idx_bitacora_objetivo (objetivo_id, fecha DESC)`, `idx_bitacora_accion (accion, fecha DESC)`.
- Trigger `trg_bitacora_sin_update_delete` (BEFORE UPDATE y BEFORE DELETE).

## Índices

32 en total: 14 de llave primaria, 5 de restricciones UNIQUE, 1 único parcial
(`uq_solicitud_pendiente`) y 12 secundarios. Todos son B-tree.

| Tabla | Índices secundarios y únicos (además de la PK) |
|---|---|
| `bitacora` | `idx_bitacora_fecha`, `idx_bitacora_actor`, `idx_bitacora_objetivo`, `idx_bitacora_accion` |
| `consentimientos` | `idx_consentimientos_usuario_fecha`, `uq_consentimiento_version` |
| `dispositivos_push` | `idx_dispositivos_usuario` |
| `ejercicios_asignados` | `idx_ejercicios_paciente_fecha` |
| `marcadores_clinicos` | `idx_marcadores_par_fecha` |
| `mensajes_chat` | `idx_mensajes_paciente_fecha` |
| `notas_clinicas` | `idx_notas_par_fecha` |
| `notas_clinicas_versiones` | `uq_nota_version` |
| `respuestas_eva` | `uq_eva_sesion` |
| `respuestas_gad7` | `idx_gad7_paciente_fecha` |
| `sesiones_medicion` | `idx_sesiones_paciente_fecha` |
| `solicitudes_eliminacion` | `uq_solicitud_pendiente` (parcial) |
| `usuarios` | `usuarios_email_key`, `usuarios_codigo_vinculacion_key` |
| `lecturas_biometricas` | — |

## Triggers y funciones

| Trigger | Tabla | Momento | Evento | Función |
|---|---|---|---|---|
| `trg_bitacora_sin_update_delete` | `bitacora` | BEFORE | UPDATE, DELETE | `bitacora_solo_insertar()` |
| `trg_notas_versiones_inmutables` | `notas_clinicas_versiones` | BEFORE | UPDATE | `notas_versiones_inmutables()` |

Las dos funciones son PL/pgSQL, con `SET search_path TO 'pg_catalog'`, y solo
lanzan una excepción:

```sql
CREATE OR REPLACE FUNCTION public.bitacora_solo_insertar() RETURNS trigger
  LANGUAGE plpgsql SET search_path TO 'pg_catalog'
AS $function$ BEGIN RAISE EXCEPTION 'bitacora es de solo inserción'; END $function$;

CREATE OR REPLACE FUNCTION public.notas_versiones_inmutables() RETURNS trigger
  LANGUAGE plpgsql SET search_path TO 'pg_catalog'
AS $function$ BEGIN RAISE EXCEPTION 'notas_clinicas_versiones no admite UPDATE'; END $function$;
```

**TRUNCATE, por confirmar.** `CONTEXTO_PROYECTO.md` y
`docs/tesis/02_inventario_implementacion.md` dicen que `bitacora` también tiene
`trg_bitacora_sin_truncate`. C4 no lo muestra, pero tampoco podría:
`information_schema.triggers` solo lista triggers de INSERT, UPDATE y DELETE.
Se confirma con la consulta C7 (al final).

## Seguridad a nivel de fila (RLS)

| Tabla | RLS activa | RLS forzada |
|---|:--:|:--:|
| `bitacora` | sí | no |
| `consentimientos` | sí | no |
| `dispositivos_push` | sí | no |
| `ejercicios_asignados` | sí | no |
| `lecturas_biometricas` | sí | no |
| `marcadores_clinicos` | sí | no |
| `mensajes_chat` | sí | no |
| `notas_clinicas` | sí | no |
| `notas_clinicas_versiones` | sí | no |
| `respuestas_eva` | sí | no |
| `respuestas_gad7` | sí | no |
| `sesiones_medicion` | sí | no |
| `solicitudes_eliminacion` | sí | no |
| `usuarios` | sí | no |

Ninguna tabla tiene políticas, así que la API REST de Supabase (roles `anon` y
`authenticated`) no ve ni escribe ninguna fila, y esos roles tampoco tienen
permisos sobre las tablas. El backend entra con el rol dueño
(`rolbypassrls = true`), por eso RLS no está forzada: toda la autorización la
decide el backend (ver `rutas.md`).

## Observaciones

- `usuarios.especialista_id`, `usuarios.codigo_vinculacion` y
  `mensajes_chat.especialista_id` son `varchar` sin longitud; el resto de los
  identificadores son `varchar(50)`.
- `lecturas_biometricas` conserva las columnas `score_ansiedad` y
  `estado_ansiedad` de la primera versión. Solo las usa la ruta de lecturas
  sueltas (`POST /api/lecturas` y su resumen); las sesiones de medición no las
  usan.

## Consultas usadas

Todas son solo `SELECT` sobre el catálogo, corridas en el SQL Editor de Supabase.

```sql
-- C0. Versión de PostgreSQL
SELECT version();

-- C1. Columnas: tipo, longitud, nulos y valor por defecto
SELECT table_name, ordinal_position, column_name,
       data_type, udt_name, character_maximum_length,
       is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;

-- C2. Restricciones: PK, FK, UNIQUE y CHECK, con su definición
SELECT conrelid::regclass AS tabla, conname AS nombre, contype AS tipo,
       pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
ORDER BY 1, 3, 2;

-- C3. Índices
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- C4. Triggers
SELECT event_object_table AS tabla, trigger_name, action_timing,
       event_manipulation, action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY 1, 2, 4;

-- C5. Funciones propias del esquema public (las que usan los triggers)
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS argumentos,
       pg_get_functiondef(p.oid) AS definicion
FROM pg_proc p
WHERE p.pronamespace = 'public'::regnamespace
ORDER BY 1;

-- C6. RLS por tabla
SELECT relname AS tabla, relrowsecurity AS rls_activa, relforcerowsecurity AS rls_forzada
FROM pg_class
WHERE relnamespace = 'public'::regnamespace AND relkind = 'r'
ORDER BY 1;
```

`information_schema.triggers` no lista los triggers de `TRUNCATE`. C7 los lee de
`pg_trigger` (pendiente de correr):

```sql
-- C7. Todos los triggers propios de bitacora, incluidos los de TRUNCATE
SELECT tgname, tgrelid::regclass AS tabla, pg_get_triggerdef(oid) AS definicion
FROM pg_trigger
WHERE tgrelid = 'public.bitacora'::regclass AND NOT tgisinternal
ORDER BY 1;
```
