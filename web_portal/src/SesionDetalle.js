import { useEffect, useState } from 'react';
import axios from 'axios';
import { ArrowLeft, BadgeCheck, Timer, Heart, Droplet, ShieldAlert, CircleAlert, Activity, Info, MessageSquare } from 'lucide-react';
import {
  ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip, CartesianGrid, ReferenceArea,
} from 'recharts';
import { auth } from './firebase';
import { Card, KpiCard, Button, Badge, Alert, Disclaimer } from './ui/components';
import {
  SESIONES_URL, normalizarSesion, serieConCortes, huecosDeSerie, ticksEje,
  porcentajeCalidad, duracionTexto, fechaHora, minSeg,
  evaSobre10, textoContextoEva, demoraEva,
} from './sesiones';

// Regla de seguridad de DESARROLLO_FUNDAMENTADO.md §2.3 (la misma que la app).
const SPO2_UMBRAL_SEGURIDAD = 94;

// Un color por métrica, de la paleta por tipo de dato de tokens.css (FC =
// --color-primary, HRV = --color-cyan, SpO2 = --color-sky). Nunca verde/ámbar/
// rojo: son del semáforo y aquí no se clasifica nada.
const COLORES = { bpm: '#2563eb', hrv: '#0891b2', spo2: '#0284c7' };
const EJE = { fontSize: 11, fill: '#94a3b8' };

// Detalle de una sesión para el especialista (Fase M1, portal). Muestra lo que
// al paciente se le oculta: el sello de calidad de la medición (índice de
// calidad y segundos válidos) y las gráficas CORTADAS en los huecos, con una
// franja gris donde no hubo señal válida. En la app las líneas son continuas.
function SesionDetalle({ paciente, sesionId, onVolver }) {
  const [sesion, setSesion] = useState(null);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let cancelado = false;

    const cargar = async () => {
      setCargando(true);
      setError('');
      try {
        const token = await auth.currentUser.getIdToken();
        const res = await axios.get(`${SESIONES_URL}/${paciente.id}/${sesionId}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (cancelado) return;
        setSesion(normalizarSesion(res.data));
      } catch (e) {
        if (cancelado) return;
        console.error('Error al cargar el detalle de la sesión:', e);
        const status = e.response?.status;
        setError(
          status === 404
            ? 'Esta sesión ya no está disponible.'
            : status === 403
              ? 'Este paciente no está vinculado a tu cuenta.'
              : 'No se pudo cargar la sesión. Intenta de nuevo en unos segundos.'
        );
      } finally {
        if (!cancelado) setCargando(false);
      }
    };

    cargar();
    return () => {
      cancelado = true;
    };
  }, [paciente.id, sesionId]);

  return (
    <div className="ui-stack">
      <div>
        <Button variant="secondary" size="sm" icon={ArrowLeft} onClick={onVolver}>Volver a sesiones</Button>
      </div>
      {error ? (
        <Alert tone="altos" icon={CircleAlert}>{error}</Alert>
      ) : cargando || !sesion ? (
        <Card><div className="ui-empty">Cargando sesión…</div></Card>
      ) : (
        <Contenido sesion={sesion} />
      )}
    </div>
  );
}

function Contenido({ sesion: s }) {
  const serie = s.serie || [];
  const huecos = huecosDeSerie(serie);
  const datos = serieConCortes(serie);
  const ultimoT = serie.length ? serie[serie.length - 1].t : 0;

  return (
    <>
      <Card
        title={fechaHora(s.fecha_inicio)}
        subtitle={`Duración ${duracionTexto(s.duracion_total_seg)}`}
        icon={Activity}
        actions={s.origen === 'simulacion' ? <Badge tone="neutral">Simulación</Badge> : <Badge tone="neutral">Sensor</Badge>}
      >
        {/* Sello de calidad: tono neutro, nunca alarma (DISENO_FLUJO_MEDICION.md §3).
            Toda sesión guardada cumplió el mínimo de señal válida; no hay umbral
            de "calidad baja" porque no tenemos fundamento para fijarlo. */}
        <Alert tone="neutral" icon={BadgeCheck}>
          <strong>Medición válida</strong>
          {' · '}Calidad de señal {porcentajeCalidad(s.indice_calidad)} %
          {' · '}{s.duracion_valida_seg} s válidos de {s.duracion_total_seg} s
        </Alert>
      </Card>

      <div className="ui-grid ui-grid-kpi">
        <KpiCard
          label="HRV (RMSSD)"
          value={<>{Math.round(s.hrv_rmssd)}<span className="ui-unit" style={{ fontSize: 'var(--text-md)' }}>ms</span></>}
          hint={`Mín ${Math.round(s.hrv_min)} · Máx ${Math.round(s.hrv_max)} ms`}
          icon={Timer}
          tone="cyan"
        />
        <KpiCard
          label="FC promedio"
          value={<>{Math.round(s.bpm_promedio)}<span className="ui-unit" style={{ fontSize: 'var(--text-md)' }}>lpm</span></>}
          hint={`Mín ${s.bpm_min} · Máx ${s.bpm_max} lpm`}
          icon={Heart}
          tone="primary"
        />
        <KpiCard
          label="SpO2 promedio"
          value={<>{Math.round(s.spo2_promedio)}<span className="ui-unit" style={{ fontSize: 'var(--text-md)' }}>%</span></>}
          hint={`Mín ${s.spo2_min} · Máx ${s.spo2_max} %`}
          icon={Droplet}
          tone="sky"
        />
      </div>

      {s.spo2_promedio < SPO2_UMBRAL_SEGURIDAD && (
        <Alert tone="elevados" icon={ShieldAlert}>
          SpO2 promedio por debajo de {SPO2_UMBRAL_SEGURIDAD} %: sugerir confirmar con un oxímetro. No se
          relaciona con la ansiedad (regla de seguridad, DESARROLLO_FUNDAMENTADO.md §2.3).
        </Alert>
      )}

      <ReporteSubjetivo sesion={s} />

      {serie.length < 2 ? (
        <Card><div className="ui-empty">La sesión no tiene suficientes puntos para graficar.</div></Card>
      ) : (
        <>
          <GraficaSerie titulo="Frecuencia cardiaca (lpm)" campo="bpm" color={COLORES.bpm} datos={datos} huecos={huecos} ultimoT={ultimoT} />
          <GraficaSerie titulo="HRV, RMSSD de ventana móvil de 30 s (ms)" campo="hrv" color={COLORES.hrv} datos={datos} huecos={huecos} ultimoT={ultimoT} />
          <GraficaSerie titulo="SpO2 (%)" campo="spo2" color={COLORES.spo2} datos={datos} huecos={huecos} ultimoT={ultimoT} dominioY={['dataMin - 2', 100]} />
          <p className="ui-muted" style={{ fontSize: 'var(--text-sm)', margin: 0 }}>
            {huecos.length === 0
              ? 'Señal válida durante toda la sesión.'
              : `Franjas grises: tramos sin señal válida (${huecos.length} ${huecos.length === 1 ? 'tramo' : 'tramos'}). La línea se corta ahí; esos segundos no entran en el cálculo.`}
          </p>
        </>
      )}

      <Disclaimer icon={Info}>
        Datos fisiológicos de apoyo. La interpretación y el diagnóstico corresponden al profesional de salud.
      </Disclaimer>
    </>
  );
}

// EVA post-medición (Fase M2): lo que el paciente reportó, sobre 10, con su
// contexto y cuánto tardó en responder. Antes de las gráficas porque
// contextualiza la lectura de los datos objetivos; no los cruza ni interpreta
// (la correlación va con la línea base). Si se omitió también se muestra: la
// tasa de omisión es un dato del objetivo 5.
function ReporteSubjetivo({ sesion: s }) {
  return (
    <Card title="Reporte subjetivo (EVA)" icon={MessageSquare}>
      {s.eva_valor == null ? (
        <div className="ui-muted">El paciente no respondió la EVA en esta sesión.</div>
      ) : (
        <div style={{ display: 'flex', alignItems: 'center', gap: 24, flexWrap: 'wrap' }}>
          <div>
            <span className="ui-num" style={{ fontSize: 'var(--text-kpi)', fontWeight: 700 }}>{evaSobre10(s.eva_valor)}</span>
            <span className="ui-unit" style={{ fontSize: 'var(--text-md)' }}>/ 10</span>
          </div>
          <div>
            <div>{textoContextoEva(s.eva_contexto)}</div>
            <div className="ui-muted" style={{ fontSize: 'var(--text-sm)' }}>{demoraEva(s)}</div>
          </div>
        </div>
      )}
      <p className="ui-muted" style={{ fontSize: 'var(--text-sm)', margin: '12px 0 0' }}>
        Escala visual analógica respondida por el paciente al terminar la medición: 0 = nada, 10 = la máxima
        ansiedad imaginable.
      </p>
    </Card>
  );
}

// Un parámetro contra el tiempo de la sesión (eje en m:ss), con la línea
// cortada en los huecos (puntos null, connectNulls apagado) y una franja gris
// en cada tramo sin señal válida.
function GraficaSerie({ titulo, campo, color, datos, huecos, ultimoT, dominioY = ['dataMin - 5', 'dataMax + 5'] }) {
  return (
    <Card title={titulo}>
      <div style={{ width: '100%', height: 200 }}>
        <ResponsiveContainer>
          <LineChart data={datos} margin={{ top: 10, right: 20, left: -10, bottom: 0 }}>
            <CartesianGrid stroke="#e2e8f0" vertical={false} />
            {huecos.map((h) => (
              <ReferenceArea key={h.desde} x1={h.desde} x2={h.hasta} fill="#94a3b8" fillOpacity={0.15} strokeOpacity={0} />
            ))}
            <XAxis
              dataKey="t"
              type="number"
              domain={[0, ultimoT]}
              ticks={ticksEje(ultimoT)}
              tickFormatter={minSeg}
              tick={EJE}
              axisLine={{ stroke: '#e2e8f0' }}
              tickLine={false}
            />
            <YAxis domain={dominioY} allowDecimals={false} tick={EJE} axisLine={false} tickLine={false} />
            <Tooltip
              contentStyle={{ borderRadius: 8, border: '1px solid #e2e8f0', fontSize: 13 }}
              labelFormatter={(t) => minSeg(t)}
              formatter={(v) => (v == null ? '—' : Math.round(v * 10) / 10)}
            />
            <Line type="monotone" dataKey={campo} stroke={color} strokeWidth={2} dot={false} connectNulls={false} isAnimationActive={false} />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </Card>
  );
}

export default SesionDetalle;
