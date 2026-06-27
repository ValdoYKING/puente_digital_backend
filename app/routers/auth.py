from fastapi import APIRouter, HTTPException, Depends
from supabase import Client
from app.core.database import get_db

router = APIRouter(prefix="/auth", tags=["Autenticacion"])

@router.post("/webhook")
async def auth_webhook(payload: dict, db: Client = Depends(get_db)):
    """
    Webhook para reaccionar a eventos de Supabase Auth.
    Cuando un usuario se registra, crea su perfil en la tabla 'usuarios'.
    """
    try:
        event_type = payload.get("type")
        record = payload.get("record", {})

        print(f"\n{'='*80}")
        print(f"🔔 WEBHOOK DE AUTH RECIBIDO")
        print(f"{'='*80}")
        print(f"Tipo de evento: '{event_type}'")
        print(f"{'='*80}")
        print(f"🔍 PAYLOAD COMPLETO:")
        import json
        print(json.dumps(payload, indent=2, default=str))
        print(f"{'='*80}")

        if event_type == "INSERT" and record:
            user_id = record.get("id")
            user_email = record.get("email", "")
            raw_meta = record.get("raw_user_meta_data", {})
            
            print(f"\n📋 DATOS DEL USUARIO:")
            print(f"  ID:             {user_id}")
            print(f"  Email:          {user_email}")
            print(f"  Creado:         {record.get('created_at')}")
            print(f"{'─'*50}")
            print(f"📦 raw_user_meta_data:")
            print(json.dumps(raw_meta, indent=4, default=str))
            print(f"{'─'*50}")
            
            # Campos de interés específico
            print(f"🎯 CAMPOS DE INTERÉS:")
            print(f"  username:       {raw_meta.get('username', '❌ NO ENVIADO')}")
            print(f"  nombre_completo: {raw_meta.get('nombre_completo', '❌ NO ENVIADO')}")
            print(f"  avatar_url:     {raw_meta.get('avatar_url', '❌ NO ENVIADO')}")
            print(f"  genero:         {raw_meta.get('genero', '❌ NO ENVIADO')}")
            print(f"  sexo_biologico: {raw_meta.get('sexo_biologico', '❌ NO ENVIADO')}")
            print(f"  fecha_nacimiento: {raw_meta.get('fecha_nacimiento', '❌ NO ENVIADO')}")
            print(f"  redes_sociales: {raw_meta.get('redes_sociales', '❌ NO ENVIADO')}")
            print(f"{'─'*50}")

            user_data = {
                "id": user_id,
                "username": raw_meta.get("username") or user_email.split("@")[0],
                "nombre_completo": raw_meta.get("nombre_completo") or raw_meta.get("full_name", "Usuario Puente"),
                "avatar_url": raw_meta.get("avatar_url"),
                "genero": raw_meta.get("genero"),
                "sexo_biologico": raw_meta.get("sexo_biologico"),
                "fecha_nacimiento": raw_meta.get("fecha_nacimiento"),
                "redes_sociales": raw_meta.get("redes_sociales", {}),
            }
            
            print(f"🚀 DATOS A INSERTAR EN 'usuarios':")
            print(json.dumps(user_data, indent=2, default=str))
            
            response = db.table("usuarios").insert(user_data).execute()

            if len(response.data) > 0:
                print(f"\n✅ ¡Éxito! Perfil creado para el usuario '{user_data['username']}'")
                print(f"  ID: {response.data[0]['id']}")
            else:
                print(f"\n❌ Error: La inserción no devolvió datos. Revisa los logs de Supabase.")

        print(f"{'='*80}\n")

        return {"status": "ok", "message": "Webhook procesado"}
    
    except Exception as e:
        import traceback
        print(f"\n💥 ¡ERROR! Excepción en el webhook de Auth:")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Error en el webhook: {str(e)}")
