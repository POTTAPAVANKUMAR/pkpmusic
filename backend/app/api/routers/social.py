from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app import schemas
from app.crud import crud
from app.core import security as auth
from app.db.database import get_db
from app.db import models

router = APIRouter(prefix="/social", tags=["social"])

@router.get("/search", response_model=List[schemas.ChatUser])
def search_users(q: str, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    if len(q) < 2:
        return []
    users = crud.search_users(db, query=q)
    return [schemas.ChatUser(id=u.id, username=u.username) for u in users if u.id != current_user.id]

@router.get("/users", response_model=List[schemas.ChatUser])
def get_all_users(current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    users = db.query(models.User).filter(models.User.id != current_user.id).all()
    return [schemas.ChatUser(id=u.id, username=u.username) for u in users]

@router.post("/request", response_model=schemas.FriendshipResponse)
def send_friend_request(req: schemas.FriendshipCreate, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    existing = db.query(models.Friendship).filter(
        models.Friendship.user_id == current_user.id,
        models.Friendship.friend_id == req.friend_id
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Friendship or request already exists")
    
    return crud.send_friend_request(db, user_id=current_user.id, friend_id=req.friend_id)

@router.post("/accept", response_model=schemas.FriendshipResponse)
def accept_friend_request(req: schemas.FriendshipBase, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    result = crud.accept_friend_request(db, user_id=current_user.id, friend_id=req.friend_id)
    if not result:
        raise HTTPException(status_code=404, detail="Pending request not found")
    return result

@router.get("/friends", response_model=List[schemas.FriendshipResponse])
def get_friends(current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    return crud.get_friends(db, user_id=current_user.id)

@router.get("/requests", response_model=List[schemas.FriendshipResponse])
def get_pending_requests(current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    return crud.get_pending_requests(db, user_id=current_user.id)

@router.get("/chat/{friend_id}", response_model=List[schemas.MessageResponse])
def get_chat_history(friend_id: int, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    messages = crud.get_chat_history(db, user_id=current_user.id, friend_id=friend_id)
    return messages
