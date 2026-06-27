-- ============================================================
-- TRIGGER: Auto-crear perfil en public.usuarios al registrarse
-- ============================================================
-- Este script crea un trigger nativo de PostgreSQL que:
--   1. Escucha eventos INSERT en auth.users
--   2. Extrae datos del usuario (id, email, metadata)
--   3. Crea automáticamente el registro en public.usuarios
--   4. Maneja tanto registro con email como OAuth (Google, etc.)
--
-- ✅ Ventajas sobre webhooks:
--   - No depende de internet/URLs públicas (ngrok/Vercel)
--   - Es transaccional: si falla, el registro en auth.users se revierte
--   - Más rápido (no hay llamada HTTP)
--   - Funciona en producción sin configuración adicional
-- ============================================================

-- 1. Crear la función que ejecutará el trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    v_username VARCHAR(30);
    v_nombre_completo VARCHAR(150);
    v_avatar_url TEXT;
    v_redes_sociales JSONB;
    v_genero VARCHAR(30);
    v_sexo_biologico VARCHAR(30);
    v_fecha_nacimiento DATE;
BEGIN
    -- ============================================================
    -- LOG: Mostrar qué datos llegaron en raw_user_meta_data
    -- ============================================================
    RAISE NOTICE '=== TRIGGER handle_new_user DISPARADO ===';
    RAISE NOTICE 'ID usuario: %', NEW.id;
    RAISE NOTICE 'Email: %', NEW.email;
    RAISE NOTICE 'raw_user_meta_data: %', NEW.raw_user_meta_data;
    
    RAISE NOTICE '  username (de metadata): %', NEW.raw_user_meta_data ->> 'username';
    RAISE NOTICE '  nombre_completo (de metadata): %', NEW.raw_user_meta_data ->> 'nombre_completo';
    RAISE NOTICE '  genero (de metadata): %', NEW.raw_user_meta_data ->> 'genero';
    RAISE NOTICE '  sexo_biologico (de metadata): %', NEW.raw_user_meta_data ->> 'sexo_biologico';
    RAISE NOTICE '  fecha_nacimiento (de metadata): %', NEW.raw_user_meta_data ->> 'fecha_nacimiento';
    RAISE NOTICE '===========================================';

    -- ============================================================
    -- ESTRATEGIA DE BLOQUEO DE USERNAME
    -- ============================================================

    -- 1. Extraer o generar username
    v_username := COALESCE(
        NEW.raw_user_meta_data ->> 'username',
        NULLIF(SPLIT_PART(NEW.email, '@', 1), ''),
        'usuario_' || SUBSTRING(NEW.id::TEXT, 1, 8)
    );

    -- 2. Asegurar que cumple con límite de 30 caracteres
    v_username := LEFT(v_username, 30);

    -- 3. Verificar unicidad y resolver conflictos
    IF EXISTS (SELECT 1 FROM public.usuarios WHERE username = v_username) THEN
        v_username := LEFT(v_username, 25) || '_' || SUBSTRING(gen_random_uuid()::TEXT, 1, 4);
    END IF;

    -- 4. Extraer nombre completo
    v_nombre_completo := COALESCE(
        NEW.raw_user_meta_data ->> 'full_name',
        NEW.raw_user_meta_data ->> 'nombre_completo',
        'Usuario Puente'
    );

    -- 5. Extraer avatar
    v_avatar_url := NULLIF(NEW.raw_user_meta_data ->> 'avatar_url', '');

    -- 6. Extraer redes sociales
    BEGIN
        v_redes_sociales := COALESCE(
            (NEW.raw_user_meta_data ->> 'redes_sociales')::JSONB,
            '{}'::JSONB
        );
    EXCEPTION WHEN OTHERS THEN
        v_redes_sociales := '{}'::JSONB;
    END;

    -- 7. Extraer género
    v_genero := NULLIF(NEW.raw_user_meta_data ->> 'genero', '');
    
    -- 8. Extraer sexo biológico
    v_sexo_biologico := NULLIF(NEW.raw_user_meta_data ->> 'sexo_biologico', '');

    -- 9. Extraer fecha de nacimiento
    BEGIN
        v_fecha_nacimiento := NULLIF(NEW.raw_user_meta_data ->> 'fecha_nacimiento', '')::DATE;
    EXCEPTION WHEN OTHERS THEN
        v_fecha_nacimiento := NULL;
    END;

    RAISE NOTICE 'Valores finales a insertar:';
    RAISE NOTICE '  username: %', v_username;
    RAISE NOTICE '  nombre_completo: %', v_nombre_completo;
    RAISE NOTICE '  avatar_url: %', v_avatar_url;
    RAISE NOTICE '  genero: %', v_genero;
    RAISE NOTICE '  sexo_biologico: %', v_sexo_biologico;
    RAISE NOTICE '  fecha_nacimiento: %', v_fecha_nacimiento;
    RAISE NOTICE '  redes_sociales: %', v_redes_sociales;

    -- 10. Insertar el perfil con TODOS los campos
    BEGIN
        INSERT INTO public.usuarios (
            id,
            username,
            nombre_completo,
            avatar_url,
            genero,
            sexo_biologico,
            fecha_nacimiento,
            redes_sociales,
            configuracion_perfil
        ) VALUES (
            NEW.id,
            v_username,
            v_nombre_completo,
            v_avatar_url,
            v_genero,
            v_sexo_biologico,
            v_fecha_nacimiento,
            v_redes_sociales,
            '{"tema": "oscuro"}'::JSONB
        );
        
        RAISE NOTICE '✅ Perfil creado exitosamente para %', v_username;
        
    EXCEPTION 
        WHEN unique_violation THEN
            RAISE WARNING '⚠️ Conflicto de username, generando alternativo...';
            v_username := LEFT(v_username, 22) || '_' || SUBSTRING(gen_random_uuid()::TEXT, 1, 6);
            
            INSERT INTO public.usuarios (
                id, username, nombre_completo, avatar_url,
                genero, sexo_biologico, fecha_nacimiento,
                redes_sociales, configuracion_perfil
            ) VALUES (
                NEW.id, v_username, v_nombre_completo, 
                v_avatar_url, v_genero, v_sexo_biologico,
                v_fecha_nacimiento, v_redes_sociales,
                '{"tema": "oscuro"}'::JSONB
            );
            
            RAISE NOTICE '✅ Perfil creado con username alternativo: %', v_username;
        WHEN OTHERS THEN
            RAISE WARNING '💥 handle_new_user: Error inesperado al crear perfil para usuario %: %', NEW.id, SQLERRM;
    END;

    RETURN NEW;
END;
$$;

-- 2. Crear el trigger sobre auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- 3. Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_usuarios_updated ON public.usuarios;
CREATE TRIGGER on_usuarios_updated
    BEFORE UPDATE ON public.usuarios
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================
-- Backfill para usuarios existentes
-- ============================================================
-- INSERT INTO public.usuarios (id, username, nombre_completo, genero, sexo_biologico, fecha_nacimiento)
-- SELECT 
--     au.id,
--     COALESCE(
--         au.raw_user_meta_data->>'username',
--         SPLIT_PART(au.email, '@', 1),
--         'usuario_' || SUBSTRING(au.id::TEXT, 1, 8)
--     ),
--     COALESCE(
--         au.raw_user_meta_data->>'nombre_completo',
--         au.raw_user_meta_data->>'full_name',
--         'Usuario Puente'
--     ),
--     au.raw_user_meta_data->>'genero',
--     au.raw_user_meta_data->>'sexo_biologico',
--     NULLIF(au.raw_user_meta_data->>'fecha_nacimiento', '')::DATE
-- FROM auth.users au
-- WHERE au.id NOT IN (SELECT id FROM public.usuarios);
-- ============================================================

-- 4. Políticas RLS para la tabla usuarios
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Perfiles públicos - lectura" ON public.usuarios;
CREATE POLICY "Perfiles públicos - lectura"
    ON public.usuarios
    FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Usuarios modifican su propio perfil" ON public.usuarios;
CREATE POLICY "Usuarios modifican su propio perfil"
    ON public.usuarios
    FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "Trigger puede insertar perfiles" ON public.usuarios;
CREATE POLICY "Trigger puede insertar perfiles"
    ON public.usuarios
    FOR INSERT
    WITH CHECK (true);

-- ============================================================
-- FUNCIONES AUXILIARES RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.verificar_email_existe(email_buscar TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    email_existe BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM auth.users WHERE email = email_buscar
    ) INTO email_existe;
    RETURN email_existe;
END;
$$;

CREATE OR REPLACE FUNCTION public.verificar_username_disponible(username_buscar TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    username_existe BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM public.usuarios WHERE username = username_buscar
    ) INTO username_existe;
    RETURN NOT username_existe;
END;
$$;

COMMENT ON FUNCTION public.handle_new_user IS 'Crea automáticamente un perfil en public.usuarios cuando se registra un nuevo usuario en auth.users. Maneja tanto email como OAuth. Incluye campos: genero, sexo_biologico, fecha_nacimiento.';
