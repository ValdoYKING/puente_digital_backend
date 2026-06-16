from app.core.database import get_db

db = get_db()

def get_usuario_by_username(username: str):
    response = db.table("usuarios").select("*").eq("username", username).execute()
    if len(response.data) > 0:
        return response.data[0]
    return None

def update_redes_sociales(usuario_id: str, redes: dict):
    response = db.table("usuarios").update({"redes_sociales": redes}).eq("id", usuario_id).execute()
    return response.data[0] if response.data else None