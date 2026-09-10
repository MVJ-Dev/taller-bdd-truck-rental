# Contexto — Proyecto BDY1103 (Taller de Base de Datos) · TRUCK_RENTAL
*Última actualización: 10 de septiembre de 2026*

## Qué es este proyecto (NO es preventa AWS)

Evaluación académica de **Oracle PL/SQL**, asignatura **BDY1103 - Taller de Base de Datos**
(instituto chileno, tipo Duoc UC). Evaluación Parcial N°1. NO es un caso de migración ni
preventa AWS — mi rol aquí es como conocedor de PL/SQL/bases de datos, no arquitecto AWS.

**Solicitante:** Mathias Von Jentschy (uno de los integrantes del equipo).

## El caso elegido por el equipo

Base de datos TRUCK_RENTAL (arriendo de camiones). Dos tablas existen pero están VACÍAS:
`MULTA_ARRIENDO` e `HIST_ARRIENDO_ANUAL_CAMION`. El proyecto es un "proceso de cierre" en
PL/SQL que las puebla:
- **Proceso A:** calcula multas por atraso en la devolución → `MULTA_ARRIENDO`.
- **Proceso B:** historial anual de veces arrendado por camión → `HIST_ARRIENDO_ANUAL_CAMION`.

## Integrantes

Mathias Von Jentschy · Nelson Carrasco · Juan Serna · Barbara Bustamante.
⚠️ Son 4, pero la rúbrica dice "equipos de máximo 3". Tema administrativo pendiente de ellos.

## Qué pide la evaluación (rúbrica)

- Vale 30% del semestre. Interno: **Informe 40% / Presentación 60%** (presentación pesa más).
- Evaluación **individual** en ambas situaciones: cada integrante defiende TODO el proyecto.
- Elementos PL/SQL obligatorios: RECORD, VARRAY, cursores explícitos (con y sin parámetro),
  loops anidados, excepciones (Oracle + propia).
- Sección de mayor peso individual (15% informe + 15% presentación): **evaluar uso FUTURO**
  de procedures, functions, packages y triggers (solo proponer, NO programar).
- Error #1 que castigan: conceptos/código sin conectar a una necesidad de negocio real.

## Estado: COMPLETADO y VERIFICADO (8-9 sept 2026)

### Repositorio (privado)
👉 **https://github.com/MVJ-Dev/taller-bdd-truck-rental** (PRIVATE, branch master, commit 118a2d5).
Local sincronizado en: `/home/mathias-von/Documents/clientes/taller-bdd-truck-rental/`

### Verificación real en Oracle 21c XE (Docker)
- Contenedor `oracle-bdy1103`, puerto host **1522**, usuario `TRUCK_RENTAL`/`truck123`, PDB `XEPDB1`.
  (OJO: hay OTRO Oracle en 1521. Apagar con `docker rm -f oracle-bdy1103` cuando no se use.)
- Ejecutado el conjunto completo desde cero → "OK: 38 multas y 24 historial - PROYECTO VERIFICADO".
- Números: MULTA_ARRIENDO=38 (2025:17, 2026:21) · HIST=24 (12+12).

### BUG CRÍTICO encontrado y corregido
El script de creación NO cargaba nada en Oracle estándar: literales de fecha en `DD/MM/YYYY`
pero `NLS_DATE_FORMAT` por defecto es `DD-MON-RR` → 218 ORA-01843 + cascada de FK → tablas vacías.
**Fix:** se antepuso `ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY'` al script 01. Ahora es portable.

### Otras correcciones aplicadas
- Los 5 scripts reescritos en UTF-8 limpio (originales tenían acentos corruptos tipo `diseÃ±o`).
- Comentario de `DUP_VAL_ON_INDEX` corregido: SÍ se dispara al reejecutar (el original decía "no debería").
- Justificación del VARRAY(5) con 3 tramos agregada.
- Cálculo de `dias_atraso` refactorizado (idéntico algebraicamente, verificado que da lo mismo).
- Rediseño de PK de MULTA_ARRIENDO a `id_arriendo` (ya venía del equipo, se documentó bien).

### Datos clave del caso (para defensa)
- Excepción propia la dispara **arriendo 104** (patente BC1002, inicio 25/02/2026, dev 05/02/2026).
- Arriendo 4 (BT1002, 2025): 31 días atraso → multa $111.600 (el mayor).
- 4 camiones con `valor_garantia_dia` NULL: ASEE11, ASEW11, ASEZ11, OPDD23 (columna admite nulos).
- Tramos multa (regla propia del equipo, no viene del enunciado): 1-3 días=5%, 4-7=10%, 8+=15%.

### Estructura del repo (20 archivos)
- `sql/00_setup/` (01 creación+poblado con fix NLS, 02 alter PK)
- `sql/01_procesos/` (proceso A multas, proceso B historial)
- `sql/02_pruebas/` (test conteo sin INSERT)
- `docs/` (informe.md completo, guia-presentacion.md, resultados-esperados.md, diagrama PNG)
- `evidencia/` (6 .txt de salidas reales de consola)
- `entregables/` (.docx y .pptx ORIGINALES, sin actualizar)

## Rúbrica: mapeo verificado (todo ✅)
RECORD (r_tramo_multa, r_liquidacion) · VARRAY (va_multa) · cursor sin param (c_camiones) ·
cursores con param (c_arriendos, c_arriendos_camion) · loops anidados (4 por proceso) ·
DUP_VAL_ON_INDEX · e_fecha_devolucion_invalida · sección 4.5 con proc/func/pkg/triggers.
Informe con 7 secciones (4.1-4.7).

## PENDIENTES (lo que NO está 100%)
1. **`.docx` y `.pptx` de `entregables/` son los ORIGINALES sin actualizar.** El contenido
   correcto está en los `.md`. Si el profe exige Word/PPT formal → volcar contenido de
   `docs/informe.md` y `docs/guia-presentacion.md` a esos binarios. (Kiro no editó los binarios.)
2. Faltan **docente y fecha** en portada del informe (placeholders).
3. Mathias aún NO confirmó que corre en SU SQL Developer (solo verificado en Docker).
4. Tema administrativo: 4 integrantes vs "máximo 3" de la rúbrica.
5. Preparar/ensayar la defensa individual (60% de la nota). Banco de preguntas en guia-presentacion.md.

## Próximos pasos sugeridos
- Que Mathias corra los scripts en su SQL Developer (localhost:1522, XEPDB1, o su propia instancia).
- Decidir si se vuelca el contenido a .docx/.pptx.
- Ensayar defensa con el banco de preguntas.
