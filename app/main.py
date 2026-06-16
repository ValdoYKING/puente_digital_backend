from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Importamos nuestros módulos (routers)
from app.routers import auth, usuarios, interacciones, tips

app = FastAPI(
    title="Puente Digital API",
    description="Backend modular para conectar personas.",
    version="1.0.0"
)

# Configuración de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:4000"], # Asegúrate de que apunte a tu Next.js
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Agregamos los routers a la aplicación principal
app.include_router(auth.router, prefix="/api/v1")
app.include_router(usuarios.router, prefix="/api/v1")
app.include_router(interacciones.router, prefix="/api/v1")
app.include_router(tips.router, prefix="/api/v1")

@app.get("/")
async def root():
    return {"message": "¡API de Puente Digital corriendo al 100, carnal!"}