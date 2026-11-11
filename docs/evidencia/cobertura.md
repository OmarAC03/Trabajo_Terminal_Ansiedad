# Cobertura de líneas

Medida el 11 de noviembre de 2026 sobre el commit `1e4e2e0`.

| Suite | Comando | Líneas cubiertas | Cobertura de líneas | Qué archivos cuenta |
|---|---|---:|---:|---|
| Backend | `node --test --experimental-test-coverage` | — | **88.37 %** (ramas 97.20 %, funciones 87.71 %) | Solo los módulos que cargan las pruebas (ver nota) |
| Portal | `react-scripts test --coverage` (Jest) | 534 / 1415 | **37.73 %** | Todo `src/` |
| App | `flutter test --coverage` | 1593 / 4356 | **36.57 %** | 92 de 95 archivos de `lib/` |

**Cómo leer estos números.**

- **Backend:** la cobertura de Node solo mide los archivos que alguna prueba carga.
  `server.js` (1362 líneas, las rutas y Socket.io), `admin.js` (519) y `auth.js`
  (151) no los carga ninguna prueba unitaria, así que **no entran en el 88.37 %**.
  Su lógica se probó con los scripts de integración en PowerShell
  (`backend/pruebas/*.ps1`) contra el backend local, que no generan cobertura. Las
  reglas de negocio están en módulos puros (bitácora, consentimiento, GAD-7, línea
  base, notas, etc.), casi todos al 100 %.
- **Portal:** cuenta todo `src/`. Lo probado son sobre todo los módulos de lógica
  (100 %); la mayoría de las pantallas de React no tienen pruebas unitarias, y por
  eso el total es bajo.
- **App:** `main.dart`, `firebase_options.dart` y `ui/app_theme.dart` no los carga
  ninguna prueba y no aparecen en el reporte.

## Backend, por archivo

| Archivo | Líneas % | Ramas % | Funciones % |
|---|---:|---:|---:|
| `bitacora.js` | 100.00 | 100.00 | 94.44 |
| `consentimiento.js` | 100.00 | 100.00 | 100.00 |
| `cuentas.js` | 100.00 | 100.00 | 100.00 |
| `dispositivos.js` | 100.00 | 100.00 | 100.00 |
| `eliminacion.js` | 100.00 | 100.00 | 100.00 |
| `errors.js` | 100.00 | 100.00 | 100.00 |
| `especialista.js` | 100.00 | 97.73 | 95.24 |
| `gad7_vista.js` | 100.00 | 100.00 | 100.00 |
| `gad7.js` | 100.00 | 100.00 | 100.00 |
| `linea_base_vista.js` | 100.00 | 94.44 | 100.00 |
| `linea_base.js` | 100.00 | 96.23 | 100.00 |
| `logger.js` | 100.00 | 75.00 | 50.00 |
| `marcadores.js` | 100.00 | 96.15 | 100.00 |
| `notas.js` | 100.00 | 97.06 | 100.00 |
| `notificaciones.js` | 100.00 | 96.15 | 100.00 |
| `pruebas/semilla_aislamiento.js` | 82.69 | 83.33 | 100.00 |
| `reporte.js` | 100.00 | 92.68 | 100.00 |
| `salud.js` | 100.00 | 100.00 | 100.00 |
| `seguridad.js` | 100.00 | 88.24 | 100.00 |
| `validation.js` | 37.67 | 100.00 | 28.00 |

## Portal, por archivo

| Archivo | Líneas % | Cubiertas / total |
|---|---:|---:|
| `src/actividad.js` | 100 | 29 / 29 |
| `src/AdminApp.js` | 0 | 0 / 12 |
| `src/AdminBitacora.js` | 72.41 | 42 / 58 |
| `src/AdminSolicitudes.js` | 0 | 0 / 55 |
| `src/AdminUsuarios.js` | 0 | 0 / 51 |
| `src/App.js` | 0 | 0 / 103 |
| `src/bitacora.js` | 100 | 27 / 27 |
| `src/ChatPaciente.js` | 0 | 0 / 59 |
| `src/CodigoVinculacion.js` | 0 | 0 / 9 |
| `src/config.js` | 100 | 1 / 1 |
| `src/cuentas.js` | 100 | 25 / 25 |
| `src/Dashboard.js` | 0 | 0 / 25 |
| `src/EditarUsuario.js` | 0 | 0 / 78 |
| `src/EjerciciosPaciente.js` | 0 | 0 / 50 |
| `src/ExportarReporte.js` | 71.42 | 30 / 42 |
| `src/firebase.js` | 0 | 0 / 3 |
| `src/gad7.js` | 100 | 33 / 33 |
| `src/Gad7Paciente.js` | 0 | 0 / 48 |
| `src/index.js` | 0 | 0 / 3 |
| `src/Login.js` | 0 | 0 / 22 |
| `src/marca.js` | 100 | 4 / 4 |
| `src/marcadores.js` | 100 | 40 / 40 |
| `src/MarcadoresPanel.js` | 86.84 | 33 / 38 |
| `src/notas.js` | 100 | 22 / 22 |
| `src/NotasPaciente.js` | 76.19 | 64 / 84 |
| `src/PacienteDetalle.js` | 0 | 0 / 1 |
| `src/PacientesComun.js` | 12 | 3 / 25 |
| `src/PacientesList.js` | 0 | 0 / 13 |
| `src/PerfilEspecialista.js` | 0 | 0 / 89 |
| `src/RecuperarPassword.js` | 0 | 0 / 27 |
| `src/RegistroEspecialista.js` | 0 | 0 / 31 |
| `src/reporte.js` | 100 | 57 / 57 |
| `src/ReporteImpresion.js` | 83.33 | 5 / 6 |
| `src/reportWebVitals.js` | 0 | 0 / 8 |
| `src/semaforo.js` | 100 | 17 / 17 |
| `src/SesionDetalle.js` | 0 | 0 / 40 |
| `src/sesiones.js` | 100 | 70 / 70 |
| `src/SesionesPaciente.js` | 0 | 0 / 72 |
| `src/solicitudes.js` | 100 | 8 / 8 |
| `src/tecnicas.js` | 0 | 0 / 2 |
| `src/ui/AuthLayout.js` | 100 | 2 / 2 |
| `src/ui/components.js` | 95.45 | 21 / 22 |
| `src/ui/Layout.js` | 25 | 1 / 4 |

## App, por archivo

| Archivo | Líneas % | Cubiertas / total |
|---|---:|---:|
| `lib/api_client.dart` | 0.0 | 0 / 40 |
| `lib/app_config.dart` | 33.33 | 9 / 27 |
| `lib/auth_gate.dart` | 11.11 | 1 / 9 |
| `lib/avatar_widgets.dart` | 92.68 | 38 / 41 |
| `lib/contenido/acerca_textos.dart` | 0.0 | 0 / 1 |
| `lib/contenido/gad7_textos.dart` | 50.0 | 1 / 2 |
| `lib/contenido/marca.dart` | 0.0 | 0 / 1 |
| `lib/contenido/privacidad_textos.dart` | 87.5 | 7 / 8 |
| `lib/contenido/textos_educativos.dart` | 66.67 | 2 / 3 |
| `lib/cuenta_bloqueada.dart` | 100.0 | 6 / 6 |
| `lib/logger.dart` | 66.67 | 6 / 9 |
| `lib/main_layout.dart` | 1.09 | 1 / 92 |
| `lib/medicion/aviso_sesiones.dart` | 66.67 | 2 / 3 |
| `lib/medicion/calculo_sesion.dart` | 98.67 | 74 / 75 |
| `lib/medicion/estado_sensor.dart` | 100.0 | 30 / 30 |
| `lib/medicion/mensajes_mascota.dart` | 97.14 | 34 / 35 |
| `lib/models/calibracion.dart` | 100.0 | 35 / 35 |
| `lib/models/consentimiento.dart` | 100.0 | 10 / 10 |
| `lib/models/ejercicio_asignado.dart` | 0.0 | 0 / 8 |
| `lib/models/eva_respuesta.dart` | 100.0 | 7 / 7 |
| `lib/models/gad7.dart` | 100.0 | 17 / 17 |
| `lib/models/lectura_cruda.dart` | 100.0 | 1 / 1 |
| `lib/models/mensaje.dart` | 0.0 | 0 / 13 |
| `lib/models/pendientes.dart` | 25.0 | 1 / 4 |
| `lib/models/perfil.dart` | 0.0 | 0 / 6 |
| `lib/models/sesion_detalle.dart` | 100.0 | 14 / 14 |
| `lib/models/sesion_medicion.dart` | 100.0 | 25 / 25 |
| `lib/models/sesion_resumen.dart` | 100.0 | 11 / 11 |
| `lib/models/solicitud_eliminacion.dart` | 100.0 | 8 / 8 |
| `lib/models/vinculacion.dart` | 0.0 | 0 / 7 |
| `lib/notificaciones/notificaciones_locales.dart` | 0.0 | 0 / 12 |
| `lib/notificaciones/recordatorio_gad7.dart` | 59.38 | 38 / 64 |
| `lib/notificaciones/servicio_push.dart` | 52.24 | 35 / 67 |
| `lib/providers/alerta_provider.dart` | 91.14 | 72 / 79 |
| `lib/providers/cambiar_password_provider.dart` | 80.0 | 32 / 40 |
| `lib/providers/consentimiento_provider.dart` | 76.09 | 35 / 46 |
| `lib/providers/cuestionario_gad7_provider.dart` | 89.04 | 65 / 73 |
| `lib/providers/ejercicios_provider.dart` | 0.0 | 0 / 27 |
| `lib/providers/eliminar_cuenta_provider.dart` | 75.0 | 30 / 40 |
| `lib/providers/historial_sesiones_provider.dart` | 89.47 | 34 / 38 |
| `lib/providers/inicio_provider.dart` | 88.37 | 38 / 43 |
| `lib/providers/medicion_provider.dart` | 73.46 | 119 / 162 |
| `lib/providers/mensajes_provider.dart` | 0.0 | 0 / 53 |
| `lib/providers/pendientes_provider.dart` | 0.0 | 0 / 33 |
| `lib/providers/perfil_provider.dart` | 0.0 | 0 / 53 |
| `lib/providers/sesion_detalle_provider.dart` | 70.83 | 17 / 24 |
| `lib/providers/vinculacion_provider.dart` | 0.0 | 0 / 25 |
| `lib/repositories/chat_repository.dart` | 0.0 | 0 / 39 |
| `lib/repositories/consentimiento_repository.dart` | 6.67 | 1 / 15 |
| `lib/repositories/dispositivos_repository.dart` | 0.0 | 0 / 8 |
| `lib/repositories/ejercicios_repository.dart` | 0.0 | 0 / 5 |
| `lib/repositories/eliminacion_repository.dart` | 0.0 | 0 / 13 |
| `lib/repositories/gad7_repository.dart` | 0.0 | 0 / 19 |
| `lib/repositories/interprete_sensor.dart` | 100.0 | 63 / 63 |
| `lib/repositories/lector_lineas.dart` | 100.0 | 17 / 17 |
| `lib/repositories/pendientes_repository.dart` | 0.0 | 0 / 9 |
| `lib/repositories/perfil_repository.dart` | 0.0 | 0 / 11 |
| `lib/repositories/repository_exception.dart` | 100.0 | 3 / 3 |
| `lib/repositories/sensor_repository.dart` | 17.86 | 5 / 28 |
| `lib/repositories/sesion_repository.dart` | 2.33 | 1 / 43 |
| `lib/repositories/simulador_sensor.dart` | 100.0 | 52 / 52 |
| `lib/repositories/vinculacion_repository.dart` | 0.0 | 0 / 22 |
| `lib/screens/acerca_widgets.dart` | 94.81 | 73 / 77 |
| `lib/screens/cambiar_password_screen.dart` | 97.3 | 36 / 37 |
| `lib/screens/consentimiento_screen.dart` | 43.59 | 51 / 117 |
| `lib/screens/ejercicios_asignados_screen.dart` | 2.63 | 2 / 76 |
| `lib/screens/eliminar_cuenta_screen.dart` | 4.55 | 2 / 44 |
| `lib/screens/gad7_screen.dart` | 2.26 | 3 / 133 |
| `lib/screens/historial_screen.dart` | 4.29 | 3 / 70 |
| `lib/screens/inicio_screen.dart` | 1.51 | 3 / 199 |
| `lib/screens/login_screen.dart` | 1.47 | 1 / 68 |
| `lib/screens/medicion_screen.dart` | 4.18 | 11 / 263 |
| `lib/screens/mensajes_screen.dart` | 9.09 | 10 / 110 |
| `lib/screens/perfil_screen.dart` | 1.51 | 3 / 199 |
| `lib/screens/recuperar_password_screen.dart` | 0.0 | 0 / 59 |
| `lib/screens/registro_screen.dart` | 51.85 | 42 / 81 |
| `lib/screens/sesion_detalle_screen.dart` | 0.0 | 0 / 92 |
| `lib/screens/tecnicas_screen.dart` | 0.49 | 2 / 408 |
| `lib/screens/vinculacion_screen.dart` | 3.77 | 2 / 53 |
| `lib/sesion.dart` | 0.0 | 0 / 17 |
| `lib/ui/app_colors.dart` | 0.0 | 0 / 1 |
| `lib/ui/boton_medir.dart` | 95.83 | 69 / 72 |
| `lib/ui/estructura_acceso.dart` | 95.0 | 38 / 40 |
| `lib/ui/fechas_chat.dart` | 100.0 | 27 / 27 |
| `lib/ui/fila_indicador.dart` | 0.0 | 0 / 39 |
| `lib/ui/fondo_paisaje.dart` | 94.87 | 37 / 39 |
| `lib/ui/formato_fecha.dart` | 100.0 | 18 / 18 |
| `lib/ui/pantalla_cargando.dart` | 100.0 | 27 / 27 |
| `lib/ui/progreso_calibracion.dart` | 3.45 | 1 / 29 |
| `lib/ui/selector_fuente.dart` | 100.0 | 32 / 32 |
| `lib/ui/tarjeta_gad7.dart` | 100.0 | 45 / 45 |
| `lib/ui/widgets.dart` | 52.73 | 58 / 110 |

Sin cargar en ninguna prueba: `lib/firebase_options.dart`, `lib/main.dart`, `lib/ui/app_theme.dart`.
