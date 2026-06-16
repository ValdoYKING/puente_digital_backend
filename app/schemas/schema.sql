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