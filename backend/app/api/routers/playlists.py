from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, BackgroundTasks
from sqlalchemy.orm import Session
from typing import List
import csv
import io
from app import schemas
from app.crud import crud
from app.core import security as auth
from app.db.database import get_db, SessionLocal
from app.services.youtube import yt
from app.db import models

router = APIRouter(prefix="/playlists", tags=["playlists"])

@router.post("/", response_model=schemas.Playlist)
def create_playlist(playlist: schemas.PlaylistCreate, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    return crud.create_user_playlist(db, playlist, current_user.id)

@router.get("/", response_model=List[schemas.Playlist])
def get_playlists(skip: int = 0, limit: int = 100, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    return db.query(models.Playlist).filter(models.Playlist.owner_id == current_user.id).offset(skip).limit(limit).all()

@router.post("/{playlist_id}/items", response_model=schemas.PlaylistItem)
def add_song_to_playlist(playlist_id: int, item: schemas.PlaylistItemCreate, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
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

@router.post("/import/csv")
async def import_playlist_csv(background_tasks: BackgroundTasks, file: UploadFile = File(...), current_user: models.User = Depends(auth.get_current_user)):
    content = await file.read()
    text = content.decode("utf-8-sig")
    background_tasks.add_task(process_csv_import, text, user_id=current_user.id)
    return {"message": "Import process started in the background. Songs and playlists will gradually appear in your library."}

def process_csv_import(csv_text: str, user_id: int):
    db = SessionLocal()
    reader = csv.DictReader(io.StringIO(csv_text))
    
    existing_playlists = crud.get_playlists(db, limit=1000)
    playlist_map = {p.name: p.id for p in existing_playlists}
    
    imported_count = 0
    for row in reader:
        title = row.get("Track name", row.get("Track Name", row.get("Title", row.get("title", ""))))
        artist = row.get("Artist name", row.get("Artist Name", row.get("Artist", row.get("artist", ""))))
        playlist_name = row.get("Playlist name", "")
        
        if not title:
            continue
            
        try:
            query = f"{title} {artist}"
            results = yt.search(query, filter="songs")
            if results:
                top_hit = results[0]
                video_id = top_hit['videoId']
                if not video_id:
                    continue
                    
                db_song = crud.get_song(db, video_id)
                if not db_song:
                    song_data = schemas.SongCreate(
                        id=video_id,
                        title=top_hit.get('title', title),
                        artist=top_hit['artists'][0]['name'] if top_hit.get('artists') else artist,
                        album=top_hit['album']['name'] if top_hit.get('album') else None,
                        duration_ms=top_hit.get('duration_seconds', 0) * 1000 if top_hit.get('duration_seconds') else None,
                        cover_art_url=top_hit['thumbnails'][-1]['url'] if top_hit.get('thumbnails') else None
                    )
                    crud.create_song(db, song_data)
                
                if playlist_name in ["Library Songs", "My Likes", "Library Albums", ""]:
                    existing_favs = crud.get_favorites(db, user_id=user_id)
                    if not any(f.song_id == video_id for f in existing_favs):
                        fav = schemas.FavoriteCreate(song_id=video_id)
                        crud.add_favorite(db, fav, user_id=user_id)
                else:
                    if playlist_name not in playlist_map:
                        p_create = schemas.PlaylistCreate(name=playlist_name)
                        new_p = crud.create_user_playlist(db, p_create, user_id=user_id)
                        playlist_map[playlist_name] = new_p.id
                        
                    pid = playlist_map[playlist_name]
                    db_playlist = db.query(models.Playlist).filter(models.Playlist.id == pid).first()
                    if db_playlist and not any(i.song_id == video_id for i in db_playlist.items):
                        item = schemas.PlaylistItemCreate(song_id=video_id, position=0)
                        crud.add_song_to_playlist(db, playlist_id=pid, item=item)
                        
                imported_count += 1
        except Exception as e:
            print(f"Error importing {title}: {e}")
            
    db.close()
    print(f"Background CSV Import Complete: {imported_count} songs imported.")
