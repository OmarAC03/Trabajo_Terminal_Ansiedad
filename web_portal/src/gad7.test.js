import {
  ITEMS_GAD7, OPCIONES_GAD7, OPCIONES_DIFICULTAD, REFERENCIAS_GAD7,
  TONO_SEVERIDAD, TONO_GAD7, COLOR_GAD7,
  textoSeveridad, formatoPuntaje, fechaDia, textoProximo, textoDificultad,
  detalleItems, datosGrafica, resumenTabla,
} from './gad7';
import { colorEstado } from './semaforo';

// GAD-7 en el portal (M5a paso 5): categorías del instrumento, en tonos
// neutros, nunca el semáforo de los indicadores fisiológicos.
describe('texto del instrumento (gad7-es-v1)', () => {
  test('7 ítems, 4 opciones y 4 de dificultad', () => {
    expect(ITEMS_GAD7).toHaveLength(7);
    expect(OPCIONES_GAD7).toEqual(['De nada', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']);
    expect(OPCIONES_DIFICULTAD).toHaveLength(4);
    expect(ITEMS_GAD7[0]).toBe('Sentirse nervioso, ansioso o muy tenso');
  });

  test('líneas de referencia en 5, 10 y 15', () => {
    expect(REFERENCIAS_GAD7.map((r) => r.valor)).toEqual([5, 10, 15]);
  });
});

describe('severidad y puntaje', () => {
  test('texto de cada severidad', () => {
    expect(textoSeveridad('minima')).toBe('Mínima');
    expect(textoSeveridad('leve')).toBe('Leve');
    expect(textoSeveridad('moderada')).toBe('Moderada');
    expect(textoSeveridad('grave')).toBe('Grave');
    expect(textoSeveridad(null)).toBe('—');
    expect(textoSeveridad('altos')).toBe('—');
  });

  test('formato del puntaje', () => {
    expect(formatoPuntaje(12)).toBe('12 / 21');
    expect(formatoPuntaje(0)).toBe('0 / 21');
    expect(formatoPuntaje(null)).toBe('—');
  });

  test('nunca usa los tonos ni los colores del semáforo', () => {
    const semaforo = ['normal', 'elevados', 'altos'];
    expect(semaforo).not.toContain(TONO_SEVERIDAD);
    expect(semaforo).not.toContain(TONO_GAD7);
    expect(semaforo.map(colorEstado)).not.toContain(COLOR_GAD7);
  });
});

describe('próximo cuestionario', () => {
  test('fechaDia no se corre un día (no se lee como UTC)', () => {
    expect(fechaDia('2026-11-06')).toBe('vie 6 nov');
    expect(fechaDia('2026-11-01')).toBe('dom 1 nov');
    expect(fechaDia('2027-01-01')).toBe('vie 1 ene');
  });

  test('le toca, nunca respondió, singular y plural', () => {
    expect(textoProximo({ toca: true, ultima_respuesta: '2026-10-01T15:00:00Z' })).toBe('Le toca responder');
    expect(textoProximo({ toca: true, ultima_respuesta: null })).toBe('Aún no responde · le toca');
    expect(textoProximo({ toca: false, dias_restantes: 1, proxima_fecha: '2026-11-06' }))
      .toBe('Próximo en 1 día · desde el vie 6 nov');
    expect(textoProximo({ toca: false, dias_restantes: 11, proxima_fecha: '2026-11-06' }))
      .toBe('Próximo en 11 días · desde el vie 6 nov');
    expect(textoProximo(null)).toBeNull();
  });
});

describe('detalle de una respuesta', () => {
  test('ítems con su opción', () => {
    const d = detalleItems({ items: [0, 1, 2, 3, 0, 1, 2] });
    expect(d).toHaveLength(7);
    expect(d[0]).toEqual({ numero: 1, texto: ITEMS_GAD7[0], valor: 0, opcion: 'De nada' });
    expect(d[3].opcion).toBe('Casi todos los días');
  });

  test('dificultad: respondida, no preguntada y omitida', () => {
    expect(textoDificultad(2, 12)).toBe('Muy difícil');
    expect(textoDificultad(0, 3)).toBe('No es nada difícil');
    expect(textoDificultad(null, 0)).toBe('No se preguntó (no marcó ningún problema)');
    expect(textoDificultad(null, 8)).toBe('Prefirió no responder');
  });
});

describe('gráfica y tabla de pacientes', () => {
  test('la gráfica va de la más vieja a la más reciente', () => {
    const datos = datosGrafica([
      { id: 'c', fecha_respuesta: '2026-10-20T18:00:00Z', puntaje: 4, severidad: 'minima', valorar: false },
      { id: 'a', fecha_respuesta: '2026-09-08T18:00:00Z', puntaje: 16, severidad: 'grave', valorar: true },
      { id: 'b', fecha_respuesta: '2026-09-22T18:00:00Z', puntaje: 12, severidad: 'moderada', valorar: true },
    ]);
    expect(datos.map((d) => d.id)).toEqual(['a', 'b', 'c']);
    expect(datos[0]).toMatchObject({ puntaje: 16, valorar: true });
  });

  test('celda de la tabla con y sin respuestas', () => {
    expect(resumenTabla({ ultimo_gad7_fecha: null, ultimo_gad7_puntaje: null, gad7_toca: true })).toBeNull();
    expect(resumenTabla({
      ultimo_gad7_fecha: '2026-10-23T16:00:00Z',
      ultimo_gad7_puntaje: 12,
      ultimo_gad7_severidad: 'moderada',
      ultimo_gad7_valorar: true,
      gad7_toca: false,
    })).toEqual({ puntaje: 12, severidad: 'Moderada', valorar: true, fecha: '2026-10-23T16:00:00Z', toca: false });
  });
});
