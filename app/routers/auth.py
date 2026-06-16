from fastapi import APIRouter, HTTPException, Depends
from supabase import Client
from app.core.database import get_db

router = APIRouter(prefix="/auth", tags=["Autenticacion"])

@router.post("/webhook")
async def auth_webhook(payload: dict, db: Client = Depends(get_db)):
    try:
        event_type = payload.get("type")
        record = payload.get("record", {})

        if event_type == "INSERT" and record:
            user_data = {
                "id": record.get("id"),
                "username": record.get("email", "").split("@")[0],
                "nombre_completo": record.get("raw_user_meta_data", {}).get("full_name", "Usuario")
            }
            db.table("usuarios").insert(user_data).execute()

        return {"status": "ok"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
