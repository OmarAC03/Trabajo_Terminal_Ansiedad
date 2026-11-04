import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import axios from 'axios';
import { CircleAlert, FileDown, Printer, ShieldCheck } from 'lucide-react';
import { auth } from './firebase';
import { Alert, Button, Card, Disclaimer, Field } from './ui/components';
import { diaLocal } from './notas';
import { reporteUrl, rangoPorDefecto, errorRango, parametrosReporte, csvDesdeReporte, nombreArchivo } from './reporte';
import ReporteImpresion from './ReporteImpresion';

function descargar(texto, nombre) {
  const url = URL.createObjectURL(new Blob([texto], { type: 'text/csv;charset=utf-8' }));
  const a = document.createElement('a');
  a.href = url;
  a.download = nombre;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 0);
}

// Exportar el reporte del paciente (Bloque 2, paso 4: WEB-RF-29 /
// RNF-WEB-08): CSV o impresión/PDF, con o sin identificación. Cada
// exportación queda en la bitácora (la registra el backend antes de
// responder).
function ExportarReporte({ paciente }) {
  const [rango, setRango] = useState(() => rangoPorDefecto());
  const [seudonimizado, setSeudonimizado] = useState(false);
  const [cargando, setCargando] = useState(null); // 'csv' | 'pdf' | null
  const [error, setError] = useState('');
  const [paraImprimir, setParaImprimir] = useState(null);

  const problema = errorRango(rango);
  const hoy = diaLocal();

  // Ya montada la vista de impresión, se abre el diálogo; al cerrarlo se quita.
  useEffect(() => {
    if (!paraImprimir) return undefined;
    const quitar = () => setParaImprimir(null);
    window.addEventListener('afterprint', quitar);
    const t = setTimeout(() => window.print(), 0);
    return () => {
      clearTimeout(t);
      window.removeEventListener('afterprint', quitar);
    };
  }, [paraImprimir]);

  const exportar = async (formato) => {
    if (problema || cargando) return;
    setCargando(formato);
    setError('');
    try {
      const token = await auth.currentUser.getIdToken();
      const res = await axios.get(reporteUrl(paciente.id), {
        headers: { Authorization: `Bearer ${token}` },
        params: parametrosReporte(rango, formato, seudonimizado),
      });
      if (formato === 'csv') descargar(csvDesdeReporte(res.data), nombreArchivo(res.data, 'csv'));
      else setParaImprimir(res.data);
    } catch (e) {
      console.error('Error al exportar el reporte:', e);
      setError(
        e.response?.status === 403
          ? 'Este paciente no está vinculado a tu cuenta.'
          : e.response?.data?.error || 'No se pudo generar el reporte. Intenta de nuevo.'
      );
    } finally {
      setCargando(null);
    }
  };

  return (
    <Card
      className="ui-section-gap"
      title="Exportar reporte"
      subtitle="Sesiones, GAD-7 y marcadores del periodo, en CSV o para imprimir / guardar como PDF"
      icon={FileDown}
    >
      <form className="ui-filtros ui-filtros-en-card" onSubmit={(e) => e.preventDefault()}>
        <Field id="reporte-desde" label="Desde" type="date" max={hoy} value={rango.desde} onChange={(e) => setRango((r) => ({ ...r, desde: e.target.value }))} />
        <Field id="reporte-hasta" label="Hasta" type="date" max={hoy} value={rango.hasta} onChange={(e) => setRango((r) => ({ ...r, hasta: e.target.value }))} />
        <label className="ui-check" htmlFor="reporte-seudonimizado">
          <input
            id="reporte-seudonimizado"
            type="checkbox"
            checked={seudonimizado}
            onChange={(e) => setSeudonimizado(e.target.checked)}
          />
          Seudonimizado (sin nombre, correo ni texto libre)
        </label>
        <div className="ui-filtros-acciones">
          <Button icon={FileDown} onClick={() => exportar('csv')} disabled={Boolean(problema) || Boolean(cargando)}>
            {cargando === 'csv' ? 'Generando…' : 'Descargar CSV'}
          </Button>
          <Button variant="secondary" icon={Printer} onClick={() => exportar('pdf')} disabled={Boolean(problema) || Boolean(cargando)}>
            {cargando === 'pdf' ? 'Generando…' : 'Imprimir / PDF'}
          </Button>
        </div>
      </form>

      {(problema || error) && (
        <div style={{ marginTop: 12 }}>
          <Alert tone="altos" icon={CircleAlert}>{problema || error}</Alert>
        </div>
      )}

      <div style={{ marginTop: 16 }}>
        <Disclaimer icon={ShieldCheck}>
          Cada exportación queda registrada en la bitácora. La versión seudonimizada cambia el nombre por un
          identificador (P-…) y quita el texto libre; conserva las fechas, y el identificador se puede recalcular
          a partir de la cuenta. Para guardar el PDF, elige "Guardar como PDF" en el diálogo de impresión.
        </Disclaimer>
      </div>

      {paraImprimir && createPortal(<ReporteImpresion reporte={paraImprimir} />, document.body)}
    </Card>
  );
}

export default ExportarReporte;
