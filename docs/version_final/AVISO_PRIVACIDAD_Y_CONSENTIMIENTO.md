# Aviso de privacidad y consentimiento informado — versión 1 (aprobada por los directores)

> **Uso:** estos textos sustituyen los borradores de `app_ansiedad/lib/contenido/privacidad_textos.dart`. Cuando los directores los aprueben:
> - versión del aviso: `privacidad-v1`;
> - versión del consentimiento: `consentimiento-v1`;
> - quitar la marca VERIFICAR.
>
> También van como anexo de la tesis.
>
> **Responsable confirmado: ESCOM del IPN** (mismo modelo que los avisos integrales de las escuelas del IPN, donde la escuela es la responsable y los derechos ARCO se ejercen ante la Unidad de Transparencia del IPN).
>
> **Falta un solo dato entre [corchetes]:** el correo de contacto del proyecto. Los otros cuatro se completaron el 9 de noviembre de 2026.
>
> **Marco legal:**
> - El IPN es una institución pública y, como sujeto obligado, se rige por la **Ley General de Protección de Datos Personales en Posesión de Sujetos Obligados** (DOF 20/03/2025), no por la LFPDPPP. Esa ley considera **sensibles** los datos de salud (art. 3, fr. IX) y pide aviso simplificado y aviso integral (arts. 21 y 22).
> - Para datos sensibles, confirmar con la Unidad de Transparencia del IPN si la aceptación electrónica con cuenta autenticada (casilla + inicio de sesión) basta como consentimiento expreso. La ley prohíbe dejar la casilla marcada de antemano, y la app ya la deja sin marcar.

---

## A. Aviso de privacidad simplificado

*Pantalla de registro y puerta de consentimiento. Es corto a propósito.*

**Aviso de privacidad**

Este prototipo forma parte del Trabajo Terminal 2026-B085 de la Escuela Superior de Cómputo (ESCOM) del Instituto Politécnico Nacional. La ESCOM es la responsable del tratamiento de tus datos personales.

Usamos tus datos para:
- registrar tus mediciones de pulso (frecuencia cardiaca, variabilidad de la frecuencia cardiaca y oxigenación) y tus respuestas a los cuestionarios;
- compararlas con tu propio ritmo habitual;
- que el especialista con el que te vincules pueda darte seguimiento.

Algunos de estos datos son **datos de salud** y por eso te pedimos tu consentimiento expreso.

Con datos **agregados y sin identificarte** se evaluará el funcionamiento del prototipo dentro del Trabajo Terminal. Si no quieres que tus datos se usen para esto, escríbenos a [correo de contacto del proyecto].

No vendemos tus datos ni los compartimos con terceros para otros fines.

Puedes pedir la eliminación de tu cuenta en **Perfil → Privacidad**.

Consulta el aviso completo en **Perfil → Privacidad → Aviso de privacidad**.

---

## B. Aviso de privacidad integral

*Perfil → Privacidad, y anexo de la tesis.*

### 1. Responsable

La Escuela Superior de Cómputo (ESCOM) del Instituto Politécnico Nacional, con domicilio en Av. Juan de Dios Bátiz s/n, esq. Miguel Othón de Mendizábal, Col. Lindavista, Alcaldía Gustavo A. Madero, C.P. 07738, Ciudad de México, es la responsable del tratamiento de los datos personales que se recaben mediante este prototipo, conforme a la Ley General de Protección de Datos Personales en Posesión de Sujetos Obligados.

El prototipo lo desarrollan Omar Alejandro Angeles Carcamo y Luis Enrique Lopez Marin como parte del Trabajo Terminal 2026-B085. Lo dirigen el Dr. José Alfredo Jiménez Benítez y la M. en C. Jacqueline Arzate Gordillo.

### 2. Datos personales que se tratan

**Datos de identificación y de cuenta:**
- nombre;
- correo electrónico;
- contraseña. La contraseña la administra el servicio de autenticación y el proyecto nunca la conoce.

**Datos de salud (sensibles):**
- frecuencia cardiaca, variabilidad de la frecuencia cardiaca (RMSSD) y saturación de oxígeno (SpO2) de cada medición, con su fecha, hora y calidad de la señal;
- la escala de cómo te sientes que respondes después de cada medición;
- las respuestas al cuestionario GAD-7.

**Datos de comunicación:**
- los mensajes que intercambias con tu especialista;
- los ejercicios que te asigna.

**Datos técnicos del dispositivo:** si activas las notificaciones, se guarda un identificador técnico de tu teléfono (token de notificaciones) para poder avisarte de mensajes y ejercicios nuevos. Se borra al cerrar sesión, si tu cuenta se suspende o al eliminarla. Las notificaciones **nunca muestran el contenido** de tus mensajes ni resultados; aun así, quien vea tu pantalla podría notar que usas la app. Puedes desactivarlas en cualquier momento en los ajustes de tu teléfono.

**No recabamos** tu ubicación, tus contactos ni otros datos de tu teléfono. El permiso de Bluetooth se usa solo para conectar el sensor.

### 3. Finalidades

**Necesarias para el servicio:**

1. Crear y administrar tu cuenta.
2. Registrar tus mediciones y calcular tu línea base individual, es decir, tu propio ritmo habitual.
3. Que el especialista con el que te vincules consulte tus mediciones y tus cuestionarios para darte seguimiento.
4. Permitir la comunicación entre tú y tu especialista.

**Adicional:**

5. Evaluar el funcionamiento del prototipo con datos **agregados y sin identificarte**, dentro del Trabajo Terminal y su documento. Puedes negarte escribiendo a [correo de contacto del proyecto]; tu negativa no afecta el uso de la app.

La app **no emite diagnósticos** y no sustituye la atención de un profesional de la salud.

### 4. Quién puede ver tus datos

| Quién | Qué ve |
|---|---|
| **Tú** | Tus mediciones y tu historial. |
| **Tu especialista** (solo si te vinculas con él o ella) | Tus mediciones, cómo se comparan con tu línea base, la calidad de cada medición, tus cuestionarios, tus mensajes y tus ejercicios. También puede escribir notas de seguimiento y marcar fechas relevantes (por ejemplo, un periodo de exámenes), y exportar un reporte de tus datos para tu seguimiento. |
| **Administración del sistema** | Tu nombre, correo, rol y estado de la cuenta, y la bitácora de seguridad (quién hizo qué acción y cuándo). **No ve** tus datos de salud ni las notas de tu especialista. |

### 5. Servicios que usa el sistema (encargados)

Para funcionar, el sistema se apoya en proveedores que guardan o procesan los datos **por cuenta del proyecto** y solo para prestar el servicio:

- **Google Firebase**: autenticación de cuentas.
- **Supabase**: base de datos.
- **Render**: servidor de la aplicación y portal web.

Estos servicios pueden almacenar la información en servidores fuera de México. La base de datos (Supabase) y el servidor (Render) están en la región East US, en Estados Unidos.

No se hacen otras transferencias, salvo las que exija una autoridad competente conforme a la ley.

### 6. Cuánto tiempo se conservan

Tus datos se conservan mientras tu cuenta esté activa y dure el Trabajo Terminal, como máximo hasta el 31 de enero de 2027.

Cuando el administrador atiende una solicitud de eliminación:
- **se borran** tus mediciones, cuestionarios, mensajes y ejercicios, así como tu cuenta de acceso;
- **se conserva** solo un registro seudonimizado (identificado solo con un código interno, sin tu nombre ni tu correo) que indica que la cuenta existió, que aceptaste este aviso y que pediste la eliminación.
- **se conserva** la bitácora de seguridad del sistema: un registro de qué acciones se hicieron sobre la cuenta y cuándo (por ejemplo, que un especialista consultó tus datos o que se atendió tu solicitud). Solo guarda un identificador interno de la cuenta, **sin datos de salud** y sin contenido de mensajes ni de notas.

El especialista también puede escribir **notas de seguimiento** sobre ti, que solo ve él o ella mientras estés vinculado. Estas notas se borran junto con tus demás datos al atender tu solicitud de eliminación.

### 7. Tus derechos (ARCO y portabilidad)

Tienes derecho a acceder a tus datos, rectificarlos, cancelarlos u oponerte a su tratamiento, y a solicitar su portabilidad.

- **Dentro de la app:**
  - consultar tus mediciones en Historial;
  - corregir tu nombre en Perfil;
  - pedir la eliminación de tu cuenta en Perfil → Privacidad → Eliminar mi cuenta.
- **Por escrito:** a [correo de contacto del proyecto].
- **Ante la Unidad de Transparencia del IPN:** Av. Wilfrido Massieu s/n, Edificio «Adolfo Ruiz Cortines», planta baja, Unidad Profesional Adolfo López Mateos, Zacatenco, Alcaldía Gustavo A. Madero, C.P. 07738, Ciudad de México. Teléfono 55 5729 6000, extensiones 50128 y 51992. Correo: acceinfo@ipn.mx.

Puedes **retirar tu consentimiento** en cualquier momento solicitando la eliminación de tu cuenta.

### 8. Cambios a este aviso

Si este aviso cambia, la app te mostrará la nueva versión y te pedirá aceptarla antes de seguir midiendo.

Versión: `privacidad-v1` · Fecha: 10 de noviembre de 2026.

---

## C. Consentimiento informado

*Segunda casilla de la puerta de consentimiento.*

**Consentimiento para participar**

Al aceptar, confirmo que:

1. **Entiendo qué es la app.** Es un prototipo académico que mide señales de mi pulso con un sensor en el dedo durante unos minutos, en reposo, para conocer mi ritmo habitual. **No da diagnósticos** ni sustituye la atención de un profesional.
2. **Entiendo qué veré y qué no.** La app me muestra mis valores y mi progreso, pero **no me muestra interpretaciones** sobre mi estado. Si me vinculo con un especialista, él o ella revisará esta información para darme seguimiento.
3. **Mi participación es voluntaria.** Puedo dejar de usar la app y pedir la eliminación de mi cuenta en cualquier momento, sin ninguna consecuencia.
4. **Autorizo el tratamiento de mis datos de salud** (frecuencia cardiaca, variabilidad, oxigenación y respuestas a cuestionarios) para las finalidades descritas en el aviso de privacidad.
5. **Riesgos.** La medición no es invasiva: es la misma técnica de un oxímetro de dedo. Responder cuestionarios sobre cómo me siento puede resultar incómodo; puedo dejar de responder cuando quiera.
6. **Si necesito ayuda.** Esta app no atiende emergencias. Si me siento en crisis o en peligro, llamo al **911** o a la **Línea de la Vida 800 911 2000** (gratuita, 24 horas, todos los días).

Versión: `consentimiento-v1` · Fecha: 10 de noviembre de 2026.

---

## Notas para Claude Code al integrar

- Mostrar primero el **simplificado (A)** con el enlace "Leer aviso completo" hacia el **integral (B)**. Después va el **consentimiento (C)**, con su casilla propia. Las dos casillas empiezan **sin marcar**.
- La constante `apoyoLinea` (marcada VERIFICAR) puede tomar ya `800 911 2000`. Verificado: Línea de la Vida, CONASAMA, 24/7, nota del 20/08/2026.
- **Regla de oro:** ningún texto menciona resultados, niveles ni etiquetas. La prueba `privacidad_textos_test.dart` debe seguir pasando.
- Mientras queden [corchetes] sin resolver, la versión debe seguir conteniendo `borrador`. La prueba ya lo exige.
