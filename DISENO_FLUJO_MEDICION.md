# Diseño del flujo de medición clínica

> Documento de arquitectura para la evolución del sistema: de "un sensor que sube números
> sueltos" a "un sistema de monitoreo con propósito clínico y contexto". Responde a los
> comentarios de los directores (fortalecer la obtención de datos, justificar el valor para el
> especialista, generar un análisis robusto y no datos sin fundamento).
>
> Fecha: 2026-10-10 · Omar — Trabajo Terminal

---

## 0. El problema que resuelve este rediseño

**Hoy:** el paciente mide cuando quiere, de forma manual, y sube una lectura suelta. Un número
sin contexto (BPM 92) no le dice nada clínicamente útil al especialista: ¿es ansiedad, o acaba
de subir escaleras? ¿Es alto *para este paciente*, o es su normal?

**La meta:** que cada medición tenga (a) un **propósito clínico** definido por el especialista,
(b) una **captura confiable** basada en la calidad de la señal, y (c) un **contexto subjetivo**
que permita interpretarla. El dato objetivo (fisiológico) y el dato subjetivo (cómo se siente,
qué hace) juntos producen un análisis robusto.

**El principio rector:** *el sistema no entrega datos, entrega evidencia contextualizada para
el juicio del especialista.*

---

## 1. El flujo clínico completo (la historia)

```
  ESPECIALISTA                    PACIENTE (app)                   ESPECIALISTA (portal)
  ───────────                     ──────────────                   ─────────────────────
  1. Prescribe una       →        2. Recibe la rutina:      →      6. Ve la sesión con:
     RUTINA de medición             "Mide 3 min en reposo            - datos fisiológicos
     (moldeable, pre-                al despertar"                     (HRV, BPM, SpO2)
      establecida)                                                   - el contexto subjetivo
                                   3. Hace la MEDICIÓN               - comparación vs. su
                                      guiada: la app                   línea base
                                      captura hasta tener            - correlación objetivo
                                      señal estable                     ↔ subjetivo
                                      (muestreo dinámico)
                                                                     7. Interpreta y da
                                   4. Responde un breve                seguimiento
                                      CUESTIONARIO:
                                      "¿cómo te sientes?
                                       ¿qué hacías?"

                                   5. Se sube la SESIÓN
                                      completa (datos +
                                      contexto + resumen)
```

---

## 2. Capacidad 1 — Rutinas de medición (prescritas por el especialista)

### Qué es
El especialista define un **protocolo de medición** para el paciente, como una receta. Moldeable
pero a partir de plantillas pre-establecidas (tu decisión del punto 1).

### Plantillas pre-establecidas (ejemplos a definir con criterio clínico)
- **Línea base matutina:** medir en reposo al despertar, N minutos, durante N días. (Sirve para
  establecer el "normal" del paciente.)
- **Pre/post estresor:** medir antes y después de una situación que el paciente identifique como
  estresante (examen, presentación).
- **Monitoreo diario:** una medición al día a una hora fija.
- **Bajo demanda:** cuando el paciente sienta un episodio, mide y reporta.

### Qué puede moldear el especialista
- Duración objetivo de cada medición (sugerida; el muestreo dinámico la ajusta — ver Cap. 2).
- Frecuencia (cuántas veces al día / a la semana).
- Duración del protocolo (cuántos días).
- Momento sugerido (al despertar, antes de dormir, etc.).
- Una nota/indicación libre ("mídete después de tu clase de cálculo").

### Por qué es valioso (para la tesis)
Convierte datos aleatorios en **datos comparables con propósito**. Responde al objetivo 3
("indicaciones del especialista") y al objetivo general ("seguimiento personalizado"). Un
especialista no quiere ruido; quiere "cómo está en reposo matutino a lo largo de 2 semanas".

---

## 3. Capacidad 2 — Muestreo dinámico basado en calidad de señal

> Este es el punto más técnico y el más importante para la **confiabilidad** (objetivo 2).
> Tu decisión (punto 2): el muestreo debe guiarse por la señal, buscando información realmente
> confiable, no una lectura cualquiera.

### El problema del muestreo manual actual
Una lectura instantánea puede caer en un mal momento: dedo mal puesto, movimiento, los primeros
segundos en que el sensor aún se estabiliza. Eso produce datos basura que ensucian el análisis.

### Principio: la confiabilidad se GARANTIZA en origen, no se "estima" al final

> Corrección de diseño importante: el control de calidad NO es un veredicto que se muestra al
> paciente ("tu medición fue 60% confiable"). Eso desmerecería la herramienta y sembraría duda.
> El objetivo es que **toda medición que el paciente completa SEA confiable por diseño**: el
> sistema no deja terminar una medición con señal mala, sino que guía al usuario a corregirla.
> El paciente nunca ve una medición dudosa, porque el sistema no la deja llegar a ese punto.

### La propuesta: sesión de medición con control de calidad invisible y guía
En lugar de "mide y sube un número", la app conduce una **sesión** donde el control de calidad
actúa DURANTE la captura, de forma guía y no de juicio:

1. **Estabilización:** la app espera a que la señal del sensor sea buena antes de empezar a
   contar. Hoy el firmware ya detecta presencia de dedo con umbral; se extiende a "señal estable".
2. **Captura:** durante la sesión se registran lecturas continuas (BPM, SpO2, HRV), no una sola.
3. **Guía en vivo (no juicio):** si la señal se degrada, la app GUÍA al paciente con instrucciones
   positivas y accionables, no con una alarma de desconfianza:
   - "Acomoda tu dedo en el sensor"
   - "Mantén la mano quieta un momento"
   - "Casi listo, un momento más"
   Esos segundos de mala señal simplemente no cuentan como válidos; el paciente solo ve una guía.
4. **Criterio de término (dinámico):** la sesión se completa cuando se acumuló **suficiente señal
   válida y estable** para un cálculo confiable — no por un cronómetro ciego. El paciente ve una
   barra de progreso ("Midiendo…") que avanza solo con señal buena. Al llegar al 100%, la
   medición está completa Y es confiable.
5. **Resultado para el paciente:** o la medición **se completó bien** (y entonces es buena, sin
   asteriscos ni dudas), o la app lo guió a reintentar. Nunca "quizás". Es binario y positivo,
   como un termómetro que dice "espera…" hasta tener una lectura buena y entonces da el número.

### El índice de calidad: interno, NO para el paciente
De cada sesión se calcula un **índice de calidad** (qué % de la señal fue válida). Pero:
- **NO se le muestra al paciente** como "confiabilidad de tu medición" — eso queda prohibido por
  el principio de arriba.
- **SÍ queda registrado internamente**, para dos usos:
  - el **especialista** puede ver un sello discreto de "medición válida" (no una alarma);
  - sirve para la **validación del objetivo 5** (documentar la confiabilidad del sistema).

### Cálculo del resumen
De la sesión completa se calculan indicadores robustos: BPM promedio/mín/máx, HRV (RMSSD) sobre
la ventana estable, SpO2 promedio.

### Qué se sube
Una **sesión** = las lecturas de la sesión (o una muestra representativa) + el resumen calculado
+ el índice de calidad (interno) + la marca de tiempo + la rutina a la que responde.

> Decisión de diseño a cerrar contigo: ¿guardamos todas las lecturas crudas de la sesión, o una
> muestra + el resumen? Mi recomendación: **el resumen + una serie submuestreada** (ej. un valor
> cada pocos segundos para poder graficar la sesión), para no inflar la base de datos pero sí
> permitir que el especialista vea la evolución dentro de la sesión.

### Por qué es valioso (para la tesis)
Ataca directo el **objetivo 2** ("tratamiento y filtrado... indicadores confiables"). Y la
respuesta a "¿cómo garantizas la confiabilidad?" es más fuerte que un disclaimer: **el sistema
garantiza la calidad en el origen** (no deja completar una medición mala, guía a corregirla), en
lugar de entregar un dato dudoso con una advertencia. Afirmar que el sistema GARANTIZA la
confiabilidad es defendible; afirmar que la "estima" es más débil.

---

## 4. Capacidad 3 — Cuestionario breve de contexto (lo subjetivo)

> Tu decisión (punto 3): después de medir, un cuestionario breve que ayude mucho a los datos.
> Esta es la pieza que vuelve el análisis robusto, y además cumple el objetivo 3 ("pruebas
> psicométricas rápidas").

### Cuándo
**Justo después de la sesión de medición**, mientras el momento está fresco. Breve (no más de 3-5
toques), para que el paciente no lo abandone.

### Qué preguntar (propuesta — a validar con criterio clínico / tus directores)
El contenido debe tener fundamento psicométrico, no inventado. Propuesta mínima:

1. **Nivel de ansiedad percibido** — escala 0-10 (tipo escala visual análoga, muy usada en
   clínica). "¿Qué tan ansioso/a te sientes ahora?"
2. **Qué estabas haciendo / contexto** — opciones rápidas: en reposo, estudiando, antes de un
   examen, después de una situación estresante, otro. Da el "qué" que explica el dato.
3. (Opcional, moldeable por el especialista) **una pregunta corta validada** — por ejemplo un
   ítem tipo GAD (escala de ansiedad generalizada) para darle respaldo psicométrico.

> Importante para la defensa: si usamos ítems de una escala validada (GAD-7, STAI, etc.), hay que
> citarla y respetar su uso. No inventar una escala propia sin fundamento. Esto lo definimos con
> criterio clínico — es justo donde tus directores pueden guiar.

### Por qué es valioso (para la tesis)
Resuelve el problema central de cualquier sistema fisiológico: **el dato solo no significa nada
sin contexto.** Cruzar HRV baja + "ansiedad 8/10" + "antes de un examen" produce una
interpretación clínica real. Y cumple el objetivo 3 (psicométricos). Es la diferencia entre un
juguete y una herramienta.

---

## 5. Capacidad 4 — Análisis robusto cruzado (lo que ve el especialista)

Con las 3 capacidades anteriores, el portal del especialista deja de mostrar "HRV 42" y pasa a
mostrar una **sesión interpretada**:

> **Sesión — martes 14, 8:15 am** (rutina: línea base matutina) · medición válida ✓
> - HRV: 30 ms — **por debajo de su línea base (45 ms)**
> - BPM: 92 — elevado respecto a su reposo habitual (72)
> - SpO2: 97%
> - El paciente reportó: **ansiedad 8/10**, contexto: "antes de un examen"
> - *Correlación: la respuesta fisiológica (HRV↓, BPM↑) coincide con el estresor y el malestar
>   reportado.*

### La pieza clave: la LÍNEA BASE del paciente
Para poder decir "su HRV **cayó respecto a su normal**", el sistema necesita calcular la **línea
base** de cada paciente (su promedio en reposo durante los primeros días). Sin línea base, un
HRV de 30 no dice nada; con línea base, "30 vs. su normal de 45" es información clínica.

Esto se calcula de las sesiones de "línea base matutina" de los primeros días. Es un concepto
central del nuevo diseño.

### Por qué es valioso (para la tesis)
Esto es, literalmente, lo que responde a tus directores: **el sistema apoya al especialista con
fundamento**, no entrega datos sueltos. Muestra la correlación objetivo↔subjetivo, comparada
contra la propia normalidad del paciente.

---

## 6. Qué implica construir esto (impacto técnico)

Esto toca **todo el sistema** y reorganiza cómo fluyen los datos. Por eso hay que diseñarlo bien
antes de codificar. Áreas afectadas:

- **Base de datos:** nuevas estructuras — `rutinas` (prescripciones), `sesiones_medicion` (en vez
  de lecturas sueltas), `respuestas_cuestionario` (contexto subjetivo), y el cálculo de línea
  base. Las `lecturas_biometricas` actuales pasan a agruparse en sesiones.
- **App (paciente):** recibir rutinas, conducir la sesión con control de calidad de señal, mostrar
  el cuestionario post-medición, subir la sesión completa.
- **Firmware (sensor):** reportar un indicador de calidad de señal más fino (no solo "hay dedo",
  sino "señal estable"). Coordinar con tu compañero.
- **Backend:** endpoints para rutinas, sesiones, cuestionarios; el cálculo de línea base y del
  análisis cruzado.
- **Portal (especialista):** prescribir rutinas, ver sesiones interpretadas con el análisis
  cruzado y la comparación contra línea base.

---

## 7. Cómo lo construimos (fases sugeridas)

> **Numeración vigente (alineada el 2026-10-21):** la de `DESARROLLO_FUNDAMENTADO.md` §7, que es
> la que se implementó. La propuesta original de este documento ponía las rutinas en M3, la línea
> base en M4 y la validación en M5; se reordenó así:

1. **Fase M1 — Modelo de datos y sesión de medición** (✅ hecha: M1a backend, M1b captura, M1c
   sesiones en app y portal). Capturar una *sesión* con control de calidad en vez de una lectura
   suelta. Es la base; sin esto lo demás no se sostiene.
2. **Fase M2 — EVA post-medición + contexto** (✅ hecha). El cuestionario post-medición en la app,
   guardado con la sesión.
3. **Fase M3 — Línea base + estado** (✅ hecha). Línea base individual y estado de la sesión como
   desviación de esa base, visible solo para el especialista.
4. **Fase M4 — Rutinas del especialista** (pendiente). El especialista prescribe rutinas desde el
   portal; el paciente las recibe en la app.
5. **Fase M5 — GAD-7 periódico + análisis cruzado** (pendiente). La sesión interpretada
   (objetivo ↔ subjetivo ↔ línea base) en el portal.
6. **Fase M6 — Textos educativos + metodología** (pendiente).
7. **Fase M7 — Sensor físico:**
   - **M7a — Integración del sensor** (en curso; en conversación, "Fase D"): la app mide con el
     ESP32 real por Bluetooth clásico. Contrato de datos en `CONTRATO_SENSOR.md`.
   - **M7b — Validación (objetivo 5).** La prueba piloto: comparar el sensor contra un equipo de
     referencia, registrar reposo vs. estresor, documentar la confiabilidad.

> Nota: el muestreo dinámico de la Fase M1 y el indicador de calidad de señal dependen también
> del firmware — hay que coordinarlo con tu compañero del hardware.

---

## 8. Lo que hay que definir con criterio clínico (preguntas para los directores)

Estas decisiones NO son técnicas, son clínicas, y conviene llevarlas a tus directores:

1. **Las plantillas de rutina:** ¿cuáles protocolos de medición tienen sentido clínico? (duración,
   frecuencia, momentos).
2. **El criterio de "señal suficiente y confiable":** ¿cuántos minutos de señal limpia se
   necesitan para una HRV confiable? (hay literatura: suele hablarse de ventanas de 1-5 min para
   HRV de corto plazo).
3. **El cuestionario:** ¿qué escala psicométrica validada usar (GAD-7, STAI, escala visual
   análoga)? Esto da respaldo científico y evita inventar.
4. **La línea base:** ¿cuántos días/sesiones de reposo se necesitan para establecer el "normal"
   de un paciente?

Llevar estas 4 preguntas a tus directores los involucra en el diseño y fortalece el fundamento
clínico — justo lo que pidieron.

---

## 9. El mensaje de fondo (para la defensa)

> "El sistema evolucionó de capturar datos fisiológicos aislados a conducir mediciones con
> propósito clínico: el especialista prescribe una rutina, el paciente la realiza mientras el
> sistema garantiza la calidad de la señal en origen (guiándolo a una buena toma, sin entregar
> mediciones dudosas), y reporta su contexto subjetivo. El análisis cruza el dato objetivo (HRV,
> FC, SpO2) con el reporte subjetivo y la línea base del propio paciente. Así, el sistema no
> entrega números sueltos: entrega evidencia confiable y contextualizada, como apoyo al juicio
> del especialista."

---

## 10. Principio de experiencia de usuario (de la corrección de diseño)

Regla permanente para toda pantalla de medición en la app del paciente:

- El paciente **nunca** ve un mensaje que ponga en duda su propia medición ("podría no ser
  confiable", "confiabilidad 60%"). Eso desmerece la herramienta.
- El control de calidad se expresa SIEMPRE como **guía positiva y accionable** durante la captura
  ("acomoda tu dedo", "mantén la mano quieta", "casi listo"), no como un veredicto al final.
- El resultado para el paciente es **binario y positivo**: medición completada (buena) o guía a
  reintentar. Nunca un punto intermedio de duda.
- El índice de calidad numérico es **interno**: para el especialista (como sello discreto de
  validez) y para la validación del sistema (objetivo 5). No se muestra al paciente.
