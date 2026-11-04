import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import axios from 'axios';
import MarcadoresPanel from './MarcadoresPanel';

jest.mock('axios', () => ({ post: jest.fn(), delete: jest.fn() }));
jest.mock('./firebase', () => ({ auth: { currentUser: { getIdToken: async () => 'token' } } }));

const paciente = { id: 'pac-1' };
const M1 = { id: 'm1', fecha: '2026-10-20T16:00:00Z', tipo: 'periodo_examenes', descripcion: 'Parciales' };

beforeEach(() => jest.clearAllMocks());

test('agrega un marcador con fecha ISO y descripción null si va vacía', async () => {
  const onCambio = jest.fn();
  axios.post.mockResolvedValue({ data: { id: 'm2', fecha: '2026-11-04T16:00:00Z', tipo: 'consulta', descripcion: null } });
  render(<MarcadoresPanel paciente={paciente} marcadores={[M1]} numeros={new Map([['m1', 1]])} onCambio={onCambio} />);

  expect(screen.getByText('Parciales')).toBeInTheDocument(); // el tipo también es una opción del select
  expect(screen.getByText('1')).toBeInTheDocument();
  fireEvent.click(screen.getByRole('button', { name: /Agregar marcador/ }));

  await waitFor(() => expect(onCambio).toHaveBeenCalled());
  const [url, cuerpo] = axios.post.mock.calls[0];
  expect(url).toMatch(/\/api\/pacientes\/pac-1\/marcadores$/);
  expect(cuerpo.tipo).toBe('consulta');
  expect(cuerpo.descripcion).toBeNull();
  expect(cuerpo.fecha).toMatch(/Z$/);
  expect(onCambio.mock.calls[0][0].map((m) => m.id)).toEqual(['m1', 'm2']);
});

test('borrar pide confirmación y quita el marcador', async () => {
  const onCambio = jest.fn();
  axios.delete.mockResolvedValue({ status: 204 });
  render(<MarcadoresPanel paciente={paciente} marcadores={[M1]} numeros={new Map()} onCambio={onCambio} />);

  fireEvent.click(screen.getByRole('button', { name: /Borrar marcador/ }));
  expect(axios.delete).not.toHaveBeenCalled();
  fireEvent.click(screen.getByRole('button', { name: /Sí, borrar/ }));

  await waitFor(() => expect(onCambio).toHaveBeenCalledWith([]));
  expect(axios.delete.mock.calls[0][0]).toMatch(/\/marcadores\/m1$/);
});
