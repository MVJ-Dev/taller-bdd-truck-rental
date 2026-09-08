/* ============================================================
   BDY1103 - Taller de Base de Datos - Evaluacion Parcial N°1
   Caso: Proceso de Cierre de Arriendos - TRUCK_RENTAL
   Proceso B: Historial anual de veces arrendado por camion

   Puebla HIST_ARRIENDO_ANUAL_CAMION. Por decision del equipo,
   solo se incluyen los camiones con AL MENOS un arriendo en el
   ano procesado (los camiones sin uso no generan historial).

   Elementos PL/SQL evidenciados en este bloque:
     - Cursor explicito SIN parametro: c_camiones (recorre flota)
     - Cursor explicito CON parametro: c_arriendos_camion(patente, ano)
     - Loops anidados: cursor FOR externo + cursor FOR interno
     - Excepcion Oracle: DUP_VAL_ON_INDEX (reejecucion segura)
   ------------------------------------------------------------
   USO: cambiar la constante v_anno antes de cada corrida y
        ejecutar una vez por ano (2025, 2026, ...).
   ============================================================ */

SET SERVEROUTPUT ON;

ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';

DECLARE

    /* ==> CAMBIA ESTE VALOR ANTES DE CADA CORRIDA <== */
    v_anno CONSTANT NUMBER := 2026;

    /* Cursor externo SIN parametro: recorre todos los camiones */
    CURSOR c_camiones IS
        SELECT nro_patente, valor_arriendo_dia, valor_garantia_dia
        FROM   CAMION
        ORDER BY nro_patente;

    /* Cursor interno CON PARAMETRO: arriendos de un camion en un ano.
       Deja que Oracle filtre por camion y ano de forma eficiente,
       en vez de traer todos los arriendos y filtrarlos en PL/SQL. */
    CURSOR c_arriendos_camion(p_patente VARCHAR2, p_anno NUMBER) IS
        SELECT id_arriendo
        FROM   ARRIENDO_CAMION
        WHERE  nro_patente = p_patente
        AND    EXTRACT(YEAR FROM fecha_ini_arriendo) = p_anno;

    v_total_veces         NUMBER;
    v_contador_insertados NUMBER := 0;
    v_contador_sin_uso    NUMBER := 0;

BEGIN

    /* Loop externo: un camion a la vez */
    FOR rec_camion IN c_camiones LOOP

        v_total_veces := 0;

        /* Loop interno anidado: cuenta los arriendos de ESE camion
           en el ano. Dos cursores trabajando en simultaneo. */
        FOR rec_arriendo IN c_arriendos_camion(rec_camion.nro_patente, v_anno) LOOP
            v_total_veces := v_total_veces + 1;
        END LOOP;

        BEGIN  -- bloque interno: aisla el error de UN camion del resto

            IF v_total_veces = 0 THEN
                v_contador_sin_uso := v_contador_sin_uso + 1;
                DBMS_OUTPUT.PUT_LINE('Camion ' || rec_camion.nro_patente ||
                    ': sin arriendos en ' || v_anno || ', no se incluye en el historial.');
            ELSE
                INSERT INTO HIST_ARRIENDO_ANUAL_CAMION (
                    anno_proceso, nro_patente, valor_arriendo_dia,
                    valor_garactia_dia, total_veces_arrendado
                ) VALUES (
                    v_anno, rec_camion.nro_patente, rec_camion.valor_arriendo_dia,
                    rec_camion.valor_garantia_dia, v_total_veces
                );

                v_contador_insertados := v_contador_insertados + 1;
                DBMS_OUTPUT.PUT_LINE('Camion ' || rec_camion.nro_patente ||
                    ': ' || v_total_veces || ' arriendos en ' || v_anno || ' -> insertado.');
            END IF;

        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                /* Excepcion Oracle: al reejecutar el mismo ano, la PK
                   (anno_proceso, nro_patente) ya existe. Se informa y
                   se omite, manteniendo el proceso re-ejecutable. */
                DBMS_OUTPUT.PUT_LINE('Camion ' || rec_camion.nro_patente ||
                    ': ya existia historial para ' || v_anno || ', se omite (reejecucion).');
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error inesperado con camion ' ||
                    rec_camion.nro_patente || ': ' || SQLERRM);
        END;

    END LOOP;

    DBMS_OUTPUT.PUT_LINE('--- Resumen del proceso, ano ' || v_anno || ' ---');
    DBMS_OUTPUT.PUT_LINE('Camiones insertados en historial: ' || v_contador_insertados);
    DBMS_OUTPUT.PUT_LINE('Camiones sin uso en el ano (excluidos): ' || v_contador_sin_uso);

    COMMIT;

END;
/
