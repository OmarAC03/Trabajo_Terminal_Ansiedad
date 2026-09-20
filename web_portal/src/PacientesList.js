import { Users, Heart } from 'lucide-react';

// Helper para colores del semáforo (mismo criterio que backend/app_ansiedad).
const getStatusColor = (status) => {
  if (status === 'Alta') return '#ef4444';
  if (status === 'Moderada') return '#f59e0b';
  if (status === 'Baja') return '#10b981';
  return '#9ca3af'; // sin lecturas aún
};

function PacientesList({ pacientes }) {
  if (pacientes.length === 0) {
    return (
      <div style={styles.empty}>
        <Users size={32} color="#9ca3af" />
        <p>Todavía no hay pacientes registrados.</p>
      </div>
    );
  }

  return (
    <div style={styles.grid}>
      {pacientes.map((p) => (
        <div key={p.id} style={styles.card}>
          <div style={styles.cardHeader}>
            <span style={styles.nombre}>{p.nombre}</span>
            <span style={{ ...styles.badge, backgroundColor: getStatusColor(p.ultimo_estado) }}>
              {p.ultimo_estado || 'Sin datos'}
            </span>
          </div>
          <div style={styles.email}>{p.email}</div>
          <div style={styles.cardFooter}>
            <Heart size={14} color="#999" />
            {p.ultima_lectura
              ? `Última lectura: ${new Date(p.ultima_lectura).toLocaleString()}`
              : 'Sin lecturas registradas'}
          </div>
        </div>
      ))}
    </div>
  );
}

const styles = {
  grid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: '20px' },
  card: { backgroundColor: '#fff', borderRadius: '15px', padding: '20px', boxShadow: '0 4px 6px rgba(0,0,0,0.02)', border: '1px solid #eee' },
  cardHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '10px', marginBottom: '8px' },
  nombre: { fontSize: '16px', fontWeight: 'bold', color: '#1a1a1a' },
  badge: { padding: '4px 10px', borderRadius: '20px', color: '#fff', fontSize: '10px', fontWeight: 'bold', whiteSpace: 'nowrap' },
  email: { fontSize: '13px', color: '#666', marginBottom: '15px' },
  cardFooter: { display: 'flex', alignItems: 'center', gap: '6px', borderTop: '1px solid #f0f0f0', paddingTop: '10px', fontSize: '11px', color: '#999' },
  empty: { textAlign: 'center', marginTop: '60px', color: '#666', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '10px' },
};

export default PacientesList;
