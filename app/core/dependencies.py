import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from app.core.config import settings

# Esta es la "receta" para que FastAPI sepa cómo buscar un token.
# Buscará un header "Authorization" con el valor "Bearer <token>"
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

def get_current_user(token: str = Depends(oauth2_scheme)):
    """
    Decodifica el token JWT de Supabase para obtener el ID del usuario.
    Esta función será usada como una dependencia en los endpoints protegidos.
    """
    try:
        # Decodificamos el token usando el secreto JWT de Supabase
        payload = jwt.decode(
            token,
            settings.SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated"
        )
        
        # El 'sub' (subject) del token de Supabase es el ID del usuario.
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="No se pudo validar las credenciales",
            )
        
        print(f"--> Token validado. El ID del usuario es: {user_id}")
        return {"id": user_id}

    except jwt.PyJWTError as e:
        print(f"  > ¡ERROR! Token inválido: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No se pudo validar las credenciales",
        )
    except Exception as e:
        print(f"  > ¡ERROR! Ocurrió un error inesperado al validar el token: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error del servidor al validar el token."
        )
