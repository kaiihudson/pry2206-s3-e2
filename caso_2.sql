-- se ejecuta con respecto al anno anterior
VAR anno_proceso NUMBER;
EXEC :anno_proceso := EXTRACT(YEAR FROM SYSDATE)-1;

TRUNCATE TABLE medico_servicio_comunidad;

DECLARE

    -- cursor para unidades
    CURSOR cursor_aux_unidad IS
    SELECT
        uni_id,
        nombre
    FROM
        unidad
    ORDER BY
        nombre;

    TYPE tipos_fila_cursor_aux_unidad IS RECORD (
        unidad_id     NUMBER,
        unidad_nombre unidad.nombre%TYPE
    );

    fila_cursor_aux_unidad tipos_fila_cursor_aux_unidad;

    -- cursor para medicos con parametro
    CURSOR nombre_cursor_caso2_medico (
        id_unidad NUMBER
    ) IS
    SELECT
        med_run,
        apaterno,
        pnombre
        || ' '
        || NVL(snombre, '')
        || ' '
        || apaterno
        || ' '
        || NVL(amaterno, '') nombre_medico
    FROM
        medico
    WHERE
        uni_id = id_unidad
    ORDER BY
        apaterno;

    TYPE tipos_fila_cursor_caso2_medico IS RECORD (
        run_med     medico.med_run%TYPE,
        apaterno    medico.apaterno%TYPE,
        nombre_med  medico_servicio_comunidad.nombre_medico%TYPE
    );

    fila_cursor_caso2_medico tipos_fila_cursor_caso2_medico;

    -- variables para insert
    ix_m_destino      medico_servicio_comunidad.destinacion%TYPE;
    ix_m_atenciones   NUMBER;

BEGIN

    OPEN cursor_aux_unidad;

    -- desde esta lista de unidades
    LOOP

        FETCH cursor_aux_unidad INTO fila_cursor_aux_unidad;

        EXIT WHEN cursor_aux_unidad%NOTFOUND;

        -- usando cada una de las unidades
        OPEN nombre_cursor_caso2_medico(fila_cursor_aux_unidad.unidad_id);

        LOOP

            FETCH nombre_cursor_caso2_medico
            INTO fila_cursor_caso2_medico;

            EXIT WHEN nombre_cursor_caso2_medico%NOTFOUND;

            -- trae cantidad de atenciones del anno de proceso
            SELECT
                COUNT(ate_id)
            INTO
                ix_m_atenciones
            FROM
                atencion
            WHERE
                    med_run = fila_cursor_caso2_medico.run_med
                AND EXTRACT(YEAR FROM fecha_atencion) = :anno_proceso;

            -- cambia un valor basandote en ciertas condiciones
            CASE

                -- adulto 400 ambulatoria 100 Servicio de Atención Primaria de Urgencia (SAPU)
                WHEN fila_cursor_aux_unidad.unidad_id = 100 THEN
                    ix_m_destino :=
                        'Servicio de Atención Primaria de Urgencia (SAPU)';

                -- urgencia 200 if between 0 and 3 Servicio de Atención Primaria de Urgencia (SAPU)
                -- urgencia 200 more than 3 Hospitales del área de la Salud Pública
                WHEN fila_cursor_aux_unidad.unidad_id = 200 THEN

                    IF ix_m_atenciones BETWEEN 0 AND 3 THEN
                        ix_m_destino :=
                            'Servicio de Atención Primaria de Urgencia (SAPU)';
                    ELSE
                        ix_m_destino :=
                            'Hospitales del área de la Salud Pública';
                    END IF;

                -- cirugia 700 plastica 800 more than 3 Hospitales del área de la Salud Pública
                WHEN fila_cursor_aux_unidad.unidad_id IN (700, 800) THEN

                    IF ix_m_atenciones > 3 THEN
                        ix_m_destino :=
                            'Hospitales del área de la Salud Pública';
                    ELSE
                        ix_m_destino :=
                            'Consultorios Generales';
                    END IF;

                -- psiq 600 Centros de Salud Familiar (CESFAM)
                WHEN fila_cursor_aux_unidad.unidad_id = 600 THEN
                    ix_m_destino :=
                        'Centros de Salud Familiar (CESFAM)';

                -- else Consultorios Generales
                ELSE
                    ix_m_destino := 'Consultorios Generales';

            END CASE;

            -- inserta la info
            INSERT INTO medico_servicio_comunidad (
                unidad,
                run_medico,
                nombre_medico,
                total_aten_medicas,
                destinacion
            ) VALUES (
                fila_cursor_aux_unidad.unidad_nombre,
                fila_cursor_caso2_medico.run_med,
                fila_cursor_caso2_medico.nombre_med,
                ix_m_atenciones,
                ix_m_destino
            );

        END LOOP;

        -- desecha el caso
        CLOSE nombre_cursor_caso2_medico;

    END LOOP;

    -- desecha el caso
    CLOSE cursor_aux_unidad;

    -- guarda info
    COMMIT;

END;
/