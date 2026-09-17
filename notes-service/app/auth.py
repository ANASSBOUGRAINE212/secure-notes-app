import os
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt

# THIS SECRET MUST MATCH auth-service's JWT_SECRET exactly.
# notes-service never talks to auth-service directly — it just verifies
# tokens auth-service already signed, using the same shared secret.
SECRET_KEY = os.getenv("JWT_SECRET", "change-this-before-you-ship-anything")
ALGORITHM = "HS256"

# tokenUrl here is just for the OpenAPI docs UI - the actual login
# happens on auth-service, not here.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def get_current_user_id(token: str = Depends(oauth2_scheme)) -> int:
    """
    Returns the user id embedded in the token. There's no local
    'User' object here on purpose - notes-service doesn't own user
    data, it just trusts the id once the signature checks out.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            raise credentials_exception
        return int(user_id)
    except JWTError:
        raise credentials_exception
