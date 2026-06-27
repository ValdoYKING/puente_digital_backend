from app.core.database import get_db

db = get_db()

def get_usuario_by_username(username: str):
    print(f"--> Búsqueda en tabla 'usuarios' por username: {username}")
    response = db.table("usuarios").select("*").eq("username", username).execute()
    if len(response.data) > 0:
        print(f"  > Usuario encontrado: {response.data[0]['username']}")
        return response.data[0]
    
    print(f"  > El usuario '{username}' no fue encontrado en la base de datos.")
    return None

def update_usuario(usuario_id: str, datos_usuario: dict):
    """
    Actualiza los datos de un perfil de usuario en la base de datos.
    """
    # Filtramos los valores None para no sobrescribir campos existentes con nada.
    update_data = {key: value for key, value in datos_usuario.items() if value is not None}

    if not update_data:
        print("  > No hay datos para actualizar.")
        return None # O podrías devolver el perfil actual sin cambios

    print(f"--> Actualizando perfil para el usuario ID: {usuario_id}")
    print(f"  > Datos para la actualización: {update_data}")

    response = db.table("usuarios").update(update_data).eq("id", usuario_id).execute()

    if response.data:
        print("  > Perfil actualizado con éxito.")
        return response.data[0]
    
    print("  > Error: No se pudo actualizar el perfil o no se encontraron datos de retorno.")
    return None

def update_redes_sociales(usuario_id: str, redes: dict):
    response = db.table("usuarios").update({"redes_sociales": redes}).eq("id", usuario_id).execute()
    return response.data[0] if response.data else None