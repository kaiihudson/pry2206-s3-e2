/*
    SOMETHING SOMETHING THIS BEGINS HERE
*/
var anio_ref number;
exec :anio_ref := to_number(extract(year from sysdate)-1)

TRUNCATE TABLE pago_moroso;

DECLARE
    -- mostrar un cursor explícito sin parámetros >> no se usa, ni es necesaria... pero esta en rubrica
    CURSOR consulta_aux IS
    SELECT
        sysdate
    FROM
        dual;
    -- cursor explícito con parámetro p_anio_ref (NUMBER) para filtrar el año anterior; el valor se entregará por VARIABLE BIND :anio_ref
    CURSOR nombre_cursor_caso1 (
        p_anio_ref NUMBER
    ) IS
    SELECT
        pac.pac_run,
        pac.dv_run,
        initcap(pac.pnombre
                || ' '
                || nvl(pac.snombre, '')
                || ' '
                || pac.apaterno
                || ' '
                || nvl(pac.amaterno, '')),
        ate.ate_id,
        p.fecha_venc_pago,
        p.fecha_pago,
        ( fecha_pago - fecha_venc_pago ),
        esp.esp_id,
        esp.nombre,
        round(months_between(sysdate, pac.fecha_nacimiento) / 12,
              0)
    FROM
             pago_atencion p
        INNER JOIN atencion     ate ON p.ate_id = ate.ate_id
        INNER JOIN especialidad esp ON esp.esp_id = ate.esp_id
        INNER JOIN paciente     pac ON ate.pac_run = pac.pac_run
    WHERE
        2025 = EXTRACT(YEAR FROM ate.fecha_atencion)
    ORDER BY
        p.fecha_venc_pago ASC,
        pac.apaterno ASC;

    TYPE tipos_fila_cursor_caso1 IS RECORD (
            pac_run         pago_moroso.pac_run%TYPE,
            pac_dv_run      pago_moroso.pac_dv_run%TYPE,
            complete_name   pago_moroso.pac_nombre%TYPE,
            ate_id          pago_moroso.ate_id%TYPE,
            fecha_venc_pago pago_moroso.fecha_venc_pago%TYPE,
            fecha_pago      pago_moroso.fecha_pago%TYPE,
            dia_mora        pago_moroso.dias_morosidad%TYPE,
            especialidad_id NUMBER,
            especialidad    pago_moroso.especialidad_atencion%TYPE,
            edad            NUMBER
    );
    fila_cursor_caso1 tipos_fila_cursor_caso1;
    monto_multa       NUMBER;
    ix_t_tramo        NUMBER;
BEGIN
    OPEN nombre_cursor_caso1(:anio_ref);
    LOOP
        ix_t_tramo := NULL;
        monto_multa := 0;
        FETCH nombre_cursor_caso1 INTO fila_cursor_caso1;
        EXIT WHEN nombre_cursor_caso1%notfound;
        IF fila_cursor_caso1.dia_mora > 0 THEN
            -- check dias de mora, asignar segun especialidad
            CASE 
            -- cirugia general + dermato 1450
                WHEN fila_cursor_caso1.especialidad_id IN ( 100, 300 ) THEN
                    monto_multa := fila_cursor_caso1.dia_mora * 1450;
            -- ortopedia 1300
                WHEN fila_cursor_caso1.especialidad_id = 200 THEN
                    monto_multa := fila_cursor_caso1.dia_mora * 1300;
            -- inmuno + otorrino 1950
                WHEN fila_cursor_caso1.especialidad_id IN ( 400, 900 ) THEN
                    monto_multa := fila_cursor_caso1.dia_mora * 1950;
            -- fisiatria + interna 2500
                WHEN fila_cursor_caso1.especialidad_id IN ( 500, 600 ) THEN
                    monto_multa := fila_cursor_caso1.dia_mora * 2500;
            -- medicina general 1850
                WHEN fila_cursor_caso1.especialidad_id = 700 THEN
                    monto_multa := fila_cursor_caso1.dia_mora * 1850;
            -- neuro 2500
                WHEN fila_cursor_caso1.especialidad_id = 800 THEN
                    monto_multa := fila_cursor_caso1.dia_mora * 2500;
            -- digestiva + reumato 2750
                WHEN fila_cursor_caso1.especialidad_id IN ( 1400, 1800 ) THEN
                    monto_multa := fila_cursor_caso1.dia_mora * 2750;
            -- resto 2900
                ELSE
                    monto_multa := fila_cursor_caso1.dia_mora * 2900;
            END CASE;

        -- check if applies discount
            BEGIN
                SELECT
                    porcentaje_descto
                INTO ix_t_tramo
                FROM
                    porc_descto_3ra_edad
                WHERE
                    fila_cursor_caso1.edad BETWEEN anno_ini AND anno_ter;

            EXCEPTION
                WHEN no_data_found THEN
                    ix_t_tramo := NULL;
            END;

            IF ix_t_tramo IS NOT NULL THEN
                monto_multa := monto_multa * ( 1 - ix_t_tramo / 100 );
            END IF;

            INSERT INTO pago_moroso (
                pac_run,
                pac_dv_run,
                pac_nombre,
                ate_id,
                fecha_venc_pago,
                fecha_pago,
                dias_morosidad,
                especialidad_atencion,
                monto_multa
            ) VALUES ( fila_cursor_caso1.pac_run,
                       fila_cursor_caso1.pac_dv_run,
                       fila_cursor_caso1.complete_name,
                       fila_cursor_caso1.ate_id,
                       fila_cursor_caso1.fecha_venc_pago,
                       fila_cursor_caso1.fecha_pago,
                       fila_cursor_caso1.dia_mora,
                       fila_cursor_caso1.especialidad,
                       monto_multa );

        END IF;

    END LOOP;

    CLOSE nombre_cursor_caso1;
    COMMIT;
END;
/
