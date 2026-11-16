import { render, screen } from '@testing-library/react';
import { ValorEva, ContextoEva, CaraEva } from './EvaVisual';

test('ValorEva: cara, número sobre 10, tooltip y aria-label', () => {
  render(<ValorEva valor={74} />);
  const eva = screen.getByRole('img', { name: 'Ansiedad autorreportada por el paciente: 7.4 de 10' });
  expect(eva).toHaveAttribute('title', 'Ansiedad autorreportada por el paciente');
  expect(eva).toHaveTextContent('7.4/10');
  expect(eva.querySelector('svg')).toHaveAttribute('data-nivel', 'alta');
  expect(eva.querySelector('svg')).toHaveAttribute('aria-hidden', 'true');
});

test('ValorEva: ningún texto visible pone etiqueta a la ansiedad', () => {
  for (const v of [0, 25, 50, 70, 100]) {
    const { container, unmount } = render(<ValorEva valor={v} />);
    expect(container).not.toHaveTextContent(/tranquila|leve|moderada|alta|grave|normal|elevad/i);
    unmount();
  }
});

test('ValorEva omitida → "—" sin cara', () => {
  const { container } = render(<ValorEva valor={null} />);
  expect(container).toHaveTextContent('—');
  expect(container.querySelector('svg')).toBeNull();
});

test('cada nivel dibuja una cara distinta con su tono (nunca el del semáforo)', () => {
  const niveles = [5, 30, 50, 70, 90].map((v) => {
    const { container, unmount } = render(<CaraEva valor={v} />);
    const svg = container.querySelector('svg');
    const r = { nivel: svg.getAttribute('data-nivel'), clase: svg.getAttribute('class'), boca: svg.lastChild.getAttribute('d') };
    unmount();
    return r;
  });
  expect(niveles.map((n) => n.nivel)).toEqual(['tranquila', 'leve', 'moderada', 'alta', 'muy_alta']);
  expect(new Set(niveles.map((n) => n.boca)).size).toBe(5);
  for (const n of niveles) expect(n.clase).not.toMatch(/tone-|elevados|altos/);
});

test('ContextoEva: ícono + texto para cada contexto; sin contexto, nada', () => {
  const textos = {
    reposo: 'En reposo', estudiando: 'Estudiando', antes_examen: 'Antes de un examen',
    despues_estresor: 'Después de una situación estresante', otro: 'Otro',
  };
  for (const [clave, texto] of Object.entries(textos)) {
    const { container, unmount } = render(<ContextoEva clave={clave} />);
    expect(container).toHaveTextContent(texto);
    expect(container.querySelector('svg')).toHaveAttribute('aria-hidden', 'true');
    unmount();
  }
  const { container } = render(<ContextoEva clave={null} />);
  expect(container).toBeEmptyDOMElement();
});

test('reporte para imprimir: misma cara y mismo contexto que la tabla', () => {
  const ReporteImpresion = require('./ReporteImpresion').default;
  const reporte = {
    seudonimizado: false,
    paciente: { id: 'p-1', nombre: 'PRUEBA', email: 'x@example.com' },
    especialista: { nombre: 'PRUEBA E' },
    periodo: { desde: '2026-10-01', hasta: '2026-10-31', zona_horaria: 'America/Mexico_City' },
    generado_en: '2026-11-01T00:00:00.000Z',
    sesiones: [{ fecha_inicio: '2026-10-05T15:00:00Z', origen: 'sensor', hrv_rmssd: 42.5, bpm_promedio: 71, bpm_min: 60,
      bpm_max: 85, spo2_promedio: 97, indice_calidad: 0.9, eva_valor: 74, eva_contexto: 'estudiando', estado: 'normal', etapa: 'consolidada' }],
    gad7: [], marcadores: [],
  };
  render(<ReporteImpresion reporte={reporte} />);
  expect(screen.getByRole('img', { name: 'Ansiedad autorreportada por el paciente: 7.4 de 10' })).toBeInTheDocument();
  expect(screen.getByText('Estudiando').closest('.eva-contexto').querySelector('svg')).not.toBeNull();
});
