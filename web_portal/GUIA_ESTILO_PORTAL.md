# Guía de estilo del portal — extraída del mockup HealthMonitor

> Referencia VISUAL para el rediseño del portal (Fase A). Estos son los valores exactos
> sacados del mockup (Next.js + Tailwind + shadcn). El objetivo es **reproducir este look en
> el portal React actual**, NO migrar de framework ni copiar el código del mockup.
> Solo se toma el estilo (colores, medidas, tipografía, espaciados), nunca los textos de
> diagnóstico del mockup ("Sin ansiedad", "Score ansiedad", etc.). El lenguaje sigue siendo
> Normal / Elevados / Altos e "Indicadores fisiológicos".

---

## 1. Paleta de colores (modo claro)

Estos son los valores hex exactos del mockup. Reemplazar/ajustar los tokens de
`web_portal/src/ui/tokens.css` con estos:

### Base
| Token | Valor | Uso |
|---|---|---|
| Fondo página | `#F8FAFC` | fondo general |
| Superficie / tarjeta | `#FFFFFF` | tarjetas, paneles |
| Texto principal | `#1E293B` | títulos y texto |
| Texto secundario / etiquetas | `#94A3B8` | labels de KPI, subtítulos |
| Texto gris medio | `#475569` / `#334155` | texto de navegación |
| Borde | `#E2E8F0` | bordes de tarjetas e inputs |

### Primario (azul)
| Token | Valor |
|---|---|
| Primario | `#2563EB` |
| Primario oscuro (hover) | `#1D4ED8` |
| Azul suave (fondo/acento) | `#EFF6FF` |
| Azul claro | `#DBEAFE` |

### Semáforo (estados) — con su fondo suave
| Estado (interno) | Etiqueta visible | Color | Fondo suave |
|---|---|---|---|
| Baja | **Normal** | verde `#16A34A` | `#F0FDF4` |
| Moderada | **Elevados** | ámbar `#D97706` | `#FFFBEB` |
| Alta | **Altos** | rojo `#DC2626` | `#FEF2F2` |
| (sin lectura) | **Sin lecturas** | gris `#94A3B8` | `#F1F5F9` |

### Colores para gráficas (dona, líneas)
| Uso | Valor |
|---|---|
| Azul (chart-1) | `#2563EB` |
| Verde (chart-2) | `#16A34A` |
| Ámbar (chart-3) | `#D97706` |
| Rojo (chart-4) | `#DC2626` |
| Azul claro (chart-5) | `#60A5FA` |

---

## 2. Tipografía

- Fuente: **Inter** (el mockup usa "Geist", pero Inter ya está cargada en el portal y es
  visualmente equivalente; mantener Inter para no agregar dependencias).
- Título de página (h1): grande y muy bold (~28–32px, font-weight 800).
- Valor grande de KPI: **~36px (text-4xl), font-weight 900** (negro/black).
- Etiqueta de KPI: ~16px, semibold, color gris `#94A3B8`.
- Etiquetas de sección del sidebar ("PRINCIPAL", "GESTIÓN"): ~12–13px, extrabold, en
  mayúsculas, con letter-spacing, color gris `#94A3B8`.

---

## 3. Medidas y forma

| Elemento | Valor |
|---|---|
| Radio general | `0.75rem` (12px) — tarjetas, botones |
| Radio de iconos/chips | `0.5rem` (8px) |
| Sombra de tarjeta | sutil: `shadow-sm` (0 1px 2px rgba(0,0,0,0.05)) |
| Padding de tarjeta | `20px` (p-5) |
| Ancho del sidebar | `240px` |
| Padding del sidebar | `20px` |

---

## 4. Componentes clave (medidas exactas del mockup)

### KPI Card (las tarjetas de arriba)
- Contenedor: fondo blanco, borde `#E2E8F0`, radio 12px, padding 20px, sombra sutil.
- Arriba: fila con la **etiqueta** a la izquierda (gris, semibold) y un **chip de icono** a la
  derecha (48×48px, radio 8px, fondo de color suave y el icono en el color fuerte).
  - Ej.: KPI "Normal" → chip verde (`bg #F0FDF4`, icono `#16A34A`).
- En medio: el **valor grande** (~36px, font-weight 900, color `#1E293B`).
- Abajo: subtítulo (ej. "58% del grupo"), gris o coloreado según el estado.
- Iconos por tipo (referencia): azul = grupo/usuarios, verde = check, ámbar = triángulo de
  atención, rojo = alerta. (Usar los iconos que tengas; lucide-react no es obligatorio.)

### Sidebar
- Ancho 240px, fondo `#F8FAFC`, borde derecho `#E2E8F0`, padding 20px, columna.
- Dos grupos con encabezado: **PRINCIPAL** y **GESTIÓN** (o CUENTA), en gris extrabold
  mayúsculas.
- Ítems: fila con icono + texto, padding 10px 12px, radio 8px, color gris `#475569`.
  - Hover: fondo gris claro `#F1F5F9`.
  - **Activo:** fondo azul suave `#EFF6FF`, texto azul `#2563EB`, bold.
- Badge opcional a la derecha del ítem: círculo/pastilla rojo `#DC2626`, texto blanco.

### Tabla de pacientes
- Encabezados de columna en gris `#94A3B8`, uppercase, pequeños.
- Cada fila: avatar de iniciales (círculo), nombre en bold + email/subtexto gris debajo.
- Columna de estado: **badge** con el color del semáforo (Normal/Elevados/Altos/Sin lecturas)
  y su fondo suave.
- Barra de indicador: barra horizontal redondeada con el color del estado (NO etiquetarla como
  "Score ansiedad" — usar "última lectura" / el badge de estado).

### Badges de estado (pastillas)
- Pastilla redondeada, texto pequeño bold, con punto de color a la izquierda.
- Color del texto = color del estado; fondo = versión suave del estado.

---

## 5. Layout general

- Fondo de página `#F8FAFC`.
- Sidebar fijo a la izquierda (240px) + área de contenido a la derecha.
- Encabezado de página arriba del contenido: título grande + subtítulo (fecha / conteo) a la
  izquierda, y acciones (botón "Actualizar", "Tu código") a la derecha.
- Fila de 4 KPI cards.
- Debajo: dos columnas → izquierda la tabla de pacientes (ancha), derecha una columna con
  panel "Últimas lecturas altas" y la dona de distribución.
- En móvil: el sidebar pasa arriba y las columnas se apilan.

---

## 6. Recordatorio de alcance (obligatorio)

- Del mockup se toma SOLO el estilo. Los textos de diagnóstico del mockup NO se usan:
  - ❌ "Sin ansiedad", "Ansiedad moderada", "Score ansiedad", "Alertas activas"
  - ✅ "Normal", "Elevados", "Altos", "Indicadores fisiológicos", "Últimas lecturas altas"
- Toda pantalla con datos del paciente lleva el disclaimer de que no es diagnóstico.
- La marca sigue siendo "Portal Clínico TT", no "HealthMonitor".
