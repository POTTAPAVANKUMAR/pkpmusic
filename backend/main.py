from fastapi import FastAPI, Depends, HTTPException, Query, UploadFile, File, BackgroundTasks
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

import models, schemas, crud, auth
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

@app.post("/auth/register", response_model=schemas.User)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=user.email)
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    return crud.create_user(db=db, user=user)

@app.post("/auth/login", response_model=schemas.Token)
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

@app.post("/auth/forgot-password")
def forgot_password(req: schemas.ForgotPassword, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=req.email)
    if not db_user:
        # Prevent email enumeration by returning success anyway
        return {"message": "If that email is in our system, an OTP has been sent."}
    
    otp = auth.generate_otp()
    expires_at = time.time() + (15 * 60) # 15 mins from now
    crud.update_user_otp(db, db_user, otp, expires_at)
    
    # Mock Email Sending
    auth.send_otp_email(db_user.email, otp)
    
    return {"message": "If that email is in our system, an OTP has been sent."}

@app.post("/auth/verify-otp")
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

@app.post("/playlists/import/csv")
async def import_playlist_csv(background_tasks: BackgroundTasks, file: UploadFile = File(...), current_user: models.User = Depends(auth.get_current_user)):
    content = await file.read()
    text = content.decode("utf-8-sig")
    
    # Run the heavy processing in the background
    background_tasks.add_task(process_csv_import, text, user_id=current_user.id)
    
    return {"message": "Import process started in the background. Songs and playlists will gradually appear in your library."}

def process_csv_import(csv_text: str, user_id: int):
    # We need a new DB session for the background task
    db = SessionLocal()
    yt = YTMusic()
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
                
                # Check where it should go
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
        # Run yt-dlp to get the dump json
        command = [
            "yt-dlp", "--no-warnings", "--dump-json",
            "-f", "18/140/bestaudio",
            "--extractor-args", "youtube:player_client=android,web",
            url
        ]
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        
        # Extract the JSON block
        lines = result.stdout.strip().split('\n')
        json_data = None
        for line in reversed(lines):
            if line.startswith('{'):
                try:
                    json_data = json.loads(line)
                    break
                except:
                    continue
                    
        if not json_data or 'url' not in json_data:
            raise HTTPException(status_code=404, detail="Could not extract stream URL")
            
        stream_url = json_data['url']
        dl_headers = json_data.get('http_headers', {})
        
        # Build headers for the proxy request
        client_headers = {}
        for k, v in dl_headers.items():
            client_headers[k.lower()] = v
            
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
def create_playlist(playlist: schemas.PlaylistCreate, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    return crud.create_user_playlist(db, playlist, current_user.id)

@app.get("/playlists/", response_model=List[schemas.Playlist])
def get_playlists(skip: int = 0, limit: int = 100, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    # Assuming crud.get_playlists can be modified or we just query by owner
    return db.query(models.Playlist).filter(models.Playlist.owner_id == current_user.id).offset(skip).limit(limit).all()

@app.post("/playlists/{playlist_id}/items", response_model=schemas.PlaylistItem)
def add_song_to_playlist(playlist_id: int, item: schemas.PlaylistItemCreate, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
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
def read_songs(skip: int = 0, limit: int = 100, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    songs = crud.get_songs(db, skip=skip, limit=limit)
    return songs

@app.post("/history/", response_model=schemas.History)
def add_to_history(history: schemas.HistoryCreate, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
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
    
    return crud.add_to_history(db, history, current_user.id)

@app.get("/history/", response_model=List[schemas.History])
def get_history(current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    return crud.get_history(db, user_id=current_user.id)

import time

# Simple cache for dashboard to prevent slow loading every time
dashboard_cache = {
    "data": None,
    "timestamp": 0
}
CACHE_TTL = 3600 # 1 hour

import asyncio
from fastapi import BackgroundTasks

@app.on_event("startup")
async def startup_event():
    # Pre-warm the cache in the background
    asyncio.create_task(prewarm_dashboard_cache())

async def prewarm_dashboard_cache():
    try:
        # Give the server a few seconds to fully boot
        await asyncio.sleep(5)
        # We need a db session to fetch history
        db = SessionLocal()
        get_dashboard_sync(user_id=1, db=db)
        db.close()
    except Exception as e:
        print(f"Error pre-warming cache: {e}")

def get_dashboard_sync(user_id: int, db: Session):
    global dashboard_cache
    sections = []
    
    # 1. Trending Songs (Charts)
    try:
        charts = yt.get_charts(country='US')
        trending_items = []
        if 'trending' in charts and 'items' in charts['trending']:
            for track in charts['trending']['items'][:10]:
                trending_items.append(schemas.DashboardItem(
                    id=track['videoId'],
                    title=track.get('title', 'Unknown'),
                    subtitle=", ".join([a['name'] for a in track.get('artists', [])]),
                    image_url=track.get('thumbnails', [{}])[-1].get('url'),
                    type="song"
                ))
            if trending_items:
                sections.append(schemas.DashboardSection(title="Trending Hits", items=trending_items))
    except Exception as e:
        print(f"Error fetching charts: {e}")

    # 2. For You (Personalized Recommendations based on history)
    history = crud.get_history(db, user_id=user_id, limit=1)
    if history:
        try:
            seed_song = history[0].song_id
            watch_playlist = yt.get_watch_playlist(videoId=seed_song, limit=15)
            foryou_items = []
            for track in watch_playlist.get('tracks', [])[1:11]: # Skip the seed song itself
                if track.get('videoId'):
                    foryou_items.append(schemas.DashboardItem(
                        id=track['videoId'],
                        title=track.get('title', 'Unknown'),
                        subtitle=", ".join([a['name'] for a in track.get('artists', [])]),
                        image_url=track.get('thumbnail', [{}])[-1].get('url'),
                        type="song"
                    ))
            if foryou_items:
                sections.append(schemas.DashboardSection(title="Recommended For You", items=foryou_items))
        except Exception as e:
            print(f"Error fetching recommendations: {e}")

    # 3. Moods & Genres
    try:
        moods = yt.get_mood_categories()
        mood_items = []
        for category_group in moods.values():
            for mood in category_group[:5]: # Take 5 from each group to mix it up
                mood_items.append(schemas.DashboardItem(
                    id=mood['params'], # we can use params to fetch playlists later
                    title=mood['title'],
                    type="mood"
                ))
            if len(mood_items) > 15:
                break
        if mood_items:
            sections.append(schemas.DashboardSection(title="Moods & Genres", items=mood_items))
    except Exception as e:
        print(f"Error fetching moods: {e}")

    # 4. Featured Playlists (Generic from Home)
    try:
        home = yt.get_home(limit=2)
        for section in home:
            title = section.get('title', 'Featured')
            items = []
            for content in section.get('contents', [])[:10]:
                if content.get('videoId'):
                    items.append(schemas.DashboardItem(
                        id=content['videoId'],
                        title=content.get('title', 'Unknown'),
                        subtitle=", ".join([a['name'] for a in content.get('artists', [])]) if content.get('artists') else "",
                        image_url=content.get('thumbnails', [{}])[-1].get('url'),
                        type="song"
                    ))
                elif content.get('playlistId'):
                    items.append(schemas.DashboardItem(
                        id=content['playlistId'],
                        title=content.get('title', 'Unknown'),
                        subtitle=content.get('description'),
                        image_url=content.get('thumbnails', [{}])[-1].get('url'),
                        type="playlist"
                    ))
            if items:
                sections.append(schemas.DashboardSection(title=title, items=items))
    except Exception as e:
        print(f"Error fetching home features: {e}")

    dashboard_cache["data"] = sections
    dashboard_cache["timestamp"] = time.time()
    return sections

@app.get("/dashboard/", response_model=List[schemas.DashboardSection])
def get_dashboard(current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    global dashboard_cache
    
    # Check cache
    if dashboard_cache["data"] and (time.time() - dashboard_cache["timestamp"]) < CACHE_TTL:
        return dashboard_cache["data"]

    return get_dashboard_sync(current_user.id, db)

@app.post("/favorites/", response_model=schemas.Favorite)
def add_favorite(favorite: schemas.FavoriteCreate, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    return crud.add_favorite(db, favorite, current_user.id)

@app.get("/favorites/", response_model=List[schemas.Favorite])
def get_favorites(current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    return crud.get_favorites(db, current_user.id)

# NEW ENDPOINTS FOR ALL FEATURES

@app.get("/search/suggestions")
def get_search_suggestions(query: str):
    try:
        results = yt.get_search_suggestions(query)
        # return list of strings
        return [res.get('text', res) if isinstance(res, dict) else res for res in results]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/lyrics/{video_id}", response_model=schemas.LyricsResponse)
def get_lyrics(video_id: str):
    try:
        lyrics_id = None
        try:
            watch_playlist = yt.get_watch_playlist(videoId=video_id)
            lyrics_id = watch_playlist.get('lyrics')
        except KeyError:
            pass
            
        if not lyrics_id:
            raise HTTPException(status_code=404, detail="Lyrics not found for this song")
        
        lyrics = yt.get_lyrics(lyrics_id)
        return schemas.LyricsResponse(
            lyrics=lyrics.get('lyrics', ''),
            source=lyrics.get('source', 'Unknown')
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/artist/{channel_id}", response_model=schemas.ArtistDetail)
def get_artist(channel_id: str):
    try:
        artist = yt.get_artist(channel_id)
        songs = []
        if 'songs' in artist and 'results' in artist['songs']:
            for s in artist['songs']['results']:
                songs.append(schemas.SongBase(
                    id=s['videoId'],
                    title=s.get('title', 'Unknown'),
                    artist=artist.get('name', 'Unknown'),
                    album=s.get('album', {}).get('name') if s.get('album') else None,
                    duration_ms=0,
                    cover_art_url=s.get('thumbnails', [{}])[-1].get('url')
                ))
        return schemas.ArtistDetail(
            name=artist.get('name', 'Unknown'),
            description=artist.get('description'),
            views=artist.get('views'),
            subscribers=artist.get('subscribers'),
            thumbnails=artist.get('thumbnails', []),
            songs=songs,
            albums=artist.get('albums', {}).get('results', [])
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/album/{browse_id}", response_model=schemas.AlbumDetail)
def get_album(browse_id: str):
    try:
        album = yt.get_album(browse_id)
        songs = []
        for track in album.get('tracks', []):
            if track.get('videoId'):
                songs.append(schemas.SongBase(
                    id=track['videoId'],
                    title=track.get('title', 'Unknown'),
                    artist=", ".join([a['name'] for a in track.get('artists', [])]),
                    album=album.get('title'),
                    duration_ms=track.get('duration_seconds', 0) * 1000 if track.get('duration_seconds') else 0,
                    cover_art_url=album.get('thumbnails', [{}])[-1].get('url')
                ))
        return schemas.AlbumDetail(
            title=album.get('title', 'Unknown'),
            description=album.get('description'),
            trackCount=album.get('trackCount', len(songs)),
            thumbnails=album.get('thumbnails', []),
            songs=songs
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/moods/{params}", response_model=List[schemas.DashboardItem])
def get_mood_playlists(params: str):
    try:
        # It's actually yt.get_mood_playlists(params) or yt.get_mood_categories() -> then use params.
        # But wait, get_mood_categories returns categories which HAVE params.
        # So we use yt.get_mood_playlists(params) to get playlists for a mood!
        playlists = yt.get_mood_playlists(params)
        items = []
        for p in playlists:
            if 'videoId' in p or 'playlistId' in p:
                items.append(schemas.DashboardItem(
                    id=p.get('playlistId') or p.get('videoId'),
                    title=p.get('title', 'Unknown'),
                    subtitle=p.get('description') or p.get('subtitle', ''),
                    image_url=p.get('thumbnails', [{}])[-1].get('url'),
                    type="playlist"
                ))
        return items
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
