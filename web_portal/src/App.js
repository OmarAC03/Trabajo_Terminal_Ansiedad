import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { Activity, Heart, Wind, AlertTriangle, RefreshCw } from 'lucide-react';

const API_URL = "https://tt-ansiedad-backend.onrender.com/api/lecturas";

function App() {
  const [lecturas, setLecturas] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchData = async () => {
    try {
      const response = await axios.get(API_URL);
      setLecturas(response.data);
      setLoading(false);
    } catch (error) {
      console.error("Error al obtener datos:", error);
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 15000); // Actualiza cada 15 seg
    return () => clearInterval(interval);
  }, []);

  return (
    <div style={styles.container}>
      <header style={styles.header}>
        <h1 style={styles.title}><Activity color="#1E6AFB" size={32} /> Portal Clínico TT</h1>
        <button onClick={fetchData} style={styles.refreshBtn}>
          <RefreshCw size={20} /> Actualizar
        </button>
      </header>

      <main style={styles.main}>
        {loading ? (
          <div style={styles.center}>Cargando registros...</div>
        ) : (
          <div style={styles.grid}>
            {lecturas.map((l, index) => (
              <div key={index} style={styles.card}>
                <div style={styles.cardHeader}>
                  <span style={styles.patientId}>ID: {l.paciente_id.substring(0, 8)}</span>
                  <span style={{...styles.badge, backgroundColor: getStatusColor(l.estado_ansiedad)}}>
                    {l.estado_ansiedad}
                  </span>
                </div>
                
                <div style={styles.metrics}>
                  <div style={styles.metricItem}>
                    <Heart color="#ef4444" size={20} />
                    <strong>{l.bpm}</strong> <small>BPM</small>
                  </div>
                  <div style={styles.metricItem}>
                    <Wind color="#10b981" size={20} />
                    <strong>{l.spo2}%</strong> <small>SpO2</small>
                  </div>
                  <div style={styles.metricItem}>
                    <AlertTriangle color="#f59e0b" size={20} />
                    <strong>{l.score_ansiedad}</strong> <small>Score</small>
                  </div>
                </div>
                
                <div style={styles.cardFooter}>
                  {new Date(l.fecha_registro || l.created_at).toLocaleString()}
                </div>
              </div>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}

// Helper para colores del semáforo
const getStatusColor = (status) => {
  if (status === 'Alta') return '#ef4444';
  if (status === 'Moderada') return '#f59e0b';
  return '#10b981';
};

// Estilos básicos (CSS-in-JS para rapidez)
const styles = {
  container: { backgroundColor: '#f6f8fb', minHeight: '100vh', fontFamily: 'Segoe UI, sans-serif' },
  header: { backgroundColor: '#fff', padding: '20px 40px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', boxShadow: '0 2px 10px rgba(0,0,0,0.05)' },
  title: { display: 'flex', alignItems: 'center', gap: '12px', margin: 0, color: '#1a1a1a' },
  refreshBtn: { display: 'flex', gap: '8px', padding: '10px 20px', borderRadius: '8px', border: 'none', backgroundColor: '#1E6AFB', color: '#fff', cursor: 'pointer' },
  main: { padding: '40px' },
  grid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '20px' },
  card: { backgroundColor: '#fff', borderRadius: '15px', padding: '20px', boxShadow: '0 4px 6px rgba(0,0,0,0.02)', border: '1px solid #eee' },
  cardHeader: { display: 'flex', justifyContent: 'space-between', marginBottom: '20px' },
  patientId: { fontSize: '12px', color: '#666', fontWeight: 'bold' },
  badge: { padding: '4px 10px', borderRadius: '20px', color: '#fff', fontSize: '10px', fontWeight: 'bold' },
  metrics: { display: 'flex', justifyContent: 'space-around', marginBottom: '15px' },
  metricItem: { textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center' },
  cardFooter: { borderTop: '1px solid #f0f0f0', paddingTop: '10px', fontSize: '11px', color: '#999', textAlign: 'right' },
  center: { textAlign: 'center', marginTop: '50px', color: '#666' }
};

export default App;