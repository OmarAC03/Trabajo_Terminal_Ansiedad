import { tonoIdentidad } from './components';

// El color de identidad solo sirve para reconocer al paciente: fijo por su id
// y nunca un color del semáforo.
describe('tonoIdentidad', () => {
  const SEMAFORO = ['normal', 'elevados', 'altos', 'sin-datos'];
  const ids = ['1', '2', '3', 42, 'a3f9c2d0-1b2c-4d5e-8f90-123456789abc', '', null, undefined];

  test('el mismo id siempre da el mismo tono', () => {
    ids.forEach((id) => expect(tonoIdentidad(id)).toBe(tonoIdentidad(id)));
    expect(tonoIdentidad(42)).toBe(tonoIdentidad('42'));
  });

  test('solo tonos de identidad, nunca del semáforo', () => {
    ids.forEach((id) => {
      expect(['primary', 'indigo', 'violet', 'cyan', 'sky']).toContain(tonoIdentidad(id));
      expect(SEMAFORO).not.toContain(tonoIdentidad(id));
    });
  });

  test('reparte ids distintos entre varios tonos', () => {
    const tonos = new Set(Array.from({ length: 20 }, (_, i) => tonoIdentidad(String(i + 1))));
    expect(tonos.size).toBeGreaterThan(1);
  });
});
