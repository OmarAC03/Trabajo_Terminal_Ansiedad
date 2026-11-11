# Versiones y licencias

Leído del repositorio el 11 de noviembre de 2026 (commit `1e4e2e0`). La versión instalada sale de
`node_modules/*/package.json` (backend y portal) y de `pubspec.lock` (app). La
licencia sale del `package.json` de cada paquete (npm) o de su archivo `LICENSE` en la
caché de pub (Flutter).

## Herramientas

| Herramienta | Versión | Licencia | Nota |
|---|---|---|---|
| Node.js | 24.21.0 | MIT | Versión local. El backend no fija `engines` en `package.json`: Render usa su versión por defecto. |
| npm | 11.19.0 | Artistic-2.0 | |
| Flutter | 3.47.5 (canal stable, revisión 6a19cca564) | BSD-3-Clause | |
| Dart | 3.13.4 | BSD-3-Clause | La app pide `sdk: ^3.11.5`. |
| PostgreSQL | administrado por Supabase | PostgreSQL License | La versión exacta se lee con `SELECT version();` (ver esquema.md). |

## Backend (`backend/package.json`)

Express, Socket.io y express-rate-limit están aquí.

| Paquete | Tipo | Rango declarado | Versión instalada | Licencia |
|---|---|---|---|---|
| `cors` | dependencia | `^2.8.6` | 2.8.6 | MIT |
| `dotenv` | dependencia | `^17.4.2` | 17.4.2 | BSD-2-Clause |
| `express` | dependencia | `^5.2.1` | 5.2.1 | MIT |
| `express-rate-limit` | dependencia | `8.7.1` | 8.7.1 | MIT |
| `firebase-admin` | dependencia | `^13.0.0` | 13.10.0 | Apache-2.0 |
| `pg` | dependencia | `^8.20.0` | 8.20.0 | MIT |
| `socket.io` | dependencia | `^4.8.3` | 4.8.3 | MIT |
| `nodemon` | desarrollo | `^3.1.14` | 3.1.14 | MIT |
| `socket.io-client` | desarrollo | `4.8.3` | 4.8.3 | MIT |

## Portal (`web_portal/package.json`)

React, Recharts y Axios están aquí. Al final van herramientas que trae `react-scripts`
(no se declaran directamente).

| Paquete | Tipo | Rango declarado | Versión instalada | Licencia |
|---|---|---|---|---|
| `@testing-library/dom` | dependencia | `^10.4.1` | 10.4.1 | MIT |
| `@testing-library/jest-dom` | dependencia | `^6.9.1` | 6.9.1 | MIT |
| `@testing-library/react` | dependencia | `^16.3.2` | 16.3.2 | MIT |
| `@testing-library/user-event` | dependencia | `^13.5.0` | 13.5.0 | MIT |
| `axios` | dependencia | `^1.15.2` | 1.15.2 | MIT |
| `firebase` | dependencia | `^11.0.2` | 11.10.0 | Apache-2.0 |
| `lucide-react` | dependencia | `^1.14.0` | 1.14.0 | ISC |
| `react` | dependencia | `^19.2.5` | 19.2.5 | MIT |
| `react-dom` | dependencia | `^19.2.5` | 19.2.5 | MIT |
| `react-scripts` | dependencia | `5.0.1` | 5.0.1 | MIT |
| `recharts` | dependencia | `^3.10.1` | 3.10.1 | MIT |
| `socket.io-client` | dependencia | `^4.8.3` | 4.8.3 | MIT |
| `web-vitals` | dependencia | `^2.1.4` | 2.1.4 | Apache-2.0 |
| `jest` | transitiva (herramienta) | `â€”` | 27.5.1 | MIT |
| `typescript` | transitiva (herramienta) | `â€”` | 4.9.5 | Apache-2.0 |
| `webpack` | transitiva (herramienta) | `â€”` | 5.106.2 | MIT |

## App (`app_ansiedad/pubspec.yaml`)

Todos los paquetes de `dependencies` y `dev_dependencies`.

| Paquete | Tipo | Rango declarado | Versión instalada | Licencia |
|---|---|---|---|---|
| `flutter` | dependencia | `sdk: flutter` | SDK de Flutter | BSD-3-Clause |
| `cupertino_icons` | dependencia | `^1.0.8` | 1.0.9 | MIT |
| `http` | dependencia | `^1.6.0` | 1.6.0 | BSD-3-Clause |
| `socket_io_client` | dependencia | `^3.0.2` | 3.0.2 | MIT |
| `firebase_core` | dependencia | `^2.27.0` | 2.32.0 | BSD-3-Clause |
| `firebase_auth` | dependencia | `^4.17.4` | 4.20.0 | BSD-3-Clause |
| `flutter_classic_bluetooth` | dependencia | `1.7.0` | 1.7.0 | MIT |
| `permission_handler` | dependencia | `^12.0.1` | 12.0.1 | MIT |
| `fl_chart` | dependencia | `^1.2.0` | 1.2.0 | MIT |
| `provider` | dependencia | `^6.1.2` | 6.1.5+1 | MIT |
| `flutter_tts` | dependencia | `^4.2.0` | 4.2.5 | MIT |
| `audioplayers` | dependencia | `^6.1.0` | 6.8.1 | MIT |
| `wakelock_plus` | dependencia | `^1.5.2` | 1.5.2 | BSD-3-Clause |
| `firebase_messaging` | dependencia | `14.9.4` | 14.9.4 | BSD-3-Clause |
| `flutter_local_notifications` | dependencia | `19.4.0` | 19.4.0 | BSD-3-Clause |
| `timezone` | dependencia | `0.10.1` | 0.10.1 | BSD-2-Clause |
| `shared_preferences` | dependencia | `2.3.2` | 2.3.2 | BSD-3-Clause |
| `flutter_test` | desarrollo | `sdk: flutter` | SDK de Flutter | BSD-3-Clause |
| `flutter_lints` | desarrollo | `^6.0.0` | 6.0.0 | BSD-3-Clause |
| `flutter_launcher_icons` | desarrollo | `0.14.4` | 0.14.4 | MIT |
| `image` | desarrollo | `4.5.0` | 4.5.0 | MIT |

## Resumen de licencias

Todas son permisivas (MIT, ISC, BSD-2-Clause, BSD-3-Clause, Apache-2.0). Ningún
paquete directo es GPL.
