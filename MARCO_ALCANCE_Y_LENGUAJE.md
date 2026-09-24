# Marco de alcance y lenguaje — Sistema de Ansiedad

> Documento de referencia para alinear TODAS las interfaces (app móvil + portal web) con el
> enfoque correcto del proyecto. Pásalo a Claude Code para aplicar los cambios de forma
> consistente. También sirve como fundamento para la tesis y para responder al jurado.

---

## 1. El enfoque correcto del proyecto

El sistema es un **monitoreo de parámetros fisiológicos asociados a la ansiedad, como apoyo al
especialista.**

- **Qué SÍ hace:** captura y muestra parámetros fisiológicos (BPM, SpO2, HRV) medidos por el
  sensor, para que el especialista los consulte.
- **Qué NO hace:** NO diagnostica ansiedad. NO reemplaza al profesional de salud. NO toma
  decisiones clínicas. La interpretación de los datos corresponde siempre al especialista.

Fundamento: BPM, SpO2 y HRV son correlatos fisiológicos que **pueden** asociarse a estados de
activación (incluida la ansiedad), pero su interpretación requiere criterio profesional y
contexto clínico. La herramienta provee el dato; el especialista provee el juicio.

---

## 2. Cambio de lenguaje (lo que el usuario VE)

Importante: cambiar SOLO los textos e etiquetas visibles. NO cambiar los nombres internos de la
base de datos ni de los campos del backend (`score_ansiedad`, `estado_ansiedad`, etc.) — eso
rompería el sistema. La columna sigue llamándose `estado_ansiedad` por dentro; el usuario ve
otro texto.

### Semáforo / niveles
Reemplazar en la interfaz:
- Título "Nivel de Ansiedad" → **"Indicadores fisiológicos"**
- Valores mostrados:
  - "Baja" → **"Normal"**
  - "Moderada" → **"Elevados"**
  - "Alta" → **"Altos"**

Los colores se mantienen (Normal=verde/teal, Elevados=naranja, Altos=rojo).

### Otros textos a revisar
- Donde diga "detecta ansiedad", "tu nivel de ansiedad", o similar → reformular a "indicadores
  fisiológicos" o "parámetros medidos".
- En Historial: "Tendencia de ansiedad" → "Tendencia de indicadores fisiológicos" (o similar).
- Mantener la palabra "ansiedad" solo cuando esté correctamente enmarcada (ej. "parámetros
  asociados a la ansiedad"), nunca como afirmación de diagnóstico.

---

## 3. Disclaimers visibles (en TODAS las interfaces)

Agregar un aviso claro en los puntos donde se muestran los datos:

### App móvil
- **Monitor (AlertaScreen):** un aviso breve visible, ej.:
  *"Estos son parámetros fisiológicos, no un diagnóstico. Consulta a tu especialista."*
- **Historial:** nota al pie o en el encabezado:
  *"Datos de apoyo. La interpretación corresponde a tu especialista."*
- **Perfil o pantalla de inicio:** una nota sobre el alcance de la herramienta.

### Portal web (especialista)
- **Detalle del paciente:** aviso visible, ej.:
  *"Datos fisiológicos de apoyo. La interpretación y el diagnóstico corresponden al profesional
  de salud."*
- **Lista de pacientes / header:** una nota general del alcance del sistema.

El disclaimer debe ser visible pero no invasivo (un banner discreto, texto en gris, o una nota
al pie de la sección de datos).

---

## 4. Regla general para futuras pantallas

Toda pantalla nueva que muestre datos del paciente (ej. la próxima Fase 2a del portal) debe
nacer ya con: (a) el lenguaje de "indicadores fisiológicos", y (b) su disclaimer de alcance.
Nunca presentar los datos como un diagnóstico.

---

## 5. Para la tesis / el jurado

Frase de referencia para defender el alcance:
> "El sistema monitorea parámetros fisiológicos (frecuencia cardiaca, saturación de oxígeno y
> variabilidad de la frecuencia cardiaca) que pueden asociarse a estados de ansiedad, y los
> pone a disposición del especialista como apoyo. El sistema no emite diagnósticos: la
> interpretación clínica de los datos es responsabilidad del profesional de salud. Este alcance
> está reflejado explícitamente en todas las interfaces mediante lenguaje de parámetros
> fisiológicos y avisos de limitación."
