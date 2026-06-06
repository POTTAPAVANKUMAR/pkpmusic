from fastapi import FastAPI, Depends, HTTPException, Query
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
from typing import List
import subprocess
import json
from datetime import datetime

import models, schemas, crud
from database import SessionLocal, engine

# Create the database tables
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="PKP Music API", description="Backend for the new cross-platform music app.")

# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

from ytmusicapi import YTMusic
yt = YTMusic()

@app.get("/")
def read_root():
    return {"message": "Welcome to the PKP Music API"}

@app.post("/users/", response_model=schemas.User)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=user.email)
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    return crud.create_user(db=db, user=user)

@app.get("/search/yt", response_model=List[schemas.SongBase])
def search_youtube(query: str = Query(..., min_length=1)):
    """Search YouTube Music and return formatted results."""
    try:
        results = yt.search(query, filter="songs", limit=20)
        formatted = []
        for r in results:
            if r.get('videoId'):
                # Extract the best thumbnail
                thumbnails = r.get('thumbnails', [])
                cover_url = thumbnails[-1]['url'] if thumbnails else None
                
                # Format to match SongBase schema
                song = {
                    "id": r['videoId'],
                    "title": r.get('title', 'Unknown Title'),
                    "artist": ", ".join([a['name'] for a in r.get('artists', [])]),
                    "album": r.get('album', {}).get('name') if r.get('album') else None,
                    "duration_ms": r.get('duration_seconds', 0) * 1000 if r.get('duration_seconds') else 0,
                    "cover_art_url": cover_url
                }
                formatted.append(song)
        return formatted
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/stream/yt/{video_id}")
def stream_youtube(video_id: str):
    """Uses yt-dlp to extract the raw audio stream URL and redirects the client."""
    url = f"https://www.youtube.com/watch?v={video_id}"
    try:
        # Run yt-dlp to get the direct URL
        result = subprocess.run(
            ["yt-dlp", "-f", "bestaudio", "-g", url],
            capture_output=True,
            text=True,
            check=True
        )
        stream_url = result.stdout.strip()
        if not stream_url:
            raise HTTPException(status_code=404, detail="Could not extract stream URL")
        
        # Redirect the iPhone AVPlayer directly to Google's servers
        return RedirectResponse(url=stream_url)
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"yt-dlp error: {e.stderr}")

@app.get("/songs/", response_model=List[schemas.Song])
def read_songs(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    songs = crud.get_songs(db, skip=skip, limit=limit)
    return songs

@app.post("/history/", response_model=schemas.History)
def add_to_history(history: schemas.HistoryCreate, user_id: int = 1, db: Session = Depends(get_db)):
    # Ensure the song exists in our local DB first so we can reference it
    db_song = crud.get_song(db, song_id=history.song_id)
    if not db_song:
        # We need the client to optionally pass song details to save it, or fetch from YT here.
        # For simplicity, if it's not in DB, we'll fetch from ytmusicapi and save it.
        try:
            song_info = yt.get_song(history.song_id)
            details = song_info.get('videoDetails', {})
            thumbnails = details.get('thumbnail', {}).get('thumbnails', [])
            cover_url = thumbnails[-1]['url'] if thumbnails else None
            
            new_song = schemas.SongCreate(
                id=history.song_id,
                title=details.get('title', 'Unknown'),
                artist=details.get('author', 'Unknown'),
                duration_ms=int(details.get('lengthSeconds', 0)) * 1000,
                cover_art_url=cover_url
            )
            db_song = crud.create_song(db, new_song)
        except Exception as e:
            raise HTTPException(status_code=404, detail="Song not found and could not be fetched from YT")
    
    return crud.add_to_history(db, history, user_id)

@app.get("/history/", response_model=List[schemas.History])
def get_history(user_id: int = 1, db: Session = Depends(get_db)):
    return crud.get_history(db, user_id=user_id)

@app.post("/favorites/", response_model=schemas.Favorite)
def add_favorite(favorite: schemas.FavoriteCreate, user_id: int = 1, db: Session = Depends(get_db)):
    return crud.add_favorite(db, favorite, user_id)

@app.get("/favorites/", response_model=List[schemas.Favorite])
def get_favorites(user_id: int = 1, db: Session = Depends(get_db)):
    return crud.get_favorites(db, user_id=user_id)
