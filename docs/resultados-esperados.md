# Resultados esperados de la ejecución

Valores obtenidos en la ejecución de referencia, **verificados en Oracle Database 21c XE**
(septiembre 2026). Sirven para confirmar que el proceso corrió correctamente en otra
máquina.

> **Requisito de portabilidad:** el script `01_creacion` fija
> `ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY'` al inicio. Sin ese ajuste, en una
> instalación con `NLS_DATE_FORMAT` distinto (ej. `DD-MON-RR`) los INSERT de fecha
> fallan y las tablas quedan vacías. Con el ajuste, carga: **107 arriendos, 25 camiones,
> 111 clientes, 23 empleados**.
>
> **Años:** los datos usan `EXTRACT(YEAR FROM SYSDATE)`, por lo que los años concretos
> dependen de cuándo se cargó la base. En la ejecución verificada fueron **2025 y 2026**.

## Conteo final de ambas tablas

```
TOTAL_MULTAS  TOTAL_HIST
------------  ----------
         38          24
```

## Proceso A — MULTA_ARRIENDO

Total de registros: **38**

Resumen por año:

| Año | Con multa | Sin atraso | Inconsistencias | Omitidos (sin devolver) |
|---|---|---|---|---|
| 2025 | 17 | 37 | 0 | 0 |
| 2026 | 21 | 31 | 1 (arriendo 104) | 0 |

Distribución por período:

| anno_mes_proceso | Registros |
|---|---|
| 202503 | 9 |
| 202504 | 2 |
| 202505 | 1 |
| 202507 | 1 |
| 202508 | 1 |
| 202509 | 3 |
| 202602 | 5 |
| 202603 | 5 |
| 202604 | 2 |
| 202605 | 1 |
| 202607 | 4 |
| 202608 | 4 |

Casos destacados verificados:
- **Arriendo 104** (patente BC1002): inicio 25/02/2026, devolución 05/02/2026 →
  dispara la excepción propia `e_fecha_devolucion_invalida`.
- **Arriendo 4** (patente BT1002, 2025): 31 días de atraso → tramo 15% → multa $111.600
  (el atraso más alto del conjunto).
- Tramos verificados: 1 día = 5%, 5 días = 10%, 11-13 días = 15%.

## Proceso B — HIST_ARRIENDO_ANUAL_CAMION

Total de registros: **24** (12 camiones por año).

Veces arrendado por camión:

| Patente | 2025 | 2026 |
|---|---|---|
| AA1001 | 3 | 6 |
| AHEW11 | 5 | 7 |
| AQDD04 | 4 | 4 |
| ASEZ11 | 3 | 4 |
| AZ1001 | 5 | 3 |
| BC1002 | 2 | 3 |
| BE1002 | 5 | 4 |
| BT1002 | 1 | 2 |
| FG1001 | 3 | 2 |
| TY1003 | 12 | 8 |
| VR1003 | 6 | 7 |
| WE1002 | 5 | 3 |

Camiones excluidos por no tener arriendos en el año: **13 de 25** en ambos años.

## Prueba de re-ejecución (DUP_VAL_ON_INDEX)

Reejecutar el Proceso A para un año ya procesado dispara `DUP_VAL_ON_INDEX` en cada fila
ya existente, informa "ya existía ... se omite (reejecución)" y **termina sin abortar**.
El cierre es re-ejecutable de forma segura.
