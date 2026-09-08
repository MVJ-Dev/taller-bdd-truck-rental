/* ============================================================
   BDY1103 - Taller de Base de Datos - Evaluacion Parcial N°1
   Caso: Proceso de Cierre de Arriendos - TRUCK_RENTAL
   Script 02: Ajuste de diseno de la tabla MULTA_ARRIENDO

   ------------------------------------------------------------
   DECISION DE DISENO DEL EQUIPO (justificada en el informe 4.5):

   La PK original de MULTA_ARRIENDO era (anno_mes_proceso,
   nro_patente): permitia UN solo registro por camion y mes.
   Eso obligaba a descartar arriendos con atraso de un mismo
   camion en el mismo mes, perdiendo informacion real de cobro.

   Se agrega la columna id_arriendo (referencia directa al
   arriendo real) y se redefine la PK sobre ella, de modo que
   cada arriendo con atraso quede registrado individualmente,
   con trazabilidad e integridad hacia ARRIENDO_CAMION via FK.
   ============================================================ */

-- 1) Eliminar la PK actual (anno_mes_proceso + nro_patente)
ALTER TABLE MULTA_ARRIENDO DROP CONSTRAINT PK_MULTA_ARRIENDO;

-- 2) Agregar la columna id_arriendo (identifica el arriendo real)
ALTER TABLE MULTA_ARRIENDO ADD id_arriendo NUMBER(7);

-- 3) Nueva PK: un registro unico por arriendo
ALTER TABLE MULTA_ARRIENDO
    ADD CONSTRAINT PK_MULTA_ARRIENDO PRIMARY KEY (id_arriendo);

-- 4) FK hacia ARRIENDO_CAMION, para mantener trazabilidad e integridad
ALTER TABLE MULTA_ARRIENDO
    ADD CONSTRAINT fk_multa_arriendo_arriendo FOREIGN KEY (id_arriendo)
        REFERENCES ARRIENDO_CAMION (id_arriendo);

-- Verificacion de la nueva estructura
DESCRIBE MULTA_ARRIENDO;
