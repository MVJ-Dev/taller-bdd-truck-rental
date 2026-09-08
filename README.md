# BDY1103 · Proceso de Cierre de Arriendos (TRUCK_RENTAL)

Evaluación Parcial N°1 — Taller de Base de Datos.
Procesos PL/SQL de cierre para la base de datos TRUCK_RENTAL.

**Integrantes:** Mathias Von Jentschy · Nelson Carrasco · Juan Serna · Barbara Bustamante

## ¿De qué se trata?

La base de datos TRUCK_RENTAL contiene dos tablas que existen pero están **vacías**:
`MULTA_ARRIENDO` e `HIST_ARRIENDO_ANUAL_CAMION`. No hay ningún proceso que las alimente.

Este proyecto construye ese proceso de cierre con PL/SQL:

| Proceso | Qué hace | Tabla destino |
|---|---|---|
| **A** | Calcula y registra las multas por atraso en la devolución de camiones | `MULTA_ARRIENDO` |
| **B** | Genera el historial anual de veces arrendado por camión | `HIST_ARRIENDO_ANUAL_CAMION` |

## Estructura del repositorio

```
sql/
  00_setup/      Scripts de creación de la BD y ajustes de estructura
  01_procesos/   Los dos procesos principales (entregables técnicos)
  02_pruebas/    Bloque de verificación sin INSERT (seguro de re-ejecutar)
docs/            Informe, guía de presentación, resultados esperados y diagrama
entregables/     Informe (.docx) y presentación (.pptx) para la entrega
evidencia/       Salidas de consola reales capturadas de la ejecución
```

## Cómo levantar el proyecto desde cero

Requisitos: Oracle Database 21c XE y SQL Developer, conectado con el usuario `TRUCK_RENTAL`.

> **Importante — SET SERVEROUTPUT ON:** actívalo en SQL Developer o no verás la salida de
> `DBMS_OUTPUT`, que es donde está toda la evidencia del proceso. Los scripts ya incluyen
> `SET SERVEROUTPUT ON`, pero conviene tenerlo activo en la sesión.

Ejecutar **en este orden**:

1. `sql/00_setup/01_creacion_y_poblado_truck_rental.sql`
   Crea todas las tablas y carga los datos de prueba.
   **Ya incluye `ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY'` al inicio** — sin eso,
   los INSERT de fecha fallan y las tablas quedan vacías (ver "Decisiones de diseño").

2. `sql/00_setup/02_alter_multa_arriendo.sql`
   Rediseña la PK de `MULTA_ARRIENDO` para permitir un registro por arriendo.

3. `sql/01_procesos/proceso_a_liquidacion_multas.sql`
   Editar la constante `v_anno` antes de cada corrida. Ejecutar una vez por año (2025, 2026).

4. `sql/01_procesos/proceso_b_historial_anual.sql`
   Igual que el anterior: editar `v_anno` y ejecutar una vez por año.

## Verificar que quedó bien

```sql
SELECT COUNT(*) FROM MULTA_ARRIENDO;                  -- esperado: 38
SELECT COUNT(*) FROM HIST_ARRIENDO_ANUAL_CAMION;      -- esperado: 24

SELECT anno_mes_proceso, COUNT(*)
FROM MULTA_ARRIENDO GROUP BY anno_mes_proceso ORDER BY 1;
```

Resultados completos verificados en `docs/resultados-esperados.md`.

## Decisiones de diseño (esto es lo que hay que saber defender)

### 1. El script fija el formato de fecha (portabilidad)

Los datos de prueba usan fechas en formato `DD/MM/YYYY`. Oracle interpreta esos literales
según el parámetro de sesión `NLS_DATE_FORMAT`, que por defecto suele ser `DD-MON-RR`.
Sin ajustarlo, **todos los INSERT con fecha fallan** (`ORA-01843`) y las tablas quedan
vacías. Por eso el script 01 antepone `ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY'`,
haciendo el poblado portable a cualquier máquina.

### 2. Los tramos de multa son una regla propia del equipo

La base de datos **no tiene** ninguna tabla de tarifas de multa, y el enunciado no
especifica cómo calcularla. El equipo definió estos tramos:

| Días de atraso | % diario sobre `valor_arriendo_dia` |
|---|---|
| 1 a 3 | 5 % |
| 4 a 7 | 10 % |
| 8 o más | 15 % |

Como no está parametrizada, se modela en memoria con un **VARRAY** cargado una sola vez
al inicio del bloque.

### 3. Se rediseñó la PK de MULTA_ARRIENDO

La PK original era `(anno_mes_proceso, nro_patente)`: un solo registro por camión y mes.
Eso obligaba a descartar arriendos con atraso del mismo camión en el mismo mes, perdiendo
información real de cobro. Se agregó `id_arriendo` como nueva PK, con FK hacia
`ARRIENDO_CAMION`. Ahora cada arriendo con atraso queda registrado individualmente.

### 4. El historial anual excluye camiones sin uso

Solo se insertan camiones con al menos un arriendo en el año. De los 25 camiones de la
flota, 12 tuvieron arriendos en 2025 y 12 en 2026 (13 excluidos cada año).

## Elementos PL/SQL exigidos y dónde están

| Requisito | Dónde |
|---|---|
| RECORD | `r_tramo_multa`, `r_liquidacion` (Proceso A) |
| VARRAY | `v_tramos` (Proceso A) |
| Cursor **sin** parámetro | `c_camiones` (Proceso B) |
| Cursor **con** parámetro | `c_arriendos(p_anno)` (A), `c_arriendos_camion(p_patente, p_anno)` (B) |
| Más de un loop simultáneo | Loop principal + búsqueda en VARRAY (A); cursor externo + interno (B) |
| Excepción Oracle | `DUP_VAL_ON_INDEX` (ambos procesos) |
| Excepción propia | `e_fecha_devolucion_invalida` (Proceso A) |

## Hallazgos reales en los datos (sirven de evidencia)

- **Arriendo 104** (patente BC1002): `fecha_devolucion` (05/02/2026) anterior a
  `fecha_ini_arriendo` (25/02/2026). Capturado por la excepción propia
  `e_fecha_devolucion_invalida`.
- **Arriendo 4** (patente BT1002, 2025): 31 días de atraso → multa $111.600.
- **4 camiones con `valor_garantia_dia` en NULL**: `ASEE11`, `ASEW11`, `ASEZ11`, `OPDD23`.
  El proceso los maneja sin problema (la columna admite nulos).
- **Re-ejecución segura:** reejecutar un año ya procesado dispara `DUP_VAL_ON_INDEX` en
  cada fila y omite los duplicados sin romper el proceso.

## Estado del proyecto

- [x] Código verificado ejecutándose en Oracle 21c XE (38 multas, 24 registros de historial)
- [x] Fix de portabilidad (`NLS_DATE_FORMAT`) aplicado y documentado
- [x] Informe completo con evidencia real (`docs/informe.md`)
- [x] Guía de presentación con banco de preguntas (`docs/guia-presentacion.md`)
- [x] Evidencia de consola capturada (`evidencia/`)
- [ ] Completar docente y fecha en la portada del informe
- [ ] Pasar el contenido de `docs/informe.md` al `.docx` de entrega si el formato lo exige
- [ ] Repartir y ensayar la exposición (ver `docs/guia-presentacion.md`)

## Nota para el equipo

La evaluación es **individual en ambas situaciones**, aunque el trabajo sea grupal.
Cada integrante debe poder explicar el proyecto completo, no solo la parte que programó
o redactó. La presentación pesa el 60% de la nota.
