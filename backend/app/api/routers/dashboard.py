from fastapi import APIRouter, Depends
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

router = APIRouter(tags=["dashboard"])

dashboard_cache = {} # user_id -> {"data": sections, "timestamp": float}
CACHE_TTL = 1800 # 30 minutes

def get_dashboard_sync(user_id: int, db: Session):
    sections = []
    
    # 1. For You (Personalized Recommendations based on history and favorites)
    foryou_items = []
    seed_songs = set()
    
    history = crud.get_history(db, user_id=user_id, limit=3)
    favorites = crud.get_favorites(db, user_id=user_id)
    
    if history:
        seed_songs.add(history[0].song_id)
    if favorites:
        seed_songs.add(favorites[-1].song_id)
        
    for seed in list(seed_songs)[:2]: # Use up to 2 seeds
        try:
            watch_playlist = yt.get_watch_playlist(videoId=seed, limit=10)
            for track in watch_playlist.get('tracks', [])[1:6]: # 5 recs per seed
                if track.get('videoId'):
                    # check if already added
                    if not any(i.id == track['videoId'] for i in foryou_items):
                        foryou_items.append(schemas.DashboardItem(
                            id=track['videoId'],
                            title=track.get('title', 'Unknown'),
                            subtitle=", ".join([a['name'] for a in track.get('artists', [])]),
                            image_url=track.get('thumbnail')[-1].get('url') if track.get('thumbnail') else None,
                            type="song"
                        ))
        except Exception as e:
            print(f"Error fetching recommendations for seed {seed}: {e}")
            
    if foryou_items:
        sections.append(schemas.DashboardSection(title="Recommended For You", items=foryou_items))

    
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
                    image_url=track.get('thumbnails')[-1].get('url') if track.get('thumbnails') else None,
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

    # 4. Featured Playlists
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
                        image_url=content.get('thumbnails')[-1].get('url') if content.get('thumbnails') else None,
                        type="song"
                    ))
                elif content.get('playlistId'):
                    items.append(schemas.DashboardItem(
                        id=content['playlistId'],
                        title=content.get('title', 'Unknown'),
                        subtitle=content.get('description'),
                        image_url=content.get('thumbnails')[-1].get('url') if content.get('thumbnails') else None,
                        type="playlist"
                    ))
            if items:
                sections.append(schemas.DashboardSection(title=title, items=items))
    except Exception as e:
        print(f"Error fetching home features: {e}")

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
                    image_url=p.get('thumbnails', [{}])[-1].get('url'),
                    type="playlist"
                ))
        return items
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
