# Pruebas automatizadas

Ejecutadas el 11 de noviembre de 2026 sobre el commit `1e4e2e0`. Todas pasaron.

| Suite | Herramienta | Archivos | Pruebas | Resultado |
|---|---|---:|---:|---|
| Backend | `node --test` (Node 24) | 17 | 157 | 157/157 |
| Portal | Jest 27 (`react-scripts test`) | 16 | 100 | 100/100 |
| App | `flutter test` | 26 | 286 | 286/286 |
| **Total** | | **59** | **543** | |

Además de estas suites hay pruebas de integración manuales en PowerShell contra el
backend local (`backend/pruebas/*.ps1`: sesiones, GAD-7, cuentas, especialista,
notificaciones y aislamiento). No se cuentan aquí porque necesitan cuentas PRUEBA y
la base real.

## Backend, por archivo

| Archivo | Pruebas |
|---|---:|
| `bitacora.test.js` | 23 |
| `consentimiento.test.js` | 10 |
| `cuentas.test.js` | 13 |
| `dispositivos.test.js` | 4 |
| `eliminacion.test.js` | 9 |
| `especialista.test.js` | 11 |
| `gad7.test.js` | 18 |
| `gad7_vista.test.js` | 9 |
| `linea_base.test.js` | 15 |
| `linea_base_vista.test.js` | 8 |
| `marcadores.test.js` | 4 |
| `notas.test.js` | 7 |
| `notificaciones.test.js` | 8 |
| `pruebas/semilla_aislamiento.test.js` | 5 |
| `reporte.test.js` | 5 |
| `salud.test.js` | 1 |
| `seguridad.test.js` | 7 |

## Portal, por archivo

| Archivo | Pruebas |
|---|---:|
| `src/actividad.test.js` | 10 |
| `src/AdminBitacora.test.js` | 1 |
| `src/bitacora.test.js` | 8 |
| `src/cuentas.test.js` | 6 |
| `src/ExportarReporte.test.js` | 2 |
| `src/gad7.test.js` | 11 |
| `src/marca.test.js` | 6 |
| `src/marcadores.test.js` | 6 |
| `src/MarcadoresPanel.test.js` | 2 |
| `src/notas.test.js` | 7 |
| `src/NotasPaciente.test.js` | 2 |
| `src/reporte.test.js` | 5 |
| `src/semaforo.test.js` | 5 |
| `src/sesiones.test.js` | 21 |
| `src/solicitudes.test.js` | 5 |
| `src/ui/components.test.js` | 3 |

## App, por archivo

| Archivo | Pruebas |
|---|---:|
| `test/acerca_test.dart` | 5 |
| `test/alerta_provider_test.dart` | 11 |
| `test/avatares_test.dart` | 5 |
| `test/calculo_sesion_test.dart` | 17 |
| `test/calibracion_test.dart` | 6 |
| `test/cambiar_password_test.dart` | 6 |
| `test/consentimiento_test.dart` | 18 |
| `test/cuenta_bloqueada_test.dart` | 6 |
| `test/eliminar_cuenta_test.dart` | 9 |
| `test/estado_sensor_test.dart` | 3 |
| `test/eva_test.dart` | 12 |
| `test/fechas_chat_test.dart` | 7 |
| `test/fondo_paisaje_test.dart` | 2 |
| `test/gad7_test.dart` | 15 |
| `test/gad7_textos_test.dart` | 27 |
| `test/historial_test.dart` | 15 |
| `test/inicio_test.dart` | 16 |
| `test/interprete_sensor_test.dart` | 27 |
| `test/lector_lineas_test.dart` | 13 |
| `test/marca_test.dart` | 8 |
| `test/mensajes_mascota_test.dart` | 16 |
| `test/notificaciones_push_test.dart` | 9 |
| `test/recordatorio_gad7_test.dart` | 10 |
| `test/sabores_test.dart` | 5 |
| `test/simulador_sensor_test.dart` | 3 |
| `test/version_final_ui_test.dart` | 15 |
