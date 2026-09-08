# Contexto para Claude (chat) — Pasos manuales pendientes del Incremento 6a

> Pega este documento completo al inicio de una conversación con Claude.ai (chat) para que te
> guíe paso a paso en las tareas manuales de abajo. No son tareas de código — son configuración
> en consolas web (Firebase, Render) y comandos de terminal que no se pudieron ejecutar desde
> Claude Code en la sesión anterior. Cuando termines TODOS los pasos, vuelve a Claude Code y
> avísale qué hiciste (y qué resultado diste, sobre todo si algo falló) para que retome el trabajo.

---

## 1. Qué es el proyecto (contexto mínimo)

Sistema de monitoreo biométrico de ansiedad, monorepo con 3 partes:

- **`app_ansiedad/`** — App móvil Flutter (la usa el paciente).
- **`backend/`** — Node.js + Express + Socket.io, desplegado en Render:
  `https://tt-ansiedad-backend.onrender.com`.
- **`web_portal/`** — Portal clínico en React (lo usa el especialista).

Base de datos: PostgreSQL en Supabase. Autenticación: Firebase Auth.

## 2. Qué se acaba de terminar (Incremento 6a)

Se implementó autenticación Firebase end-to-end para que el backend deje de exponer datos de
pacientes sin control (antes `GET /api/lecturas` no tenía ni filtro ni autenticación). El código
ya está escrito:

- `backend/auth.js` — verifica el `idToken` de Firebase enviado en el header `Authorization:
  Bearer <token>`; resuelve el rol (`paciente`/`especialista`) consultando la tabla `usuarios`.
- Todas las rutas de `backend/server.js` ahora exigen ese token y validan que quien pide el
  recurso sea su dueño o un especialista.
- `app_ansiedad/lib/api_client.dart` manda el token en cada request.
- `web_portal/` ganó pantalla de login (`Login.js`) y `App.js` exige sesión antes de mostrar
  datos.
- Nueva dependencia en el backend: `firebase-admin` (agregada a `package.json`, falta instalar).
- Nueva dependencia en el portal: `firebase` (agregada a `package.json`, falta instalar).

Todo esto **ya está escrito en el código pero no verificado ni desplegado**. Lo que falta son
5 pasos manuales que no se pueden automatizar desde una terminal de agente:

---

## 3. Los 5 pasos manuales pendientes

### Paso 1 — Generar la Service Account Key de Firebase

1. Entra a [Firebase Console](https://console.firebase.google.com/) → selecciona el proyecto de
   este sistema (el mismo que usa `app_ansiedad/lib/firebase_options.dart`).
2. Ve a **Configuración del proyecto (⚙️) → Cuentas de servicio (Service accounts)**.
3. Click en **Generar nueva clave privada** (Generate new private key). Descarga el JSON.
4. Ese JSON completo (todo el contenido, en una sola línea si hace falta) debe ir como valor de
   una variable de entorno llamada `FIREBASE_SERVICE_ACCOUNT_JSON`:
   - **Local:** agrégala a `backend/.env` (créalo si no existe; no debe subirse a git — revisa
     que `.env` esté en `.gitignore`).
   - **Render:** en el dashboard del servicio backend → **Environment** → agrega la misma
     variable con el mismo nombre y valor.
5. **Importante de seguridad:** ese archivo JSON da acceso administrativo total al proyecto
   Firebase. No lo compartas, no lo subas a git, no lo pegues en chats públicos.

### Paso 2 — Crear una cuenta de prueba con rol `especialista`

Hoy no existe forma de auto-registrarse como especialista desde la app (solo se registran
pacientes). Hay que crear el registro a mano:

1. Crea un usuario normal en Firebase Auth (por ejemplo, registrándote desde la app o desde la
   consola de Firebase Authentication).
2. En la tabla `usuarios` de Supabase, busca (o inserta) la fila correspondiente a ese usuario
   (columna que guarda el uid de Firebase) y cambia su columna de rol a `especialista`.
3. Guarda el email/password de esa cuenta — la vas a necesitar para probar el portal web.

### Paso 3 — Instalar dependencias nuevas

Desde una terminal con `node`/`npm` en el PATH:

```bash
cd backend
npm install

cd ../web_portal
npm install
```

Esto instala `firebase-admin` (backend) y `firebase` (web_portal), que ya están declaradas en
los respectivos `package.json` pero no instaladas físicamente.

### Paso 4 — Verificación end-to-end

Con el backend corriendo (localmente con la variable de entorno del Paso 1, o ya desplegado):

1. **Backend, las 8 rutas**, probar con y sin token, y con distintos roles:
   - `POST /api/lecturas`, `GET /api/lecturas` (debe exigir rol `especialista` sin filtro),
     `GET /api/lecturas/:pacienteId`, `GET /api/lecturas/:pacienteId/resumen`,
     `POST /api/usuarios`, `GET /api/usuarios/:id`, `PUT /api/usuarios/:id`.
   - Sin header `Authorization` → debe responder 401/403 (no datos).
   - Con token de un paciente pidiendo datos de otro paciente → debe rechazar.
   - Con token de especialista → debe permitir.
2. **Socket.io del chat:** conectar sin token → debe rechazar el handshake; conectar con token
   válido → debe funcionar; `enviar_mensaje` con `paciente_id` que no coincide con el emisor (y
   sin ser especialista) → debe rechazar.
3. **App Flutter en el celular físico:** probar Historial, Alerta, Perfil y Mensajes con una
   cuenta de paciente real — confirmar que todo sigue funcionando con el token agregado
   automáticamente.
4. **Portal web** (`npm start` en `web_portal/`): iniciar sesión con la cuenta de especialista
   del Paso 2, confirmar que carga los datos; probar iniciar sesión con una cuenta sin rol
   especialista y confirmar que se muestra el mensaje de error (403) en vez de fallar en
   silencio.

### Paso 5 — Desplegar el backend actualizado a Render

Una vez que el Paso 1 (variable de entorno) ya esté puesta en Render y el Paso 4 haya pasado
localmente:

1. Push del código a la rama que Render observa (o el flujo de deploy que usen).
2. Confirmar en los logs de Render que el servicio levantó sin errores (que
   `FIREBASE_SERVICE_ACCOUNT_JSON` se leyó bien — si falta o está mal formada, `firebase-admin`
   normalmente tira un error claro al iniciar).
3. Repetir una verificación rápida del Paso 4 contra la URL de producción
   (`https://tt-ansiedad-backend.onrender.com`).

---

## 4. Al terminar

Cuando hayas hecho estos 5 pasos (o si te atoraste en alguno), vuelve a la conversación con
Claude Code y cuéntale:

- Qué pasos completaste y cuáles no.
- Cualquier error o resultado inesperado (mensajes de error exactos, en qué paso, con qué
  cuenta/rol).
- Si el Incremento 6a quedó verificado end-to-end, para marcarlo como cerrado en
  `CONTEXTO_PROYECTO.md` y seguir con el **Incremento 6b** (estrategia de testing).
