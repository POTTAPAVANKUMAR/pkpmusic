from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
import time
import asyncio

from app import schemas
from app.crud import crud
from app.core import security as auth
from app.db.database import get_db, SessionLocal
from app.services.youtube import yt
from app.db import models
from app.api.image_utils import upscale_thumbnail, extract_thumbnail_url

router = APIRouter(tags=["dashboard"])

dashboard_cache = {} # user_id -> {"data": sections, "timestamp": float}
CACHE_TTL = 1800 # 30 minutes

def clear_dashboard_cache(user_id: int = None):
    global dashboard_cache
    if user_id is not None:
        if user_id in dashboard_cache:
            del dashboard_cache[user_id]
    else:
        dashboard_cache.clear()

def get_dashboard_sync(user_id: int, db: Session):
    sections = []
    
    # 0. AI Recommendations (Top Priority if they exist)
    try:
        ai_recs = crud.get_ai_recommendations(db, user_id=user_id)
        if ai_recs:
            rec_items = []
            for rec in ai_recs[:10]: # Top 10
                if rec.song:
                    rec_items.append(schemas.DashboardItem(
                        id=rec.song.id,
                        title=rec.song.title or 'Unknown',
                        subtitle=rec.song.artist or '',
                        image_url=upscale_thumbnail(rec.song.cover_art_url) if rec.song.cover_art_url else None,
                        type="song"
                    ))
            if rec_items:
                sections.append(schemas.DashboardSection(
                    title="✨ AI Recommended for You", 
                    items=rec_items
                ))
    except Exception as e:
        print(f"Error fetching AI recommendations: {e}")
    
    # 0. Bookmarks
    try:
        bookmarks = crud.get_bookmarks(db, user_id=user_id)
        if bookmarks:
            bm_items = []
            for bm in bookmarks:
                bm_items.append(schemas.DashboardItem(
                    id=bm.item_id,
                    title=bm.title,
                    subtitle="Artist" if bm.item_type == "artist" else "Album",
                    image_url=bm.cover_art_url,
                    type=bm.item_type
                ))
            sections.append(schemas.DashboardSection(
                title="Your Bookmarks",
                items=bm_items
            ))
    except Exception as e:
        print(f"Error fetching bookmarks: {e}")
    
    # 1. For You (Personalized Recommendations based on history and favorites)
    seed_video_id = None
    try:
        favs = crud.get_favorites(db, user_id=user_id)
        if favs:
            seed_video_id = favs[0].song_id
        else:
            history = crud.get_history(db, user_id=user_id)
            if history:
                seed_video_id = history[0].song_id
                
        if seed_video_id:
            rec_songs = []
            try:
                watch_playlist = yt.get_watch_playlist(videoId=seed_video_id, radio=True, limit=25)
                tracks = watch_playlist.get('tracks', []) if isinstance(watch_playlist, dict) else []
                for track in tracks[:10]:
                    if isinstance(track, dict) and track.get('videoId') and track['videoId'] != seed_video_id:
                        artist_names = [a['name'] for a in track.get('artists', []) if isinstance(a, dict) and 'name' in a]
                        rec_songs.append(schemas.SongBase(
                            id=track['videoId'],
                            title=track.get('title', 'Unknown'),
                            artist=", ".join(artist_names) if artist_names else "Unknown Artist",
                            album=track.get('album', {}).get('name') if isinstance(track.get('album'), dict) else None,
                            duration_ms=track.get('lengthSeconds', 0) * 1000 if track.get('lengthSeconds') else 0,
                            cover_art_url=extract_thumbnail_url(track)
                        ))
            except Exception:
                pass
                
            # If watch_playlist fails, fall back to searching related music by seed song details
            if not rec_songs:
                seed_song = db.query(models.Song).filter(models.Song.id == seed_video_id).first()
                query = f"{seed_song.artist or ''} {seed_song.title or ''}".strip() if seed_song else "top music"
                try:
                    search_tracks = yt.search(query, filter="songs", limit=10)
                    for track in search_tracks:
                        if isinstance(track, dict) and track.get('videoId') and track['videoId'] != seed_video_id:
                            artist_names = [a['name'] for a in track.get('artists', []) if isinstance(a, dict) and 'name' in a]
                            rec_songs.append(schemas.SongBase(
                                id=track['videoId'],
                                title=track.get('title', 'Unknown'),
                                artist=", ".join(artist_names) if artist_names else "Unknown Artist",
                                album=track.get('album', {}).get('name') if isinstance(track.get('album'), dict) else None,
                                duration_ms=track.get('duration_seconds', 0) * 1000 if track.get('duration_seconds') else 0,
                                cover_art_url=extract_thumbnail_url(track)
                            ))
                except Exception:
                    pass
            
            if rec_songs:
                sections.append(schemas.DashboardSection(
                    title="Recommended For You",
                    items=[schemas.DashboardItem(id=s.id, title=s.title, subtitle=s.artist, image_url=s.cover_art_url, type="song") for s in rec_songs]
                ))
    except Exception as e:
        print(f"Error fetching recommendations: {e}")
            
    # 2. Trending Songs (Hits)
    try:
        trending_tracks = yt.search("Top trending hits", filter="songs", limit=10)
        trending_items = []
        for track in trending_tracks:
            if isinstance(track, dict) and track.get('videoId'):
                artist_names = [a['name'] for a in track.get('artists', []) if isinstance(a, dict) and 'name' in a]
                trending_items.append(schemas.DashboardItem(
                    id=track.get('videoId', ''),
                    title=track.get('title', 'Unknown'),
                    subtitle=", ".join(artist_names) if artist_names else "Trending",
                    image_url=extract_thumbnail_url(track),
                    type="song"
                ))
        if trending_items:
            sections.append(schemas.DashboardSection(title="Trending Hits", items=trending_items))
    except Exception as e:
        print(f"Error fetching trending hits: {e}")


    # 3. Moods & Genres
    try:
        moods = yt.get_mood_categories()
        mood_items = []
        if isinstance(moods, dict):
            for category_group in moods.values():
                if isinstance(category_group, list):
                    for mood in category_group[:5]:
                        if isinstance(mood, dict) and 'params' in mood:
                            mood_items.append(schemas.DashboardItem(
                                id=mood['params'],
                                title=mood.get('title', 'Unknown'),
                                type="mood"
                            ))
                if len(mood_items) > 15:
                    break
        if mood_items:
            sections.append(schemas.DashboardSection(title="Moods & Genres", items=mood_items))
    except Exception as e:
        print(f"Error fetching moods: {e}")

    # 4. Personalized Playlists (Replacing Featured Playlists)
    try:
        history = crud.get_history(db, user_id=user_id, limit=200)
        seed_artists = []
        for h in history:
            if h.song and h.song.artist:
                first_artist = h.song.artist.split(",")[0].strip()
                if first_artist and first_artist not in seed_artists:
                    seed_artists.append(first_artist)
                if len(seed_artists) >= 6:
                    break
        
        if seed_artists:
            for artist in seed_artists:
                results = yt.search(f"{artist}", filter="playlists", limit=5)
                items = []
                for content in results:
                    p_id = content.get('playlistId') or content.get('browseId')
                    if p_id:
                        if p_id.startswith("VL"):
                            p_id = p_id[2:]
                        items.append(schemas.DashboardItem(
                            id=p_id,
                            title=content.get('title', 'Unknown'),
                            subtitle=content.get('author', ''),
                            image_url=extract_thumbnail_url(content),
                            type="playlist"
                        ))
                if items:
                    sections.append(schemas.DashboardSection(title=f"Playlists for fans of {artist}", items=items))
        else:
            # Fallback to generic home
            home = yt.get_home(limit=2)
            for section in home:
                title = section.get('title', 'Featured')
                items = []
                for content in section.get('contents', [])[:10]:
                    if content.get('videoId'):
                        artist_names = [a['name'] for a in content.get('artists', []) if isinstance(a, dict) and 'name' in a]
                        items.append(schemas.DashboardItem(
                            id=content['videoId'],
                            title=content.get('title', 'Unknown'),
                            subtitle=", ".join(artist_names) if artist_names else "",
                            image_url=extract_thumbnail_url(content),
                            type="song"
                        ))
                    elif content.get('playlistId'):
                        items.append(schemas.DashboardItem(
                            id=content['playlistId'],
                            title=content.get('title', 'Unknown'),
                            subtitle=content.get('description'),
                            image_url=extract_thumbnail_url(content),
                            type="playlist"
                        ))
                if items:
                    sections.append(schemas.DashboardSection(title=title, items=items))
    except Exception as e:
        print(f"Error fetching personalized playlists: {e}")

    # 5. Top Artists (Combined)
    try:
        artist_queries = [
            "top telugu artists",
            "top tamil artists",
            "top pop artists"
        ]
        combined_items = []
        for query in artist_queries:
            results = yt.search(query, filter="artists", limit=5)
            for r in results:
                if r.get('browseId') and not any(item.id == r['browseId'] for item in combined_items):
                    combined_items.append(schemas.DashboardItem(
                        id=r['browseId'],
                        title=r.get('artist', 'Unknown'),
                        subtitle="Artist",
                        image_url=extract_thumbnail_url(r),
                        type="artist"
                    ))
        if combined_items:
            import random
            random.shuffle(combined_items)
            sections.append(schemas.DashboardSection(title="Top Artists", items=combined_items))
    except Exception as e:
        print(f"Error fetching top artists: {e}")

    return sections

@router.get("/dashboard/", response_model=List[schemas.DashboardSection])
def get_dashboard(current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    global dashboard_cache
    user_cache = dashboard_cache.get(current_user.id)
    if user_cache and (time.time() - user_cache["timestamp"]) < CACHE_TTL:
        return user_cache["data"]
        
    sections = get_dashboard_sync(current_user.id, db)
    dashboard_cache[current_user.id] = {
        "data": sections,
        "timestamp": time.time()
    }
    return sections

@router.get("/moods/{params}", response_model=List[schemas.DashboardItem])
def get_mood_playlists(params: str):
    try:
        playlists = yt.get_mood_playlists(params)
        items = []
        for p in playlists:
            if 'videoId' in p or 'playlistId' in p:
                items.append(schemas.DashboardItem(
                    id=p.get('playlistId') or p.get('videoId'),
                    title=p.get('title', 'Unknown'),
                    subtitle=p.get('description') or p.get('subtitle', ''),
                    image_url=extract_thumbnail_url(p),
                    type="playlist"
                ))
        return items
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/dashboard/explore/", response_model=List[schemas.DashboardSection])
def get_explore():
    """
    Get the generic explore page using yt.get_home() to show globally trending community playlists, new releases, and moods.
    """
    try:
        sections = []
        home = yt.get_home(limit=8)
        for section in home:
            title = section.get('title', 'Featured')
            items = []
            for content in section.get('contents', [])[:12]:
                if content.get('videoId'):
                    artist_names = [a['name'] for a in content.get('artists', []) if isinstance(a, dict) and 'name' in a]
                    items.append(schemas.DashboardItem(
                        id=content['videoId'],
                        title=content.get('title', 'Unknown'),
                        subtitle=", ".join(artist_names) if artist_names else "",
                        image_url=extract_thumbnail_url(content),
                        type="song"
                    ))
                elif content.get('playlistId'):
                    items.append(schemas.DashboardItem(
                        id=content['playlistId'],
                        title=content.get('title', 'Unknown'),
                        subtitle=content.get('description'),
                        image_url=extract_thumbnail_url(content),
                        type="playlist"
                    ))
                elif content.get('browseId'):
                    items.append(schemas.DashboardItem(
                        id=content['browseId'],
                        title=content.get('title', 'Unknown'),
                        subtitle=content.get('subtitle', ''),
                        image_url=extract_thumbnail_url(content),
                        type="album" if not content.get('browseId').startswith('UC') else "artist"
                    ))
            if items:
                sections.append(schemas.DashboardSection(title=title, items=items))
        return sections
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/bookmarks/", response_model=schemas.BookmarkResponse)
def add_bookmark(bookmark: schemas.BookmarkCreate, current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    # Clear dashboard cache
    global dashboard_cache
    if current_user.id in dashboard_cache:
        del dashboard_cache[current_user.id]
    return crud.add_bookmark(db, bookmark, current_user.id)

@router.get("/bookmarks/", response_model=List[schemas.BookmarkResponse])
def get_bookmarks(current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    return crud.get_bookmarks(db, current_user.id)
