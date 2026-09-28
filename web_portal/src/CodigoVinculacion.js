import { useState } from 'react';
import { KeyRound, Copy, Check } from 'lucide-react';
import { Button } from './ui/components';

// Botón con el codigo_vinculacion fijo del especialista logueado, para que lo
// pueda compartir con sus pacientes (Fase D, ver CONTEXTO_PROYECTO.md). Vive
// en las acciones del encabezado de página (Fase A); un clic lo copia.
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
    <Button variant="secondary" icon={KeyRound} onClick={copiar} title="Copiar tu código de vinculación">
      Tu código: <span className="ui-mono" style={{ color: 'var(--color-primary)', fontWeight: 700 }}>{codigo}</span>
      {copiado ? <Check size={16} color="var(--color-normal)" /> : <Copy size={16} />}
    </Button>
  );
}

export default CodigoVinculacion;
