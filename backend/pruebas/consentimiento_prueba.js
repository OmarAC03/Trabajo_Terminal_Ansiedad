// SQL que da el consentimiento VIGENTE (Bloque 1, paso 2) a las cuentas de
// paciente "PRUEBA ...". Lo agregan semilla_m3.js y semilla_gad7.js a su SQL de
// siembra: desde el paso 2, sin consentimiento POST /api/sesiones, la EVA y el
// GAD-7 dan 403, y prueba_sesiones.ps1 / prueba_gad7.ps1 fallarían.
// Idempotente (ON CONFLICT DO NOTHING): se puede pegar las veces que sea.
const { CONFIG_CONSENTIMIENTO } = require('../consentimiento');

function sqlConsentimientoPruebas() {
  return `-- Consentimiento vigente para las cuentas de paciente "PRUEBA ..." (Bloque 1).
INSERT INTO consentimientos (usuario_id, version_aviso, version_consentimiento, origen)
SELECT id, '${CONFIG_CONSENTIMIENTO.version_aviso}', '${CONFIG_CONSENTIMIENTO.version_consentimiento}', 'inicio_sesion'
FROM usuarios
WHERE rol = 'paciente' AND nombre LIKE 'PRUEBA%' AND eliminado_en IS NULL
ON CONFLICT (usuario_id, version_aviso, version_consentimiento) DO NOTHING;
`;
}

module.exports = { sqlConsentimientoPruebas };
