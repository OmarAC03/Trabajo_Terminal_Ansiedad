import { NOMBRE_APP } from './marca';

// "Acerca del proyecto" (versión final, Fase 2): el MISMO texto que la app
// (app_ansiedad/lib/contenido/acerca_textos.dart). acerca.test.js lee el
// archivo de la app y falla si los dos dejan de coincidir.

export const TITULO_ACERCA = 'Por qué existe este proyecto';

export const PARRAFOS_ACERCA = [
  'En la Escuela Superior de Cómputo, como en cualquier universidad, se vive un problema que a simple vista '
    + 'pasa desapercibido. Es un enemigo silencioso que afecta el rendimiento, el sueño, las relaciones y las '
    + 'ganas de seguir: la ansiedad y el estrés con los que los estudiantes lidiamos día a día.',
  'Este proyecto nació de lo más cercano. Como estudiantes, mi compañero y yo hemos sido testigos de cómo la '
    + 'ansiedad nos alcanza a nosotros y a quienes nos rodean, muchas veces sin que nadie lo note. Eso nos '
    + 'llevó a preguntarnos si lo que aprendemos en la ESCOM podía convertirse en una herramienta para '
    + 'conocernos mejor y pedir ayuda a tiempo.',
  'Así surgió esta app: un sensor, una aplicación y un portal que te ayudan a conocer tu propio ritmo y '
    + 'permiten que un especialista te acompañe. No da diagnósticos ni sustituye a un profesional; es un '
    + 'primer paso para que cuidar tu salud mental sea parte de tu día, como cualquier otra materia.',
];

export const PIE_ACERCA = `${NOMBRE_APP} · Escuela Superior de Cómputo · Instituto Politécnico Nacional`;
