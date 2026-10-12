# Documento maestro de desarrollo fundamentado

> Guía para construir la app y el portal con respaldo científico en cada decisión. Une la
> evidencia (de la investigación) con las decisiones de desarrollo y el plan de fases. Cada
> característica del sistema tiene aquí su "por qué". Sirve también como sustento ante los
> directores: el sistema no entrega datos sin fundamento.
>
> Fecha: 2026-10-11 · Trabajo Terminal — monitoreo de correlatos fisiológicos como apoyo al
> especialista (NO diagnóstico).

---

## 0. Encuadre (lo que el sistema ES y NO ES)

- **ES:** un monitor de **correlatos autonómicos** de la activación asociada a la ansiedad,
  comparados contra la **línea base individual** de cada estudiante, como apoyo al especialista.
- **NO ES:** un detector ni diagnosticador de ansiedad. No clasifica personas. No reemplaza al
  profesional.
- **Jerarquía de parámetros** (de la evidencia): **HRV/RMSSD (principal) > Frecuencia Cardíaca
  (complementaria) > SpO2 (seguridad y calidad de señal)**.

---

## 1. Por qué estos parámetros funcionan (fundamento para la app y el portal)

### 1.1 HRV / RMSSD — el parámetro principal
- **Qué es:** variación entre latidos sucesivos. La calcula el nervio vago (parasimpático).
- **Por qué sirve:** según el modelo de integración neurovisceral (Thayer & Lane, 2000), una HRV
  vagal alta refleja buena capacidad de regulación emocional; una HRV reducida refleja
  predominio del sistema de amenaza, rasgo de la ansiedad. Dos metaanálisis lo respaldan:
  Chalmers et al. (2014, 36 estudios) y Cheng et al. (2022, 99 estudios, 4.897 pacientes): HRV
  vagal reducida en trastornos de ansiedad (efecto pequeño a moderado).
- **Métrica elegida (RMSSD):** es el índice temporal del tono vagal, simple de calcular en un
  ESP32, válido en ventanas cortas (Laborde et al., 2017; Munoz et al., 2015).
- **Consecuencia de diseño:** el "estado" del paciente se calcula sobre la **desviación de la
  HRV respecto a SU línea base**, no contra umbrales poblacionales (que se solapan y clasifican
  mal).

### 1.2 Frecuencia Cardíaca (FC/BPM) — complementaria
- **Por qué sirve:** sube con la activación simpática (respuesta de amenaza). Es la señal
  cardiovascular más reconocible de la ansiedad aguda.
- **Limitación honesta:** inespecífica — la afectan cafeína, ejercicio, postura, sueño, etc.
- **Consecuencia de diseño:** nunca se interpreta sola; se muestra junto a la HRV. El patrón
  "FC alta + HRV baja respecto a la línea base" es más coherente con activación que cualquiera
  de los dos por separado.

### 1.3 SpO2 — seguridad y calidad, NO ansiedad
- **La verdad científica:** el SpO2 NO mide ansiedad. En la hiperventilación de la ansiedad lo
  que cae es el CO2 (hipocapnia), no el O2 — el SpO2 se mantiene normal (≈95–100%).
- **Para qué SÍ sirve en el sistema:**
  1. **Seguridad:** un SpO2 persistentemente bajo (&lt;94%) no es atribuible a la ansiedad y
     obliga a sugerir valoración médica.
  2. **Contexto:** un SpO2 normal durante "falta de aire" es coherente con un origen
     funcional/ansioso, no hipoxémico.
  3. **Calidad de señal:** la estabilidad de las señales roja/IR valida el contacto antes de
     calcular el RMSSD.
- **Consecuencia de diseño:** el SpO2 se SACA de la fórmula de estado de ansiedad. Se muestra
  como dato de seguridad aparte, con su aviso.

---

## 2. La nueva fórmula del "estado" (cambio respecto a lo anterior)

### 2.1 El cambio de fondo
Antes: un "score de ansiedad" mezclaba los tres parámetros contra umbrales fijos. Eso NO tiene
respaldo científico (clasifica mal por la variabilidad entre personas, y el SpO2 no aplica).

Ahora: el estado se basa en **cuánto se desvía la HRV actual de la línea base individual del
paciente**, con la FC como apoyo. El SpO2 queda fuera (solo seguridad).

### 2.2 Cómo se calcula (lógica, no diagnóstico)
1. Transformar RMSSD con logaritmo natural (Ln RMSSD) — su distribución es asimétrica.
2. Comparar el Ln RMSSD de la sesión contra la **media móvil de 7 días** de la línea base del
   paciente y su banda individual (p. ej. media ± 0,5–1 desviación estándar intraindividual).
3. Clasificar el **indicador fisiológico** (lenguaje de "indicadores", no de diagnóstico):
   - **Dentro de su rango habitual** (verde / "Normal")
   - **Por debajo de su rango habitual** (naranja / "Elevados" = más activación de lo usual)
   - **Muy por debajo de su rango habitual** (rojo / "Altos")
   - La FC fuera de su rango habitual refuerza la señal.
4. **Mientras no haya línea base** (primeros 7–14 días): mostrar el estado provisional con rangos
   generales de referencia + aviso visible **"Calibrando tu perfil (día X de 14)"**. (Decisión A,
   opción a.)

### 2.3 Reglas de seguridad (independientes de la fórmula)
- SpO2 &lt;94% sostenido con buena señal → aviso "Confirma con un oxímetro y consulta a tu
  especialista. No se relaciona con la ansiedad."
- GAD-7 ≥10 → el portal lo marca para que el especialista lo valore (protocolo de derivación,
  dado que se trabaja con estudiantes).

---

## 3. Estrategia de monitoreo (protocolo con respaldo)

Toda medición sigue este protocolo (de la evidencia sobre HRV confiable):

| Parámetro del protocolo | Valor | Fundamento |
|---|---|---|
| Postura | Sentado, mano apoyada a la altura del corazón | Reduce artefactos; estandariza |
| Estado | Reposo, sin hablar, respiración espontánea | La evidencia de HRV-ansiedad es en reposo |
| Estabilización | ~1 min antes de contar | El sensor y la señal se estabilizan |
| Duración de registro | 3–5 min (mínimo 2 min de señal limpia válida) | Task Force 1996; Munoz et al. 2015 |
| Momento | Misma hora (p. ej. matutino) | Comparabilidad día a día |
| Antes de medir | Sin cafeína ni ejercicio 1–2 h antes | Confusores conocidos de la HRV |
| Calidad de señal | Garantizada en origen (guía al paciente) | No se entrega medición dudosa (ver doc. de flujo) |

**Línea base individual:** 7–14 días con ≥5–7 mediciones válidas, a la misma hora y postura.
Se actualiza de forma continua (media móvil de 7 días).

---

## 4. Los formularios (cuestionarios que llevan de la mano)

> Decisión B: EVA 0–10 + GAD-7. Sin STAI (derechos de autor). GAD-7 es de uso libre y tiene
> versiones validadas en español.

### 4.1 EVA 0–10 — después de CADA medición
- **Una pregunta:** "¿Qué tan ansioso/a te sientes en este momento?" (0 = nada, 10 = la máxima
  ansiedad imaginable).
- **Fundamento:** Davey et al. (2007): r = 0,78 con el STAI. Abend et al. (2014) validaron la
  EVA computarizada (formato de app). Es breve, no fatiga, apta para uso repetido.
- **Opcional, contexto:** "¿Qué estabas haciendo?" (en reposo / estudiando / antes de un examen
  / después de una situación estresante / otro). Da el "qué" que explica el dato.
- **Para qué:** cruzar el dato objetivo (HRV, FC) con el subjetivo. Es lo que hace robusto el
  análisis.

### 4.2 GAD-7 — al inicio y cada 2–4 semanas
- **7 ítems**, marco de "últimas 2 semanas". Cortes 5/10/15 = leve/moderado/grave (Spitzer et
  al., 2006; sensibilidad 89%, especificidad 82% en corte ≥10).
- **Importante:** NO se correlaciona con una medición puntual (su marco es de 2 semanas). Es
  contexto clínico periódico para el especialista, no un dato por sesión.
- **Usar versión validada en español.**

### 4.3 Registro de confusores (opcional, mejora la interpretación)
Al medir, el paciente puede marcar rápidamente: dormí mal / tomé cafeína / hice ejercicio /
estoy enfermo / medicación. La evidencia dice que estos factores alteran la HRV; registrarlos
ayuda al especialista a no malinterpretar una sesión.

---

## 5. Textos educativos (el "por qué funciona" en la interfaz)

### 5.1 En la app (paciente) — lenguaje sencillo, nunca diagnóstico
- Sobre HRV: "La variabilidad de tu ritmo cardíaco refleja cómo tu cuerpo regula la calma y la
  activación. Más variabilidad suele asociarse a mejor recuperación."
- Sobre la medición: "Medimos en reposo unos minutos para obtener un dato confiable de tu
  estado fisiológico de hoy."
- Disclaimer permanente: "Estos son indicadores fisiológicos de apoyo, no un diagnóstico. Tu
  especialista los interpreta."

### 5.2 En el portal (especialista) — fundamento técnico
- Una sección de ayuda/metodología que explique: qué mide cada parámetro, por qué la HRV es el
  principal, por qué se compara contra la línea base individual, el protocolo de medición, y las
  limitaciones (PPG de bajo costo, no grado clínico). Con las referencias clave.
- Esto genera confianza del especialista en lo que ve y respalda el alcance ante el jurado.

---

## 6. Impacto técnico (qué se construye)

- **Base de datos:** `rutinas` (prescripciones del especialista), `sesiones_medicion` (reemplaza
  lecturas sueltas: resumen + serie submuestreada + calidad), `respuestas_eva` (0–10 + contexto
  por sesión), `respuestas_gad7` (periódicas), y el cálculo de `linea_base` por paciente.
- **App:** conducir la sesión con control de calidad guiado, EVA post-medición, mostrar estado
  vs. línea base (o "calibrando"), textos educativos, registro de confusores, GAD-7 periódico.
- **Firmware (con el compañero):** reportar calidad de señal más fina (señal estable, no solo
  "hay dedo"); enviar lecturas continuas durante la sesión.
- **Backend:** endpoints de rutinas, sesiones, EVA, GAD-7; cálculo de línea base y del estado.
- **Portal:** prescribir rutinas, ver sesiones interpretadas (objetivo ↔ subjetivo ↔ línea
  base), sección de metodología/fundamento, marcado de GAD-7 ≥10.

---

## 7. Plan de fases (Decisión C: por fases)

Orden de lo más fundamental a lo más visible. Cada fase se construye y prueba por separado, como
todo el proyecto.

- **Fase M1 — Modelo de datos + sesión de medición.** Crear las estructuras (sesiones, en vez de
  lecturas sueltas) y cambiar la app para capturar una *sesión* de 3–5 min con control de calidad
  guiado. Base de todo. (Coordinar firmware para calidad de señal.)
- **Fase M2 — EVA post-medición + contexto.** El cuestionario EVA 0–10 y el "qué estabas
  haciendo" tras cada sesión, guardados con la sesión.
- **Fase M3 — Línea base + nueva fórmula de estado.** Calcular la línea base individual y mostrar
  el estado como desviación de esa base (con el modo "calibrando" los primeros días).
- **Fase M4 — Rutinas del especialista.** Prescribir rutinas desde el portal; el paciente las
  recibe y la app lo guía.
- **Fase M5 — GAD-7 periódico + análisis cruzado en el portal.** GAD-7 cada 2–4 semanas; el
  portal muestra la sesión interpretada (objetivo + subjetivo + línea base) y marca GAD-7 ≥10.
- **Fase M6 — Textos educativos + sección de metodología.** El "por qué funciona" en app y portal.
- **Fase M7 — Validación (objetivo 5 / aportación de la tesis).** Comparar el MAX30102 contra
  Polar H10 / oxímetro certificado en 15–30 estudiantes; documentar sesgo y límites de acuerdo.

> Nota: M1 y M3 dependen en parte del firmware (calidad de señal, lecturas continuas) — coordinar
> con el compañero del hardware.

---

## 8. Referencias clave (para citar en la tesis)

- Thayer JF, Lane RD (2000). *J Affect Disord* 61(3):201–216. — Modelo neurovisceral.
- Chalmers JA et al. (2014). *Front Psychiatry* 5:80. — Metaanálisis HRV–ansiedad (36 estudios).
- Cheng YC et al. (2022). *Psychiatry Clin Neurosci* 76(7):292–302. — Metaanálisis (99 estudios).
- Laborde S et al. (2017). *Front Psychol* 8:213. — Guía metodológica HRV (RMSSD, tono vagal).
- Munoz ML et al. (2015). *PLoS ONE* 10(9):e0138921. — HRV ultracorta / ventanas.
- Task Force (1996). *Circulation* 93:1043–1065. — Estándares de medición de HRV.
- Schäfer A, Vagedes J (2013). *Int J Cardiol* 166(1):15–29. — PRV (PPG) vs HRV (ECG).
- Spitzer RL et al. (2006). *Arch Intern Med* 166(10):1092–1097. — GAD-7.
- Davey HM et al. (2007). *J Clin Epidemiol* 60(4):356–360. — EVA de ansiedad.
- Abend R et al. (2014). *J Behav Ther Exp Psychiatry*. — EVA computarizada.
- Plews DJ et al. (2014). *Int J Sports Physiol Perform* 9(5):783–790. — Línea base / media 7 días.
- Bent B et al. (2020). *npj Digital Medicine* 3:18. — Artefactos de movimiento en PPG.

> (Verificar y adaptar las versiones en español del GAD-7 antes de implementarlas.)
