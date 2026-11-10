import fs from 'fs';
import path from 'path';
import { render } from '@testing-library/react';
import AuthLayout, { AVATARES } from './ui/AuthLayout';
import Layout from './ui/Layout';
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
    // Riti en lugar del dibujo de la señal.
    expect(container.querySelector(`img[alt="${NOMBRE_MASCOTA}"]`)).not.toBeNull();
    for (const p of PROHIBIDOS) {
      expect(container.textContent.toLowerCase()).not.toContain(p.toLowerCase());
    }
  });

  test('el menú lateral muestra a Riti junto a "Mi Ritmo" (sin el ícono de pulso)', () => {
    const { container, getByText } = render(
      <Layout secciones={[]} activa="" onNavegar={() => {}} usuarioNombre="PRUEBA" usuarioRol="especialista">
        <p>contenido</p>
      </Layout>
    );
    expect(getByText(NOMBRE_APP)).toBeInTheDocument();
    const marca = container.querySelector('.ui-brand');
    expect(marca.querySelector(`img[alt="${NOMBRE_MASCOTA}"]`)).not.toBeNull();
    expect(marca.querySelector('svg')).toBeNull();
  });

  test('el ícono de la pestaña es el de la app, no el de React', () => {
    const html = leerPublico('index.html');
    expect(html).toContain('href="%PUBLIC_URL%/favicon.png"');
    const iconos = JSON.parse(leerPublico('manifest.json')).icons.map((i) => i.src);
    expect(iconos).toEqual(['favicon.png', 'logo192.png']);
    for (const archivo of iconos) {
      expect(fs.existsSync(path.join(__dirname, '..', 'public', archivo))).toBe(true);
    }
  });

  test('el login usa a Riti meditando y registro y recuperar, otro avatar cada uno', () => {
    const imagen = (avatar) => {
      const { container, unmount } = render(<AuthLayout title="t" avatar={avatar}><p>x</p></AuthLayout>);
      const src = container.querySelector(`img[alt="${NOMBRE_MASCOTA}"]`).getAttribute('src');
      unmount();
      return src;
    };
    expect(AVATARES.login).toMatch(/avatar_meditando/);
    expect(imagen(undefined)).toBe(AVATARES.login);
    expect(new Set([imagen('login'), imagen('registro'), imagen('recuperar')]).size).toBe(3);
    const fuente = (archivo) => fs.readFileSync(path.join(__dirname, archivo), 'utf8');
    expect(fuente('Login.js')).toContain('avatar="login"');
    expect(fuente('RegistroEspecialista.js')).toContain('avatar="registro"');
    expect(fuente('RecuperarPassword.js')).toContain('avatar="recuperar"');
  });
});
