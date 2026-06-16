from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class InteraccionCreate(BaseModel):
    usuario_id: str
    metodo: str # 'QR' o 'NFC'

class InteraccionResponse(BaseModel):
    id: str # El token UUID
    usuario_id: str
    metodo: str
    fue_escaneado: bool
    creado_en: datetime
    escaneado_en: Optional[datetime] = None