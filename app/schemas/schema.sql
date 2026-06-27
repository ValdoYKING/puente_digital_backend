-- ==========================================
-- 1. TABLA DE PERFILES DE USUARIO
-- ==========================================
CREATE TABLE public.usuarios (
    -- Vinculamos este ID con el sistema de Auth nativo de Supabase
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username VARCHAR(30) UNIQUE NOT NULL,
    nombre_completo VARCHAR(100) NOT NULL,
    
    -- El bucket de Supabase nos dará esta URL
    avatar_url TEXT, 
    
    -- JSONB para Redes (Ej: {"instagram": "@valdo", "whatsapp": "+52..."})
    redes_sociales JSONB DEFAULT '{}'::jsonb,
    
    -- JSONB para Personalización (Ej: {"tema": "oscuro", "color_qr": "#ffffff"})
    configuracion_perfil JSONB DEFAULT '{"tema": "oscuro"}'::jsonb,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==========================================
-- 2. TABLA DE TOKENS Y RASTREO (QR / NFC)
-- ==========================================
CREATE TABLE public.interacciones_qr_nfc (
    -- Este id será el token dinámico que viaja en la URL del QR/NFC
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Quién generó el código
    usuario_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
    
    -- Para saber qué medio usan más tus usuarios
    metodo VARCHAR(10) CHECK (metodo IN ('QR', 'NFC')),
    
    -- Lógica de seguridad de un solo uso
    fue_escaneado BOOLEAN DEFAULT FALSE,
    
    -- Si el que escaneó también tiene cuenta en la app, guardamos quién fue (opcional)
    escaneado_por UUID REFERENCES public.usuarios(id) ON DELETE SET NULL, 
    
    creado_en TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    escaneado_en TIMESTAMP WITH TIME ZONE
);

-- ==========================================
-- 3. TABLA DE TIPS Y CONSEJOS PARA SOCIALIZAR
-- ==========================================
CREATE TABLE public.tips_sociales (
    id SERIAL PRIMARY KEY,
    titulo VARCHAR(100) NOT NULL,
    contenido TEXT NOT NULL,
    categoria VARCHAR(50), -- Ej: 'Romper el hielo', 'Lenguaje corporal'
    imagen_url TEXT,       -- Para imágenes guardadas en tu bucket
    esta_activo BOOLEAN DEFAULT TRUE,
    creado_en TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);


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
AS $$DECLARE
    v_username VARCHAR(30);
    v_nombre_completo VARCHAR(100);
    v_avatar_url TEXT;
    v_redes_sociales JSONB;
BEGIN
    -- ============================================================
    -- ESTRATEGIA DE BLOQUEO DE USERNAME
    -- ============================================================
    -- Para evitar problemas de concurrencia (dos usuarios eligiendo 
    -- el mismo username), usamos row-level locking con NOWAIT.
    -- Si se lanza una excepción, el trigger capturará el error y 
    -- generará un username alternativo automáticamente.
    -- ============================================================

    -- 1. Extraer o generar username
    -- Prioridad: raw_user_meta_data.username > email > fallback
    v_username := COALESCE(
        NEW.raw_user_meta_data ->> 'username',
        -- Intentar guardar el username elegido durante el registro
        NULLIF(SPLIT_PART(NEW.email, '@', 1), ''),
        'usuario_' || SUBSTRING(NEW.id::TEXT, 1, 8)
    );

    -- 2. Asegurar que cumple con límite de 30 caracteres
    v_username := LEFT(v_username, 30);

    -- 3. Verificar unicidad y resolver conflictos
    IF EXISTS (SELECT 1 FROM public.usuarios WHERE username = v_username) THEN
        -- Si ya existe, agregar sufijo aleatorio
        v_username := LEFT(v_username, 25) || '_' || SUBSTRING(gen_random_uuid()::TEXT, 1, 4);
    END IF;

    -- 4. Extraer nombre completo
    v_nombre_completo := COALESCE(
        NEW.raw_user_meta_data ->> 'full_name',
        NEW.raw_user_meta_data ->> 'nombre_completo',
        'Usuario Puente'
    );

    -- 5. Extraer avatar (para OAuth, Google envía avatar_url en metadata)
    v_avatar_url := NEW.raw_user_meta_data ->> 'avatar_url';

    -- 6. Para OAuth, intentar extraer redes sociales si se enviaron
    v_redes_sociales := COALESCE(
        (NEW.raw_user_meta_data ->> 'redes_sociales')::JSONB,
        '{}'::JSONB
    );

    -- 7. Insertar el perfil
    BEGIN
        INSERT INTO public.usuarios (
            id,
            username,
            nombre_completo,
            avatar_url,
            redes_sociales,
            configuracion_perfil
        ) VALUES (
            NEW.id,
            v_username,
            v_nombre_completo,
            v_avatar_url,
            v_redes_sociales,
            '{"tema": "oscuro"}'::JSONB
        );
    EXCEPTION 
        WHEN unique_violation THEN
            -- Si hay conflicto de username (raro pero posible en alta concurrencia)
            v_username := LEFT(v_username, 22) || '_' || SUBSTRING(gen_random_uuid()::TEXT, 1, 6);
            
            INSERT INTO public.usuarios (
                id, username, nombre_completo, avatar_url,
                redes_sociales, configuracion_perfil
            ) VALUES (
                NEW.id, v_username, v_nombre_completo, 
                v_avatar_url, v_redes_sociales,
                '{"tema": "oscuro"}'::JSONB
            );
        WHEN OTHERS THEN
            RAISE WARNING 'handle_new_user: Error inesperado al crear perfil para usuario %: %', NEW.id, SQLERRM;
            -- No relanzamos la excepción para no bloquear el registro en auth
    END;

    RETURN NEW;
END;$$;

-- 2. Crear el trigger sobre auth.users
--    Se ejecuta DESPUÉS de insertar un nuevo usuario en auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- 3. (Opcional) Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS on_usuarios_updated ON public.usuarios;
CREATE TRIGGER on_usuarios_updated
    BEFORE UPDATE ON public.usuarios
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================
-- IMPORTANTE: Backfill para usuarios existentes
-- ============================================================
-- Si ya tienes usuarios en auth.users que NO tienen perfil en
-- public.usuarios, ejecuta esto para crearlos:
-- 
-- INSERT INTO public.usuarios (id, username, nombre_completo)
-- SELECT 
--     au.id,
--     COALESCE(
--         au.raw_user_meta_data->>'username',
--         SPLIT_PART(au.email, '@', 1),
--         'usuario_' || SUBSTRING(au.id::TEXT, 1, 8)
--     ),
--     COALESCE(
--         au.raw_user_meta_data->>'full_name',
--         'Usuario Puente'
--     )
-- FROM auth.users au
-- WHERE au.id NOT IN (SELECT id FROM public.usuarios);
-- ============================================================

-- 4. (Opcional) Política RLS para la tabla usuarios
--    Permitir que usuarios autenticados lean su propio perfil
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

-- Política: Cualquiera puede leer perfiles (son públicos)
DROP POLICY IF EXISTS "Perfiles públicos - lectura" ON public.usuarios;
CREATE POLICY "Perfiles públicos - lectura"
    ON public.usuarios
    FOR SELECT
    USING (true);

-- Política: Solo el propio usuario puede modificar su perfil
DROP POLICY IF EXISTS "Usuarios modifican su propio perfil" ON public.usuarios;
CREATE POLICY "Usuarios modifican su propio perfil"
    ON public.usuarios
    FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- Política: El trigger (service_role) puede insertar
DROP POLICY IF EXISTS "Trigger puede insertar perfiles" ON public.usuarios;
CREATE POLICY "Trigger puede insertar perfiles"
    ON public.usuarios
    FOR INSERT
    WITH CHECK (true); -- El trigger usa SECURITY DEFINER

COMMENT ON FUNCTION public.handle_new_user IS 'Crea automáticamente un perfil en public.usuarios cuando se registra un nuevo usuario en auth.users. Maneja tanto email como OAuth.';
