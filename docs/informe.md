# BDY1103 - Taller de Base de Datos
## Evaluación Parcial N°1 - Informe
### Caso: Proceso de Cierre de Arriendos - TRUCK_RENTAL

**Integrantes:**
- Mathias Von Jentschy
- Nelson Carrasco
- Juan Serna
- Barbara Bustamante

**Asignatura:** BDY1103 - Taller de Base de Datos
**Evaluación:** Parcial N°1 (Informe 40% + Presentación 60%)
**Docente:** _______________________
**Fecha:** _______________________

---

## 4.1 Introducción

### Descripción del proyecto

La empresa modelada en la base de datos TRUCK_RENTAL arrienda camiones a clientes por
un número determinado de días. Al analizar el esquema, el equipo identificó dos tablas
existentes pero **vacías**: `MULTA_ARRIENDO` e `HIST_ARRIENDO_ANUAL_CAMION`. No existía
ningún proceso que las alimentara. Esto llevó a definir el caso como un **proceso de
cierre**, cuyo objetivo es poblar ambas tablas a partir de los datos reales de
`ARRIENDO_CAMION` y `CAMION`, usando PL/SQL para:

1. Calcular y registrar las multas por atraso en la devolución de camiones (**Proceso A**).
2. Generar el historial anual de uso por camión (**Proceso B**).

PL/SQL contribuye a resolver esta necesidad porque permite procesar los arriendos
**registro por registro**, aplicando reglas de negocio (tramos de multa, agrupación
por camión/año) que no se resuelven con una sola sentencia SQL, y controlando errores
de forma explícita durante el procesamiento.

### Alcance

El proyecto abarca:
- Liquidación de multas por atraso, por arriendo individual (Proceso A).
- Historial anual de uso por camión, solo para camiones efectivamente arrendados en
  el período (Proceso B).

Queda fuera del alcance de esta primera entrega — y se propone como estrategia futura
en la sección 4.5 — el análisis de clientes con arriendos bajo el promedio y cualquier
proceso relacionado con `PROY_MOVILIZACION` o `USUARIO_CLAVE`, que corresponden a
otros procesos de negocio no relacionados directamente con arriendos.

### Tecnologías utilizadas

- Oracle Database 21c XE
- PL/SQL (bloques anónimos)
- Oracle SQL Developer

### Nota sobre el proceso de trabajo (hallazgo técnico real)

> Durante el desarrollo, el equipo detectó que el script de creación y poblado
> **no cargaba los datos en una instalación estándar de Oracle**: los literales de
> fecha están en formato `DD/MM/YYYY` (ej. `'18/08/1971'`), pero el parámetro de
> sesión `NLS_DATE_FORMAT` por defecto suele ser `DD-MON-RR`. Esto provocaba que
> **todos** los INSERT con fecha fallaran (`ORA-01843: not a valid month`), y en
> cascada fallaran las claves foráneas de camiones y arriendos, dejando la base vacía.
>
> La corrección aplicada fue anteponer `ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';`
> al inicio del script. Con este ajuste, el poblado se vuelve **portable**: carga
> correctamente en cualquier máquina (107 arriendos, 25 camiones, 111 clientes,
> 23 empleados) sin depender de la configuración regional del cliente Oracle. Se
> documenta porque forma parte real del trabajo técnico realizado.

---

## 4.2 Tipos de datos compuestos (RECORD y VARRAY)

### Cómo se integran en el proyecto

En el **Proceso A** se usan tres tipos compuestos:

- `r_tramo_multa` (RECORD): agrupa `dia_ini`, `dia_fin` y `pct_diario` — representa
  un tramo de la tabla de tarifas de multa.
- `v_tramos` (VARRAY de `r_tramo_multa`): almacena los tramos definidos por el equipo
  como regla de negocio (ver justificación abajo).
- `r_liquidacion` (RECORD): agrupa todos los datos de un arriendo durante su
  procesamiento (id, patente, fechas, valor día, días de atraso y monto de multa).

### Aporte al procesamiento

**No existe en la base de datos** una tabla con tarifas de multa. El enunciado del
caso tampoco la especifica. Por eso el equipo definió los siguientes tramos como
**regla de negocio propia**:

| Días de atraso | % diario sobre valor arriendo/día |
|---|---|
| 1 a 3 | 5% |
| 4 a 7 | 10% |
| 8 o más | 15% |

Como esta tarifa no está parametrizada en una tabla, se modela como una estructura
en **memoria** (VARRAY) cargada una sola vez al iniciar el proceso, evitando consultar
la regla repetidamente dentro del loop. El `RECORD` de liquidación evita manejar 8
variables sueltas por cada arriendo, agrupándolas en una sola estructura lógica.

> **Por qué el VARRAY se declara de tamaño 5 usando solo 3 tramos:** se dejó margen
> intencional para incorporar tramos futuros (por ejemplo, separar atrasos muy largos
> en un tramo adicional) sin tener que modificar la declaración del tipo. El `VARRAY`
> exige un tope máximo al declararlo; 5 es un límite holgado y realista para esta
> regla de negocio.

### Apoyo visual

Flujo conceptual del Proceso A:

```
ARRIENDO_CAMION + CAMION  ──►  RECORD r_liquidacion  ──►  INSERT en MULTA_ARRIENDO
   (cursor c_arriendos)          (datos en proceso)
                                        ▲
                                        │ consulta el tramo aplicable
                                 VARRAY v_tramos
                              (catálogo de multas en memoria)
```

---

## 4.3 Bloques PL/SQL con cursores explícitos complejos

### Concepto

Un cursor explícito es un área de trabajo que PL/SQL reserva para ejecutar y recorrer
el resultado de una consulta SQL fila por fila, cuando esa consulta puede devolver más
de una fila (a diferencia de un `SELECT ... INTO`, que solo sirve para exactamente una
fila).

### Tipos de cursor y parámetros

- **Cursor SIN parámetro** — `c_camiones` (Proceso B): recorre toda la flota de camiones.
  No necesita filtro externo, siempre trae los mismos camiones.
- **Cursores CON parámetro** — permiten reutilizar la misma definición con distintos
  valores de entrada:
  - `c_arriendos(p_anno NUMBER)` (Proceso A): filtra arriendos por año.
  - `c_arriendos_camion(p_patente VARCHAR2, p_anno NUMBER)` (Proceso B): filtra los
    arriendos de un camión específico en un año específico.

### Loops anidados (más de un loop simultáneo)

- **Proceso A**: el loop principal recorre los arriendos con `OPEN`/`FETCH`/`CLOSE`
  explícito; **dentro** de cada iteración, un segundo loop (`FOR i IN 1..v_tramos.COUNT`)
  recorre el VARRAY de tramos buscando el aplicable a los días de atraso.
- **Proceso B**: un cursor externo (`FOR rec_camion IN c_camiones`) recorre los camiones;
  **dentro** de cada camión se abre el cursor con parámetro `c_arriendos_camion` y se
  cuentan sus filas — dos cursores trabajando en simultáneo (anidados).

### Aplicación al proyecto

Cada cursor resuelve un problema concreto: `c_arriendos` permite "cerrar" cualquier año
solo cambiando el parámetro, sin tocar el resto del código; `c_arriendos_camion` deja
que Oracle filtre los arriendos de cada camión de forma eficiente, en vez de traerlos
todos a PL/SQL y filtrarlos a mano.

### Ventajas

Permiten procesar grandes volúmenes de registros fila por fila, aplicando lógica de
negocio (cálculos, validaciones, decisiones de inserción) que una sola sentencia SQL
no puede resolver — y con control total sobre los errores de cada fila (ver 4.4).

---

## 4.4 Integración del control de excepciones

### Excepciones predefinidas por Oracle

Se usó `DUP_VAL_ON_INDEX`, que Oracle dispara automáticamente ante una violación de
clave primaria o índice único (`ORA-00001`). En el proyecto **se dispara realmente al
reejecutar el proceso para un año ya procesado**: el `id_arriendo` (Proceso A) o la PK
`(anno_proceso, nro_patente)` (Proceso B) ya existen. En lugar de que el bloque falle
completo, cada fila duplicada se detecta, se informa y se omite, dejando el cierre
**re-ejecutable de forma segura**.

> **Evidencia real:** al reejecutar el Proceso A para 2025 (con los 17 registros ya
> insertados), el bloque capturó `DUP_VAL_ON_INDEX` para cada uno de los 17 arriendos,
> informó "ya existía en MULTA_ARRIENDO, se omite (reejecución)" y terminó sin abortar.
> Ver anexo 7.2, archivo `salida_reejecucion_dup_val.txt`.

### Excepciones definidas por el usuario

Se definió `e_fecha_devolucion_invalida`, disparada cuando `fecha_devolucion` es
anterior a `fecha_ini_arriendo` — una inconsistencia de datos que no debería ocurrir,
pero que **se detectó realmente en los datos**: el arriendo **104** (patente `BC1002`)
tiene fecha de inicio `25/02/2026` y fecha de devolución `05/02/2026`, es decir, el
camión aparece "devuelto" 20 días antes de arrendarse. Esta excepción no representa un
error de programación, sino una **regla de integridad de negocio** que Oracle no valida
por sí solo.

### Integración

Ambas excepciones se manejan dentro de un bloque `BEGIN...EXCEPTION...END` **interno**,
anidado dentro del loop principal de cada proceso. Así, un problema en **un solo
arriendo o camión** no interrumpe el procesamiento de los demás. Se agregó además un
`WHEN OTHERS` como resguardo para cualquier error no anticipado.

### Justificación

Sin este control, un solo registro problemático (fecha inválida, reejecución accidental)
haría fallar el proceso completo, obligando a reiniciar desde cero. El manejo por fila
protege la integridad del cierre sin sacrificar la trazabilidad de los casos
problemáticos, que quedan explícitamente reportados en la salida.

---

## 4.5 Evaluación de procedimientos, funciones, packages y triggers

*(Esta sección es la de mayor ponderación individual del informe: 15%.)*

Actualmente ambos procesos son **bloques anónimos**: se ejecutan manualmente en SQL
Developer, no quedan almacenados en la base y no se pueden invocar desde otros
programas. La evolución natural del proyecto es encapsular esta lógica en objetos
almacenados. A continuación se evalúa cada uno.

### Procedimientos almacenados

Encapsularían cada proceso completo como un objeto invocable y parametrizado:

- `PROC_LIQUIDAR_MULTAS(p_anno NUMBER)` — reemplaza al bloque anónimo del Proceso A.
- `PROC_GENERAR_HISTORIAL(p_anno NUMBER)` — reemplaza al bloque anónimo del Proceso B.

**Qué resuelven:** eliminan la necesidad de editar la constante `v_anno` y correr el
bloque a mano. Se podrían ejecutar desde un job programado (`DBMS_SCHEDULER`) al cierre
de cada mes o año, de forma automática y sin intervención humana.

### Funciones almacenadas

Encapsularían un cálculo que **retorna un valor** y puede reutilizarse en consultas:

- `FN_CALCULAR_MULTA(p_dias_atraso NUMBER, p_valor_dia NUMBER) RETURN NUMBER` — devuelve
  el monto de multa aplicando la lógica de tramos. Hoy ese cálculo vive incrustado en
  el Proceso A; como función se podría reutilizar en un reporte de proyección de cobros
  o en una consulta ad-hoc, sin duplicar la lógica de búsqueda de tramos.

**Diferencia clave con un procedimiento:** una función **retorna un valor** y puede
usarse dentro de un `SELECT`; un procedimiento **ejecuta acciones** (como los INSERT)
y no retorna un valor directamente.

### Packages

Un `PKG_CIERRE_ARRIENDOS` agruparía en un solo objeto:
- Los dos procedimientos (`PROC_LIQUIDAR_MULTAS`, `PROC_GENERAR_HISTORIAL`).
- La función de cálculo (`FN_CALCULAR_MULTA`).
- Las constantes de negocio (los tramos de multa, hoy cargados en el VARRAY).

**Qué permiten:** separan la **especificación** (qué se expone públicamente) del
**cuerpo** (cómo se implementa). Concentran toda la lógica de cierre en un único punto
de mantenimiento; si cambian los tramos de multa, se modifica un solo lugar. Además,
el estado del package (variables de sesión) persiste durante la conexión.

### Triggers

Un trigger `BEFORE INSERT OR UPDATE` sobre `ARRIENDO_CAMION` podría validar
automáticamente que `fecha_devolucion` no sea anterior a `fecha_ini_arriendo`
**en el momento del registro**, no al cerrar el mes. Esto evitaría de raíz la
inconsistencia detectada en el arriendo 104: el dato malo nunca entraría a la tabla.

**Qué automatizan:** reglas que deben cumplirse siempre, ante cualquier `INSERT`,
`UPDATE` o `DELETE`, sin depender de que un proceso posterior las revise.

### Estrategia futura de integración

Se propone migrar en una segunda etapa del caso semestral, en este orden:
1. Convertir la lógica de tramos en `FN_CALCULAR_MULTA` (unidad más pequeña y reutilizable).
2. Convertir los bloques en `PROC_LIQUIDAR_MULTAS` y `PROC_GENERAR_HISTORIAL`.
3. Agrupar todo en `PKG_CIERRE_ARRIENDOS`.
4. Agregar el trigger de validación en `ARRIENDO_CAMION`.
5. Programar la ejecución automática con `DBMS_SCHEDULER`.

Se hace en este orden porque la lógica ya fue **validada como bloque anónimo** en esta
primera entrega, que es exactamente el paso previo recomendado antes de dejarla fija
en objetos almacenados.

### Ventajas y limitaciones

| Aspecto | Ventaja | Limitación / riesgo |
|---|---|---|
| Reutilización | Evita duplicar lógica en distintos scripts | Requiere gestionar versiones y permisos |
| Mantenimiento | Cambios centralizados (ej. tramos de multa) | Exige control de cambios más formal |
| Auditoría | Un trigger deja rastro automático de cada evento | Puede ocultar lógica si se abusa de triggers |
| Rendimiento | Objetos compilados son más rápidos que bloques anónimos repetidos | Mayor complejidad de diseño inicial |
| Seguridad | Se otorga permiso de ejecución sin dar acceso directo a las tablas | Requiere gestión de roles/privilegios |

---

## 4.6 Conclusión

### Resumen

El proyecto implementó dos procesos de cierre para TRUCK_RENTAL: liquidación de multas
por atraso (Proceso A) e historial anual de uso por camión (Proceso B), usando RECORD,
VARRAY, cursores explícitos con y sin parámetros, loops anidados, y excepciones tanto
predefinidas (`DUP_VAL_ON_INDEX`) como propias (`e_fecha_devolucion_invalida`) — todos
con datos reales de la base de datos y validados por ejecución.

### Impacto

El proceso entrega a la empresa información que antes no existía en ningún reporte:
el detalle de multas por cobrar (38 registros entre ambos años) y el uso anual de la
flota por camión (24 registros). Se genera de forma reproducible, auditable y
re-ejecutable de forma segura.

### Recomendaciones

- Migrar los bloques anónimos a objetos almacenados según la estrategia de la sección 4.5.
- Definir formalmente con el área de negocio real la tarifa de multa, reemplazando la
  regla propuesta por el equipo.
- Corregir en origen los datos inconsistentes (arriendo 104) y prevenirlos con un
  trigger de validación.
- Evaluar como siguiente etapa el análisis de clientes con arriendos bajo el promedio.

---

## 4.7 Anexos

### 7.1 Modelo de datos

Ver `docs/Diagrama_Modelo_TRUCK_RENTAL.png`. Tablas centrales del caso:
`ARRIENDO_CAMION`, `CAMION`, `MULTA_ARRIENDO`, `HIST_ARRIENDO_ANUAL_CAMION`.

### 7.2 Código completo

- `sql/00_setup/01_creacion_y_poblado_truck_rental.sql` — creación + poblado (con fix de NLS).
- `sql/00_setup/02_alter_multa_arriendo.sql` — rediseño de PK de MULTA_ARRIENDO.
- `sql/01_procesos/proceso_a_liquidacion_multas.sql` — Proceso A.
- `sql/01_procesos/proceso_b_historial_anual.sql` — Proceso B.
- `sql/02_pruebas/test_conteo_arriendos_por_camion.sql` — prueba sin INSERT.

### 7.3 Evidencia de ejecución (datos reales verificados)

Salidas completas en la carpeta `evidencia/`. Resumen de los resultados obtenidos:

**Conteo final de ambas tablas:**

```
TOTAL_MULTAS  TOTAL_HIST
------------  ----------
         38          24
```

**Proceso A — resumen por año:**

| Año | Con multa | Sin atraso | Inconsistencias | Omitidos |
|---|---|---|---|---|
| 2025 | 17 | 37 | 0 | 0 |
| 2026 | 21 | 31 | 1 (arriendo 104) | 0 |

**MULTA_ARRIENDO — distribución por período:**

| Período | Registros | | Período | Registros |
|---|---|---|---|---|
| 202503 | 9 | | 202602 | 5 |
| 202504 | 2 | | 202603 | 5 |
| 202505 | 1 | | 202604 | 2 |
| 202507 | 1 | | 202605 | 1 |
| 202508 | 1 | | 202607 | 4 |
| 202509 | 3 | | 202608 | 4 |

**Excepción propia disparándose (Proceso A 2026):**

```
Arriendo 104: INCONSISTENCIA - fecha_devolucion anterior a fecha_ini_arriendo. No se procesa.
```

**Excepción Oracle DUP_VAL_ON_INDEX al reejecutar (Proceso A 2025):**

```
Arriendo 1: ya existia en MULTA_ARRIENDO, se omite (reejecucion).
Arriendo 3: ya existia en MULTA_ARRIENDO, se omite (reejecucion).
Arriendo 4: ya existia en MULTA_ARRIENDO, se omite (reejecucion).
... (los 17 registros de 2025) ...
```

**HIST_ARRIENDO_ANUAL_CAMION — veces arrendado por camión (2026):**

| Patente | Veces | | Patente | Veces |
|---|---|---|---|---|
| AA1001 | 6 | | BC1002 | 3 |
| AHEW11 | 7 | | BE1002 | 4 |
| AQDD04 | 4 | | BT1002 | 2 |
| ASEZ11 | 4 | | FG1001 | 2 |
| AZ1001 | 3 | | TY1003 | 8 |
| VR1003 | 7 | | WE1002 | 3 |

De los 25 camiones de la flota, 12 tuvieron arriendos en 2026 (13 excluidos por no
tener uso). Nota: 4 camiones tienen `valor_garantia_dia` en NULL (`ASEE11`, `ASEW11`,
`ASEZ11`, `OPDD23`); el proceso los maneja sin problema porque la columna admite nulos.

> Nota sobre los años: los datos se generan con `EXTRACT(YEAR FROM SYSDATE)`, por lo que
> los años concretos dependen de cuándo se carga la base. En la ejecución verificada
> (septiembre 2026) los años fueron **2025 y 2026**.
