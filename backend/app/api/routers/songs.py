from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from starlette.requests import Request
from sqlalchemy.orm import Session
from typing import List
import subprocess
import json
import httpx

from app import schemas
from app.crud import crud
from app.core import security as auth
from app.db.database import get_db
from app.services.youtube import yt
from app.db import models

router = APIRouter(tags=["songs"])

@router.get("/songs/", response_model=List[schemas.Song])
def read_songs(skip: int = 0, limit: int = 100, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    return crud.get_songs(db, skip=skip, limit=limit)

@router.get("/search/yt", response_model=List[schemas.SongBase])
def search_youtube(query: str = Query(..., min_length=1)):
    try:
        results = yt.search(query, filter="songs", limit=20)
        formatted = []
        for r in results:
            if r.get('videoId'):
                thumbnails = r.get('thumbnails', [])
                cover_url = thumbnails[-1]['url'] if thumbnails else None
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

@router.get("/search/suggestions")
def get_search_suggestions(query: str):
    try:
        results = yt.get_search_suggestions(query)
        return [res.get('text', res) if isinstance(res, dict) else res for res in results]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.api_route("/stream/yt/{video_id}", methods=["GET", "HEAD"])
async def stream_youtube(video_id: str, request: Request):
    url = f"https://www.youtube.com/watch?v={video_id}"
    try:
        command = [
            "yt-dlp", "--no-warnings", "--dump-json",
            "-f", "18/140/bestaudio",
            "--extractor-args", "youtube:player_client=android,web",
            url
        ]
        import asyncio
        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            raise HTTPException(status_code=500, detail=f"yt-dlp error: {stderr.decode()}")
            
        lines = stdout.decode().strip().split('\n')
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
        
        client_headers = {}
        for k, v in dl_headers.items():
            client_headers[k.lower()] = v
            
        if "range" in request.headers:
            client_headers["range"] = request.headers["range"]
            
        client = httpx.AsyncClient()
        req = client.build_request("GET", stream_url, headers=client_headers)
        response = await client.send(req, stream=True)
        
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
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Proxy error: {str(e)}")

@router.get("/lyrics/{video_id}", response_model=schemas.LyricsResponse)
def get_lyrics(video_id: str):
    try:
        # First, try to get the song details to use for a fallback search
        song_title = "Unknown"
        song_artist = "Unknown"
        try:
            song_info = yt.get_song(video_id)
            details = song_info.get('videoDetails', {})
            song_title = details.get('title', 'Unknown')
            song_artist = details.get('author', 'Unknown')
        except Exception:
            pass

        # Try to use ytmusicapi to get official lyrics
        lyrics_id = None
        try:
            watch_playlist = yt.get_watch_playlist(videoId=video_id)
            lyrics_id = watch_playlist.get('lyrics')
        except KeyError:
            pass
            
        if lyrics_id:
            lyrics_data = yt.get_lyrics(lyrics_id)
            return schemas.LyricsResponse(
                lyrics=lyrics_data.get('lyrics', ''),
                source=lyrics_data.get('source', 'YouTube Music')
            )
            
        # Fallback to lyrics.ovh API
        if song_title != "Unknown" and song_artist != "Unknown":
            # Clean up artist name (remove " - Topic" if present)
            clean_artist = song_artist.replace(" - Topic", "").replace("VEVO", "")
            
            # Clean up title (remove "(Official Video)", etc.)
            clean_title = song_title.split("(")[0].split("[")[0].strip()
            
            try:
                response = httpx.get(f"https://api.lyrics.ovh/v1/{clean_artist}/{clean_title}", timeout=5.0)
                if response.status_code == 200:
                    data = response.json()
                    if "lyrics" in data:
                        return schemas.LyricsResponse(
                            lyrics=data["lyrics"],
                            source="Lyrics.ovh"
                        )
            except Exception:
                pass

        raise HTTPException(status_code=404, detail="Lyrics not found for this song")
        
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/artist/{channel_id}", response_model=schemas.ArtistDetail)
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

@router.get("/album/{browse_id}", response_model=schemas.AlbumDetail)
def get_album(browse_id: str):
    try:
        if browse_id.startswith('VL') or browse_id.startswith('PL') or browse_id.startswith('RD'):
            album = yt.get_playlist(browse_id)
            tracks_key = 'tracks'
        else:
            album = yt.get_album(browse_id)
            tracks_key = 'tracks'
            
        songs = []
        for track in album.get(tracks_key, []):
            if track.get('videoId'):
                songs.append(schemas.Song(
                    id=track['videoId'],
                    title=track.get('title', 'Unknown'),
                    artist=", ".join([a['name'] for a in track.get('artists', [])]) if track.get('artists') else "Unknown Artist",
                    album=album.get('title'),
                    duration_ms=0,
                    cover_art_url=track.get('thumbnails', album.get('thumbnails', [{}]))[-1].get('url')
                ))
        return schemas.AlbumDetail(
            title=album.get('title', 'Unknown'),
            description=album.get('description', ''),
            trackCount=album.get('trackCount', len(songs)),
            thumbnails=album.get('thumbnails', []),
            songs=songs
        )
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/history/", response_model=schemas.History)
def add_to_history(history: schemas.HistoryCreate, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    db_song = crud.get_song(db, song_id=history.song_id)
    if not db_song:
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

@router.get("/history/", response_model=List[schemas.History])
def get_history(current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    return crud.get_history(db, user_id=current_user.id)

@router.post("/favorites/", response_model=schemas.Favorite)
def add_favorite(favorite: schemas.FavoriteCreate, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    return crud.add_favorite(db, favorite, current_user.id)

@router.get("/favorites/", response_model=List[schemas.Favorite])
def get_favorites(current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    return crud.get_favorites(db, current_user.id)

@router.get("/upnext/{video_id}", response_model=List[schemas.SongBase])
def get_upnext(video_id: str):
    try:
        watch_playlist = yt.get_watch_playlist(videoId=video_id, limit=30)
        formatted = []
        for track in watch_playlist.get('tracks', []):
            if track.get('videoId'):
                # Avoid returning the same song if it's the exact same video_id, but the player can also filter.
                song = schemas.SongBase(
                    id=track['videoId'],
                    title=track.get('title', 'Unknown Title'),
                    artist=", ".join([a['name'] for a in track.get('artists', [])]),
                    album=track.get('album', {}).get('name') if track.get('album') else None,
                    duration_ms=track.get('lengthSeconds', 0) * 1000 if track.get('lengthSeconds') else 0,
                    cover_art_url=track.get('thumbnail', [{}])[-1].get('url') if track.get('thumbnail') else None
                )
                formatted.append(song)
        return formatted
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
