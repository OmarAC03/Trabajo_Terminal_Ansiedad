import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import axios from 'axios';
import ExportarReporte from './ExportarReporte';

jest.mock('axios', () => ({ get: jest.fn() }));
jest.mock('./firebase', () => ({ auth: { currentUser: { getIdToken: async () => 'token' } } }));

const SEUD = {
  seudonimizado: true,
  paciente: { id: 'P-1a2b3c4d' },
  especialista: null,
  periodo: { desde: '2026-10-01', hasta: '2026-10-31', zona_horaria: 'America/Mexico_City' },
  generado_en: '2026-11-04T18:00:00.000Z',
  sesiones: [{ fecha_inicio: '2026-10-05T15:00:00Z', origen: 'sensor', hrv_rmssd: 42.5, bpm_promedio: 71, bpm_min: 60, bpm_max: 85, spo2_promedio: 97, indice_calidad: 0.9, eva_valor: 40, estado: 'normal', etapa: 'consolidada' }],
  gad7: [],
  marcadores: [{ fecha: '2026-10-07T16:00:00Z', tipo: 'consulta' }],
};

beforeEach(() => {
  jest.clearAllMocks();
  window.print = jest.fn();
});

test('imprimir pide el reporte seudonimizado y monta la vista sin nombre', async () => {
  axios.get.mockResolvedValue({ data: SEUD });
  render(<ExportarReporte paciente={{ id: 'pac-1', nombre: 'Ana Pérez' }} />);

  fireEvent.click(screen.getByLabelText(/Seudonimizado/));
  fireEvent.click(screen.getByRole('button', { name: /Imprimir/ }));

  const vista = await screen.findByTestId('reporte-impresion');
  expect(axios.get.mock.calls[0][1].params).toMatchObject({ formato: 'pdf', seudonimizado: 'true' });
  expect(vista).toHaveTextContent('P-1a2b3c4d');
  expect(vista).toHaveTextContent('reporte seudonimizado');
  expect(vista).not.toHaveTextContent('Ana');
  expect(vista).not.toHaveTextContent(/Contexto EVA|Descripción/);
  await waitFor(() => expect(window.print).toHaveBeenCalled());
});

test('un periodo inválido no permite exportar', () => {
  render(<ExportarReporte paciente={{ id: 'pac-1' }} />);
  fireEvent.change(screen.getByLabelText('Desde'), { target: { value: '2026-11-03' } });
  fireEvent.change(screen.getByLabelText('Hasta'), { target: { value: '2026-11-01' } });
  expect(screen.getByRole('button', { name: /Descargar CSV/ })).toBeDisabled();
  expect(screen.getByText(/no puede ser posterior/)).toBeInTheDocument();
});
