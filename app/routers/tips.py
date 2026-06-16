from fastapi import APIRouter
from typing import List
from app.schemas.tips import TipResponse
from app.services import tips_service

router = APIRouter(prefix="/tips", tags=["Tips y Consejos"])

@router.get("/", response_model=List[TipResponse])
async def obtener_tips():
    tips = tips_service.get_active_tips()
    return tips