import fs from 'fs';
import path from 'path';
import { render } from '@testing-library/react';
import AuthLayout from './ui/AuthLayout';
import { NOMBRE_APP, LEMA, NOMBRE_MASCOTA, FRASE_MASCOTA } from './marca';

const PROHIBIDOS = ['ansiedad', 'Portal Clínico TT', 'Monitor ESCOM', 'Trabajo Terminal'];
const leerPublico = (archivo) => fs.readFileSync(path.join(__dirname, '..', 'public', archivo), 'utf8');

describe('marca del portal', () => {
  test('nombre, lema y mascota iguales a los de la app', () => {
    expect(NOMBRE_APP).toBe('Mi Ritmo');
    expect(LEMA).toBe('Tu ritmo, acompañado.');
    expect(NOMBRE_MASCOTA).toBe('Riti');
    expect(FRASE_MASCOTA).toBe('Vamos a tu ritmo.');
  });

  test('el título de la pestaña es "Mi Ritmo" con el lema y no dice "ansiedad"', () => {
    const titulo = leerPublico('index.html').match(/<title>(.*)<\/title>/)[1];
    expect(titulo).toBe(`${NOMBRE_APP} · ${LEMA}`);
    const manifiesto = JSON.parse(leerPublico('manifest.json'));
    expect(manifiesto.short_name).toBe(NOMBRE_APP);
    for (const p of PROHIBIDOS) {
      expect(titulo.toLowerCase()).not.toContain(p.toLowerCase());
      expect(manifiesto.name.toLowerCase()).not.toContain(p.toLowerCase());
    }
  });

  test('login y registro muestran "Mi Ritmo" y el lema, y ningún texto dice "ansiedad"', () => {
    const { container, getByText } = render(
      <AuthLayout title="Iniciar sesión" subtitle="Accede a tu cuenta">
        <p>formulario</p>
      </AuthLayout>
    );
    expect(getByText(NOMBRE_APP)).toBeInTheDocument();
    expect(getByText(LEMA)).toBeInTheDocument();
    for (const p of PROHIBIDOS) {
      expect(container.textContent.toLowerCase()).not.toContain(p.toLowerCase());
    }
  });
});
