# Plan Fase C — Rol Admin

> **Estado: EN EJECUCIÓN** (plan aprobado el 2026-09-29; ejecución iniciada el 2026-10-02).
> - ✅ **Verificación y DDL hechas** (sección 3, resultados abajo).
> - ✅ **Paso 1 — Ver usuarios: hecho y probado visualmente** (backend `0f16858`, portal
>   `9e1b719`). **Pendiente de confirmar:** que un especialista entra y ve su portal igual que
>   antes, y el 403 por comando de `GET /api/admin/usuarios` con token de paciente y de
>   especialista (200 con admin).
> - ⏭️ **Siguiente: paso 2 — Editar datos** (sección 5).

El admin gestiona **todas las cuentas de usuario**: ver, editar datos, cambiar roles,
suspender/reactivar, forzar restablecimiento de contraseña y eliminar. Se construye **paso
por paso**, probando cada uno (build/prueba manual → commit → docs), igual que las fases
anteriores.

---

## 1. Lo que se encontró en el código (condiciona el diseño)

- **`backend/auth.js`** resuelve el rol consultando `SELECT rol FROM usuarios WHERE id = $1`
  en cada request (no hay custom claims de Firebase). Por eso `req.rol` puede valer `'admin'`
  sin tocar Firebase: basta con el valor en la tabla.
- **Todas las rutas clínicas exigen `rol === 'paciente'` o `rol === 'especialista'`**
  (`/api/lecturas*`, `/api/mensajes`, `/api/ejercicios*`, `/api/pendientes*`,
  `/api/vinculacion`, `/api/pacientes`). Un admin ya recibe **403** en todas ellas, y así debe
  quedarse (mínimo privilegio).
- **`GET/PUT /api/usuarios/:id`** solo permiten el perfil propio (`autorizarPerfilPropio`,
  Fase 2e). El admin puede usarlas para SU perfil; los perfiles ajenos se gestionan por las
  rutas nuevas de admin.
- **`backend/validation.js`** tiene `ROLES = ['paciente', 'especialista']` y
  `POST /api/usuarios` solo registra pacientes (especialistas solo vía
  `POST /api/especialistas` con código de institución). **Nadie puede auto-registrarse como
  admin**, y esto no cambia: el cambio de rol vivirá en una lista aparte (`ROLES_ADMIN`)
  usada solo por la ruta de admin.
- **Portal (`web_portal/src/App.js`)**: tras el login, cada 15 s pide `/api/pacientes` y el
  perfil propio (`Promise.allSettled`); si `/api/pacientes` da 403 muestra "cuenta sin rol
  especialista".
- **Firebase Admin SDK** ya está inicializado en el backend (`inicializarFirebaseAdmin`).
  Ofrece `updateUser` (email, `disabled`), `revokeRefreshTokens` y `deleteUser`. **No envía
  correos de restablecimiento** (solo `generatePasswordResetLink`, que exigiría un servicio de
  correo propio).
- **Restablecimiento de contraseña**: el SDK cliente de Firebase permite a cualquiera pedir un
  reset para cualquier correo (así funciona HU02). Enviarlo desde el portal del admin con
  `sendPasswordResetEmail` **no abre ningún hueco nuevo** y no requiere endpoint.

---

## 2. Diseño aprobado

- **Opción 1 — mismo login para todos.** El admin entra con el login normal de Firebase del
  portal. Según `rol === 'admin'`, el portal le muestra la interfaz de administración en lugar
  del portal de especialista. **No hay login separado.**
- **Mínimo privilegio.** El admin gestiona **cuentas**, no datos clínicos: no ve lecturas,
  mensajes ni ejercicios. Nota fija en el panel: *"Gestión de cuentas. Este panel no da acceso
  a datos clínicos (lecturas, mensajes ni ejercicios)."*
- **Contraseñas.** El admin **no puede ver ni escribir contraseñas** (Firebase las cifra). Solo
  puede **forzar un restablecimiento**: enviar el correo `sendPasswordResetEmail` para que el
  usuario cree una nueva. Texto en la UI: *"Las contraseñas están cifradas por Firebase: nadie,
  ni el administrador, puede verlas ni escribirlas. Este botón envía al usuario un correo para
  que él mismo cree una nueva."*
- **Seguridad (no negociable).** Todos los endpoints de admin se montan bajo un router con un
  middleware único:

  ```js
  // server.js, después de app.use('/api', requiereAuth(pool))
  app.use('/api/admin', requiereAdmin, adminRouter);
  ```

  `requiereAdmin` responde **403** si `req.rol !== 'admin'` (pacientes, especialistas y
  cuentas sin fila) **antes** de llegar a cualquier ruta del router. Así ninguna ruta de admin
  puede quedar sin verificación por olvido. La interfaz del portal NO es la seguridad: aunque
  alguien forzara la vista de admin en el navegador, el backend rechaza cada llamada.
- **Candados en el backend (todas las rutas que aplique):**
  - el admin **no puede suspenderse, degradarse ni eliminarse a sí mismo**;
  - **nunca puede quedar el sistema con cero admins** (activos, no suspendidos ni eliminados);
  - un **especialista con pacientes vinculados** no puede cambiar de rol ni eliminarse hasta
    reasignar o desvincular a sus pacientes.
- **Suspensión efectiva al instante.** Un idToken de Firebase sigue siendo válido hasta ~1 h
  después de desactivar la cuenta. Para cortarlo de inmediato, `requiereAuth` y
  `requiereAuthSocket` leerán `rol` + estado (`suspendido` / eliminado) en la MISMA consulta
  que ya hacen y responderán **403 "Cuenta suspendida"** (sin consultas extra). Además:
  Firebase `disabled: true` (bloquea nuevos logins) + `revokeRefreshTokens`.
- **Detección en el portal.** `App.js` pide primero el perfil propio
  (`GET /api/usuarios/:uid`, ya devuelve `rol`). Si `rol === 'admin'` renderiza
  `<AdminApp>` (mismo `Layout`, sidebar: Administración → Usuarios; Cuenta → Mi perfil /
  Salir) y **no** pide `/api/pacientes`. Para los demás roles, el portal sigue igual.

---

## 3. Consultas de verificación (correr al retomar, ANTES de cualquier DDL o designación)

### ✅ Resultados (2026-10-02) y lo que se aplicó

- **Columnas de `usuarios`:** id, nombre, rol, email, fecha_registro, especialista_id,
  codigo_vinculacion, ultima_apertura_mensajes, ultima_apertura_ejercicios.
- **CHECK sobre `rol`:** existía `usuarios_rol_check` (solo `'paciente'`, `'especialista'`).
- **FK hacia `usuarios`:** `lecturas_biometricas.paciente_id` y `mensajes_chat.paciente_id`
  con `ON DELETE CASCADE`; `usuarios.especialista_id` (`fk_especialista`) con
  `ON DELETE SET NULL`; `mensajes_chat.remitente_id`, `ejercicios_asignados.paciente_id` y
  `.especialista_id` sin `ON DELETE`. **Consecuencia:** un `DELETE` real de un paciente
  borraría sus lecturas y mensajes (y podría fallar por los ejercicios). El paso 6 **nunca**
  hace `DELETE FROM usuarios`: solo pone `eliminado_en = now()`.
- **DDL aplicada a mano en Supabase y verificada:**
  - `usuarios_rol_check` recreado como `CHECK (rol IN ('paciente', 'especialista', 'admin'))`.
  - `suspendido boolean NOT NULL DEFAULT false` y `eliminado_en timestamptz NULL` (ya
    existen; los pasos 3 y 6 no necesitan más DDL).
- **Admin inicial designado:** cuenta dedicada `admin@sistema-ansiedad.com` (registrada como
  paciente y promovida con el `UPDATE` de abajo). Conteo final: admin 1, especialista 2,
  paciente 5.

### Consultas (referencia)

Son de **solo lectura**. Pasar los resultados completos antes de continuar.

**Consulta 1 — columnas reales de `usuarios`:**

```sql
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'usuarios'
ORDER BY ordinal_position;
```

**Consulta 2 — restricciones de `usuarios` (¿hay un CHECK que limite `rol`?):**

```sql
SELECT conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE conrelid = 'usuarios'::regclass;
```

**Consulta 3 — tablas con llaves foráneas hacia `usuarios`:**

```sql
SELECT conrelid::regclass AS tabla, conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE confrelid = 'usuarios'::regclass
  AND contype = 'f';
```

**Consulta 4 — cuentas por rol:**

```sql
SELECT rol, count(*) AS cuentas
FROM usuarios
GROUP BY rol
ORDER BY rol;
```

### Designar al admin inicial (solo DESPUÉS de revisar las 4 consultas)

- **Cuenta dedicada** (decisión aprobada): no usar la cuenta de especialista del desarrollador,
  porque el admin no ve el portal de especialista. Registrar una cuenta nueva como paciente
  desde la app, con un correo propio de administración, y luego:

  ```sql
  UPDATE usuarios
  SET rol = 'admin', especialista_id = NULL, codigo_vinculacion = NULL
  WHERE email = 'admin@tu-dominio.com'
  RETURNING id, nombre, email, rol;
  ```

- Si la consulta 2 muestra un `CHECK` sobre `rol`, primero hay que ajustarlo (la DDL se
  redacta con el nombre real de la restricción, no se asume).
- Se designa **una sola vez, a mano**; los siguientes admins se promueven desde el panel.

### DDL esperada (✅ ya aplicada el 2026-10-02 con estos nombres, ver resultados arriba)

- **Paso 3 (suspender):** columna de estado de suspensión en `usuarios`, p. ej.
  `suspendido boolean NOT NULL DEFAULT false`.
- **Paso 6 (eliminar, borrado lógico):** columna de marca de eliminación, p. ej.
  `eliminado_en timestamptz NULL`.
- Ambas se proponen con los nombres reales tras ver la consulta 1, y se aplican a mano en
  Supabase **antes** del deploy del backend que las usa.

---

## 4. Endpoints nuevos (todos bajo `requiereAdmin`)

Viven en `backend/admin.js` (`express.Router`). Ninguno devuelve datos clínicos.

| Método y ruta | Qué hace |
|---|---|
| `GET /api/admin/usuarios` | Lista de cuentas: id, nombre, email, rol, estado (activa / suspendida / eliminada), especialista vinculado (para pacientes) y n.º de pacientes (para especialistas). |
| `PUT /api/admin/usuarios/:id` | Edita nombre y email, y **reasigna/desvincula el especialista de un paciente**. El email se cambia en Firebase (`updateUser`) **y** en la BD; si falla la BD, se revierte en Firebase. |
| `POST /api/admin/usuarios/:id/suspender` | Firebase `disabled: true` + `revokeRefreshTokens` + marca de suspensión en la BD. |
| `POST /api/admin/usuarios/:id/reactivar` | Revierte lo anterior. |
| `PUT /api/admin/usuarios/:id/rol` | Cambio de rol con las reglas de la sección 5 (paso 4). |
| `DELETE /api/admin/usuarios/:id` | **Borrado lógico** (ver decisión 1): marca de eliminación + Firebase `disabled` + `revokeRefreshTokens`; los datos se conservan. |

El restablecimiento de contraseña **no** tiene endpoint: se envía desde el portal con
`sendPasswordResetEmail` (ver sección 1). Todas las acciones se registran con el logger
estructurado (`backend/logger.js`): quién (uid del admin), qué acción, sobre quién.

---

## 5. Orden de construcción (un paso a la vez: backend → portal → prueba → commit → docs)

| Paso | Qué se construye | Cómo se prueba |
|---|---|---|
| **1. Ver usuarios** ✅ | Designar admin (sección 3), `requiereAdmin`, `GET /api/admin/usuarios`, detección de rol en `App.js`, `<AdminApp>` con tabla de usuarios (búsqueda, filtro por rol y estado). | **Por comando:** `GET /api/admin/usuarios` con token de paciente → **403**, de especialista → **403**, de admin → **200**. **Portal:** el admin ve la interfaz de administración; un especialista sigue viendo su portal igual. **Hecho:** admin probado en el portal (contadores 8/5/2/1, tabla, búsqueda, filtros, "Mi perfil" como Administrador). **Falta:** el especialista sin cambios y los 403 por comando. |
| **2. Editar datos** | Nombre, email y reasignar/desvincular especialista de un paciente. | 403 con paciente y especialista; editar nombre; cambiar email y entrar con el correo nuevo; reasignar un paciente y verlo en la lista del nuevo especialista. |
| **3. Suspender / reactivar** | DDL de suspensión (tras verificación), endpoints, chequeo en `requiereAuth` y `requiereAuthSocket`, mensaje al intentar entrar (decisión 2). | Suspender a un paciente con la app abierta: su siguiente request da 403 y no puede volver a iniciar sesión; reactivar → vuelve a entrar. Intentar suspenderse a sí mismo → rechazado. Suspender al último admin → rechazado. |
| **4. Cambiar rol** | Reglas: paciente → especialista (se limpia su `especialista_id` y se genera `codigo_vinculacion`, con la misma función que `POST /api/especialistas`); especialista → otro rol **bloqueado mientras tenga pacientes vinculados**; promover a admin con confirmación explícita; degradar admin respetando "nunca cero admins". | Cada transición; especialista con pacientes → rechazado; no degradarse a sí mismo; no degradar al último admin. |
| **5. Forzar restablecimiento** | Botón "Enviar correo de restablecimiento" con el texto de contraseñas cifradas (sección 2). `auth.languageCode = 'es'`. | Llega el correo en español al usuario y puede crear su contraseña nueva. |
| **6. Eliminar** | DDL de borrado lógico (tras verificación), `DELETE` lógico, confirmación escribiendo el email en el portal. Las cuentas eliminadas desaparecen de las listas de uso normal (p. ej. `/api/pacientes` del especialista) y no pueden vincularse ni entrar. | 403 con paciente y especialista; eliminar una cuenta de prueba: no puede entrar, desaparece de la lista de su especialista, sus datos siguen en la BD; no puede eliminarse a sí mismo; especialista con pacientes → rechazado. |

### Cómo quedó el paso 1 (para los siguientes)

- **Backend:** `requiereAdmin` vive en `backend/auth.js`; el router en `backend/admin.js`
  (`crearAdminRouter(pool)`), montado en `server.js` con
  `app.use('/api/admin', requiereAdmin, crearAdminRouter(pool))`. Las rutas nuevas de los
  pasos 2–6 se agregan dentro de ese router. `GET /api/admin/usuarios` devuelve id, nombre,
  email, rol, fecha_registro, `estado` (`activa` / `suspendida` / `eliminada`, calculado en
  SQL desde `suspendido` y `eliminado_en`), especialista_id, especialista_nombre y
  `pacientes_vinculados` (solo en especialistas; hoy cuenta también a los pacientes
  eliminados — decidirlo en el paso 6).
- **Portal:** `App.js` resuelve el rol con el perfil propio antes de pedir `/api/pacientes`
  ("Cargando..." mientras tanto; sin red se reintenta en la siguiente vuelta de 15 s; con
  respuesta de error sigue al portal de especialista). `AdminApp.js` (sidebar) +
  `AdminUsuarios.js` (contadores, tabla, búsqueda y filtros en el navegador; recarga con
  "Actualizar", sin sondeo). "Mi perfil" reutiliza `PerfilEspecialista` con `esAdmin`.

---

## 6. Decisiones aprobadas

1. **Eliminar = borrado lógico por defecto.** Se marca la cuenta como eliminada (marca de fecha
   en `usuarios`), se desactiva en Firebase y se revocan sus sesiones; **los datos clínicos se
   conservan**. Implicaciones a cuidar al construir el paso 6:
   - las cuentas eliminadas se excluyen de `/api/pacientes`, de la vinculación por código y de
     cualquier lista de uso normal;
   - `requiereAuth` / `requiereAuthSocket` las rechazan igual que a las suspendidas;
   - como la cuenta de Firebase sigue existiendo (desactivada), **su correo no puede volver a
     registrarse**; un borrado real (Firebase `deleteUser` + filas) queda como opción futura
     si se necesita.
2. **Mensaje de cuenta suspendida: la opción segura.** Solo se mostrará un mensaje específico
   ("Tu cuenta está suspendida. Contacta al administrador.") **si se comprueba** que Firebase
   devuelve `user-disabled` únicamente con la contraseña correcta. Si también lo devuelve con
   una contraseña incorrecta (lo que revelaría qué correos existen), se mantiene el genérico
   "Correo o contraseña incorrectos." (misma política que el login del portal y de la app).
3. **Promover a admin: sí**, con confirmación explícita en el portal y la regla del backend
   de **nunca cero admins**.
4. **Bitácora de acciones del admin: trabajo futuro.** Por ahora solo logs estructurados con
   `backend/logger.js` (visibles en Render). Una tabla `admin_auditoria` (requiere DDL) queda
   en Diferidos.
5. **Reasignar especialista desde "Editar": sí** (paso 2). Además lo necesitan los candados de
   los pasos 4 y 6 (especialista con pacientes).
6. **Admin inicial en cuenta dedicada**, designada a mano una sola vez con la consulta de la
   sección 3.

---

## 7. Fuera de alcance de la Fase C

- Admin en la **app móvil**: si un admin entra a la app no verá datos (todo lo clínico le da
  403). Mejora futura: aviso "Esta cuenta es de administración; usa el portal".
- Crear cuentas desde el panel ("+ Nuevo usuario").
- Ver o editar datos clínicos (lecturas, mensajes, ejercicios).
- Borrado real de cuentas y tabla de auditoría (ver decisiones 1 y 4).

---

## 8. Reglas permanentes que aplican

- Claude Code **no tiene acceso a la base**: toda DDL va precedida de una consulta de solo
  lectura, se usan los nombres de columna reales y el desarrollador aplica las migraciones a
  mano en Supabase **antes** del deploy del backend.
- Flujo por pasos: implementar → `node --check` / `npm run build` → prueba manual → commit →
  actualizar `CONTEXTO_PROYECTO.md` → push. Trabajo sobre `main`.
- Lenguaje y alcance: el panel de admin no muestra datos fisiológicos; donde aplique, se
  mantienen los avisos de alcance del sistema (no emite diagnósticos).
