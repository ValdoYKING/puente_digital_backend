from app.core.database import get_db

db = get_db()

def get_active_tips():
    response = db.table("tips_sociales").select("*").eq("esta_activo", True).execute()
    return response.data