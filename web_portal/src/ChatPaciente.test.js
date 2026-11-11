import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import axios from 'axios';
import { io } from 'socket.io-client';
import ChatPaciente from './ChatPaciente';
import Mensajes from './Mensajes';

jest.mock('axios', () => ({ get: jest.fn() }));
jest.mock('./firebase', () => ({ auth: { currentUser: { uid: 'esp-1', getIdToken: async () => 'token' } } }));
jest.mock('socket.io-client', () => ({ io: jest.fn() }));

let emitir;
beforeEach(() => {
  jest.clearAllMocks();
  // El ack responde ok: el mensaje se "envió".
  emitir = jest.fn((evento, datos, ack) => ack(null, { ok: true }));
  io.mockReturnValue({ on: jest.fn(), disconnect: jest.fn(), timeout: () => ({ emit: emitir }) });
});

const PACIENTE = { id: 'pac-1', nombre: 'Ana Pérez' };

async function abrirChat(mensajes = [], extra = {}) {
  axios.get.mockResolvedValue({ data: mensajes });
  render(<ChatPaciente paciente={PACIENTE} {...extra} />);
  await screen.findByText(mensajes.length ? mensajes[0].texto : 'Aún no hay mensajes en esta conversación.');
  return screen.getByLabelText('Mensaje para el paciente');
}

test('la caja es un textarea de 1 línea con el límite del servidor', async () => {
  const caja = await abrirChat();
  expect(caja.tagName).toBe('TEXTAREA');
  expect(caja).toHaveAttribute('rows', '1');
  expect(caja).toHaveAttribute('maxLength', '2000');
  expect(screen.getByText(/Enter envía · Shift\+Enter/)).toBeInTheDocument();
});

test('Enter envía y avisa a la bandeja; Shift+Enter no envía', async () => {
  const onCambio = jest.fn();
  const caja = await abrirChat([], { onCambio });

  fireEvent.change(caja, { target: { value: 'Hola\nsegunda línea' } });
  fireEvent.keyDown(caja, { key: 'Enter', shiftKey: true });
  expect(emitir).not.toHaveBeenCalled();

  fireEvent.keyDown(caja, { key: 'Enter' });
  expect(emitir).toHaveBeenCalledTimes(1);
  expect(emitir.mock.calls[0][1]).toEqual({ paciente_id: 'pac-1', texto: 'Hola\nsegunda línea' });
  await waitFor(() => expect(caja).toHaveValue(''));
  expect(onCambio).toHaveBeenCalled();
});

test('Enter con la caja vacía no envía', async () => {
  const caja = await abrirChat();
  fireEvent.change(caja, { target: { value: '   ' } });
  fireEvent.keyDown(caja, { key: 'Enter' });
  expect(emitir).not.toHaveBeenCalled();
});

test('el historial lleva separadores por día', async () => {
  await abrirChat([
    { id: 'a', paciente_id: 'pac-1', remitente_id: 'pac-1', texto: 'Primero', fecha_envio: '2025-03-03T18:00:00Z' },
    { id: 'b', paciente_id: 'pac-1', remitente_id: 'esp-1', texto: 'Segundo', fecha_envio: '2025-03-04T18:00:00Z' },
  ]);
  const separadores = screen.getAllByRole('separator').map((s) => s.textContent);
  expect(separadores).toEqual(['lunes 3 de marzo de 2025', 'martes 4 de marzo de 2025']);
  expect(screen.getAllByText('12:00')).toHaveLength(2);
});

describe('bandeja de Mensajes', () => {
  const CONVERSACIONES = [
    { paciente_id: 'p1', nombre: 'Ana', ultima_fecha: '2025-03-04T18:00:00Z', ultimo_de: 'paciente', pendiente: true, sin_responder: 2 },
    { paciente_id: 'p2', nombre: 'Beto', ultima_fecha: '2025-03-03T18:00:00Z', ultimo_de: 'especialista', pendiente: false, sin_responder: 0 },
  ];

  test('muestra cuántas esperan respuesta y el estado de cada una', () => {
    render(<Mensajes conversaciones={CONVERSACIONES} onActualizar={jest.fn()} />);
    expect(screen.getByText('1 conversación pendiente de responder')).toBeInTheDocument();
    expect(screen.getByText('Pendiente de responder · 2 mensajes')).toBeInTheDocument();
    expect(screen.getByText('Respondida')).toBeInTheDocument();
    expect(screen.getByLabelText('2 sin responder')).toBeInTheDocument();
  });

  test('al elegir una conversación abre el chat de ese paciente', async () => {
    axios.get.mockResolvedValue({ data: [] });
    render(<Mensajes conversaciones={CONVERSACIONES} onActualizar={jest.fn()} />);
    fireEvent.click(screen.getByRole('button', { name: /Beto/ }));
    expect(await screen.findByText('Conversación con Beto')).toBeInTheDocument();
    expect(axios.get.mock.calls[0][0]).toMatch(/\/api\/mensajes\/p2$/);
  });

  test('sin pacientes vinculados lo dice', () => {
    render(<Mensajes conversaciones={[]} onActualizar={jest.fn()} />);
    expect(screen.getByText(/Aún no tienes pacientes vinculados/)).toBeInTheDocument();
  });
});
