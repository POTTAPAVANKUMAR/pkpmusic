from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse, RedirectResponse
from starlette.requests import Request
from sqlalchemy.orm import Session
from typing import List
import subprocess
import json
import httpx
import time
import logging
import asyncio
from app import schemas
from app.crud import crud
from app.core import security as auth
from app.db.database import get_db
from app.services.youtube import yt
from app.db import models
from app.api.image_utils import upscale_thumbnail

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
                cover_url = upscale_thumbnail(thumbnails[-1]['url']) if thumbnails else None
                song = {
                    "id": r['videoId'],
                    "title": r.get('title', 'Unknown Title'),
                    "artist": ", ".join([a['name'] for a in r.get('artists', [])]),
                    "album": r.get('album', {}).get('name') if r.get('album') else None,
                    "album_id": r.get('album', {}).get('id') if r.get('album') else None,
                    "duration_ms": r.get('duration_seconds', 0) * 1000 if r.get('duration_seconds') else 0,
                    "cover_art_url": cover_url
                }
                formatted.append(song)
        return formatted
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/search/yt/albums", response_model=List[schemas.AlbumSearchResult])
def search_youtube_albums(query: str = Query(..., min_length=1)):
    try:
        results = yt.search(query, filter="albums", limit=20)
        formatted = []
        for r in results:
            if r.get('browseId'):
                thumbnails = r.get('thumbnails', [])
                cover_url = upscale_thumbnail(thumbnails[-1]['url']) if thumbnails else None
                album = {
                    "browseId": r['browseId'],
                    "title": r.get('title', 'Unknown Title'),
                    "artist": ", ".join([a['name'] for a in r.get('artists', [])]) if r.get('artists') else "Unknown",
                    "year": r.get('year'),
                    "cover_art_url": cover_url
                }
                formatted.append(album)
        return formatted
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/search/yt/artists", response_model=List[schemas.ArtistSearchResult])
def search_youtube_artists(query: str = Query(..., min_length=1)):
    try:
        results = yt.search(query, filter="artists", limit=20)
        formatted = []
        for r in results:
            if r.get('browseId'):
                thumbnails = r.get('thumbnails', [])
                cover_url = upscale_thumbnail(thumbnails[-1]['url']) if thumbnails else None
                artist = {
                    "browseId": r['browseId'],
                    "artist": r.get('artist', 'Unknown Artist'),
                    "cover_art_url": cover_url
                }
                formatted.append(artist)
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

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

STREAM_CACHE = {}
LYRICS_CACHE = {}
YT_DLP_SEMAPHORE = asyncio.Semaphore(5)

@router.api_route("/stream/yt/{video_id}", methods=["GET", "HEAD"])
async def stream_youtube(video_id: str, request: Request, video: bool = False):
    logger.info(f"Received stream request for video_id: {video_id}")
    url = f"https://www.youtube.com/watch?v={video_id}"
    try:
        now = time.time()
        # Clean up old cache entries if cache grows too large (1 hour TTL)
        if len(STREAM_CACHE) > 500:
            cleaned = 0
            for k in list(STREAM_CACHE.keys()):
                if now - STREAM_CACHE[k]['time'] > 3600:
                    del STREAM_CACHE[k]
                    cleaned += 1
            if cleaned > 0:
                logger.info(f"Cleaned {cleaned} expired entries from stream cache.")
                
        stream_url = None
        cache_key = f"{video_id}_video" if video else f"{video_id}_audio"
        if cache_key in STREAM_CACHE and (now - STREAM_CACHE[cache_key]['time'] < 3600):
            stream_url = STREAM_CACHE[cache_key]['url']
            logger.info(f"Cache hit for {cache_key}")
        else:
            logger.info(f"Cache miss for {cache_key}. Preparing yt-dlp extraction.")
            
            format_str = "18/best[ext=mp4]/best" if video else "140/bestaudio[ext=m4a]/bestaudio[acodec^=mp4a]/18/best[ext=mp4]/bestaudio/best"
            
            command = [
                "yt-dlp", "--no-warnings", "--dump-json",
                "-f", format_str,
                "--extractor-args", "youtube:player_client=ios,android,web",
                url
            ]
            
            logger.info(f"Waiting for semaphore to execute yt-dlp for {video_id}...")
            async with YT_DLP_SEMAPHORE:
                logger.info(f"Acquired semaphore. Executing yt-dlp for {video_id}...")
                start_time = time.time()
                process = await asyncio.create_subprocess_exec(
                    *command,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                stdout, stderr = await process.communicate()
                exec_time = time.time() - start_time
                logger.info(f"yt-dlp execution for {video_id} completed in {exec_time:.2f}s with return code {process.returncode}")
            
            if process.returncode != 0:
                error_msg = stderr.decode()
                logger.error(f"yt-dlp failed for {video_id}: {error_msg}")
                raise HTTPException(status_code=500, detail=f"yt-dlp error: {error_msg}")
                
            lines = stdout.decode().strip().split('\n')
            json_data = None
            for line in reversed(lines):
                if line.startswith('{'):
                    try:
                        json_data = json.loads(line)
                        break
                    except json.JSONDecodeError as e:
                        logger.warning(f"Failed to parse JSON line from yt-dlp output for {video_id}: {e}")
                        continue
                        
            if not json_data or 'url' not in json_data:
                logger.error(f"Could not extract stream URL for {video_id} from yt-dlp output.")
                raise HTTPException(status_code=404, detail="Could not extract stream URL")
                
            stream_url = json_data['url']
            STREAM_CACHE[cache_key] = {'url': stream_url, 'time': now}
            logger.info(f"Successfully extracted and cached stream URL for {cache_key}")
            
        logger.info(f"Redirecting {video_id} to stream URL.")
        return RedirectResponse(url=stream_url)
    except Exception as e:
        import traceback
        err_msg = "".join(traceback.format_exception(type(e), e, e.__traceback__))
        logger.error(f"STREAM ERROR for {video_id}: {err_msg}")
        raise HTTPException(status_code=500, detail=f"Stream error: {str(e)}")

def sanitize_metadata_for_lyrics(title: str, artist: str):
    """Clean artist and title strings for external lyrics search engines."""
    clean_artist = artist.replace(" - Topic", "").replace("VEVO", "").replace(" Official", "").strip()
    if "," in clean_artist:
        clean_artist = clean_artist.split(",")[0].strip()
    if "&" in clean_artist:
        clean_artist = clean_artist.split("&")[0].strip()
    
    import re
    clean_artist = re.split(r'\s+(?:feat\.|ft\.|featuring)\s+', clean_artist, flags=re.IGNORECASE)[0].strip()

    clean_title = title
    # Remove bracketed extras like (Official Music Video), [Lyric Video], (Audio), etc.
    clean_title = re.sub(r'[\(\[][^\)\]]*(?:video|audio|visualizer|lyric|remaster|version|explicit|prod\.)[^\)\]]*[\)\]]', '', clean_title, flags=re.IGNORECASE)
    clean_title = re.sub(r'[\(\[].*?[\)\]]', '', clean_title) # Remove remaining parentheses if clean
    clean_title = clean_title.split("-")[0].strip() if "-" in clean_title and len(clean_title.split("-")[0].strip()) > 2 else clean_title.strip()
    clean_title = clean_title.strip()
    if not clean_title:
        clean_title = title.split("(")[0].split("[")[0].strip()
        
    return clean_title, clean_artist

@router.get("/lyrics/{video_id}", response_model=schemas.LyricsResponse)
def get_lyrics(video_id: str):
    now = time.time()
    # Check cache first
    if video_id in LYRICS_CACHE and (now - LYRICS_CACHE[video_id]['time'] < 86400):
        cached = LYRICS_CACHE[video_id]
        return schemas.LyricsResponse(lyrics=cached['lyrics'], source=cached['source'])

    try:
        # 1. Fetch song details (title & artist) from YouTube
        song_title = "Unknown"
        song_artist = "Unknown"
        try:
            song_info = yt.get_song(video_id)
            details = song_info.get('videoDetails', {})
            song_title = details.get('title', 'Unknown')
            song_artist = details.get('author', 'Unknown')
        except Exception:
            pass

        # 2. Tier 1: Try official YouTube Music lyrics via ytmusicapi
        lyrics_id = None
        try:
            watch_playlist = yt.get_watch_playlist(videoId=video_id)
            lyrics_id = watch_playlist.get('lyrics')
        except Exception:
            pass
            
        if lyrics_id:
            try:
                lyrics_data = yt.get_lyrics(lyrics_id)
                lyrics_text = lyrics_data.get('lyrics', '')
                if lyrics_text and lyrics_text.strip():
                    source = lyrics_data.get('source', 'YouTube Music')
                    LYRICS_CACHE[video_id] = {'lyrics': lyrics_text.strip(), 'source': source, 'time': now}
                    return schemas.LyricsResponse(
                        lyrics=lyrics_text.strip(),
                        source=source
                    )
            except Exception:
                pass
            
        # 3. Tier 2: Try LRCLIB API
        if song_title != "Unknown" and song_artist != "Unknown":
            clean_title, clean_artist = sanitize_metadata_for_lyrics(song_title, song_artist)
            
            try:
                lrclib_url = f"https://lrclib.net/api/get?track_name={httpx.URL(clean_title).raw_path.decode()}&artist_name={httpx.URL(clean_artist).raw_path.decode()}"
                response = httpx.get(
                    "https://lrclib.net/api/get",
                    params={"track_name": clean_title, "artist_name": clean_artist},
                    headers={"User-Agent": "PKPMusic/1.0"},
                    timeout=4.0
                )
                if response.status_code == 200:
                    data = response.json()
                    lyrics_text = data.get("plainLyrics") or data.get("syncedLyrics")
                    if lyrics_text and lyrics_text.strip():
                        LYRICS_CACHE[video_id] = {'lyrics': lyrics_text.strip(), 'source': 'LRCLIB', 'time': now}
                        return schemas.LyricsResponse(
                            lyrics=lyrics_text.strip(),
                            source="LRCLIB"
                        )
            except Exception as e:
                logger.warning(f"LRCLIB fetch error for {clean_title} - {clean_artist}: {e}")

            # 4. Tier 3: Fallback to Lyrics.ovh API
            try:
                clean_artist_enc = httpx.URL(clean_artist).raw_path.decode()
                clean_title_enc = httpx.URL(clean_title).raw_path.decode()
                response = httpx.get(
                    f"https://api.lyrics.ovh/v1/{clean_artist}/{clean_title}",
                    headers={"User-Agent": "PKPMusic/1.0"},
                    timeout=4.0
                )
                if response.status_code == 200:
                    data = response.json()
                    if "lyrics" in data and data["lyrics"].strip():
                        lyrics_text = data["lyrics"].strip()
                        LYRICS_CACHE[video_id] = {'lyrics': lyrics_text, 'source': 'Lyrics.ovh', 'time': now}
                        return schemas.LyricsResponse(
                            lyrics=lyrics_text,
                            source="Lyrics.ovh"
                        )
            except Exception:
                pass

        raise HTTPException(status_code=404, detail="Lyrics not found for this song")
        
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=str(e))

def extract_duration_ms(item):
    dur = item.get('duration_seconds')
    if dur is not None:
        try:
            return int(dur) * 1000
        except:
            pass
            
    duration_str = item.get('duration')
    if duration_str:
        parts = str(duration_str).split(':')
        try:
            if len(parts) == 2:
                return (int(parts[0]) * 60 + int(parts[1])) * 1000
            elif len(parts) == 3:
                return (int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])) * 1000
        except Exception:
            pass
    return 0

@router.get("/artist/{channel_id}", response_model=schemas.ArtistDetail)
def get_artist(channel_id: str):
    try:
        artist = yt.get_artist(channel_id)
        
        # Fetch the full playlist for songs if available
        songs_list = []
        songs_playlist_id = artist.get('songs', {}).get('browseId')
        if songs_playlist_id:
            try:
                playlist = yt.get_playlist(songs_playlist_id, limit=200)
                songs_list = playlist.get('tracks', [])
            except Exception as e:
                logger.error(f"Failed to fetch songs playlist for {channel_id}: {e}")
                songs_list = artist.get('songs', {}).get('results', [])
        else:
            songs_list = artist.get('songs', {}).get('results', [])

        songs = []
        for s in songs_list:
            # The playlist tracks might have slightly different keys than artist top songs
            if s.get('videoId'):
                songs.append(schemas.SongBase(
                    id=s['videoId'],
                    title=s.get('title', 'Unknown'),
                    artist=artist.get('name', 'Unknown'),
                    album=s.get('album', {}).get('name') if s.get('album') else None,
                    album_id=s.get('album', {}).get('id') if s.get('album') else None,
                    duration_ms=extract_duration_ms(s),
                    cover_art_url=upscale_thumbnail(s.get('thumbnails', [{}])[-1].get('url') if s.get('thumbnails') else None)
                ))
                
        # Combine albums and singles
        all_albums = artist.get('albums', {}).get('results', []) + artist.get('singles', {}).get('results', [])
        
        return schemas.ArtistDetail(
            name=artist.get('name', 'Unknown'),
            description=artist.get('description'),
            views=artist.get('views'),
            subscribers=artist.get('subscribers'),
            thumbnails=artist.get('thumbnails', []),
            songs=songs,
            albums=all_albums
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
                # Safely get thumbnails, fallback to album thumbnails or a default empty list
                t_thumbs = track.get('thumbnails')
                a_thumbs = album.get('thumbnails')
                thumbnails = t_thumbs if t_thumbs else (a_thumbs if a_thumbs else [{}])
                cover_url = upscale_thumbnail(thumbnails[-1].get('url')) if thumbnails else None
                
                songs.append(schemas.Song(
                    id=track['videoId'],
                    title=track.get('title', 'Unknown'),
                    artist=", ".join([a['name'] for a in track.get('artists', [])]) if track.get('artists') else "Unknown Artist",
                    album=album.get('title'),
                    duration_ms=extract_duration_ms(track),
                    cover_art_url=cover_url
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
            cover_url = upscale_thumbnail(thumbnails[-1]['url']) if thumbnails else None
            
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
                    album_id=track.get('album', {}).get('id') if track.get('album') else None,
                    duration_ms=track.get('lengthSeconds', 0) * 1000 if track.get('lengthSeconds') else 0,
                    cover_art_url=track.get('thumbnail', [{}])[-1].get('url') if track.get('thumbnail') else None
                )
                formatted.append(song)
        return formatted
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{video_id}/related", response_model=dict)
def get_song_related(video_id: str):
    """
    Get related songs for a given video ID using yt.get_song_related()
    """
    try:
        watch_playlist = yt.get_watch_playlist(videoId=video_id)
        related_browse_id = watch_playlist.get("related")
        if not related_browse_id:
            raise HTTPException(status_code=404, detail="No related content found for this song")
        
        related_data = yt.get_song_related(related_browse_id)
        return {"related": related_data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{video_id}/credits", response_model=dict)
def get_song_credits(browse_id: str):
    """
    Get credits for a song using its credits browseId.
    """
    try:
        credits_data = yt.get_song_credits(browse_id)
        return {"credits": credits_data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/artist/{channel_id}/albums", response_model=dict)
def get_artist_albums_endpoint(channel_id: str, params: str = ""):
    """
    Get all albums for an artist.
    """
    try:
        if not params:
            artist_info = yt.get_artist(channel_id)
            if 'albums' in artist_info and 'browseId' in artist_info['albums']:
                channel_id = artist_info['albums']['browseId']
                params = artist_info['albums'].get('params', "")
        
        albums = yt.get_artist_albums(channel_id, params)
        return {"albums": albums}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
