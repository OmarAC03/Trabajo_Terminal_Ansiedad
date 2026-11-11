# Esquema de la base de datos

> **Pendiente de completar.** El repositorio no guarda el DDL: las tablas se crearon en
> Supabase. Este archivo se llena con el resultado de las consultas de solo lectura de
> abajo, y no se inventa ninguna columna.

## Tablas que usa el código

Las 14 tablas del esquema `public`, según el SQL de `backend/` (y según la revisión de
RLS de la Fase S, donde ya aparecían las 14):

| Tabla | Para qué |
|---|---|
| `usuarios` | Cuentas (paciente, especialista, admin), vínculo con el especialista, suspensión y eliminación |
| `consentimientos` | Aceptaciones del aviso y del consentimiento, por versión |
| `lecturas_biometricas` | Lecturas sueltas del sensor |
| `sesiones_medicion` | Sesiones de medición guiada (HRV, frecuencia cardiaca, SpO2, calidad) |
| `respuestas_eva` | EVA al terminar una sesión |
| `respuestas_gad7` | Cuestionario GAD-7 quincenal |
| `mensajes_chat` | Mensajes entre paciente y especialista |
| `ejercicios_asignados` | Ejercicios que asigna el especialista |
| `notas_clinicas` | Notas del especialista |
| `notas_clinicas_versiones` | Versiones anteriores de cada nota |
| `marcadores_clinicos` | Marcadores de eventos en el historial |
| `dispositivos_push` | Tokens de notificaciones de la app |
| `solicitudes_eliminacion` | Solicitudes de eliminación de cuenta |
| `bitacora` | Bitácora de seguridad (accesos, escrituras, exportaciones, administración) |

## Consultas de solo lectura

Ninguna modifica nada: solo `SELECT` sobre el catálogo. Córrelas en el SQL Editor de
Supabase y exporta cada resultado (CSV o copia de la tabla).

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

-- C6. RLS por tabla (para confirmar el estado después del DDL de la Fase S)
SELECT relname AS tabla, relrowsecurity AS rls_activa, relforcerowsecurity AS rls_forzada
FROM pg_class
WHERE relnamespace = 'public'::regnamespace AND relkind = 'r'
ORDER BY 1;
```

En `contype` de C2: `p` = llave primaria, `f` = llave foránea, `u` = única,
`c` = CHECK.
