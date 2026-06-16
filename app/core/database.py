from supabase import create_client, Client
from app.core.config import settings

# Inicializamos el cliente de Supabase
supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)

def get_db() -> Client:
    """Devuelve la instancia de base de datos para usarla en los servicios."""
    return supabase