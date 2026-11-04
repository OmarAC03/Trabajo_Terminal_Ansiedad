import { render, screen } from '@testing-library/react';
import axios from 'axios';
import AdminBitacora from './AdminBitacora';

// Sin red ni Firebase: axios devuelve una página fija de la bitácora.
jest.mock('axios', () => ({ get: jest.fn() }));
jest.mock('./firebase', () => ({ auth: { currentUser: { getIdToken: async () => 'token' } } }));

const FILAS = [
  {
    id: 3, fecha: '2026-11-04T16:00:00Z', accion: 'nota_editada',
    // Un detalle con una clave que la bitácora nunca debería traer: la
    // pantalla no la muestra aunque llegue.
    detalle: { nota_id: 'n1', version: 2, contenido: 'TEXTO CLINICO SECRETO' },
    actor_id: 'esp-1', actor_rol: 'especialista', actor_nombre: 'Dra. Uno',
    objetivo_id: 'pac-1', objetivo_nombre: 'Paciente Uno', objetivo_rol: 'paciente',
  },
  {
    id: 2, fecha: '2026-11-04T15:00:00Z', accion: 'acceso_datos_clinicos', detalle: { recurso: 'gad7' },
    actor_id: 'esp-1', actor_rol: 'especialista', actor_nombre: 'Dra. Uno',
    objetivo_id: 'pac-1', objetivo_nombre: 'Paciente Uno', objetivo_rol: 'paciente',
  },
];

beforeEach(() => {
  axios.get.mockImplementation(async (url) =>
    url.endsWith('/api/admin/bitacora')
      ? { data: { filas: FILAS, siguiente: 2 } }
      : { data: [{ id: 'esp-1', nombre: 'Dra. Uno', rol: 'especialista' }] }
  );
});

test('muestra quién, qué y sobre quién, y nunca un contenido inesperado', async () => {
  render(<AdminBitacora />);
  // "Nota editada" también es una opción del filtro: se espera a la tabla.
  expect(await screen.findByText('Versión 2')).toBeInTheDocument();
  expect(screen.getAllByText('Nota editada').length).toBe(2); // opción + fila
  expect(screen.getByText('Consultó GAD-7')).toBeInTheDocument();
  expect(screen.getAllByText('Paciente Uno').length).toBe(2);
  expect(screen.queryByText(/TEXTO CLINICO SECRETO/)).not.toBeInTheDocument();
  // Hay página siguiente: se ofrece "Cargar más".
  expect(screen.getByRole('button', { name: /Cargar más/ })).toBeInTheDocument();
});
