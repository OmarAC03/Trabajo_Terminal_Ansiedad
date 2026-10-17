import {
  textoEstado, tonoEstado, colorEstado, textoSinEstado, textoEtapa, etiquetaEvaluacion,
  evaluacionUltimaSesion, textoCalibracion,
} from './semaforo';

// El texto visible es lenguaje de indicadores, nunca de diagnóstico
// (MARCO_ALCANCE_Y_LENGUAJE.md, sección 2). Estado contra la línea base
// individual (M3), vista del especialista.
describe('estado contra la línea base', () => {
  test('texto y tono de cada estado', () => {
    expect(textoEstado('normal')).toBe('Normal');
    expect(textoEstado('elevados')).toBe('Elevados');
    expect(textoEstado('altos')).toBe('Altos');
    expect(textoEstado(null)).toBeNull();
    expect(tonoEstado('altos')).toBe('altos');
    expect(tonoEstado(null)).toBe('sin-datos');
    expect(colorEstado('elevados')).toBe('#d97706');
    expect(colorEstado(null)).toBe('#94a3b8');
    // Las claves viejas del semáforo de umbrales fijos ya no significan nada.
    expect(textoEstado('Alta')).toBeNull();
  });

  test('sin estado y etapa', () => {
    expect(textoSinEstado('calibrando')).toBe('Calibrando');
    expect(textoSinEstado('calidad_baja')).toBe('Calidad insuficiente');
    expect(textoSinEstado(null)).toBe('Sin estado');
    expect(textoEtapa('preliminar')).toBe('Preliminar');
    expect(textoEtapa(undefined)).toBe('—');
  });

  test('etiquetaEvaluacion: estado de verdad o gris con el motivo', () => {
    expect(etiquetaEvaluacion({ estado: 'elevados', etapa: 'preliminar', motivo_sin_estado: null }))
      .toEqual({ texto: 'Elevados', tono: 'elevados', conEstado: true });
    expect(etiquetaEvaluacion({ estado: null, etapa: 'calibrando', motivo_sin_estado: 'calibrando' }))
      .toEqual({ texto: 'Calibrando', tono: 'sin-datos', conEstado: false });
    expect(etiquetaEvaluacion({ estado: null, etapa: 'consolidada', motivo_sin_estado: 'calidad_baja' }).texto)
      .toBe('Calidad insuficiente');
    expect(etiquetaEvaluacion(null).conEstado).toBe(false);
  });

  test('evaluacionUltimaSesion: de los campos de /api/pacientes; null si nunca midió', () => {
    expect(evaluacionUltimaSesion({ ultima_sesion: null, ultima_sesion_estado: null })).toBeNull();
    expect(evaluacionUltimaSesion({
      ultima_sesion: '2026-10-16T14:00:00Z',
      ultima_sesion_estado: 'altos',
      ultima_sesion_etapa: 'consolidada',
      ultima_sesion_motivo_sin_estado: null,
      ultima_sesion_fc_por_encima: true,
    })).toEqual({ estado: 'altos', etapa: 'consolidada', motivo_sin_estado: null, fc_por_encima: true });
    // Backend sin el paso 2 de M3: los campos faltan, sin romper nada.
    expect(evaluacionUltimaSesion({ ultima_sesion: '2026-10-16T14:00:00Z' }).estado).toBeNull();
  });

  test('textoCalibracion', () => {
    expect(textoCalibracion({ etapa: 'calibrando', dia_calibracion: 2, dias_objetivo: 7, n: 1 }))
      .toBe('Calibrando: día 2 de 7');
    expect(textoCalibracion({ etapa: 'preliminar', n: 5 })).toBe('Preliminar · 5 días');
    expect(textoCalibracion({ etapa: 'consolidada', n: 7 })).toBe('Consolidada · 7 días');
  });
});
