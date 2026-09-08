# Guía de preparación de la presentación

La evaluación es **individual** y la presentación pesa el **60%**. El docente puede
preguntar a cualquier integrante sobre cualquier parte del proyecto — no solo sobre lo
que expuso. **Todos deben poder explicar y defender TODO el proyecto.**

**Integrantes:** Mathias Von Jentschy, Nelson Carrasco, Juan Serna, Barbara Bustamante.

## Reparto sugerido de la exposición

Es solo una sugerencia de quién habla cuándo. **Todos deben poder responder todo.**

| Bloque | Diapositiva | Sugerencia |
|---|---|---|
| Contexto y datos | 2–3 | Mathias |
| RECORD y VARRAY | 4 | Nelson |
| Cursores y loops | 5 | Juan |
| Excepciones | 6 | Barbara |
| Evolución futura (procedures/functions/packages/triggers) | 7 | Mathias / Nelson |
| Cierre | 8 | Juan / Barbara |

## Estructura sugerida de la presentación (según la rúbrica)

1. **Contexto** — problema, objetivo y alcance del proceso de cierre.
2. **Datos** — qué se procesa (arriendos, camiones) y qué información se genera (multas, historial).
3. **RECORD / VARRAY** — uso y ejemplo aplicado.
4. **Cursores** — sin parámetro, con parámetro y loops anidados; mostrar código y resultado.
5. **Excepciones** — Oracle (`DUP_VAL_ON_INDEX`) y del usuario (`e_fecha_devolucion_invalida`).
6. **Evolución futura** — procedures, functions, packages y triggers (bloque de mayor peso).
7. **Cierre** — impacto y conclusión.

## Banco de preguntas para ensayar entre ustedes

Háganselas entre los cuatro antes de presentar. Si alguien no puede responder alguna
con sus propias palabras, ahí hay que reforzar.

### Sobre el caso

1. ¿Por qué eligieron este caso y no otro?
2. ¿Qué información necesita el negocio que antes no tenía?
3. ¿De dónde salen los datos que procesan?

### Sobre RECORD y VARRAY

4. ¿Cuál es la diferencia entre un RECORD y un VARRAY?
5. ¿Por qué los tramos de multa están en un VARRAY y no en una tabla?
6. ¿Qué pasaría si cargaran el VARRAY dentro del loop en vez de antes? *(Respuesta: se
   recargaría en cada iteración, desperdiciando trabajo; por eso se carga una sola vez.)*
7. ¿Por qué usaron un RECORD para la liquidación en lugar de variables sueltas?
8. ¿Por qué el VARRAY se declaró de tamaño 5 si solo usan 3 tramos? *(Respuesta: margen
   para tramos futuros sin cambiar el tipo; el VARRAY exige un tope al declararlo.)*

### Sobre cursores

9. ¿Qué es un cursor explícito y en qué se diferencia de un SELECT INTO?
10. ¿Cuál de sus cursores tiene parámetro y cuál no? ¿Por qué esa diferencia?
11. ¿Qué ventaja concreta les dio que `c_arriendos` reciba el año como parámetro?
12. Muestren dónde hay dos loops trabajando simultáneamente y expliquen qué hace cada uno.
13. ¿Por qué en el Proceso A usaron OPEN/FETCH/CLOSE y en el B un cursor FOR?

### Sobre excepciones

14. ¿Qué diferencia hay entre una excepción predefinida de Oracle y una definida por ustedes?
15. ¿Qué condición exacta controla `e_fecha_devolucion_invalida`? ¿La encontraron en los
    datos? *(Respuesta: sí, el arriendo 104, patente BC1002, inicio 25/02/2026 y
    devolución 05/02/2026.)*
16. ¿Cuándo se dispara `DUP_VAL_ON_INDEX` en su proceso? *(Respuesta: al reejecutar un
    año ya procesado; el id_arriendo / la PK ya existen. Lo verificamos reejecutando 2025.)*
17. ¿Por qué el bloque EXCEPTION está dentro del loop y no al final del bloque principal?
18. ¿Qué pasaría si no tuvieran ese manejo de excepciones? *(Respuesta: un solo registro
    malo abortaría todo el proceso y habría que reiniciar desde cero.)*

### Sobre la evolución futura (bloque de mayor peso: 15%)

19. ¿Qué diferencia hay entre un procedimiento y una función? *(Respuesta: la función
    retorna un valor y se puede usar en un SELECT; el procedimiento ejecuta acciones.)*
20. ¿Qué harían con un package que no puedan hacer hoy? *(Respuesta: agrupar procesos +
    función + constantes en un objeto, separar especificación del cuerpo, un solo punto
    de mantenimiento.)*
21. ¿Qué trigger propondrían y qué problema resolvería? *(Respuesta: BEFORE INSERT/UPDATE
    en ARRIENDO_CAMION para bloquear fechas inválidas en origen — el caso del arriendo 104.)*
22. ¿Qué desventaja tiene usar muchos triggers? *(Respuesta: ocultan lógica, dificultan
    la depuración si se abusa de ellos.)*

### Sobre decisiones de diseño (las más probables)

23. ¿Por qué modificaron la clave primaria de MULTA_ARRIENDO? *(Respuesta: la PK original
    (mes, patente) solo permitía un registro por camión-mes y se perdían atrasos; con
    id_arriendo cada arriendo con atraso queda registrado.)*
24. ¿Qué pasaba antes de ese cambio? ¿Qué información se perdía?
25. ¿De dónde sacaron los porcentajes de multa? *(Respuesta: son una regla de negocio
    propia del equipo; la BD no trae tabla de tarifas y el enunciado no la especifica.)*
26. ¿Por qué excluyeron del historial los camiones sin arriendos?
27. Si el docente les pide procesar el año 2024, ¿qué tendrían que cambiar? *(Respuesta:
    solo la constante `v_anno` del bloque; el cursor con parámetro hace el resto.)*

### Sobre el hallazgo técnico del formato de fecha (nos hace ver rigurosos)

28. ¿Por qué el script de creación fija `NLS_DATE_FORMAT`? *(Respuesta: los literales de
    fecha están en DD/MM/YYYY, pero el formato por defecto de Oracle suele ser DD-MON-RR;
    sin el ajuste, todos los INSERT de fecha fallan con ORA-01843 y la base queda vacía.
    Lo detectamos al cargar en una instalación limpia.)*
29. ¿Cómo verificaron que el proceso realmente funciona? *(Respuesta: lo ejecutamos en
    Oracle 21c XE, confirmamos 38 multas y 24 registros de historial, y capturamos las
    salidas de consola en la carpeta `evidencia/`.)*

## Recomendaciones para el día

- No leer las diapositivas. Están hechas para apoyar, no para recitar.
- Si muestran código, señalar la parte específica que están explicando.
- Tener SQL Developer abierto por si piden ejecutar algo en vivo.
- Si no saben una respuesta, es mejor decir "no lo verificamos, lo asumimos" que inventar.
  Varias decisiones del proyecto son supuestos del equipo y está bien reconocerlo.
