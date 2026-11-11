import { Info } from 'lucide-react';
import { LEMA, NOMBRE_APP, NOMBRE_MASCOTA } from './marca';
import { PARRAFOS_ACERCA, PIE_ACERCA, TITULO_ACERCA } from './acerca';
import { Card, Disclaimer, PageHeader } from './ui/components';
import escudoEscom from './ui/escudo_escom.png';
import escudoIpn from './ui/escudo_ipn.png';
import mascota from './ui/avatar_saludando.png';

// "Acerca del proyecto" en el portal (versión final, Fase 2): el mismo texto
// que la app, con los escudos de la ESCOM y del IPN. Sin datos técnicos.
function AcercaProyecto() {
  return (
    <div className="ui-page">
      <PageHeader title="Acerca del proyecto" subtitle={`${NOMBRE_APP} · ${LEMA}`} />
      <Card>
        <div className="ui-acerca-escudos">
          <img src={escudoIpn} alt="Escudo del IPN" />
          <img src={escudoEscom} alt="Escudo de la ESCOM" />
        </div>
        <h2 className="ui-acerca-titulo">{TITULO_ACERCA}</h2>
        <div className="ui-acerca-texto">
          {PARRAFOS_ACERCA.map((p) => <p key={p.slice(0, 24)}>{p}</p>)}
        </div>
        <div className="ui-acerca-pie">
          <span className="ui-brand-mascota"><img src={mascota} alt={NOMBRE_MASCOTA} /></span>
          <span>{PIE_ACERCA}</span>
        </div>
      </Card>
      <div style={{ marginTop: 20 }}>
        <Disclaimer icon={Info}>
          {NOMBRE_APP} muestra parámetros fisiológicos asociados a la ansiedad como apoyo al especialista. No emite
          diagnósticos: la interpretación clínica corresponde al profesional de salud.
        </Disclaimer>
      </div>
    </div>
  );
}

export default AcercaProyecto;
