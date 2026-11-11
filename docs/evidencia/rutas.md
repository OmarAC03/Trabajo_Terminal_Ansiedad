# Rutas REST y eventos de Socket.io

Leído de `backend/server.js`, `backend/especialista.js`, `backend/admin.js`,
`backend/auth.js` y `backend/seguridad.js` el 11 de noviembre de 2026 (commit `1e4e2e0`).
**49 rutas REST** (31 en `server.js`, 8 en el router del especialista, 3 en el router
de la cuenta del especialista y 7 en el router de administración) y **2 eventos de
Socket.io** propios. Actualizado con la Fase 2 del portal (router
`cuenta_especialista.js`).

## Cadena de middleware

Se aplica en este orden a toda petición:

| # | Middleware | Dónde | Qué hace |
|---|---|---|---|
| 1 | `trust proxy = 1` | `server.js` | Toma la IP real detrás del proxy de Render (para los límites por IP). |
| 2 | `cors(opcionesCors)` | `seguridad.js` | Solo acepta el origen `https://monitor-ansiedad-escom.onrender.com` (y `http://localhost:3000` si `NODE_ENV` ≠ `production`). Una petición sin `Origin` (la app) pasa. |
| 3 | `limites.porIp` en `/api` | `seguridad.js` | 1000 peticiones / 15 min por IP. |
| 4 | `express.json()` | Express | Lee el cuerpo JSON. |
| 5 | `requiereAuth(pool)` en `/api` | `auth.js` | Exige `Authorization: Bearer <token de Firebase>`; adjunta `req.uid`, `req.rol` y `req.consentimientoVigente`; rechaza cuentas suspendidas o eliminadas (403). **No aplica a `GET /api/salud`.** |
| 6 | `limites.porUsuario` en `/api` | `seguridad.js` | 600 peticiones / 15 min por cuenta. |
| 7 | `limites.estricto` | `seguridad.js` | 10 peticiones / hora por cuenta, solo en las 4 rutas marcadas con **E**. |
| 8 | `requiereAdmin` en `/api/admin` | `auth.js` | 403 a cualquier rol que no sea `admin`. |
| — | Manejador de errores | `server.js` | Responde `{ error, codigo }` con el código HTTP del error (400, 403, 404, 409, 429, 500). |

La autorización fina (dueño de los datos, especialista vinculado, rol) se decide al
inicio de cada handler:

- **Propio o vinculado** (`autorizarLecturaPaciente`): el propio paciente, o un
  especialista vinculado a él; el acceso del especialista queda en la bitácora
  (uno por par cada 10 min).
- **Especialista vinculado** (`autorizarEspecialistaVinculado`): solo el especialista
  del paciente.
- **Consentimiento** (`exigirConsentimiento`): un paciente sin el consentimiento
  vigente recibe 403 `consentimiento_requerido`.

En la columna Middleware, «base» = 1–6 de la tabla anterior.

## Rutas de `server.js`

| Método | Ruta | Rol que puede usarla | Middleware y reglas |
|---|---|---|---|
| GET | `/api/salud` | Pública (sin token) | 1–4. Responde `{ ok: true }` con `Cache-Control: no-store`. |
| POST | `/api/lecturas` | Paciente (solo las suyas) | base · consentimiento |
| GET | `/api/lecturas` | Especialista | base · solo lecturas de sus pacientes vinculados |
| GET | `/api/lecturas/:pacienteId` | Propio o vinculado | base · bitácora de acceso |
| GET | `/api/lecturas/:pacienteId/resumen` | Propio o vinculado | base · bitácora de acceso |
| GET | `/api/linea-base/:pacienteId` | Propio o vinculado | base · el paciente no recibe bandas ni z (regla de oro) |
| POST | `/api/sesiones` | Paciente | base · consentimiento |
| GET | `/api/sesiones/:pacienteId` | Propio o vinculado | base · bitácora de acceso |
| GET | `/api/sesiones/:pacienteId/:sesionId` | Propio o vinculado | base · bitácora de acceso |
| POST | `/api/sesiones/:sesionId/eva` | Paciente (dueño de la sesión) | base · consentimiento |
| POST | `/api/gad7` | Paciente vinculado a un especialista | base · **E** · consentimiento · solo si le toca (cada 14 días) |
| GET | `/api/gad7/:pacienteId` | Propio o vinculado | base · el paciente solo recibe la fecha, nunca el puntaje |
| GET | `/api/mensajes/:pacienteId` | Propio o vinculado | base · solo la conversación con el especialista vinculado actual |
| POST | `/api/ejercicios` | Especialista vinculado | base |
| GET | `/api/ejercicios/:pacienteId` | Propio o vinculado | base |
| PUT | `/api/dispositivos` | Paciente | base · registra el token de notificaciones |
| DELETE | `/api/dispositivos` | Paciente | base |
| GET | `/api/dispositivos` | Paciente | base |
| GET | `/api/pendientes` | Paciente | base · indicadores de mensajes y ejercicios nuevos |
| POST | `/api/pendientes/:seccion/visto` | Paciente | base |
| POST | `/api/usuarios` | Cuenta de Firebase sin perfil (registra su propio uid como paciente) | base · **E** · guarda el consentimiento en la misma transacción |
| GET | `/api/solicitud-eliminacion` | Paciente | base |
| POST | `/api/solicitud-eliminacion` | Paciente | base |
| GET | `/api/consentimiento` | Cualquier cuenta registrada | base · especialistas y admins reciben `requerido: false` |
| POST | `/api/consentimiento` | Paciente | base · **E** |
| POST | `/api/especialistas` | Cuenta de Firebase sin perfil + `codigo_institucion` correcto | base · **E** |
| POST | `/api/vinculacion` | Paciente | base · con el código de vinculación del especialista |
| GET | `/api/vinculacion` | Paciente | base |
| GET | `/api/usuarios/:id` | Solo el propio usuario | base |
| PUT | `/api/usuarios/:id` | Solo el propio usuario | base · solo cambia el nombre |
| GET | `/api/pacientes` | Especialista | base · solo sus pacientes vinculados |

## Router del especialista (`especialista.js`, montado en `/api/pacientes`)

Todas exigen **especialista vinculado** al paciente; las escrituras y la exportación
quedan en la bitácora en la misma transacción.

| Método | Ruta | Qué hace |
|---|---|---|
| GET | `/api/pacientes/:pacienteId/notas` | Notas clínicas del paciente |
| POST | `/api/pacientes/:pacienteId/notas` | Crea una nota |
| PUT | `/api/pacientes/:pacienteId/notas/:notaId` | Edita una nota (guarda la versión anterior) |
| GET | `/api/pacientes/:pacienteId/notas/:notaId/versiones` | Historial de versiones de una nota |
| GET | `/api/pacientes/:pacienteId/marcadores` | Marcadores de eventos |
| POST | `/api/pacientes/:pacienteId/marcadores` | Crea un marcador |
| DELETE | `/api/pacientes/:pacienteId/marcadores/:marcadorId` | Borra un marcador |
| GET | `/api/pacientes/:pacienteId/reporte` | Reporte para exportar (`Cache-Control: no-store`) |

## Router de la cuenta del especialista (`cuenta_especialista.js`, montado en `/api/especialista`)

Todas exigen el rol `especialista` (403 a pacientes y admins) y filtran por el uid
del token: nadie ve la bandeja, las exportaciones ni el resumen de otro.

| Método | Ruta | Qué hace |
|---|---|---|
| GET | `/api/especialista/conversaciones` | Bandeja de Mensajes: por paciente vinculado, fecha del último mensaje, quién lo escribió y cuántos mensajes del paciente siguen sin respuesta. No devuelve el texto de ningún mensaje. |
| GET | `/api/especialista/exportaciones` | Últimas 100 exportaciones propias, leídas de la bitácora; sin nombre si el paciente ya no está vinculado (`Cache-Control: no-store`). |
| GET | `/api/especialista/resumen` | Fecha de alta y conteos propios: pacientes vinculados, mensajes enviados, notas y exportaciones del mes. |

## Router de administración (`admin.js`, montado en `/api/admin`)

Todas pasan por `requiereAdmin` (rol `admin`). Las rutas clínicas de arriba responden
403 a un admin (mínimo privilegio).

| Método | Ruta | Qué hace |
|---|---|---|
| GET | `/api/admin/usuarios` | Lista de cuentas |
| PUT | `/api/admin/usuarios/:id` | Edita una cuenta |
| POST | `/api/admin/usuarios/:id/suspender` | Suspende la cuenta y cierra sus sockets abiertos |
| POST | `/api/admin/usuarios/:id/reactivar` | Reactiva la cuenta |
| GET | `/api/admin/solicitudes-eliminacion` | Solicitudes de eliminación pendientes |
| POST | `/api/admin/solicitudes-eliminacion/:id/atender` | Atiende una solicitud: desactiva la cuenta en Firebase, borra los datos clínicos y deja la fila de `usuarios` seudonimizada, todo en una transacción |
| GET | `/api/admin/bitacora` | Bitácora de seguridad |

## Socket.io (`server.js`)

| Momento | Evento | Sentido | Datos | Reglas |
|---|---|---|---|---|
| Handshake | — | cliente → servidor | `auth: { token }` | `allowRequest` rechaza otro origen (mismo criterio que CORS); `requiereAuthSocket` exige un token de Firebase válido y rechaza cuentas suspendidas o eliminadas (`auth_required`, `auth_invalid`, `server_error`). |
| Conexión | `connection` | — | — | El socket entra a su sala privada `usuario:<uid>` y a ninguna otra. |
| Enviar mensaje | `enviar_mensaje` | cliente → servidor | `{ paciente_id, texto (máx. 2000), tipo_mensaje }` + *ack* `{ ok, error? }` | Un paciente solo escribe en su conversación y necesita especialista vinculado; un especialista solo a sus pacientes vinculados. `remitente_id` y `especialista_id` los pone el servidor. Si escribe el especialista, el paciente recibe un push con texto fijo, sin el mensaje. |
| Recibir mensaje | `recibir_mensaje` | servidor → cliente | la fila guardada de `mensajes_chat` | Solo a las salas del paciente y de su especialista vinculado actual. |
| Desconexión | `disconnect` | — | — | Solo se registra en el log. Al suspender una cuenta, el servidor cierra sus sockets (`disconnectSockets`). |

La prueba `backend/pruebas/prueba_aislamiento.ps1` (con `aislamiento_socket.js`)
comprueba que otro paciente o un especialista no vinculado reciben 403 en las rutas de
un paciente y no pueden escribir en su canal ni recibir sus mensajes.
