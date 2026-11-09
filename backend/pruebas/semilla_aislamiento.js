// Cuentas PRUEBA de la prueba de aislamiento (Fase S, d). Nunca cuentas reales:
// correos @example.com (dominio reservado, no llega correo a nadie).
//   - B: paciente SIN especialista (no es el paciente A).
//   - F: especialista SIN pacientes (no es el especialista de A).
// prueba_aislamiento.ps1 las crea si no existen (Firebase + POST /api/usuarios
// o /api/especialistas en el backend LOCAL) con la contraseña que se le dé.
//
//   node pruebas/semilla_aislamiento.js verificar   SQL de solo lectura: estado de B y F
//   node pruebas/semilla_aislamiento.js limpiar     SQL que borra los mensajes de la prueba
//   node pruebas/semilla_aislamiento.js cuentas     nombres y correos (los usa el .ps1)

const CUENTAS_AISLAMIENTO = Object.freeze({
  B: Object.freeze({ nombre: 'PRUEBA - Aislamiento B', email: 'prueba.aislamiento.b@example.com', rol: 'paciente' }),
  F: Object.freeze({ nombre: 'PRUEBA - Aislamiento F', email: 'prueba.aislamiento.f@example.com', rol: 'especialista' }),
});

// Texto con que empiezan los mensajes que deja el script (en la conversación
// de A con su especialista E).
const PREFIJO_MENSAJE = 'PRUEBA aislamiento';

const correos = () => Object.values(CUENTAS_AISLAMIENTO).map((c) => `'${c.email}'`).join(', ');

function sqlVerificar() {
  return `-- Solo lectura: las cuentas de la prueba de aislamiento (Fase S).
-- Esperado: B paciente sin especialista_id; F especialista con 0 pacientes.
SELECT u.nombre, u.email, u.rol, u.especialista_id IS NOT NULL AS vinculado,
       (SELECT count(*) FROM usuarios p WHERE p.especialista_id = u.id) AS pacientes,
       u.suspendido, u.eliminado_en
FROM usuarios u
WHERE u.email IN (${correos()})
ORDER BY u.nombre;
`;
}

function sqlLimpiar() {
  return `-- Borra los mensajes que deja prueba_aislamiento.ps1 (conversación de A con E).
DELETE FROM mensajes_chat WHERE texto LIKE '${PREFIJO_MENSAJE}%';
`;
}

if (require.main === module) {
  const comando = process.argv[2];
  if (comando === 'verificar') process.stdout.write(sqlVerificar());
  else if (comando === 'limpiar') process.stdout.write(sqlLimpiar());
  else if (comando === 'cuentas') process.stdout.write(JSON.stringify(CUENTAS_AISLAMIENTO, null, 2) + '\n');
  else {
    process.stderr.write('Uso: node pruebas/semilla_aislamiento.js verificar|limpiar|cuentas\n');
    process.exit(1);
  }
}

module.exports = { CUENTAS_AISLAMIENTO, PREFIJO_MENSAJE, sqlVerificar, sqlLimpiar };
