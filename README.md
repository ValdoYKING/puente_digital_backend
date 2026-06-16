app/
├── core/               # Configuraciones globales del sistema
│   ├── config.py       # Lectura de variables de entorno (.env)
│   └── database.py     # Inicialización y cliente de Supabase
├── schemas/            # Validación de datos (Pydantic Models)
│   ├── usuarios.py     # Qué datos entran/salen al manejar perfiles
│   ├── interacciones.py# Validaciones para QR/NFC
│   └── tips.py         # Validaciones para la sección de consejos
├── services/           # Lógica de Negocio pura e interacciones con Supabase
│   ├── usuarios_service.py
│   ├── qr_service.py
│   └── tips_service.py
├── routers/            # Los controladores de la API (Endpoints)
│   ├── auth.py         # Manejo de webhooks o validación de tokens de Supabase Auth
│   ├── usuarios.py     # Rutas de perfil público y configuraciones
│   ├── interacciones.py# Rutas para el escaneo de QR/NFC
│   └── tips.py         # Rutas para jalar consejos y datos interesantes
└── main.py             # Orquestador principal de la app