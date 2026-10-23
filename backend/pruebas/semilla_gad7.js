// Semilla de respuestas GAD-7 (Fase M5a) para la cuenta de pruebas
// "PRUEBA - Test M3", para ver el historial en el portal sin esperar semanas.
// Mismo diseño que semilla_m3.js: una sola fuente de datos (SEMILLA) para el
// SQL que se pega en Supabase y para la demo local.
//
//   node pruebas/semilla_gad7.js sql       SQL de inserción (se niega si la cuenta ya tiene GAD-7)
//   node pruebas/semilla_gad7.js limpiar   SQL que borra TODOS los GAD-7 de la cuenta de pruebas
//   node pruebas/semilla_gad7.js demo      lo que vería el especialista (sin tocar la base)
//
// Se inserta por SQL porque POST /api/gad7 no deja poner fechas pasadas. La
// última es de hace 16 días: hoy le toca responder (lo que espera
// prueba_gad7.ps1). Trayectoria que mejora: grave → moderada → leve → mínima.

const { CONFIG_GAD7 } = require('../gad7');
const { vistaGad7 } = require('../gad7_vista');

const NOMBRE_CUENTA = 'PRUEBA - Test M3';
const ZONA = CONFIG_GAD7.zonaHoraria;

// dias_atras, hora local, ítems 1–7 (0–3), dificultad (0–3 o null).
const SEMILLA = [
  { dias_atras: 58, hora: '20:10', items: [3, 2, 3, 2, 2, 2, 2], dificultad: 3, nota: '16 → grave (valorar)' },
  { dias_atras: 44, hora: '19:45', items: [2, 2, 2, 1, 2, 2, 1], dificultad: 2, nota: '12 → moderada (valorar)' },
  { dias_atras: 30, hora: '21:05', items: [1, 1, 2, 1, 1, 1, 1], dificultad: 1, nota: '8 → leve' },
  { dias_atras: 16, hora: '20:30', items: [1, 1, 1, 0, 0, 1, 0], dificultad: null, nota: '4 → mínima' },
];

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

function sqlSemilla() {
  const valores = SEMILLA.map((g) => {
    const fecha = `((date_trunc('day', now() AT TIME ZONE '${ZONA}') - interval '${g.dias_atras} days'`
      + ` + interval '${g.hora}') AT TIME ZONE '${ZONA}')`;
    return `    (pid, ${g.items.join(', ')}, ${g.dificultad === null ? 'NULL' : g.dificultad}, '${CONFIG_GAD7.version}', ${fecha})`;
  });
  return `-- Semilla GAD-7 (${valores.length} respuestas) para "${NOMBRE_CUENTA}".
-- Generado por backend/pruebas/semilla_gad7.js. Se niega si la cuenta ya tiene GAD-7.
BEGIN;

DO $$
DECLARE
  pid varchar;
  n_cuentas int;
  n_previas int;
  n_insertadas int;
BEGIN
${BUSCAR_CUENTA}
  SELECT count(*) INTO n_previas FROM respuestas_gad7 WHERE paciente_id = pid;
  IF n_previas > 0 THEN
    RAISE EXCEPTION 'La cuenta de pruebas ya tiene % GAD-7: corre primero el SQL de "limpiar".', n_previas;
  END IF;

  INSERT INTO respuestas_gad7 (
    paciente_id, item1, item2, item3, item4, item5, item6, item7, dificultad, version, fecha_respuesta
  ) VALUES
${valores.join(',\n')};
  GET DIAGNOSTICS n_insertadas = ROW_COUNT;

  RAISE NOTICE 'OK: % GAD-7 sembrados en la cuenta de pruebas.', n_insertadas;
END $$;

COMMIT;
`;
}

function sqlLimpiar() {
  return `-- Borra TODOS los GAD-7 de "${NOMBRE_CUENTA}" y de nadie más (sus sesiones no se tocan).
-- Generado por backend/pruebas/semilla_gad7.js.
BEGIN;

DO $$
DECLARE
  pid varchar;
  n_cuentas int;
  n_gad7 int;
BEGIN
${BUSCAR_CUENTA}
  DELETE FROM respuestas_gad7 WHERE paciente_id = pid;
  GET DIAGNOSTICS n_gad7 = ROW_COUNT;

  RAISE NOTICE 'OK: % GAD-7 borrados de la cuenta de pruebas.', n_gad7;
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

function demo() {
  const ahora = new Date();
  // Filas con la misma forma que devuelve pg (smallint como número).
  const filas = SEMILLA.map((g, i) => {
    const f = {
      id: `semilla-${i + 1}`,
      fecha_respuesta: fechaRelativa(g.dias_atras, g.hora, ahora),
      version: CONFIG_GAD7.version,
      dificultad: g.dificultad,
    };
    g.items.forEach((v, k) => { f[`item${k + 1}`] = v; });
    return f;
  });
  const v = vistaGad7(filas, true, true, ahora);
  console.log(`Demo GAD-7 ${CONFIG_GAD7.version} — hoy ${new Intl.DateTimeFormat('en-CA', { timeZone: ZONA }).format(ahora)} (${ZONA})`);
  console.table(v.respuestas.map((r) => ({
    fecha_local: new Intl.DateTimeFormat('en-CA', { timeZone: ZONA }).format(new Date(r.fecha_respuesta)),
    items: r.items.join(' '),
    puntaje: r.puntaje,
    severidad: r.severidad,
    valorar: r.valorar ? 'sí' : 'no',
    dificultad: r.dificultad ?? '—',
  })));
  console.log('Estado de hoy (lo mismo que recibe el paciente):', v.estado);
}

const [comando] = process.argv.slice(2);
if (comando === 'sql') process.stdout.write(sqlSemilla());
else if (comando === 'limpiar') process.stdout.write(sqlLimpiar());
else if (comando === 'demo') demo();
else {
  console.error('Uso: node pruebas/semilla_gad7.js sql | limpiar | demo');
  process.exit(1);
}
