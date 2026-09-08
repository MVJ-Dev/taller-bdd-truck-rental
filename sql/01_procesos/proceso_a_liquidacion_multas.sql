/* ============================================================
   BDY1103 - Taller de Base de Datos - Evaluacion Parcial N°1
   Caso: Proceso de Cierre de Arriendos - TRUCK_RENTAL
   Proceso A: Liquidacion de multas por atraso en la devolucion

   Puebla la tabla MULTA_ARRIENDO (un registro por arriendo, tras
   el rediseno de PK del script 02 que agrego id_arriendo).

   Elementos PL/SQL evidenciados en este bloque:
     - RECORD:  r_tramo_multa, r_liquidacion
     - VARRAY:  v_tramos (catalogo de tramos en memoria)
     - Cursor explicito CON parametro: c_arriendos(p_anno)
     - Loops anidados: loop principal (FETCH) + loop del VARRAY
     - Excepcion Oracle: DUP_VAL_ON_INDEX
     - Excepcion propia: e_fecha_devolucion_invalida

   NOTA DE NEGOCIO: la base de datos NO tiene una tabla de tarifas
   de multa y el enunciado no la especifica. Los tramos de abajo
   son una REGLA DE NEGOCIO DEFINIDA POR EL EQUIPO y se justifican
   asi en el informe (seccion 4.2).
   ------------------------------------------------------------
   USO: cambiar la constante v_anno antes de cada corrida y
        ejecutar una vez por ano (2025, 2026, ...).
   ============================================================ */

SET SERVEROUTPUT ON;

-- Fecha en formato DD/MM/YYYY para que EXTRACT y las comparaciones
-- de fecha se comporten igual en cualquier instalacion de Oracle.
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';

DECLARE

    /* ==> CAMBIA ESTE VALOR ANTES DE CADA CORRIDA <== */
    v_anno CONSTANT NUMBER := 2026;

    /* --- RECORD que describe un tramo de la tabla de multas --- */
    TYPE r_tramo_multa IS RECORD (
        dia_ini     NUMBER,
        dia_fin     NUMBER,
        pct_diario  NUMBER
    );

    /* --- VARRAY de tramos ---------------------------------------
       Se declara de tamano 5 aunque hoy solo se usan 3 tramos:
       deja margen para agregar tramos futuros (p.ej. separar
       atrasos muy largos) sin cambiar el tipo. Es una estructura
       en MEMORIA, cargada una sola vez antes del loop principal,
       para no consultar la regla de negocio en cada iteracion. */
    TYPE va_multa IS VARRAY(5) OF r_tramo_multa;
    v_tramos va_multa := va_multa();

    /* --- RECORD que agrupa los datos de un arriendo en proceso ---
       Evita manejar 8 variables sueltas por cada arriendo. */
    TYPE r_liquidacion IS RECORD (
        id_arriendo         ARRIENDO_CAMION.id_arriendo%TYPE,
        nro_patente         ARRIENDO_CAMION.nro_patente%TYPE,
        fecha_ini_arriendo  ARRIENDO_CAMION.fecha_ini_arriendo%TYPE,
        dias_solicitados    ARRIENDO_CAMION.dias_solicitados%TYPE,
        fecha_devolucion    ARRIENDO_CAMION.fecha_devolucion%TYPE,
        valor_arriendo_dia  CAMION.valor_arriendo_dia%TYPE,
        dias_atraso         NUMBER,
        valor_multa         NUMBER
    );
    v_liq r_liquidacion;

    /* --- Cursor explicito CON PARAMETRO: procesa por ano ---------
       El parametro permite "cerrar" cualquier ano sin reescribir
       el cursor. El JOIN trae el valor de arriendo/dia del camion,
       necesario para calcular la multa. */
    CURSOR c_arriendos(p_anno NUMBER) IS
        SELECT ac.id_arriendo,
               ac.nro_patente,
               ac.fecha_ini_arriendo,
               ac.dias_solicitados,
               ac.fecha_devolucion,
               c.valor_arriendo_dia
        FROM   ARRIENDO_CAMION ac
        JOIN   CAMION c ON c.nro_patente = ac.nro_patente
        WHERE  EXTRACT(YEAR FROM ac.fecha_ini_arriendo) = p_anno;

    v_pct_aplicado          NUMBER;
    v_encontro_tramo        BOOLEAN;
    v_contador_multas       NUMBER := 0;  -- arriendos con atraso -> insertados
    v_contador_sin_atraso   NUMBER := 0;  -- devueltos a tiempo
    v_contador_inconsist    NUMBER := 0;  -- fecha_devolucion < fecha_ini_arriendo
    v_contador_omitidos     NUMBER := 0;  -- aun no devueltos (fecha nula)

    /* --- Excepcion definida por el usuario ----------------------
       Regla de integridad de negocio que Oracle no valida solo. */
    e_fecha_devolucion_invalida EXCEPTION;

BEGIN

    /* Carga del VARRAY de tramos (una sola vez, antes del loop) */
    v_tramos.EXTEND; v_tramos(1).dia_ini := 1; v_tramos(1).dia_fin := 3;    v_tramos(1).pct_diario := 5;
    v_tramos.EXTEND; v_tramos(2).dia_ini := 4; v_tramos(2).dia_fin := 7;    v_tramos(2).pct_diario := 10;
    v_tramos.EXTEND; v_tramos(3).dia_ini := 8; v_tramos(3).dia_fin := 9999; v_tramos(3).pct_diario := 15;

    OPEN c_arriendos(v_anno);
    LOOP
        FETCH c_arriendos INTO
            v_liq.id_arriendo, v_liq.nro_patente, v_liq.fecha_ini_arriendo,
            v_liq.dias_solicitados, v_liq.fecha_devolucion, v_liq.valor_arriendo_dia;
        EXIT WHEN c_arriendos%NOTFOUND;

        BEGIN  -- bloque interno: aisla el error de UN arriendo del resto

            IF v_liq.fecha_devolucion IS NULL THEN
                -- El camion aun no se devuelve: no se puede liquidar todavia.
                v_contador_omitidos := v_contador_omitidos + 1;

            ELSIF v_liq.fecha_devolucion < v_liq.fecha_ini_arriendo THEN
                -- Inconsistencia de datos: se devuelve ANTES de arrendar.
                RAISE e_fecha_devolucion_invalida;

            ELSE
                /* Dias de atraso = dias reales de uso menos los dias
                   pactados. Positivo => devolvio tarde. */
                v_liq.dias_atraso := (v_liq.fecha_devolucion - v_liq.fecha_ini_arriendo)
                                     - v_liq.dias_solicitados;

                IF v_liq.dias_atraso <= 0 THEN
                    v_contador_sin_atraso := v_contador_sin_atraso + 1;
                ELSE
                    /* Loop interno anidado: recorre el VARRAY buscando
                       el tramo aplicable a los dias de atraso. */
                    v_encontro_tramo := FALSE;
                    FOR i IN 1 .. v_tramos.COUNT LOOP
                        IF v_liq.dias_atraso BETWEEN v_tramos(i).dia_ini AND v_tramos(i).dia_fin THEN
                            v_pct_aplicado := v_tramos(i).pct_diario;
                            v_encontro_tramo := TRUE;
                            EXIT;
                        END IF;
                    END LOOP;

                    v_liq.valor_multa := ROUND(v_liq.valor_arriendo_dia *
                                                (v_pct_aplicado / 100) * v_liq.dias_atraso);

                    INSERT INTO MULTA_ARRIENDO (
                        anno_mes_proceso, nro_patente, fecha_ini_arriendo,
                        dias_solicitado, fecha_devolucion, dias_atraso,
                        valor_multa, id_arriendo
                    ) VALUES (
                        TO_NUMBER(TO_CHAR(v_liq.fecha_ini_arriendo, 'YYYYMM')),
                        v_liq.nro_patente, v_liq.fecha_ini_arriendo,
                        v_liq.dias_solicitados, v_liq.fecha_devolucion,
                        v_liq.dias_atraso, v_liq.valor_multa, v_liq.id_arriendo
                    );

                    v_contador_multas := v_contador_multas + 1;

                    DBMS_OUTPUT.PUT_LINE(
                        'Arriendo ' || v_liq.id_arriendo ||
                        ' | Patente ' || v_liq.nro_patente ||
                        ' | Atraso: ' || v_liq.dias_atraso || ' dias' ||
                        ' | Tramo: ' || v_pct_aplicado || '%' ||
                        ' | Multa: $' || v_liq.valor_multa
                    );
                END IF;
            END IF;

        EXCEPTION
            WHEN e_fecha_devolucion_invalida THEN
                v_contador_inconsist := v_contador_inconsist + 1;
                DBMS_OUTPUT.PUT_LINE('Arriendo ' || v_liq.id_arriendo ||
                    ': INCONSISTENCIA - fecha_devolucion anterior a fecha_ini_arriendo. No se procesa.');
            WHEN DUP_VAL_ON_INDEX THEN
                /* Excepcion predefinida de Oracle (ORA-00001).
                   SE DISPARA al reejecutar el mismo ano: el id_arriendo
                   ya existe en MULTA_ARRIENDO. Se informa y se omite la
                   fila, de modo que el cierre es RE-EJECUTABLE de forma
                   segura sin abortar el proceso completo. */
                DBMS_OUTPUT.PUT_LINE('Arriendo ' || v_liq.id_arriendo ||
                    ': ya existia en MULTA_ARRIENDO, se omite (reejecucion).');
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error inesperado en arriendo ' ||
                    v_liq.id_arriendo || ': ' || SQLERRM);
        END;

    END LOOP;
    CLOSE c_arriendos;

    DBMS_OUTPUT.PUT_LINE('--- Resumen del proceso, ano ' || v_anno || ' ---');
    DBMS_OUTPUT.PUT_LINE('Arriendos con multa (insertados): ' || v_contador_multas);
    DBMS_OUTPUT.PUT_LINE('Arriendos sin atraso: ' || v_contador_sin_atraso);
    DBMS_OUTPUT.PUT_LINE('Arriendos con fecha inconsistente: ' || v_contador_inconsist);
    DBMS_OUTPUT.PUT_LINE('Arriendos aun no devueltos (omitidos): ' || v_contador_omitidos);

    COMMIT;

END;
/
