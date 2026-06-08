-- se ejecuta con respecto al anno anterior
var anno_proceso number;
exec :anno_proceso := extract(year from sysdate)-1;

TRUNCATE TABLE medico_servicio_comunidad;

DECLARE
    CURSOR nombre_cursor_caso2 IS
    SELECT
        COUNT(*),
        med_run
    FROM
        atencion
    WHERE
        EXTRACT(YEAR FROM fecha_atencion) = :anno_proceso
    GROUP BY
        med_run;

    TYPE tipos_fila_cursor_caso2 IS RECORD (
            atenciones NUMBER,
            med_run    NUMBER
    );
    fila_cursor_caso2  tipos_fila_cursor_caso2;
    ix_m_unidad_id     NUMBER;
    ix_m_unidad_nombre unidad.nombre%TYPE;
    ix_m_run_med       medico_servicio_comunidad.nombre_medico%TYPE;
    ix_m_nombre_med    medico_servicio_comunidad.nombre_medico%TYPE;
    ix_m_destino       medico_servicio_comunidad.destinacion%TYPE;
BEGIN
    OPEN nombre_cursor_caso2;
    LOOP
        FETCH nombre_cursor_caso2 INTO fila_cursor_caso2;
        EXIT WHEN nombre_cursor_caso2%notfound;
        SELECT
            med.med_run,
            med.pnombre
            || ' '
            || nvl(med.snombre, '')
            || ' '
            || med.apaterno
            || ' '
            || nvl(med.amaterno, ''),
            med.uni_id,
            uni.nombre
        INTO
            ix_m_run_med,
            ix_m_nombre_med,
            ix_m_unidad_id,
            ix_m_unidad_nombre
        FROM
                 medico med
            INNER JOIN unidad uni ON med.uni_id = uni.uni_id
        WHERE
            med.med_run = fila_cursor_caso2.med_run;

        CASE
            -- adulto 400 ambulatoria 100 Servicio de Atención Primaria de Urgencia (SAPU)
            WHEN ix_m_unidad_id = 100 THEN
                ix_m_destino := 'Servicio de Atención Primaria de Urgencia (SAPU)';
            -- urgencia 200 if  between 0 and 3 Servicio de Atención Primaria de Urgencia (SAPU)
            -- urgencia 200 more than 3 Hospitales del área de la Salud Pública
            WHEN ix_m_unidad_id = 200 THEN
                IF fila_cursor_caso2.atenciones BETWEEN 0 AND 3 THEN
                    ix_m_destino := 'Servicio de Atención Primaria de Urgencia (SAPU)';
                ELSE
                    ix_m_destino := 'Hospitales del área de la Salud Pública';
                END IF;
            -- cirugia 700 plastica 800 more than 3 Hospitales del área de la Salud Pública
            WHEN
                ix_m_unidad_id IN ( 700, 800 )
                AND fila_cursor_caso2.atenciones > 3
            THEN
                ix_m_destino := 'Hospitales del área de la Salud Pública';
            -- psiq 600 Centros de Salud Familiar (CESFAM)
            WHEN ix_m_unidad_id = 600 THEN
                ix_m_destino := 'Centros de Salud Familiar (CESFAM)';
            -- else Consultorios Generales
            ELSE
                ix_m_destino := 'Consultorios Generales';
        END CASE;

        INSERT INTO medico_servicio_comunidad (
            unidad,
            run_medico,
            nombre_medico,
            total_aten_medicas,
            destinacion
        ) VALUES ( ix_m_unidad_nombre,
                   fila_cursor_caso2.med_run,
                   ix_m_nombre_med,
                   fila_cursor_caso2.atenciones,
                   ix_m_destino );

    END LOOP;

    COMMIT;
END;
/