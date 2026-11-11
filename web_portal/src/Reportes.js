import { useCallback, useEffect, useState } from 'react';
import axios from 'axios';
import { CircleAlert, History, RefreshCw } from 'lucide-react';
import { auth } from './firebase';
import ExportarReporte from './ExportarReporte';
import { Alert, Badge, Button, Card, PageHeader, Select } from './ui/components';
import { exportacionesUrl, filaHistorial, pacientesParaExportar } from './exportaciones';

// Sección "Reportes" del portal (versión final, Fase 2): exportar el reporte
// de cualquiera de los pacientes vinculados (el mismo ExportarReporte del
// detalle) y el historial de lo exportado, leído de la bitácora. Nada se
// guarda en el servidor: el CSV y el PDF se generan en el navegador.
function Reportes({ pacientes }) {
  const lista = pacientesParaExportar(pacientes);
  const [pacienteId, setPacienteId] = useState('');
  const elegido = lista.find((p) => p.id === pacienteId) || null;

  const [historial, setHistorial] = useState(null); // null = cargando
  const [limite, setLimite] = useState(null);
  const [error, setError] = useState('');

  const cargarHistorial = useCallback(async () => {
    setError('');
    try {
      const token = await auth.currentUser.getIdToken();
      const res = await axios.get(exportacionesUrl, { headers: { Authorization: `Bearer ${token}` } });
      setHistorial(res.data.filas.map(filaHistorial));
      setLimite(res.data.limite);
    } catch (e) {
      console.error('Error al cargar el historial de exportaciones:', e);
      setError('No se pudo cargar el historial de exportaciones.');
      setHistorial((h) => h || []);
    }
  }, []);

  useEffect(() => { cargarHistorial(); }, [cargarHistorial]);

  return (
    <div className="ui-page ui-page-wide">
      <PageHeader title="Reportes" subtitle="Exporta el reporte de un paciente y consulta lo que has exportado" />

      <Card title="Paciente" subtitle="Elige a quién corresponde el reporte">
        {lista.length === 0 ? (
          <div className="ui-empty">Aún no tienes pacientes vinculados.</div>
        ) : (
          <Select id="reportes-paciente" label="Paciente" value={pacienteId} onChange={(e) => setPacienteId(e.target.value)}>
            <option value="">Elige un paciente…</option>
            {lista.map((p) => <option key={p.id} value={p.id}>{p.nombre}</option>)}
          </Select>
        )}
      </Card>

      {elegido && <ExportarReporte key={elegido.id} paciente={elegido} onExportado={cargarHistorial} />}

      <Card
        className="ui-section-gap"
        title="Historial de exportaciones"
        subtitle={limite ? `Tus últimas ${limite} exportaciones, según la bitácora` : 'Según la bitácora'}
        icon={History}
        actions={<Button variant="soft" size="sm" icon={RefreshCw} onClick={cargarHistorial}>Actualizar</Button>}
      >
        {error && (
          <div style={{ marginBottom: 12 }}>
            <Alert tone="altos" icon={CircleAlert}>{error}</Alert>
          </div>
        )}
        {historial === null ? (
          <div className="ui-empty">Cargando historial…</div>
        ) : historial.length === 0 ? (
          <div className="ui-empty">Todavía no has exportado ningún reporte.</div>
        ) : (
          <div className="ui-table-wrap">
            <table className="ui-table">
              <thead>
                <tr>
                  <th scope="col">Fecha</th>
                  <th scope="col">Paciente</th>
                  <th scope="col">Formato</th>
                  <th scope="col">Identificación</th>
                  <th scope="col">Periodo</th>
                </tr>
              </thead>
              <tbody>
                {historial.map((f) => (
                  <tr key={f.clave}>
                    <td className="ui-num">{f.fecha}</td>
                    <td className={f.vinculado ? undefined : 'ui-muted'}>{f.paciente}</td>
                    <td>{f.formato}</td>
                    <td><Badge tone={f.identificacion === 'Seudonimizado' ? 'primary' : 'neutral'} dot={false}>{f.identificacion}</Badge></td>
                    <td>{f.periodo}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
    </div>
  );
}

export default Reportes;
