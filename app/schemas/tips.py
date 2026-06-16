from pydantic import BaseModel
from typing import Optional

class TipResponse(BaseModel):
    id: int
    titulo: str
    contenido: str
    categoria: Optional[str] = None
    imagen_url: Optional[str] = None