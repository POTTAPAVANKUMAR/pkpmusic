from fastapi import FastAPI, Depends, HTTPException, Query, UploadFile, File
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
from typing import List
import subprocess
import json
import csv
import io
from datetime import datetime
import httpx
from fastapi.responses import RedirectResponse, StreamingResponse
from starlette.requests import Request

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

@app.post("/playlists/import/csv")
async def import_playlist_csv(file: UploadFile = File(...), db: Session = Depends(get_db)):
    content = await file.read()
    text = content.decode("utf-8")
    reader = csv.DictReader(io.StringIO(text))
    
    imported_count = 0
    yt = YTMusic()

    for row in reader:
        title = row.get("Track Name", row.get("Title", row.get("title", "")))
        artist = row.get("Artist Name", row.get("Artist", row.get("artist", "")))
        
        if title:
            query = f"{title} {artist}"
            results = yt.search(query, filter="songs")
            if results:
                top_hit = results[0]
                video_id = top_hit['videoId']
                db_song = crud.get_song(db, video_id)
                if not db_song:
                    song_data = schemas.SongCreate(
                        id=video_id,
                        title=top_hit['title'],
                        artist=top_hit['artists'][0]['name'] if top_hit.get('artists') else "Unknown",
                        album=top_hit['album']['name'] if top_hit.get('album') else None,
                        duration_ms=top_hit.get('duration_seconds', 0) * 1000 if top_hit.get('duration_seconds') else None,
                        cover_art_url=top_hit['thumbnails'][-1]['url'] if top_hit.get('thumbnails') else None
                    )
                    crud.create_song(db, song_data)
                
                # Check if it's already in favorites to prevent duplicates
                existing_favs = crud.get_favorites(db, user_id=1)
                if not any(f.song_id == video_id for f in existing_favs):
                    fav = schemas.FavoriteCreate(song_id=video_id)
                    crud.add_favorite(db, fav, user_id=1)
                imported_count += 1

    return {"message": f"Successfully imported {imported_count} songs to favorites"}

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

@app.api_route("/stream/yt/{video_id}", methods=["GET", "HEAD"])
async def stream_youtube(video_id: str, request: Request):
    """Uses yt-dlp to extract the raw audio stream URL and proxies the stream to the client."""
    url = f"https://www.youtube.com/watch?v={video_id}"
    try:
        # Run yt-dlp to get the direct URL
        command = ["yt-dlp", "--no-warnings", "-f", "m4a/bestaudio/best", "-g", url]
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        stream_url = result.stdout.strip().split('\n')[-1]
        if not stream_url.startswith("http"):
            raise HTTPException(status_code=404, detail="Could not extract stream URL")
        
        # Build headers for the proxy request
        client_headers = {}
        if "range" in request.headers:
            client_headers["range"] = request.headers["range"]
            
        client = httpx.AsyncClient()
        # Make a stream request to the Google servers
        req = client.build_request("GET", stream_url, headers=client_headers)
        response = await client.send(req, stream=True)
        
        # Forward the headers back to the AVPlayer (like Content-Type, Content-Length, Content-Range)
        response_headers = {}
        for key in ["content-type", "content-length", "content-range", "accept-ranges"]:
            if key in response.headers:
                response_headers[key] = response.headers[key]
                
        async def stream_generator():
            async for chunk in response.aiter_bytes():
                yield chunk
            await client.aclose()
            
        return StreamingResponse(
            stream_generator(),
            status_code=response.status_code,
            headers=response_headers
        )
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"yt-dlp error: {e.stderr}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Proxy error: {str(e)}")

# Playlists API
@app.post("/playlists/", response_model=schemas.Playlist)
def create_playlist(playlist: schemas.PlaylistCreate, user_id: int = 1, db: Session = Depends(get_db)):
    return crud.create_user_playlist(db, playlist, user_id)

@app.get("/playlists/", response_model=List[schemas.Playlist])
def get_playlists(user_id: int = 1, skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    # Assuming crud.get_playlists can be modified or we just query by owner
    return db.query(models.Playlist).filter(models.Playlist.owner_id == user_id).offset(skip).limit(limit).all()

@app.post("/playlists/{playlist_id}/items", response_model=schemas.PlaylistItem)
def add_song_to_playlist(playlist_id: int, item: schemas.PlaylistItemCreate, db: Session = Depends(get_db)):
    # Ensure song exists
    db_song = crud.get_song(db, song_id=item.song_id)
    if not db_song:
        try:
            song_info = yt.get_song(item.song_id)
            details = song_info.get('videoDetails', {})
            thumbnails = details.get('thumbnail', {}).get('thumbnails', [])
            cover_url = thumbnails[-1]['url'] if thumbnails else None
            
            new_song = schemas.SongCreate(
                id=item.song_id,
                title=details.get('title', 'Unknown'),
                artist=details.get('author', 'Unknown'),
                duration_ms=int(details.get('lengthSeconds', 0)) * 1000,
                cover_art_url=cover_url
            )
            db_song = crud.create_song(db, new_song)
        except Exception as e:
            raise HTTPException(status_code=404, detail="Song not found and could not be fetched from YT")
            
    return crud.add_song_to_playlist(db, playlist_id=playlist_id, item=item)

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
