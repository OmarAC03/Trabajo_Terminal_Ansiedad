import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import axios from 'axios';
import NotasPaciente from './NotasPaciente';

// Sin red ni Firebase: axios responde con notas fijas.
jest.mock('axios', () => ({ get: jest.fn(), post: jest.fn(), put: jest.fn() }));
jest.mock('./firebase', () => ({ auth: { currentUser: { getIdToken: async () => 'token' } } }));

const NOTA = {
  id: 'n1', fecha: '2026-11-02', contenido: 'Refiere mejor sueño.', version: 2,
  creada_en: '2026-11-02T16:00:00Z', editada_en: '2026-11-03T16:00:00Z',
};
const paciente = { id: 'pac-1', nombre: 'Paciente Uno' };

beforeEach(() => {
  jest.clearAllMocks();
  axios.get.mockImplementation(async (url) =>
    url.endsWith('/versiones')
      ? { data: [{ version: 1, fecha: '2026-11-02', contenido: 'Primera versión', escrita_en: NOTA.creada_en, reemplazada_en: NOTA.editada_en }] }
      : { data: [NOTA] }
  );
});

test('lista las notas con su versión y abre el historial', async () => {
  render(<NotasPaciente paciente={paciente} recarga={0} />);
  expect(await screen.findByText('Refiere mejor sueño.')).toBeInTheDocument();
  expect(screen.getByText('2 nov 2026')).toBeInTheDocument();
  expect(screen.getByText(/Versión 2 · editada el/)).toBeInTheDocument();
  expect(screen.getByText(/El paciente no tiene acceso/)).toBeInTheDocument();

  fireEvent.click(screen.getByRole('button', { name: /Historial/ }));
  expect(await screen.findByText('Primera versión')).toBeInTheDocument();
  expect(axios.get).toHaveBeenLastCalledWith(expect.stringMatching(/\/api\/pacientes\/pac-1\/notas\/n1\/versiones$/), expect.anything());
});

test('editar manda la versión que se tenía; un 409 recarga y conserva el borrador', async () => {
  axios.put.mockRejectedValue({ response: { status: 409, data: { error: 'Esta nota cambió desde que la abriste.' } } });
  render(<NotasPaciente paciente={paciente} recarga={0} />);
  await screen.findByText('Refiere mejor sueño.');

  fireEvent.click(screen.getByRole('button', { name: /Editar/ }));
  fireEvent.change(screen.getByLabelText('Nota', { selector: '#nota-n1-contenido' }), { target: { value: 'Texto nuevo' } });
  fireEvent.click(screen.getByRole('button', { name: /Guardar cambios/ }));

  await waitFor(() => expect(axios.put).toHaveBeenCalled());
  expect(axios.put.mock.calls[0][1]).toEqual({ fecha: '2026-11-02', contenido: 'Texto nuevo', version: 2 });
  expect(await screen.findByText('Esta nota cambió desde que la abriste.')).toBeInTheDocument();
  expect(screen.getByText('Texto nuevo')).toBeInTheDocument();
  expect(axios.get.mock.calls.filter(([url]) => url.endsWith('/notas')).length).toBe(2);
});
