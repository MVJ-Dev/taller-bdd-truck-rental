/* ============================================================
   BDY1103 - Taller de Base de Datos - Evaluacion Parcial N°1
   Caso: Proceso de Cierre de Arriendos - TRUCK_RENTAL
   Prueba: conteo de arriendos por camion (Proceso B)

   Bloque de verificacion SIN INSERT: solo muestra por pantalla
   cuantas veces se arrendo cada camion en el ano indicado.
   Es seguro re-ejecutarlo cuantas veces se quiera, porque no
   modifica ninguna tabla. Sirvio para validar la logica del
   Proceso B antes de escribir los INSERT definitivos.
   ============================================================ */

SET SERVEROUTPUT ON;

ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';

DECLARE

    v_anno CONSTANT NUMBER := 2026;  -- <== cambia aqui el ano a probar

    /* Cursor externo: recorre todos los camiones de la flota */
    CURSOR c_camiones IS
        SELECT nro_patente, valor_arriendo_dia, valor_garantia_dia
        FROM   CAMION
        ORDER BY nro_patente;

    /* Cursor interno CON PARAMETRO: arriendos de un camion en un ano */
    CURSOR c_arriendos_camion(p_patente VARCHAR2, p_anno NUMBER) IS
        SELECT id_arriendo
        FROM   ARRIENDO_CAMION
        WHERE  nro_patente = p_patente
        AND    EXTRACT(YEAR FROM fecha_ini_arriendo) = p_anno;

    v_total_veces NUMBER;

BEGIN

    /* Loop externo: un camion a la vez */
    FOR rec_camion IN c_camiones LOOP

        v_total_veces := 0;

        /* Loop interno anidado: cuenta arriendos de ESE camion en el ano */
        FOR rec_arriendo IN c_arriendos_camion(rec_camion.nro_patente, v_anno) LOOP
            v_total_veces := v_total_veces + 1;
        END LOOP;

        DBMS_OUTPUT.PUT_LINE(
            'Camion ' || rec_camion.nro_patente ||
            ' | Valor arriendo/dia: ' || rec_camion.valor_arriendo_dia ||
            ' | Veces arrendado en ' || v_anno || ': ' || v_total_veces
        );

    END LOOP;

END;
/
