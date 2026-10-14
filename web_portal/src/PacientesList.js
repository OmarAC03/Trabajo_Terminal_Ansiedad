import { useState } from 'react';
import { Search } from 'lucide-react';
import { PageHeader, Card } from './ui/components';
import { plural, AccionesEncabezado, AvisosPacientes, TablaPacientes } from './PacientesComun';
import { FILTROS_ACTIVIDAD, coincideFiltroActividad } from './actividad';

// Sección "Pacientes" (Fase A): la tabla completa a todo el ancho, en orden
// alfabético (como la devuelve GET /api/pacientes), con búsqueda por nombre o
// email y filtro por actividad de medición (el filtro por estado del semáforo
// viejo se retiró). Filtra en el navegador; no pide nada nuevo.

// Minúsculas y sin acentos, para que "maria" encuentre "María".
const normalizar = (texto) =>
  (texto || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

function PacientesList({ pacientes, loading, perfil, errorAcceso, onSeleccionar, onActualizar }) {
  const [busqueda, setBusqueda] = useState('');
  const [filtro, setFiltro] = useState(null);

  const termino = normalizar(busqueda.trim());
  const visibles = pacientes.filter(
    (p) =>
      coincideFiltroActividad(p, filtro) &&
      (termino === '' || normalizar(p.nombre).includes(termino) || normalizar(p.email).includes(termino))
  );
  const hayFiltro = termino !== '' || filtro !== null;

  const filtros = (
    <div className="ui-table-toolbar">
      <label className="ui-search">
        <Search size={16} />
        <span className="sr-only">Buscar paciente</span>
        <input
          type="search"
          className="ui-input"
          placeholder="Buscar por nombre o email"
          value={busqueda}
          onChange={(e) => setBusqueda(e.target.value)}
        />
      </label>
      <div className="ui-segmented" role="group" aria-label="Filtrar por actividad">
        {FILTROS_ACTIVIDAD.map((f) => (
          <button
            key={String(f.clave)}
            type="button"
            className={`ui-segmented-item${filtro === f.clave ? ' is-active' : ''}`}
            aria-pressed={filtro === f.clave}
            onClick={() => setFiltro(f.clave)}
          >
            {f.texto}
          </button>
        ))}
      </div>
    </div>
  );

  return (
    <div className="ui-page ui-page-wide">
      <PageHeader
        title="Pacientes"
        subtitle={plural(pacientes.length, 'paciente vinculado', 'pacientes vinculados')}
        actions={<AccionesEncabezado perfil={perfil} onActualizar={onActualizar} />}
      />

      <AvisosPacientes errorAcceso={errorAcceso} />

      {loading ? (
        <Card><div className="ui-empty">Cargando pacientes…</div></Card>
      ) : (
        <TablaPacientes
          pacientes={visibles}
          onSeleccionar={onSeleccionar}
          subtitle={
            hayFiltro
              ? `${plural(visibles.length, 'resultado', 'resultados')} de ${pacientes.length} · se actualiza cada 15 s`
              : 'En orden alfabético · se actualiza cada 15 s'
          }
          vacio={
            pacientes.length === 0
              ? 'Todavía no tienes pacientes vinculados. Comparte tu código para que se vinculen desde la app.'
              : 'Ningún paciente coincide con la búsqueda o el filtro.'
          }
          filtros={pacientes.length > 0 && filtros}
        />
      )}
    </div>
  );
}

export default PacientesList;
