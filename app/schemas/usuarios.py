from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime

class UsuarioBase(BaseModel):
    username: str
    nombre_completo: str
    avatar_url: Optional[str] = None
    redes_sociales: Optional[Dict[str, Any]] = {}
    configuracion_perfil: Optional[Dict[str, Any]] = {"tema": "oscuro"}

class UsuarioCreate(UsuarioBase):
    id: str # UUID que viene de Supabase Auth

class UsuarioResponse(UsuarioBase):
    id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class UsuarioUpdate(BaseModel):
    username: Optional[str] = None
    nombre_completo: Optional[str] = None
    avatar_url: Optional[str] = None
    redes_sociales: Optional[Dict[str, Any]] = None
