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
from app.api.image_utils import upscale_thumbnail

router = APIRouter(tags=["dashboard"])

dashboard_cache = {} # user_id -> {"data": sections, "timestamp": float}
CACHE_TTL = 1800 # 30 minutes

def get_dashboard_sync(user_id: int, db: Session):
    sections = []
    
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
            watch_playlist = yt.get_watch_playlist(videoId=seed_video_id)
            rec_songs = []
            for track in watch_playlist.get('tracks', [])[:10]:
                if track.get('videoId') and track['videoId'] != seed_video_id:
                    rec_songs.append(schemas.SongBase(
                        id=track['videoId'],
                        title=track.get('title', 'Unknown'),
                        artist=", ".join([a['name'] for a in track.get('artists', [])]),
                        album=track.get('album', {}).get('name') if track.get('album') else None,
                        duration_ms=track.get('lengthSeconds', 0) * 1000 if track.get('lengthSeconds') else 0,
                        cover_art_url=upscale_thumbnail(track.get('thumbnail', [{}])[-1].get('url')) if track.get('thumbnail') else None
                    ))
            
            if rec_songs:
                sections.append(schemas.DashboardSection(
                    title="Recommended For You",
                    items=[schemas.DashboardItem(id=s.id, title=s.title, subtitle=s.artist, image_url=s.cover_art_url, type="song") for s in rec_songs]
                ))
    except Exception as e:
        print(f"Error fetching recommendations for seed {seed_video_id}: {e}")
            
    # 2. Trending Songs (Charts)
    try:
        charts = yt.get_charts(country='US')
        trending_items = []
        if 'trending' in charts and 'items' in charts['trending']:
            for track in charts['trending']['items'][:10]:
                trending_items.append(schemas.DashboardItem(
                    id=track['videoId'],
                    title=track.get('title', 'Unknown'),
                    subtitle=", ".join([a['name'] for a in track.get('artists', [])]),
                    image_url=upscale_thumbnail(track.get('thumbnails', [{}])[-1].get('url')) if track.get('thumbnails') else None,
                    type="song"
                ))
            if trending_items:
                sections.append(schemas.DashboardSection(title="Trending Hits", items=trending_items))
    except Exception as e:
        print(f"Error fetching charts: {e}")

    # 3. Moods & Genres
    try:
        moods = yt.get_mood_categories()
        mood_items = []
        for category_group in moods.values():
            for mood in category_group[:5]:
                mood_items.append(schemas.DashboardItem(
                    id=mood['params'],
                    title=mood['title'],
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
        history = crud.get_history(db, user_id=user_id, limit=50)
        seed_artists = []
        for h in history:
            if h.song and h.song.artist:
                first_artist = h.song.artist.split(",")[0].strip()
                if first_artist and first_artist not in seed_artists:
                    seed_artists.append(first_artist)
                if len(seed_artists) >= 2:
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
                            image_url=upscale_thumbnail(content.get('thumbnails')[-1].get('url')) if content.get('thumbnails') else None,
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
                        items.append(schemas.DashboardItem(
                            id=content['videoId'],
                            title=content.get('title', 'Unknown'),
                            subtitle=", ".join([a['name'] for a in content.get('artists', [])]) if content.get('artists') else "",
                            image_url=upscale_thumbnail(content.get('thumbnails')[-1].get('url')) if content.get('thumbnails') else None,
                            type="song"
                        ))
                    elif content.get('playlistId'):
                        items.append(schemas.DashboardItem(
                            id=content['playlistId'],
                            title=content.get('title', 'Unknown'),
                            subtitle=content.get('description'),
                            image_url=upscale_thumbnail(content.get('thumbnails')[-1].get('url')) if content.get('thumbnails') else None,
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
                        image_url=upscale_thumbnail(r.get('thumbnails', [{}])[-1].get('url')) if r.get('thumbnails') else None,
                        type="artist"
                    ))
        if combined_items:
            # Shuffle or just return them
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
                    image_url=upscale_thumbnail(p.get('thumbnails', [{}])[-1].get('url')),
                    type="playlist"
                ))
        return items
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/explore/", response_model=List[schemas.DashboardSection])
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
                    items.append(schemas.DashboardItem(
                        id=content['videoId'],
                        title=content.get('title', 'Unknown'),
                        subtitle=", ".join([a['name'] for a in content.get('artists', [])]) if content.get('artists') else "",
                        image_url=upscale_thumbnail(content.get('thumbnails')[-1].get('url')) if content.get('thumbnails') else None,
                        type="song"
                    ))
                elif content.get('playlistId'):
                    items.append(schemas.DashboardItem(
                        id=content['playlistId'],
                        title=content.get('title', 'Unknown'),
                        subtitle=content.get('description'),
                        image_url=upscale_thumbnail(content.get('thumbnails')[-1].get('url')) if content.get('thumbnails') else None,
                        type="playlist"
                    ))
                elif content.get('browseId'):
                    items.append(schemas.DashboardItem(
                        id=content['browseId'],
                        title=content.get('title', 'Unknown'),
                        subtitle=content.get('subtitle', ''),
                        image_url=upscale_thumbnail(content.get('thumbnails')[-1].get('url')) if content.get('thumbnails') else None,
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
