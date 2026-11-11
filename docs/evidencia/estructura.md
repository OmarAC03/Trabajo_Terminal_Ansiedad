# Estructura del repositorio

Dos niveles, leído con `git ls-files` el 11 de noviembre de 2026 (commit `1e4e2e0`). No incluye
`node_modules/`, `build/` ni archivos sin versionar. Entre paréntesis, cuántos
archivos versionados hay dentro de cada carpeta.

```
Trabajo_Terminal_Ansiedad/
├── app_ansiedad/
│   ├── android/  (33 archivos)
│   ├── assets/  (54 archivos)
│   ├── docs/  (1 archivos)
│   ├── ios/  (40 archivos)
│   ├── lib/  (95 archivos)
│   ├── linux/  (10 archivos)
│   ├── macos/  (28 archivos)
│   ├── test/  (26 archivos)
│   ├── tool/  (3 archivos)
│   ├── web/  (7 archivos)
│   ├── windows/  (18 archivos)
│   ├── .gitignore
│   ├── .metadata
│   ├── analysis_options.yaml
│   ├── firebase.json
│   ├── GUIA_ESTILO_APP.md
│   ├── pubspec.lock
│   ├── pubspec.yaml
│   ├── README.md
├── backend/
│   ├── pruebas/  (13 archivos)
│   ├── .gitignore
│   ├── admin.js
│   ├── auth.js
│   ├── bitacora.js
│   ├── consentimiento.js
│   ├── cuentas.js
│   ├── dispositivos.js
│   ├── eliminacion.js
│   ├── errors.js
│   ├── especialista.js
│   ├── gad7.js
│   ├── gad7_vista.js
│   ├── linea_base.js
│   ├── linea_base_vista.js
│   ├── logger.js
│   ├── marcadores.js
│   ├── notas.js
│   ├── notificaciones.js
│   ├── package-lock.json
│   ├── package.json
│   ├── reporte.js
│   ├── salud.js
│   ├── seguridad.js
│   ├── server.js
│   ├── validation.js
│   ├── *.test.js  (16 archivos de prueba)
├── docs/
│   ├── tesis/  (2 archivos)
│   ├── version_final/  (1 archivos)
├── web_portal/
│   ├── public/  (5 archivos)
│   ├── src/  (68 archivos)
│   ├── .gitignore
│   ├── DISENO_REFERENCIA.png
│   ├── GUIA_ESTILO_PORTAL.md
│   ├── package-lock.json
│   ├── package.json
│   ├── README.md
├── CONTEXTO_PASOS_MANUALES_INCREMENTO_6A.md
├── CONTEXTO_PROYECTO.md
├── CONTRATO_SENSOR.md
├── DESARROLLO_FUNDAMENTADO.md
├── DISENO_FLUJO_MEDICION.md
├── MARCO_ALCANCE_Y_LENGUAJE.md
├── PLAN_FASE_C_ADMIN.md
```

| Carpeta | Qué contiene |
|---|---|
| `app_ansiedad/` | App móvil del paciente (Flutter). `lib/` código, `test/` pruebas, `assets/` mascota, audio y escudos, `tool/` generadores de íconos. |
| `backend/` | API REST y Socket.io (Node.js + Express). Un módulo por regla de negocio y su `*.test.js`; `pruebas/` scripts de integración y semillas PRUEBA. |
| `web_portal/` | Portal del especialista y del administrador (React). `src/` código y pruebas, `public/` HTML, ícono y manifest. |
| `docs/` | `version_final/` aviso de privacidad y consentimiento publicados; `tesis/` documento; `evidencia/` este paquete. |
| Raíz | Documentos de contexto, diseño y alcance del proyecto. |

Nota: `backend/node_modules/` está versionado en git (≈6 150 archivos) por decisión
anterior; Render igual instala las dependencias con su Build Command.
