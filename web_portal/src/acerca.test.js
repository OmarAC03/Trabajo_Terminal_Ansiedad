import fs from 'fs';
import path from 'path';
import { render, screen } from '@testing-library/react';
import AcercaProyecto from './AcercaProyecto';
import { PARRAFOS_ACERCA, PIE_ACERCA, TITULO_ACERCA } from './acerca';
import { NOMBRE_APP } from './marca';

// Lee los textos de la app (Dart). En Dart, los literales seguidos se unen y
// las comas separan los párrafos de la lista.
const dart = fs.readFileSync(
  path.join(__dirname, '..', '..', 'app_ansiedad', 'lib', 'contenido', 'acerca_textos.dart'), 'utf8'
);

function literal(nombre) {
  const m = dart.match(new RegExp(`${nombre}\\s*=\\s*'((?:[^'\\\\]|\\\\.)*)'`));
  return m && m[1];
}

function parrafosDart() {
  const inicio = dart.indexOf('parrafos = [');
  const fin = dart.indexOf('];', inicio);
  const bloque = dart.slice(inicio + 'parrafos = ['.length, fin);
  const parrafos = [];
  let actual = '';
  for (const m of bloque.matchAll(/'((?:[^'\\]|\\.)*)'|(,)/g)) {
    if (m[2]) { parrafos.push(actual); actual = ''; } else actual += m[1];
  }
  if (actual) parrafos.push(actual);
  return parrafos;
}

test('el texto es idéntico al de la app', () => {
  expect(parrafosDart()).toEqual(PARRAFOS_ACERCA);
  expect(literal('titulo')).toBe(TITULO_ACERCA);
  expect(literal('pie').replace('${Marca.nombreApp}', NOMBRE_APP)).toBe(PIE_ACERCA);
});

test('la pantalla muestra el título, los tres párrafos, el pie y los dos escudos', () => {
  render(<AcercaProyecto />);
  expect(screen.getByRole('heading', { name: TITULO_ACERCA })).toBeInTheDocument();
  for (const p of PARRAFOS_ACERCA) expect(screen.getByText(p)).toBeInTheDocument();
  expect(screen.getByText(PIE_ACERCA)).toBeInTheDocument();
  expect(screen.getByAltText('Escudo de la ESCOM')).toBeInTheDocument();
  expect(screen.getByAltText('Escudo del IPN')).toBeInTheDocument();
});

test('sin datos técnicos del servidor', () => {
  const { container } = render(<AcercaProyecto />);
  expect(container.textContent).not.toMatch(/http|onrender|Render|Supabase/);
});
