// Semilla de sesiones para probar la línea base (Fase M3) en la cuenta de
// pruebas "PRUEBA - Test M3", sin esperar días reales. Una sola fuente de
// datos (SEMILLA) para el SQL que se pega en Supabase y para la demo local.
//
//   node pruebas/semilla_m3.js sql [--dias N]   SQL de inserción (N = días más
//                                                recientes a sembrar; todos si se omite)
//   node pruebas/semilla_m3.js limpiar          SQL que borra TODO lo de la cuenta de pruebas
//   node pruebas/semilla_m3.js demo [--dias N]  evalúa la semilla con linea_base.js
//
// Se inserta por SQL porque POST /api/sesiones rechaza fecha_inicio de más de
// 7 días y la base consolidada necesita más. Los valores varían día a día
// (no repiten la huella fija de prueba_sesiones.ps1). Fechas relativas a hoy,
// en hora de México; hoy no se siembra, para medir con la app.

const { CONFIG_LINEA_BASE, evaluarSesiones, progresoCalibracion } = require('../linea_base');

const NOMBRE_CUENTA = 'PRUEBA - Test M3';
const ZONA = CONFIG_LINEA_BASE.zonaHoraria;
const VALIDOS_SEG = 180; // lo que junta la app antes de terminar

// dias_atras, hora local, RMSSD (ms), FC promedio, SpO2 promedio, calidad.
const SEMILLA = [
  { dias_atras: 11, hora: '08:10', hrv: 48.2, bpm: 71.4, spo2: 97.6, calidad: 0.947 },
  { dias_atras: 10, hora: '08:25', hrv: 44.6, bpm: 73.0, spo2: 97.2, calidad: 0.900 },
  { dias_atras: 9, hora: '07:55', hrv: 51.3, bpm: 69.8, spo2: 98.1, calidad: 0.973 },
  { dias_atras: 8, hora: '08:05', hrv: 46.9, bpm: 72.1, spo2: 97.4, calidad: 0.918 },
  { dias_atras: 8, hora: '19:40', hrv: 43.1, bpm: 74.5, spo2: 97.0, calidad: 0.857, nota: '2.ª del mismo día' },
  { dias_atras: 7, hora: '08:15', hrv: 39.8, bpm: 76.2, spo2: 96.8, calidad: 0.882 },
  { dias_atras: 6, hora: '08:00', hrv: 49.5, bpm: 70.6, spo2: 97.9, calidad: 0.964 },
  { dias_atras: 5, hora: '08:20', hrv: 45.7, bpm: 72.8, spo2: 97.3, calidad: 0.927 },
  { dias_atras: 5, hora: '13:30', hrv: 28.0, bpm: 84.0, spo2: 97.1, calidad: 0.450, nota: 'calidad baja' },
  { dias_atras: 4, hora: '08:10', hrv: 33.5, bpm: 80.9, spo2: 97.0, calidad: 0.896, nota: 'por debajo' },
  { dias_atras: 3, hora: '08:05', hrv: 47.8, bpm: 71.2, spo2: 97.5, calidad: 0.938 },
  { dias_atras: 3, hora: '08:30', hrv: 61.0, bpm: 66.0, spo2: 98.0, calidad: 0.950, origen: 'sensor', nota: 'origen sensor' },
  { dias_atras: 2, hora: '08:15', hrv: 24.0, bpm: 88.0, spo2: 96.9, calidad: 0.910, nota: 'muy por debajo + FC alta' },
  { dias_atras: 1, hora: '08:00', hrv: 50.4, bpm: 70.1, spo2: 97.7, calidad: 0.952 },
];

const r1 = (v) => Math.round(v * 10) / 10;

// Sesión completa (resumen + serie de 36 puntos cada 5 s) coherente con
// validarSesion y los CHECK de la tabla.
function armarSesion(f) {
  const total = Math.round(VALIDOS_SEG / f.calidad);
  const serie = [];
  for (let i = 0; i < 36; i++) {
    serie.push({
      t: i * 5,
      bpm: r1(f.bpm + 2.5 * Math.sin(i * 0.9)),
      spo2: Math.round(f.spo2 + 0.6 * Math.sin(i * 0.5)),
      hrv: r1(f.hrv * (1 + 0.18 * Math.sin(i * 0.7 + 1))),
    });
  }
  const col = (k) => serie.map((p) => p[k]);
  return {
    ...f,
    origen: f.origen || 'simulacion',
    duracion_total_seg: total,
    duracion_valida_seg: VALIDOS_SEG,
    indice_calidad: Math.round((VALIDOS_SEG / total) * 1000) / 1000,
    hrv_min: Math.min(...col('hrv')),
    hrv_max: Math.max(...col('hrv')),
    bpm_min: Math.min(Math.floor(f.bpm), Math.floor(Math.min(...col('bpm')))),
    bpm_max: Math.max(Math.ceil(f.bpm), Math.ceil(Math.max(...col('bpm')))),
    spo2_min: Math.min(Math.floor(f.spo2), ...col('spo2')),
    spo2_max: Math.max(Math.ceil(f.spo2), ...col('spo2')),
    serie,
  };
}

function filas(dias) {
  return SEMILLA.filter((f) => dias === null || f.dias_atras <= dias).map(armarSesion);
}

// Encuentra la cuenta de pruebas y se niega a seguir si no es exactamente una
// o si su especialista no es de pruebas (así nunca toca un Dashboard real).
const BUSCAR_CUENTA = `
  SELECT count(*) INTO n_cuentas FROM usuarios
  WHERE nombre = '${NOMBRE_CUENTA}' AND rol = 'paciente';
  IF n_cuentas <> 1 THEN
    RAISE EXCEPTION 'Esperaba 1 cuenta "${NOMBRE_CUENTA}", hay %.', n_cuentas;
  END IF;
  SELECT u.id INTO pid FROM usuarios u
  JOIN usuarios esp ON esp.id = u.especialista_id
  WHERE u.nombre = '${NOMBRE_CUENTA}' AND u.rol = 'paciente'
    AND esp.rol = 'especialista' AND esp.nombre LIKE 'PRUEBA%';
  IF pid IS NULL THEN
    RAISE EXCEPTION 'La cuenta de pruebas no está vinculada a un especialista "PRUEBA ...".';
  END IF;`;

function sqlSemilla(dias) {
  const valores = filas(dias).map((s) => {
    const fecha = `((date_trunc('day', now() AT TIME ZONE '${ZONA}') - interval '${s.dias_atras} days'`
      + ` + interval '${s.hora}') AT TIME ZONE '${ZONA}')`;
    return `    (pid, ${fecha}, ${s.duracion_total_seg}, ${s.duracion_valida_seg},
     ${s.hrv}, ${s.hrv_min}, ${s.hrv_max}, ${s.bpm}, ${s.bpm_min}, ${s.bpm_max},
     ${s.spo2}, ${s.spo2_min}, ${s.spo2_max}, ${s.indice_calidad},
     '${JSON.stringify(s.serie)}'::jsonb, '${s.origen}')`;
  });
  return `-- Semilla M3 (${valores.length} sesiones${dias === null ? '' : `, últimos ${dias} días`}) para "${NOMBRE_CUENTA}".
-- Generado por backend/pruebas/semilla_m3.js. Se niega si la cuenta ya tiene sesiones.
BEGIN;

DO $$
DECLARE
  pid varchar;
  n_cuentas int;
  n_previas int;
  n_insertadas int;
BEGIN
${BUSCAR_CUENTA}
  SELECT count(*) INTO n_previas FROM sesiones_medicion WHERE paciente_id = pid;
  IF n_previas > 0 THEN
    RAISE EXCEPTION 'La cuenta de pruebas ya tiene % sesiones: corre primero el SQL de "limpiar".', n_previas;
  END IF;

  INSERT INTO sesiones_medicion (
    paciente_id, fecha_inicio, duracion_total_seg, duracion_valida_seg,
    hrv_rmssd, hrv_min, hrv_max, bpm_promedio, bpm_min, bpm_max,
    spo2_promedio, spo2_min, spo2_max, indice_calidad, serie, origen
  ) VALUES
${valores.join(',\n')};
  GET DIAGNOSTICS n_insertadas = ROW_COUNT;

  RAISE NOTICE 'OK: % sesiones sembradas en la cuenta de pruebas.', n_insertadas;
END $$;

COMMIT;
`;
}

function sqlLimpiar() {
  return `-- Borra TODAS las sesiones (y sus EVAs) de "${NOMBRE_CUENTA}" y de nadie más.
-- Generado por backend/pruebas/semilla_m3.js.
BEGIN;

DO $$
DECLARE
  pid varchar;
  n_cuentas int;
  n_eva int;
  n_ses int;
BEGIN
${BUSCAR_CUENTA}
  DELETE FROM respuestas_eva
  WHERE sesion_id IN (SELECT id FROM sesiones_medicion WHERE paciente_id = pid);
  GET DIAGNOSTICS n_eva = ROW_COUNT;

  DELETE FROM sesiones_medicion WHERE paciente_id = pid;
  GET DIAGNOSTICS n_ses = ROW_COUNT;

  RAISE NOTICE 'OK: % sesiones y % EVAs borradas de la cuenta de pruebas.', n_ses, n_eva;
END $$;

COMMIT;
`;
}

// Fecha ISO de "hace N días a la hora local H" (México es UTC−6 todo el año).
function fechaRelativa(diasAtras, hora, ahora) {
  const hoy = new Intl.DateTimeFormat('en-CA', { timeZone: ZONA }).format(ahora);
  const d = new Date(`${hoy}T${hora}:00-06:00`);
  d.setUTCDate(d.getUTCDate() - diasAtras);
  return d.toISOString();
}

function demo(dias) {
  const ahora = new Date();
  // Filas con la misma forma que devuelve pg (numeric como string).
  const sesiones = filas(dias).map((s, i) => ({
    id: `semilla-${i + 1}`,
    fecha_inicio: fechaRelativa(s.dias_atras, s.hora, ahora),
    origen: s.origen,
    hrv_rmssd: String(s.hrv),
    bpm_promedio: String(s.bpm),
    indice_calidad: String(s.indice_calidad),
    dias_atras: s.dias_atras,
    hora: s.hora,
    nota: s.nota || '',
  }));

  const f2 = (v) => (v == null ? '—' : v.toFixed(2));
  const tabla = evaluarSesiones(sesiones).map((r, i) => {
    const s = sesiones[i];
    const b = r.linea_base;
    return {
      dia: `${r.dia} ${s.hora}`,
      origen: r.origen,
      rmssd: Number(s.hrv_rmssd),
      fc: Number(s.bpm_promedio),
      calidad: Number(s.indice_calidad),
      dias_base: b.n,
      etapa: b.etapa,
      k1: b.k1 == null ? '—' : f2(b.k1),
      rango_ms: b.rango_hrv_ms ? `${b.rango_hrv_ms.min.toFixed(1)}–${b.rango_hrv_ms.max.toFixed(1)}` : '—',
      z: f2(r.z),
      estado: r.estado || `(${r.motivo_sin_estado})`,
      fc_encima: r.fc_por_encima == null ? '—' : (r.fc_por_encima ? 'sí' : 'no'),
      nota: s.nota,
    };
  });
  console.log(`Demo línea base ${CONFIG_LINEA_BASE.version} — hoy ${new Intl.DateTimeFormat('en-CA', { timeZone: ZONA }).format(ahora)} (${ZONA})`);
  console.table(tabla);

  console.log('Progreso de calibración HOY (antes de medir), según cuántos días se siembren:');
  // Sin sesiones de hoy, la base de "la próxima medición" es la misma que
  // usaría una medición hecha hoy.
  console.table([0, 1, 2, 3, 6, 11].map((n) => {
    const p = progresoCalibracion(sesiones.filter((s) => s.dias_atras <= n), 'simulacion', ahora);
    return {
      sembrar_dias: n,
      dias_con_medicion: p.dias_con_medicion,
      medir_hoy_seria_dia: p.dias_con_medicion + 1,
      etapa_al_medir_hoy: p.etapa,
      dias_en_base: p.dias_en_base,
    };
  }));
}

function leerDias(args) {
  const i = args.indexOf('--dias');
  if (i === -1) return null;
  const n = Number(args[i + 1]);
  if (!Number.isInteger(n) || n < 0) throw new Error('--dias debe ser un entero ≥ 0');
  return n;
}

const [comando, ...args] = process.argv.slice(2);
if (comando === 'sql') process.stdout.write(sqlSemilla(leerDias(args)));
else if (comando === 'limpiar') process.stdout.write(sqlLimpiar());
else if (comando === 'demo') demo(leerDias(args));
else {
  console.error('Uso: node pruebas/semilla_m3.js sql [--dias N] | limpiar | demo [--dias N]');
  process.exit(1);
}
