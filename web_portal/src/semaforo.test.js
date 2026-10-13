import { getStatusLabel, getStatusTone, getStatusOrden } from './semaforo';

// Reemplaza a la prueba de ejemplo de Create React App (buscaba "learn react").
// El texto visible del semáforo es lenguaje de indicadores, nunca de
// diagnóstico (MARCO_ALCANCE_Y_LENGUAJE.md, sección 2): los valores de la BD
// ('Alta' | 'Moderada' | 'Baja') no se muestran tal cual.
describe('semáforo de indicadores fisiológicos', () => {
  test('traduce el valor de la BD al texto visible', () => {
    expect(getStatusLabel('Alta')).toBe('Altos');
    expect(getStatusLabel('Moderada')).toBe('Elevados');
    expect(getStatusLabel('Baja')).toBe('Normal');
    expect(getStatusLabel(null)).toBe('Sin lecturas');
  });

  test('tono y orden de cada estado', () => {
    expect(getStatusTone('Alta')).toBe('altos');
    expect(getStatusTone(undefined)).toBe('sin-datos');
    const orden = ['Baja', null, 'Alta', 'Moderada'].sort((a, b) => getStatusOrden(a) - getStatusOrden(b));
    expect(orden).toEqual(['Alta', 'Moderada', 'Baja', null]);
  });
});
