from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app import schemas
from app.crud import crud
from app.core import security as auth
from app.db.database import get_db
from app.db import models
import time
import httpx
import json

router = APIRouter(prefix="/auth", tags=["auth"])

def require_admin_user(current_user: models.User = Depends(auth.get_current_user)):
    if current_user.role != "admin" and not crud.is_admin_email(current_user.email):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required."
        )
    return current_user

@router.post("/register", response_model=schemas.AuthResponse)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=user.email)
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    created_user = crud.create_user(db=db, user=user)
    access_token_expires = auth.timedelta(minutes=auth.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(
        data={"sub": created_user.email}, expires_delta=access_token_expires
    )
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": created_user
    }

@router.post("/login", response_model=schemas.AuthResponse)
def login_for_access_token(user: schemas.UserLogin, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=user.email)
    if not db_user or not db_user.hashed_password or not auth.verify_password(user.password, db_user.hashed_password):
        raise HTTPException(
            status_code=401,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = auth.timedelta(minutes=auth.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(
        data={"sub": db_user.email}, expires_delta=access_token_expires
    )
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": db_user
    }

@router.post("/google", response_model=schemas.AuthResponse)
async def google_auth(req: schemas.GoogleAuthRequest, db: Session = Depends(get_db)):
    token = req.credential or req.id_token
    email = req.email
    name = req.name
    picture = req.picture
    
    # If a Google ID token is passed, verify with Google's public tokeninfo endpoint
    if token:
        try:
            async with httpx.AsyncClient(timeout=6.0) as client:
                res = await client.get(f"https://oauth2.googleapis.com/tokeninfo?id_token={token}")
                if res.status_code == 200:
                    payload = res.json()
                    email = payload.get("email")
                    name = payload.get("name") or payload.get("given_name")
                    picture = payload.get("picture")
        except Exception as e:
            print(f"Google token verification note: {e}")
            
    if not email:
        raise HTTPException(status_code=400, detail="Could not authenticate with Google. Missing email.")
        
    db_user = crud.create_or_update_google_user(
        db=db,
        email=email,
        name=name or email.split("@")[0],
        picture=picture
    )
    
    access_token_expires = auth.timedelta(minutes=auth.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(
        data={"sub": db_user.email}, expires_delta=access_token_expires
    )
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": db_user
    }

@router.get("/me", response_model=schemas.User)
def get_me(current_user: models.User = Depends(auth.get_current_user)):
    return current_user

@router.post("/forgot-password")
def forgot_password(req: schemas.ForgotPassword, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=req.email)
    if not db_user:
        return {"message": "If that email is in our system, an OTP has been sent."}
    
    otp = auth.generate_otp()
    expires_at = time.time() + (15 * 60)
    crud.update_user_otp(db, db_user, otp, expires_at)
    auth.send_otp_email(db_user.email, otp)
    return {"message": "If that email is in our system, an OTP has been sent."}

@router.post("/verify-otp")
def verify_otp(req: schemas.VerifyOTP, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=req.email)
    if not db_user or not db_user.otp_code:
        raise HTTPException(status_code=400, detail="Invalid request")
        
    if db_user.otp_code != req.otp:
        raise HTTPException(status_code=400, detail="Invalid OTP")
        
    if time.time() > db_user.otp_expires_at:
        raise HTTPException(status_code=400, detail="OTP has expired")
        
    crud.update_user_password(db, db_user, req.new_password)
    return {"message": "Password updated successfully"}

@router.put("/profile_picture", response_model=schemas.User)
def update_profile_picture(req: schemas.ProfilePictureUpdate, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    updated_user = crud.update_profile_picture(db, current_user, req.profile_picture_url)
    return updated_user

# ==========================================
# ADMIN USER & WHITELIST MANAGEMENT
# ==========================================

@router.get("/admin/users", response_model=list[schemas.UserAdminView])
def get_all_users_admin(
    admin: models.User = Depends(require_admin_user),
    db: Session = Depends(get_db)
):
    """Admin only: List all registered users and their approval status."""
    return crud.get_all_users(db)

@router.post("/admin/users/{user_id}/approve", response_model=schemas.UserAdminView)
def approve_user_admin(
    user_id: int,
    admin: models.User = Depends(require_admin_user),
    db: Session = Depends(get_db)
):
    """Admin only: Approve user access to server portal."""
    updated = crud.update_user_approval(db, user_id=user_id, is_approved=True)
    if not updated:
        raise HTTPException(status_code=404, detail="User not found")
    return updated

@router.post("/admin/users/{user_id}/revoke", response_model=schemas.UserAdminView)
def revoke_user_admin(
    user_id: int,
    admin: models.User = Depends(require_admin_user),
    db: Session = Depends(get_db)
):
    """Admin only: Revoke user access."""
    updated = crud.update_user_approval(db, user_id=user_id, is_approved=False)
    if not updated:
        raise HTTPException(status_code=404, detail="User not found")
    return updated

@router.delete("/admin/users/{user_id}")
def delete_user_admin(
    user_id: int,
    admin: models.User = Depends(require_admin_user),
    db: Session = Depends(get_db)
):
    """Admin only: Delete a user."""
    success = crud.delete_user(db, user_id=user_id)
    if not success:
        raise HTTPException(status_code=404, detail="User not found")
    return {"success": True, "message": "User deleted"}

@router.get("/admin/whitelist", response_model=list[schemas.WhitelistEmailResponse])
def get_whitelist_admin(
    admin: models.User = Depends(require_admin_user),
    db: Session = Depends(get_db)
):
    """Admin only: List all pre-approved whitelist emails."""
    return crud.get_whitelist_emails(db)

@router.post("/admin/whitelist", response_model=schemas.WhitelistEmailResponse)
def add_whitelist_admin(
    req: schemas.WhitelistEmailCreate,
    admin: models.User = Depends(require_admin_user),
    db: Session = Depends(get_db)
):
    """Admin only: Add email to whitelist for instant signup approval."""
    return crud.add_whitelist_email(db, email=req.email, added_by=admin.email)

@router.delete("/admin/whitelist/{email}")
def remove_whitelist_admin(
    email: str,
    admin: models.User = Depends(require_admin_user),
    db: Session = Depends(get_db)
):
    """Admin only: Remove email from whitelist."""
    success = crud.remove_whitelist_email(db, email=email)
    return {"success": success}
