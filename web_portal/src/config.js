// Dirección del backend, en un solo lugar. Por defecto Render (producción);
// para probar contra el backend local, arrancar el portal con
//   $env:REACT_APP_API_URL='http://localhost:3000'; $env:PORT='3001'; npm start
// Create React App fija las REACT_APP_* al arrancar o al compilar: cambiarla
// pide reiniciar `npm start`. Sin barra final (se quita si viene).
export const API_BASE = (process.env.REACT_APP_API_URL || 'https://tt-ansiedad-backend.onrender.com').replace(/\/+$/, '');
