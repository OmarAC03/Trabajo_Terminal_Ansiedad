import { useState } from 'react';
import { KeyRound, Copy, Check } from 'lucide-react';

// Barra visible con el codigo_vinculacion fijo del especialista logueado,
// para que lo pueda compartir con sus pacientes (Fase D, ver CONTEXTO_PROYECTO.md).
function CodigoVinculacion({ codigo }) {
  const [copiado, setCopiado] = useState(false);

  if (!codigo) return null;

  const copiar = async () => {
    try {
      await navigator.clipboard.writeText(codigo);
      setCopiado(true);
      setTimeout(() => setCopiado(false), 2000);
    } catch (error) {
      console.error('No se pudo copiar el código:', error);
    }
  };

  return (
    <div style={styles.container}>
      <KeyRound size={16} color="#1E6AFB" />
      <span style={styles.label}>Tu código de vinculación:</span>
      <span style={styles.codigo}>{codigo}</span>
      <button onClick={copiar} style={styles.boton} title="Copiar código">
        {copiado ? <Check size={14} color="#10b981" /> : <Copy size={14} color="#1E6AFB" />}
        {copiado ? 'Copiado' : 'Copiar'}
      </button>
    </div>
  );
}

const styles = {
  container: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    backgroundColor: '#eef4ff',
    border: '1px solid #d6e4ff',
    borderRadius: '10px',
    padding: '10px 20px',
    margin: '0 40px',
    fontSize: '13px',
    color: '#1a1a1a',
    width: 'fit-content',
  },
  label: { color: '#555' },
  codigo: { fontWeight: 'bold', letterSpacing: '2px', fontFamily: 'monospace', fontSize: '14px' },
  boton: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
    marginLeft: '6px',
    padding: '4px 10px',
    borderRadius: '6px',
    border: 'none',
    backgroundColor: '#fff',
    color: '#1E6AFB',
    cursor: 'pointer',
    fontSize: '12px',
  },
};

export default CodigoVinculacion;
