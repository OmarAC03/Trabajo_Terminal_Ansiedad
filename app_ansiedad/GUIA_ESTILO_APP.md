# Guía de estilo de la app móvil — extraída del mockup HealthMonitor (mobile)

> Referencia VISUAL para el rediseño de la app Flutter (app_ansiedad/). Reproducir este look
> en Flutter, NO migrar de framework ni copiar el código del mockup. Solo el estilo. El lenguaje
> sigue siendo Normal / Elevados / Altos e "Indicadores fisiológicos", nunca los textos de
> diagnóstico del mockup. La marca es el nombre real del proyecto, NO "Health Monitor".

## 1. Paleta de colores (misma que el portal — sistema unificado)
- Fondo de pantalla: #F8FAFC
- Superficie / tarjeta: #FFFFFF
- Texto principal: #1E293B
- Texto secundario / etiquetas: #94A3B8
- Borde: #E2E8F0
- Primario (azul): #2563EB
- Azul oscuro (gradiente): #1D4ED8 / #1E40AF
- Azul suave (fondo/acento): #EFF6FF

Semáforo (con fondo suave):
- Baja → "Normal": verde #16A34A, fondo #F0FDF4
- Moderada → "Elevados": ámbar #D97706, fondo #FFFBEB
- Alta → "Altos": rojo #DC2626, fondo #FEF2F2
- Sin lectura → "Sin lecturas": gris #94A3B8, fondo #F1F5F9

## 2. Header con gradiente (patrón distintivo)
- Gradiente de #1D4ED8 (arriba-izq) a #2563EB (abajo-der).
- Ícono en cuadro translúcido blanco (fondo rgba(255,255,255,0.2), radio 16px), título blanco
  bold, subtítulo blanco al 70% de opacidad, pequeño.
- En Flutter: LinearGradient con esos dos azules.

## 3. Tipografía
- Títulos de pantalla: bold (~18–20px).
- Valor grande de métrica (BPM, HRV): ~24px, font-weight 900 (black), en color del estado o azul.
- Etiquetas de métrica: ~11–12px, bold, gris #94A3B8, MAYÚSCULAS con letter-spacing.
- Texto de ayuda/subtítulos: ~11px, gris #64748B.

## 4. Componentes clave
Tarjeta de métrica (BPM/SpO2/HRV): fondo blanco, borde #E2E8F0, radio 12px, padding 12px.
Etiqueta gris mayúsculas arriba, valor grande (24px black) en color de estado, unidad gris abajo.

Indicador de estado: NO usar "Score de ansiedad" con barra. Usar tarjeta "Indicadores
fisiológicos" con el badge del estado (Normal/Elevados/Altos) y su color, con disclaimer.

Campos de formulario (login/registro): input con ícono a la izquierda (correo → sobre,
contraseña → candado), radio 12px, borde #E2E8F0, foco anillo azul, ojo para mostrar/ocultar
contraseña. Etiqueta arriba pequeña semibold gris. Botón primario azul #2563EB, texto blanco
bold, a todo el ancho, radio 12px. Enlace "¿Olvidaste tu contraseña?" pequeño, bajo el campo.

Bottom nav: barra blanca, borde superior #E2E8F0, 4 ítems (Inicio, Historial, Mensajes, Perfil —
usar nombres reales). Inactivo gris #94A3B8, activo azul #2563EB con puntito azul debajo.

## 5. Forma general
- Radio de tarjetas/inputs: 12px
- Radio de íconos/chips: 8–16px
- Sombra: sutil (0 1px 2px rgba(0,0,0,0.05))
- Padding de tarjeta: 12–16px
- Fondo de pantalla: #F8FAFC

## 6. Alcance (obligatorio)
- Solo estilo. NO usar: "Score de ansiedad", "Sin ansiedad/Moderada/Alta" como diagnóstico,
  "Health Monitor".
- SÍ usar: "Indicadores fisiológicos", Normal/Elevados/Altos, nombre real del proyecto.
- Disclaimer en toda pantalla con datos (clase Disclaimers de app_config.dart).
- Los valores internos de la BD (Alta/Moderada/Baja) NO cambian, solo el texto visible.

## 7. Pantalla de "Alerta" del mockup = feature futura
El mockup tiene una pantalla donde el paciente elige un motivo y envía alerta al especialista.
Eso es funcionalidad NUEVA que la app no tiene hoy. NO se construye en este rediseño; queda
como feature futura. El rediseño solo cambia la apariencia de pantallas existentes.