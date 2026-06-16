from fastapi import APIRouter, HTTPException
from app.schemas.interacciones import InteraccionCreate, InteraccionResponse
from app.services import qr_service

router = APIRouter(prefix="/interacciones", tags=["Interacciones QR/NFC"])

@router.post("/generar", response_model=InteraccionResponse)
async def generar_codigo(interaccion: InteraccionCreate):
    nuevo_token = qr_service.generar_token(interaccion.usuario_id, interaccion.metodo)
    if not nuevo_token:
        raise HTTPException(status_code=500, detail="Error al generar el token")
    return nuevo_token

@router.get("/escanear/{token_id}")
async def procesar_escaneo(token_id: str):
    resultado = qr_service.escanear_token(token_id)
    if "error" in resultado:
        raise HTTPException(status_code=400, detail=resultado["error"])
    return resultado
