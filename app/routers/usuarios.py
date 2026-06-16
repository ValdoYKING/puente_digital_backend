from fastapi import APIRouter, HTTPException
from app.schemas.usuarios import UsuarioResponse
from app.services import usuarios_service

router = APIRouter(prefix="/usuarios", tags=["Usuarios"])

@router.get("/perfil/{username}", response_model=UsuarioResponse)
async def obtener_perfil(username: str):
    usuario = usuarios_service.get_usuario_by_username(username)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return usuario