from fastapi import APIRouter, HTTPException, Depends
from app.schemas.usuarios import UsuarioResponse, UsuarioUpdate
from app.services import usuarios_service
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/usuarios", tags=["Usuarios"])

@router.get("/debug/ultimo-registro")
async def debug_ultimo_registro():
    """
    ENDPOINT DE DEBUG: Muestra el último usuario registrado en la tabla usuarios
    para verificar si los campos genero, sexo_biologico, fecha_nacimiento se guardaron.
    """
    from app.core.database import get_db
    db = get_db()
    
    response = db.table("usuarios").select("*").order("created_at", desc=True).limit(1).execute()
    
    if response.data:
        return {"ultimo_usuario": response.data[0]}
    
    return {"mensaje": "No hay usuarios en la tabla"}


@router.put("/mi-perfil", response_model=UsuarioResponse)
async def actualizar_mi_perfil(
    datos_update: UsuarioUpdate,
    current_user: dict = Depends(get_current_user)
):
    """
    Permite a un usuario autenticado actualizar su propio perfil.
    """
    usuario_id = current_user.get("id")
    
    datos_a_actualizar = datos_update.model_dump(exclude_none=True)

    usuario_actualizado = usuarios_service.update_usuario(
        usuario_id=usuario_id,
        datos_usuario=datos_a_actualizar
    )

    if not usuario_actualizado:
        raise HTTPException(status_code=404, detail="No se pudo actualizar el perfil. Usuario no encontrado.")
    
    return usuario_actualizado


@router.get("/perfil/{username}", response_model=UsuarioResponse)
async def obtener_perfil(username: str):
    usuario = usuarios_service.get_usuario_by_username(username)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return usuario