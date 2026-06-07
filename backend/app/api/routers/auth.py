from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app import schemas
from app.crud import crud
from app.core import security as auth
from app.db.database import get_db
import time

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/register", response_model=schemas.User)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=user.email)
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    return crud.create_user(db=db, user=user)

@router.post("/login", response_model=schemas.Token)
def login_for_access_token(user: schemas.UserLogin, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=user.email)
    if not db_user or not auth.verify_password(user.password, db_user.hashed_password):
        raise HTTPException(
            status_code=401,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = auth.timedelta(minutes=auth.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(
        data={"sub": db_user.email}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

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
