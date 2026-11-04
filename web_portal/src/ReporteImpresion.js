import {
  fechaLocal, textoEstadoReporte, textoEtapaReporte, textoSeveridad, textoTipo, textoContextoEva, textoOrigen,
} from './reporte';
import { evaSobre10 } from './sesiones';
import { textoDia } from './notas';

const redondo = (v, decimales = 0) => (v == null ? '—' : Number(v).toFixed(decimales));

// Vista del reporte para imprimir o guardar como PDF (Bloque 2, paso 4). Solo
// se ve al imprimir (ui.css, @media print): ExportarReporte la monta en
// <body> y abre el diálogo del navegador. Recibe el JSON del backend tal
// cual; en la versión seudonimizada ya no trae nombre, correo ni texto libre.
function ReporteImpresion({ reporte: r }) {
  const conTexto = !r.seudonimizado;
  return (
    <div className="reporte-impresion" data-testid="reporte-impresion">
      <header className="reporte-encabezado">
        <h1>Reporte de seguimiento</h1>
        <div className="reporte-meta">
          {r.seudonimizado ? (
            <div><strong>Paciente:</strong> {r.paciente.id} <em>(reporte seudonimizado)</em></div>
          ) : (
            <>
              <div><strong>Paciente:</strong> {r.paciente.nombre} · {r.paciente.email}</div>
              <div><strong>Especialista:</strong> {r.especialista?.nombre}</div>
            </>
          )}
          <div><strong>Periodo:</strong> {textoDia(r.periodo.desde)} a {textoDia(r.periodo.hasta)} (hora de Ciudad de México)</div>
          <div><strong>Generado:</strong> {fechaLocal(r.generado_en)}</div>
        </div>
        <p className="reporte-aviso">
          Indicadores fisiológicos de apoyo y cuestionarios de tamizaje. No constituyen un diagnóstico: la
          interpretación corresponde al profesional de salud.
          {r.seudonimizado && ' Reporte seudonimizado: sin nombre, correo ni texto libre; el identificador se deriva de la cuenta.'}
        </p>
      </header>

      <section>
        <h2>Sesiones de medición ({r.sesiones.length})</h2>
        {r.sesiones.length === 0 ? <p>Sin sesiones en el periodo.</p> : (
          <table>
            <thead>
              <tr>
                <th>Fecha</th><th>Origen</th><th>HRV (ms)</th><th>FC (lpm)</th><th>SpO2 (%)</th>
                <th>Calidad</th><th>EVA /10</th>{conTexto && <th>Contexto EVA</th>}<th>Estado</th><th>Base</th>
              </tr>
            </thead>
            <tbody>
              {r.sesiones.map((s) => (
                <tr key={s.fecha_inicio}>
                  <td>{fechaLocal(s.fecha_inicio)}</td>
                  <td>{textoOrigen(s.origen)}</td>
                  <td>{redondo(s.hrv_rmssd, 1)}</td>
                  <td>{redondo(s.bpm_promedio)} ({redondo(s.bpm_min)}–{redondo(s.bpm_max)})</td>
                  <td>{redondo(s.spo2_promedio)}</td>
                  <td>{s.indice_calidad == null ? '—' : `${Math.round(s.indice_calidad * 100)}%`}</td>
                  <td>{evaSobre10(s.eva_valor)}</td>
                  {conTexto && <td>{s.eva_valor == null ? '—' : textoContextoEva(s.eva_contexto)}</td>}
                  <td>{textoEstadoReporte(s)}</td>
                  <td>{textoEtapaReporte(s)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      <section>
        <h2>GAD-7 ({r.gad7.length})</h2>
        {r.gad7.length === 0 ? <p>Sin cuestionarios en el periodo.</p> : (
          <table>
            <thead><tr><th>Fecha</th><th>Puntaje (0–21)</th><th>Severidad</th></tr></thead>
            <tbody>
              {r.gad7.map((g) => (
                <tr key={g.fecha_respuesta}>
                  <td>{fechaLocal(g.fecha_respuesta)}</td>
                  <td>{g.puntaje}</td>
                  <td>{textoSeveridad(g.severidad)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      <section>
        <h2>Marcadores clínicos ({r.marcadores.length})</h2>
        {r.marcadores.length === 0 ? <p>Sin marcadores en el periodo.</p> : (
          <table>
            <thead><tr><th>Fecha</th><th>Tipo</th>{conTexto && <th>Descripción</th>}</tr></thead>
            <tbody>
              {r.marcadores.map((m, i) => (
                <tr key={`${m.fecha}-${i}`}>
                  <td>{fechaLocal(m.fecha)}</td>
                  <td>{textoTipo(m.tipo)}</td>
                  {conTexto && <td>{m.descripcion || '—'}</td>}
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </div>
  );
}

export default ReporteImpresion;
