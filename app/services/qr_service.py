from app.core.database import get_db
from datetime import datetime

db = get_db()

def generar_token(usuario_id: str, metodo: str):
    data = {"usuario_id": usuario_id, "metodo": metodo}
    response = db.table("interacciones_qr_nfc").insert(data).execute()
    return response.data[0] if response.data else None

def escanear_token(token_id: str):
    # 1. Buscar el token
    response = db.table("interacciones_qr_nfc").select("*").eq("id", token_id).execute()
    if not response.data:
        return {"error": "Token no encontrado"}
    
    token = response.data[0]
    
    # 2. Validar si ya fue usado
    if token.get("fue_escaneado"):
        return {"error": "Este código ya fue escaneado o expiró"}
        
    # 3. Marcar como escaneado
    now = datetime.utcnow().isoformat()
    db.table("interacciones_qr_nfc").update(
        {"fue_escaneado": True, "escaneado_en": now}
    ).eq("id", token_id).execute()
    
    # 4. Retornar el ID del usuario para mostrar su perfil
    return {"success": True, "usuario_id": token.get("usuario_id")}