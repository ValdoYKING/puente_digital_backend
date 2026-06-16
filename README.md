# Puente Digital API

Backend modular para **Puente Digital**, una plataforma que conecta personas mediante códigos QR/NFC, perfiles digitales y tips de socialización. Construido con **FastAPI** + **Supabase**.

---

## 🚀 Características principales

- **Perfiles digitales** — Cada usuario tiene un perfil público con redes sociales y configuración personalizada.
- **Códigos QR / NFC** — Generación de tokens dinámicos de un solo uso para compartir perfiles al instante.
- **Tips de socialización** — Sección de consejos categorizados para ayudar a romper el hielo.
- **Autenticación vía Supabase** — Webhook que reacciona a eventos de Auth (registro, login) para crear perfiles automáticamente.
- **Base de datos en Supabase** — Todo el stack de datos manejado con PostgreSQL + PostgREST.

---

## 📁 Estructura del proyecto

```
app/
├── core/                  # Configuraciones globales del sistema
│   ├── config.py          # Variables de entorno vía Pydantic Settings (.env)
│   ├── database.py        # Cliente de Supabase (create_client)
│   └── __init__.py
│
├── schemas/               # Validación de datos (Modelos Pydantic)
│   ├── usuarios.py        # Schemas: UsuarioBase, UsuarioCreate, UsuarioResponse
│   ├── interacciones.py   # Schemas: InteraccionCreate, InteraccionResponse
│   ├── tips.py            # Schemas: TipResponse
│   └── __init__.py
│
├── services/              # Lógica de negocio (capa de datos)
│   ├── usuarios_service.py    # CRUD de perfiles de usuario
│   ├── qr_service.py          # Generación y escaneo de tokens QR/NFC
│   ├── tips_service.py        # Consulta de tips activos
│   └── __init__.py
│
├── routers/               # Endpoints de la API (controladores)
│   ├── auth.py            # POST /auth/webhook — Eventos de Supabase Auth
│   ├── usuarios.py        # GET /usuarios/perfil/{username}
│   ├── interacciones.py   # POST /interacciones/generar, GET /interacciones/escanear/{token_id}
│   ├── tips.py            # GET /tips/
│   └── __init__.py
│
├── main.py                # Orquestador principal (FastAPI app + CORS + routers)
└── __init__.py
```

---

## ⚙️ Requisitos

- Python 3.11+
- Una cuenta en [Supabase](https://supabase.com) con:
  - Proyecto creado
  - Tablas creadas (ver `app/schemas/schema.sql`)
  - URL del proyecto y Service Role Key

---

## 🛠️ Instalación y configuración

### 1. Clonar el repositorio

```bash
git clone https://github.com/tu-usuario/puente_digital_backend.git
cd puente_digital_backend
```

### 2. Crear y activar entorno virtual

```bash
python -m venv venv

# Windows
venv\Scripts\activate

# macOS / Linux
source venv/bin/activate
```

### 3. Instalar dependencias

```bash
pip install -r requirements.txt
```

### 4. Configurar variables de entorno

Crea un archivo `.env` en la raíz del proyecto:

```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_KEY=tu-service-role-key
```

### 5. Inicializar la base de datos

Ejecuta el script SQL ubicado en `app/schemas/schema.sql` desde el **SQL Editor** de tu proyecto de Supabase. Esto creará las tablas:

| Tabla | Propósito |
|---|---|
| `public.usuarios` | Perfiles de usuario vinculados a auth.users |
| `public.interacciones_qr_nfc` | Tokens QR/NFC de un solo uso |
| `public.tips_sociales` | Consejos y tips de socialización |

### 6. Iniciar el servidor

```bash
uvicorn app.main:app --reload
```

La API estará disponible en `http://localhost:8000`.

---

## 📡 Endpoints de la API

| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/` | Health check |
| `POST` | `/api/v1/auth/webhook` | Webhook de Supabase Auth (crea perfil al registrarse) |
| `GET` | `/api/v1/usuarios/perfil/{username}` | Obtener perfil público por username |
| `POST` | `/api/v1/interacciones/generar` | Generar un nuevo código QR/NFC |
| `GET` | `/api/v1/interacciones/escanear/{token_id}` | Escanear/validar un token QR/NFC |
| `GET` | `/api/v1/tips/` | Obtener todos los tips activos |

### Documentación interactiva

Una vez iniciado el servidor, visita:

- **Swagger UI**: `http://localhost:8000/docs`
- **Redoc**: `http://localhost:8000/redoc`

---

## 🔄 Diagrama de flujo (QR/NFC)

```
Usuario A                     API                          Supabase
    |                          |                              |
    |--- POST /generar ------->|                              |
    |                          |--- INSERT token ----------->|
    |                          |<-- token_id ----------------|
    |<-- {token_id, QR} ------|                              |
    |                          |                              |
    | (comparte QR/NFC)        |                              |
    |                          |                              |
Usuario B                     |                              |
    |--- GET /escanear/{id} -->|                              |
    |                          |--- SELECT token ----------->|
    |                          |<-- token data --------------|
    |                          |--- UPDATE fue_escaneado --->|
    |<-- {perfil usuario A} ---|                              |
```

---

## 🗄️ SQL (esquema de base de datos)

El schema completo está en `app/schemas/schema.sql`. Incluye:

- `usuarios` — Perfiles con JSONB para redes sociales y configuración
- `interacciones_qr_nfc` — Tokens UUID con lógica de un solo uso
- `tips_sociales` — Tips con categorías y estado activo/inactivo

---

## 🧑‍💻 Desarrollo

### Agregar un nuevo endpoint

1. Crea el schema Pydantic en `app/schemas/` (si es necesario)
2. Implementa la lógica en `app/services/`
3. Define la ruta en `app/routers/`
4. Registra el router en `app/main.py`

### Ejecutar pruebas

```bash
python -c "from fastapi.testclient import TestClient; from app.main import app; client = TestClient(app)"
```

---

## 📄 Licencia

MIT
