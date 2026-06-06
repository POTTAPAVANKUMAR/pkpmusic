from sqlalchemy.orm import Session
import models, schemas

import auth

# Users
def get_user(db: Session, user_id: int):
    return db.query(models.User).filter(models.User.id == user_id).first()

def get_user_by_email(db: Session, email: str):
    return db.query(models.User).filter(models.User.email == email).first()

def create_user(db: Session, user: schemas.UserCreate):
    hashed_password = auth.get_password_hash(user.password)
    db_user = models.User(email=user.email, username=user.username, hashed_password=hashed_password)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def update_user_otp(db: Session, user: models.User, otp_code: str, otp_expires_at: float):
    user.otp_code = otp_code
    user.otp_expires_at = otp_expires_at
    db.commit()
    db.refresh(user)
    return user

def update_user_password(db: Session, user: models.User, new_password: str):
    user.hashed_password = auth.get_password_hash(new_password)
    user.otp_code = None
    user.otp_expires_at = None
    db.commit()
    db.refresh(user)
    return user

# Songs
def get_songs(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.Song).offset(skip).limit(limit).all()

def get_song(db: Session, song_id: str):
    return db.query(models.Song).filter(models.Song.id == song_id).first()

def create_song(db: Session, song: schemas.SongCreate):
    db_song = models.Song(**song.dict())
    db.add(db_song)
    db.commit()
    db.refresh(db_song)
    return db_song

# Playlists
def get_playlists(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.Playlist).offset(skip).limit(limit).all()

def create_user_playlist(db: Session, playlist: schemas.PlaylistCreate, user_id: int):
    db_playlist = models.Playlist(**playlist.dict(), owner_id=user_id)
    db.add(db_playlist)
    db.commit()
    db.refresh(db_playlist)
    return db_playlist

def add_song_to_playlist(db: Session, playlist_id: int, item: schemas.PlaylistItemCreate):
    db_item = models.PlaylistItem(**item.dict(), playlist_id=playlist_id)
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

# History
def add_to_history(db: Session, history: schemas.HistoryCreate, user_id: int):
    db_history = models.History(**history.dict(), user_id=user_id)
    db.add(db_history)
    db.commit()
    db.refresh(db_history)
    return db_history

def get_history(db: Session, user_id: int, limit: int = 50):
    return db.query(models.History).filter(models.History.user_id == user_id).order_by(models.History.id.desc()).limit(limit).all()

# Favorites
def add_favorite(db: Session, favorite: schemas.FavoriteCreate, user_id: int):
    db_fav = models.Favorite(**favorite.dict(), user_id=user_id)
    db.add(db_fav)
    db.commit()
    db.refresh(db_fav)
    return db_fav

def get_favorites(db: Session, user_id: int):
    return db.query(models.Favorite).filter(models.Favorite.user_id == user_id).all()
