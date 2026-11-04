// Bitácora en el portal del admin (Bloque 2, paso 1: WEB-RF-31 / RNF-WEB-05).
// Funciones puras, sin React ni red: se prueban con Jest (bitacora.test.js).
// Las filas vienen de GET /api/admin/bitacora: quién, qué acción, sobre quién
// y cuándo; nunca contenido clínico (lo garantiza backend/bitacora.js).

// Mismas acciones que el CHECK de la tabla, en el orden del filtro.
export const ACCIONES = {
  acceso_datos_clinicos: { etiqueta: 'Acceso a datos clínicos', tone: 'neutral' },
  exportacion: { etiqueta: 'Exportación de reporte', tone: 'primary' },
  nota_creada: { etiqueta: 'Nota creada', tone: 'neutral' },
  nota_editada: { etiqueta: 'Nota editada', tone: 'neutral' },
  marcador_creado: { etiqueta: 'Marcador creado', tone: 'neutral' },
  marcador_eliminado: { etiqueta: 'Marcador eliminado', tone: 'elevados' },
  vinculacion: { etiqueta: 'Vinculación', tone: 'primary' },
  desvinculacion: { etiqueta: 'Desvinculación', tone: 'elevados' },
  cuenta_suspendida: { etiqueta: 'Cuenta suspendida', tone: 'elevados' },
  cuenta_reactivada: { etiqueta: 'Cuenta reactivada', tone: 'normal' },
  cuenta_eliminada: { etiqueta: 'Cuenta eliminada', tone: 'altos' },
};

const RECURSOS = {
  lecturas: 'lecturas',
  sesiones: 'sesiones de medición',
  linea_base: 'línea base',
  gad7: 'GAD-7',
  mensajes: 'mensajes',
  ejercicios: 'ejercicios',
  notas: 'notas clínicas',
  marcadores: 'marcadores',
};

const ROLES = { paciente: 'Paciente', especialista: 'Especialista', admin: 'Administrador' };

export const textoAccion = (accion) => ACCIONES[accion]?.etiqueta || accion;
export const toneAccion = (accion) => ACCIONES[accion]?.tone || 'neutral';
export const textoRol = (rol) => ROLES[rol] || rol || '';

/**
 * Nombre que se muestra para un uid: el de la fila (lo trae el backend), si
 * no el de la lista de usuarios (`nombres`: Map uid → nombre), y si no el uid
 * recortado (una cuenta borrada a mano ya no tiene fila).
 */
export function nombreDe(uid, nombreFila, nombres) {
  if (!uid) return '—';
  return nombreFila || nombres?.get(uid) || `${uid.slice(0, 8)}…`;
}

/**
 * Una línea legible con el `detalle` de la entrada. Solo usa las claves que
 * la bitácora admite; cualquier otra se ignora (no se muestra lo que no se
 * espera).
 */
export function textoDetalle(fila, nombres) {
  const d = fila.detalle || {};
  const via = d.via === 'admin' ? ' (por el administrador)' : d.via === 'codigo' ? ' (con código)' : '';
  switch (fila.accion) {
    case 'acceso_datos_clinicos':
      return RECURSOS[d.recurso] ? `Consultó ${RECURSOS[d.recurso]}` : '';
    case 'exportacion': {
      const partes = [String(d.formato || '').toUpperCase(), d.seudonimizado ? 'seudonimizado' : 'con identificación'];
      if (d.desde || d.hasta) partes.push(`${d.desde || '…'} a ${d.hasta || '…'}`);
      return partes.filter(Boolean).join(' · ');
    }
    case 'nota_editada':
      return d.version ? `Versión ${d.version}` : '';
    case 'vinculacion':
      return d.especialista_anterior
        ? `De ${nombreDe(d.especialista_anterior, null, nombres)} a ${nombreDe(d.especialista_nuevo, null, nombres)}${via}`
        : `Con ${nombreDe(d.especialista_nuevo, null, nombres)}${via}`;
    case 'desvinculacion':
      return `De ${nombreDe(d.especialista_anterior, null, nombres)}${via}`;
    default:
      return '';
  }
}

/**
 * Parámetros de GET /api/admin/bitacora a partir de los filtros del
 * formulario. Solo manda lo que tiene valor; `antesDe` es el cursor de
 * "Cargar más".
 */
export function parametrosConsulta({ desde, hasta, usuario, accion } = {}, antesDe = null) {
  const params = {};
  if (desde) params.desde = desde;
  if (hasta) params.hasta = hasta;
  if (usuario) params.usuario = usuario;
  if (accion) params.accion = accion;
  if (antesDe) params.antes_de = String(antesDe);
  return params;
}

/** El rango es válido si falta alguna fecha o si `desde` no pasa de `hasta`. */
export const rangoValido = ({ desde, hasta } = {}) => !desde || !hasta || desde <= hasta;
