import { SE_BORRA, SE_CONSERVA, contarPendientes, puedeAtender, confirmacionValida, textoEstado } from './solicitudes';

const s = (extra = {}) => ({ id: 's1', estado: 'pendiente', rol: 'paciente', email: 'ana@correo.com', ...extra });

test('cuenta solo las pendientes', () => {
  expect(contarPendientes([s(), s({ estado: 'atendida' }), s()])).toBe(2);
  expect(contarPendientes([])).toBe(0);
  expect(contarPendientes(undefined)).toBe(0);
});

test('solo se atiende una pendiente de paciente', () => {
  expect(puedeAtender(s())).toBe(true);
  expect(puedeAtender(s({ estado: 'atendida' }))).toBe(false);
  expect(puedeAtender(s({ rol: 'especialista' }))).toBe(false);
});

test('la confirmación exige escribir el correo exacto (sin importar mayúsculas ni espacios)', () => {
  expect(confirmacionValida('ana@correo.com', 'ana@correo.com')).toBe(true);
  expect(confirmacionValida('  ANA@Correo.com ', 'ana@correo.com')).toBe(true);
  expect(confirmacionValida('ana@correo.co', 'ana@correo.com')).toBe(false);
  expect(confirmacionValida('', '')).toBe(false);
  expect(confirmacionValida(undefined, 'ana@correo.com')).toBe(false);
});

test('textos de estado', () => {
  expect(textoEstado(s())).toBe('Pendiente');
  expect(textoEstado(s({ estado: 'atendida' }))).toBe('Atendida');
});

test('lo que se borra y lo que se conserva coincide con la decisión aprobada', () => {
  const borra = SE_BORRA.join(' ');
  expect(borra).toMatch(/sesiones de medición/);
  expect(borra).toMatch(/GAD-7/);
  expect(borra).toMatch(/conversación/);
  expect(borra).toMatch(/ejercicios/);
  expect(borra).toMatch(/cuenta de acceso/);
  const conserva = SE_CONSERVA.join(' ');
  expect(conserva).toMatch(/consentimiento/);
  expect(conserva).toMatch(/sin nombre ni correo/);
  expect(conserva).toMatch(/bitácora/);
});
