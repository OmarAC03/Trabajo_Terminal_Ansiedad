import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

// Mismo proyecto Firebase que usa la app Flutter (ver
// app_ansiedad/lib/firebase_options.dart, bloque `web`). La Web API key no
// es secreta: es seguro que viva en el bundle del frontend.
const firebaseConfig = {
  apiKey: 'AIzaSyBT8DdafzQLg89kmcHQ-J5A3q1Ak6fQO3o',
  authDomain: 'tt-ansiedad-sistema.firebaseapp.com',
  projectId: 'tt-ansiedad-sistema',
  storageBucket: 'tt-ansiedad-sistema.firebasestorage.app',
  messagingSenderId: '26109806229',
  appId: '1:26109806229:web:93416d6e8f7bbf3ca73d9c',
  measurementId: 'G-5C6N8JX6YX',
};

export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
